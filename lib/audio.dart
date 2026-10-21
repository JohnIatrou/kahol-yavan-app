import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'api.dart';

const kLiveId = 'live';

/// One player for the live stream and the archive episodes. Through audio_service it keeps playing with the
/// screen off, shows lock-screen / notification controls, and answers the TV remote and headphone buttons.
class RadioHandler extends BaseAudioHandler with SeekHandler {
  RadioHandler() {
    _player.playbackEventStream.listen((_) => _broadcast());
    _player.playingStream.listen((_) => _broadcast());
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && !isLive) stop();
      _broadcast();
    });
  }

  final _player = AudioPlayer();
  AppConfig _config = AppConfig.fallback;
  Episode? _episode;

  AudioPlayer get player => _player;
  bool get isLive => mediaItem.value?.id == kLiveId;
  Episode? get episode => isLive ? null : _episode;

  void setConfig(AppConfig c) => _config = c;

  Future<void> playLive({Song? now, String program = ''}) async {
    _episode = null;
    mediaItem.add(_liveItem(now, program));
    try {
      await _player.setUrl(_config.stream);
      await _player.play();
    } catch (_) {
      _broadcast(error: true);
    }
  }

  /// The song on air changed: update the lock screen / notification while the live stream plays.
  void updateLive(Song? now, String program) {
    if (isLive) mediaItem.add(_liveItem(now, program));
  }

  Future<void> playEpisode(Episode e) async {
    _episode = e;
    mediaItem.add(MediaItem(
      id: 'ep-${e.id}',
      title: e.title,
      album: _config.name,
      artist: e.label,
      artUri: e.picture.isNotEmpty ? Uri.tryParse(e.picture) : null,
      duration: e.duration > 0 ? Duration(seconds: e.duration.round()) : null,
    ));
    try {
      await _player.setUrl(e.audio);
      await _player.play();
    } catch (_) {
      _broadcast(error: true);
    }
  }

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
