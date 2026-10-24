import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/news.dart';
import 'archive_screen.dart';
import 'live_screen.dart';
import 'more_screen.dart';
import 'updates_screen.dart';

class MobileHome extends StatefulWidget {
  const MobileHome({super.key});

  @override
  State<MobileHome> createState() => MobileHomeState();
}

class MobileHomeState extends State<MobileHome> {
  int _tab = 0;

  void showTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context).state;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(children: [
          StationLogo(size: 34),
          SizedBox(width: 10),
          Text('רדיו כחול יוון', style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
        actions: [
          ListenableBuilder(
            listenable: st,
            builder: (context, _) => st.config.minBuild > kBuild
                ? TextButton(onPressed: () => openUrl(kPlayStoreUrl), child: const Text('יש גרסה חדשה'))
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(children: [
        const NewsTicker(),
        Expanded(
          child: IndexedStack(index: _tab, children: [
            const LiveScreen(),
            const ArchiveScreen(),
            PostsScreen.magazine(),
            PostsScreen.updates(),
            const MoreScreen(),
          ]),
        ),
      ]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const MiniPlayer(),
        NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: showTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.sensors), label: 'שידור חי'),
            NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'ארכיון'),
            NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories), label: 'מגזין'),
            NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'עדכונים'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'עוד'),
          ],
        ),
      ]),
    );
  }
}

/// The bar above the tabs while something plays: what is playing, play/pause, and the full player for episodes.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = Scope.of(context).audio;
    return StreamBuilder<MediaItem?>(
      stream: audio.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) return const SizedBox.shrink();
        return StreamBuilder<PlaybackState>(
          stream: audio.playbackState,
          builder: (context, ps) {
            final state = ps.data;
            if (state == null || state.processingState == AudioProcessingState.idle && !state.playing && audio.isLive) {
              return const SizedBox.shrink();
            }
            return Material(
              color: Ly.panel,
              child: InkWell(
                onTap: audio.isLive ? null : () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Ly.night, builder: (_) => const EpisodePlayer()),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(children: [
                    if (item.isLive == true) const LiveBadge() else Artwork(url: item.artUri?.toString() ?? '', size: 40, radius: 8, seed: item.title),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Ly.muted, fontSize: 12)),
                      ]),
                    ),
                    IconButton(
                      onPressed: state.playing ? audio.pause : audio.play,
                      icon: Icon(state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                    ),
                    IconButton(onPressed: audio.stop, icon: const Icon(Icons.close)),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Full player for an archive episode: position, −15 / +30 seconds, speed.
class EpisodePlayer extends StatelessWidget {
  const EpisodePlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = Scope.of(context).audio;
    final player = audio.player;
    final e = audio.episode;
    if (e == null) return const SizedBox(height: 120);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Ly.line, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Artwork(url: e.picture, size: 200, radius: 24, seed: e.title),
          const SizedBox(height: 16),
          Text(e.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(e.label, style: const TextStyle(color: Ly.muted)),
          const SizedBox(height: 12),
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = player.duration ?? Duration(seconds: e.duration.round());
              final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
              return Column(children: [
                Slider(value: pos.inMilliseconds.clamp(0, max).toDouble(), max: max, onChanged: (v) => audio.seek(Duration(milliseconds: v.round()))),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(fmtDuration(pos), style: const TextStyle(color: Ly.muted)),
                  Text(fmtDuration(dur), style: const TextStyle(color: Ly.muted)),
                ]),
              ]);
            },
          ),
          StreamBuilder<bool>(
            stream: player.playingStream,
            builder: (context, snap) {
              final playing = snap.data ?? false;
              return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(onPressed: audio.rewind, child: const Text('\u200E−15', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                IconButton.filled(
                  iconSize: 48,
                  onPressed: playing ? audio.pause : audio.play,
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: audio.fastForward, child: const Text('+30', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              ]);
            },
          ),
          StreamBuilder<double>(
            stream: player.speedStream,
            builder: (context, snap) {
              final sp = snap.data ?? 1;
              return TextButton(
                onPressed: () => player.setSpeed(sp >= 1.5 ? 1 : sp + 0.25),
                child: Text('מהירות ${sp.toStringAsFixed(sp % 1 == 0 ? 0 : 2)}×'),
              );
            },
          ),
        ]),
      ),
    );
  }
}
