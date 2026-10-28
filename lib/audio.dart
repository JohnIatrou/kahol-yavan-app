import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'api.dart';
import 'config.dart';

const kLiveId = 'live';
const _kArchiveId = 'archive';
const _kShowPrefix = 'show-';
const _kEpisodePrefix = 'ep-';

/// One player for the live stream and the archive episodes. Through audio_service it keeps playing with the
/// screen off, shows lock-screen / notification controls, and answers the TV remote and headphone buttons.
///
/// It also answers Android Auto: the live stream and the archive (shows → episodes) to browse from the car.
///
/// When the connection drops it keeps trying until the audio is back ([reconnecting] is true meanwhile), and it
/// gives way to phone calls and other apps' audio, then plays again when they are done.
class RadioHandler extends BaseAudioHandler with SeekHandler {
  RadioHandler({Api? api}) : _api = api ?? Api() {
    _player.playbackEventStream.listen((_) {
      if (!isLive && _player.position > Duration.zero) _resumeAt = _player.position;
      _broadcast();
    }, onError: (Object _, StackTrace _) => _lost());
    _player.playingStream.listen((_) => _broadcast());
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.ready && _player.playing) _recovered();
      if (s == ProcessingState.completed) {
        // A live stream never ends on its own: the server dropped us.
        isLive ? _lost() : stop();
      }
      _broadcast();
    });
    if (!kIsWeb) unawaited(_listenToOtherAudio());
  }

  // Interruptions are handled here rather than by just_audio, so a live stream restarts from now after a call.
  final _player = AudioPlayer(handleInterruptions: false);

  /// True while the connection is lost and the player keeps trying to get the audio back.
  final reconnecting = ValueNotifier<bool>(false);

  // The listener asked for audio and hasn't paused it: drops of the connection are retried while this holds.
  bool _want = false;
  int _attempt = 0;
  Timer? _retry;
  Timer? _watchdog;

  DateTime? _stuckSince;
  // Where an episode was when the connection dropped, to carry on from there.
  Duration? _resumeAt;
  // Paused for a call or another app's audio, to play again when it ends.
  bool _interrupted = false;
  Timer? _waitForQuiet;
  final Api _api;
  // Episodes seen while browsing in the car, so a tap on one can play it.
  final _episodes = <String, Episode>{};
  AppConfig _config = AppConfig.fallback;
  Episode? _episode;

  AudioPlayer get player => _player;
  bool get isLive => mediaItem.value?.id == kLiveId;
  Episode? get episode => isLive ? null : _episode;

  void setConfig(AppConfig c) => _config = c;

  Future<void> playLive({Song? now, String program = ''}) {
    _episode = null;
    _resumeAt = null;
    return _start(_liveItem(now, program), _config.stream);
  }

  // Bumped on every switch, so a slow load of an earlier choice can't start playing over the newer one.
  int _switch = 0;

  /// Stops whatever plays now (live or an episode) and starts [url] in its place.
  Future<void> _start(MediaItem item, String url, {Duration? at}) async {
    _watch();
    final mine = ++_switch;
    _want = true;
    _endInterruption();
    mediaItem.add(item);
    try {
      await _player.stop();
      if (mine != _switch) return;
      await _player.setUrl(url, initialPosition: at);
      if (mine != _switch) return;
      unawaited(_player.play().catchError((Object _) => _lost()));
    } catch (_) {
      if (mine == _switch) _lost();
    }
  }

  String get _url => isLive ? _config.stream : _episode?.audio ?? '';

  /// The audio stopped coming (no network, the server dropped the stream, a load failed): try again in a moment,
  /// a little longer each time, up to 15 seconds apart, for as long as the listener wants to hear.
  void _lost() {
    if (!_want || _retry?.isActive == true || _url.isEmpty) return;
    reconnecting.value = true;
    _stuckSince = null;
    final wait = Duration(seconds: [2, 3, 5, 8, 12, 15][_attempt.clamp(0, 5)]);
    _attempt++;
    _retry = Timer(wait, _reconnect);
    _broadcast();
  }

  Future<void> _reconnect() async {
    if (!_want) return;
    final item = mediaItem.value;
    if (item == null) return;
    await _start(item, _url, at: isLive ? null : _resumeAt);
  }

  void _recovered() {
    _retry?.cancel();
    _attempt = 0;
    _stuckSince = null;
    reconnecting.value = false;
  }

  // Loading or buffering for 20 seconds with no sound: the connection hangs without failing, so start it again.
  void _checkStuck() {
    final s = _player.processingState;
    if (!_want || reconnecting.value || !(s == ProcessingState.loading || s == ProcessingState.buffering)) {
      _stuckSince = null;
      return;
    }
    _stuckSince ??= DateTime.now();
    if (DateTime.now().difference(_stuckSince!) > const Duration(seconds: 20)) _lost();
  }

  void _watch() => _watchdog ??= Timer.periodic(const Duration(seconds: 5), (_) => _checkStuck());

  void _giveUp() {
    _want = false;
    _watchdog?.cancel();
    _watchdog = null;
    _retry?.cancel();
    _attempt = 0;
    _stuckSince = null;
    reconnecting.value = false;
  }

  /// Calls and other apps' audio. A call or a voice message asks for the sound for a while and gives it back, and
  /// the radio plays on when it does. An app that takes the sound for good (a video, another player) gives nothing
  /// back, so the radio waits until no other audio has played for a few seconds and no call is on, then plays on.
  Future<void> _listenToOtherAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.becomingNoisyEventStream.listen((_) => pause()); // Headphones unplugged.
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.3);
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _interrupt(waitForQuiet: event.type == AudioInterruptionType.unknown);
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1);
            case AudioInterruptionType.pause:
              if (_interrupted) _resumeAfterInterruption();
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (_) {}
  }

  void _interrupt({required bool waitForQuiet}) {
    if (!_want) return;
    final wasLive = isLive;
    _giveUp();
    _interrupted = true;
    // A live stream is stopped, not paused, so it comes back at what is on air now.
    wasLive ? _player.stop() : _player.pause();
    _broadcast();
    _waitForQuiet?.cancel();
    if (!waitForQuiet) return;
    final am = AndroidAudioManager();
    var quiet = 0;
    var checks = 0;
    _waitForQuiet = Timer.periodic(const Duration(seconds: 3), (t) async {
      // Give up after half an hour: by then the listener has moved on.
      if (!_interrupted || ++checks > 600) {
        _endInterruption();
        return _broadcast();
      }
      try {
        final busy = await am.isMusicActive() || await am.getMode() != AndroidAudioHardwareMode.normal;
        quiet = busy ? 0 : quiet + 1;
        if (quiet >= 2) _resumeAfterInterruption();
      } catch (_) {
        _endInterruption();
      }
    });
  }

  void _resumeAfterInterruption() {
    _endInterruption();
    play();
  }

  void _endInterruption() {
    _interrupted = false;
    _waitForQuiet?.cancel();
  }

  /// The song on air changed: update the lock screen / notification while the live stream plays.
  void updateLive(Song? now, String program) {
    if (isLive) mediaItem.add(_liveItem(now, program));
  }

  Future<void> playEpisode(Episode e) {
    _episode = e;
    _resumeAt = null;
    return _start(_episodeItem(e), e.audio);
  }

  /// A second press on the episode already loaded pauses or resumes it instead of starting it over.
  Future<void> toggleEpisode(Episode e) {
    if (!isLive && _episode?.id == e.id && _player.processingState != ProcessingState.idle) {
      return _player.playing ? pause() : play();
    }
    return playEpisode(e);
  }

  MediaItem _episodeItem(Episode e) => MediaItem(
        id: '$_kEpisodePrefix${e.id}',
        title: e.title,
        album: _config.name,
        artist: e.label,
        artUri: e.picture.isNotEmpty ? Uri.tryParse(e.picture) : null,
        duration: e.duration > 0 ? Duration(seconds: e.duration.round()) : null,
        playable: true,
      );

  // Android Auto: the car's media browser.
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    try {
      if (parentMediaId == AudioService.browsableRootId) {
        return [
          MediaItem(
            id: kLiveId,
            title: 'שידור חי',
            album: _config.name,
            artist: _config.name,
            artUri: Uri.parse(kLogoUrl),
            playable: true,
            isLive: true,
          ),
          const MediaItem(id: _kArchiveId, title: 'ארכיון התוכניות', playable: false),
        ];
      }
      if (parentMediaId == AudioService.recentRootId) return [?mediaItem.value];
      if (parentMediaId == _kArchiveId) {
        return [
          for (final s in await _api.shows())
            if (s.count > 0)
              MediaItem(
                id: '$_kShowPrefix${s.id}',
                title: s.name,
                artist: s.when,
                artUri: s.picture.isNotEmpty ? Uri.tryParse(s.picture) : null,
                playable: false,
              ),
        ];
      }
      if (parentMediaId.startsWith(_kShowPrefix)) {
        final page = await _api.episodes(show: int.parse(parentMediaId.substring(_kShowPrefix.length)));
        return [
          for (final e in page.episodes)
            if (e.playable) _episodeItem(_remember(e)),
        ];
      }
    } catch (_) {}
    return const [];
  }

  Episode _remember(Episode e) => _episodes['$_kEpisodePrefix${e.id}'] = e;

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final e = _episodes[mediaId];
    if (e != null) return playEpisode(e);
    if (mediaId == kLiveId) return playLive();
  }

  // The car's voice search ("play Kahol Yavan") starts the live stream.
  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) => playLive();

  MediaItem _liveItem(Song? now, String program) => MediaItem(
        id: kLiveId,
        title: now?.title.isNotEmpty == true ? now!.title : _config.name,
        artist: now?.artist.isNotEmpty == true ? now!.artist : 'שידור חי',
        album: program.isNotEmpty ? program : _config.name,
        artUri: now?.cover.isNotEmpty == true ? Uri.tryParse(now!.cover) : null,
        isLive: true,
      );

  @override
  Future<void> play() async {
    final item = mediaItem.value;
    if (item == null) return playLive();
    // Back to live after a pause, or after a failed load: start the stream again.
    if (_player.processingState == ProcessingState.idle || reconnecting.value) {
      return _start(item, _url, at: isLive ? null : _resumeAt);
    }
    _want = true;
    _watch();
    _endInterruption();
    _broadcast();
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _giveUp();
    _endInterruption();
    if (isLive) {
      // A paused live stream would play old audio later; stop the connection instead.
      await _player.stop();
    } else {
      await _player.pause();
    }
    _broadcast();
  }

  @override
  Future<void> stop() async {
    _giveUp();
    _endInterruption();
    await _player.stop();
    _broadcast();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() => _skip(30);

  @override
  Future<void> rewind() => _skip(-15);

  Future<void> _skip(int seconds) async {
    if (isLive) return;
    final d = _player.duration;
    var p = _player.position + Duration(seconds: seconds);
    if (p < Duration.zero) p = Duration.zero;
    if (d != null && p > d) p = d;
    await _player.seek(p);
  }

  void _broadcast() {
    // While reconnecting, or waiting out a call, the player still counts as playing: the notification stays, and
    // with it the app keeps running in the background to get the sound back.
    final retrying = reconnecting.value || _interrupted;
    final playing = _player.playing || retrying;
    final live = isLive;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (!live) MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        if (!live) MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: live
          ? const {MediaAction.playPause}
          : const {MediaAction.seek, MediaAction.playPause, MediaAction.fastForward, MediaAction.rewind},
      androidCompactActionIndices: live ? const [0] : const [0, 1, 2],
      processingState: retrying
          ? AudioProcessingState.buffering
          : const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }
}
