import 'package:audio_service/audio_service.dart';
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
class RadioHandler extends BaseAudioHandler with SeekHandler {
  RadioHandler({Api? api}) : _api = api ?? Api() {
    _player.playbackEventStream.listen((_) => _broadcast());
    _player.playingStream.listen((_) => _broadcast());
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && !isLive) stop();
      _broadcast();
    });
  }

  final _player = AudioPlayer();
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
    return _start(_liveItem(now, program), _config.stream);
  }

  // Bumped on every switch, so a slow load of an earlier choice can't start playing over the newer one.
  int _switch = 0;

  /// Stops whatever plays now (live or an episode) and starts [url] in its place.
  Future<void> _start(MediaItem item, String url) async {
    final mine = ++_switch;
    mediaItem.add(item);
    try {
      await _player.stop();
      if (mine != _switch) return;
      await _player.setUrl(url);
      if (mine != _switch) return;
      _player.play();
    } catch (_) {
      if (mine == _switch) _broadcast(error: true);
    }
  }

  /// The song on air changed: update the lock screen / notification while the live stream plays.
  void updateLive(Song? now, String program) {
    if (isLive) mediaItem.add(_liveItem(now, program));
  }

  Future<void> playEpisode(Episode e) {
    _episode = e;
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
    if (mediaItem.value == null) return playLive();
    // Back to live after a pause: start from now, not from where the buffer stopped.
    if (isLive && _player.processingState == ProcessingState.idle) {
      await _player.setUrl(_config.stream);
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (isLive) {
      // A paused live stream would play old audio later; stop the connection instead.
      await _player.stop();
    } else {
      await _player.pause();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
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

  void _broadcast({bool error = false}) {
    final playing = _player.playing;
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
      processingState: error
          ? AudioProcessingState.error
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
