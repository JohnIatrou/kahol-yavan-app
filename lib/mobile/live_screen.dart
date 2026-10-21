import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../config.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// "שידור חי": the player and the whole radio board, as on the site's radio page.
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = Scope.of(context);
    final st = scope.state;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final s = st.studio;
        return RefreshIndicator(
          onRefresh: () => Future.wait([st.refreshStudio(), st.loadShows()]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const LivePlayerCard(),
              const SizedBox(height: 16),
              if (s.recent.isNotEmpty)
                Panel(title: 'שודרו לאחרונה', child: Column(children: s.recent.take(8).map((x) => SongTile(song: x)).toList())),
              if (s.most.isNotEmpty)
                Panel(
                  title: 'הכי מושמעים השבוע',
                  mark: Ly.fresh,
                  child: Column(children: s.most.take(10).map((x) => SongTile(song: x, trailing: x.count > 0 ? '${x.count} השמעות' : null)).toList()),
                ),
              if (s.top.isNotEmpty)
                Panel(title: 'טופ 5 – המצעד היווני', mark: Ly.live, child: Column(children: s.top.take(5).map((x) => SongTile(song: x)).toList())),
              if (s.fresh.isNotEmpty)
                Panel(title: 'שירים חדשים בפלייליסט', mark: Ly.wa, child: Column(children: s.fresh.take(10).map((x) => SongTile(song: x)).toList())),
              if (st.schedule.isNotEmpty) const SchedulePanel(),
              if (st.config.platforms.isNotEmpty)
                Panel(
                  title: 'האזנה גם ב…',
                  mark: Ly.muted,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: st.config.platforms
                        .map((p) => ActionChip(label: Text(p.name), onPressed: () => openUrl(p.url), backgroundColor: Ly.card))
                        .toList(),
                  ),
                ),
              Center(
                child: TextButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(
                    text: 'מאזינים לרדיו כחול יוון – מוזיקה יוונית 24 שעות:\n$kPlayStoreUrl\n$kAppStoreUrl',
                  )),
                  icon: const Icon(Icons.share),
                  label: const Text('שתפו את האפליקציה'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LivePlayerCard extends StatelessWidget {
  const LivePlayerCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild on every board refresh: a const widget is not rebuilt by its parent.
    final st = Scope.of(context).state;
    return ListenableBuilder(listenable: st, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final scope = Scope.of(context);
    final st = scope.state;
    final s = st.studio;
    final now = s.now;
    final c = st.config;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Ly.panel, Ly.night], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Ly.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const LiveBadge(),
                const SizedBox(width: 8),
                Flexible(child: Text(c.name, style: const TextStyle(color: Ly.sky, fontWeight: FontWeight.w800))),
              ]),
              if (s.program.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('• ${s.program}', style: const TextStyle(color: Ly.muted, fontSize: 13)),
              ],
              const SizedBox(height: 10),
              const Text('עכשיו בשידור', style: TextStyle(color: Ly.muted, fontSize: 12)),
              Text(
                now?.title ?? 'מוזיקה יוונית 24 שעות',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15),
              ),
              if (now?.isNew == true) const Padding(padding: EdgeInsets.only(top: 4), child: Pill('חדש')),
              if (now?.artist.isNotEmpty == true)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(now!.artist, style: const TextStyle(color: Color(0xFFC9D2E8), fontSize: 15))),
            ]),
          ),
          const SizedBox(width: 12),
          Stack(clipBehavior: Clip.none, children: [
            now?.cover.isNotEmpty == true ? Artwork(url: now!.cover, size: 112, radius: 18, seed: now.title) : const StationLogo(size: 112),
            if (now?.cover.isNotEmpty == true) const Positioned(bottom: -8, left: -8, child: StationLogo(size: 38)),
          ]),
        ]),
        _SongProgress(studio: s),
        const Divider(color: Ly.line, height: 28),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.hostsNames, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Pill(c.hostsWhen, size: 13),
            ]),
          ),
          if (c.hostsImg.isNotEmpty)
            Container(
              decoration: BoxDecoration(border: Border.all(color: Ly.sky, width: 2), borderRadius: BorderRadius.circular(14)),
              child: Artwork(url: c.hostsImg, size: 96, radius: 12),
            ),
        ]),
        const Divider(color: Ly.line, height: 28),
        const Center(child: LivePlayButton(size: 84)),
        if (s.nextName.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Ly.cream, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Pill('התכנית הבאה', color: Color(0xFFFFE3A3)),
              const SizedBox(width: 10),
              Expanded(child: Text(s.nextName, style: const TextStyle(color: Ly.night, fontWeight: FontWeight.w800))),
              Text(s.nextStart, style: const TextStyle(color: Ly.night)),
            ]),
          ),
        ],
        if (st.offline)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('אין חיבור לאתר כרגע. השידור עדיין זמין.', textAlign: TextAlign.center, style: TextStyle(color: Ly.muted, fontSize: 12)),
          ),
      ]),
    );
  }
}

class _SongProgress extends StatelessWidget {
  const _SongProgress({required this.studio});
  final Studio studio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final p = studio.progress(DateTime.now());
        if (p == null) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: p, minHeight: 4, backgroundColor: Ly.line, color: Ly.sky),
          ),
        );
      },
    );
  }
}

/// Play / stop of the live stream. When an archive episode plays, this switches back to live.
class LivePlayButton extends StatelessWidget {
  const LivePlayButton({super.key, this.size = 80, this.autofocus = false});
  final double size;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scope = Scope.of(context);
    final audio = scope.audio;
    return StreamBuilder<PlaybackState>(
      stream: audio.playbackState,
      builder: (context, snap) {
        final ps = snap.data;
        final live = audio.isLive;
        final playing = live && (ps?.playing ?? false);
        final loading = live &&
            (ps?.processingState == AudioProcessingState.loading || ps?.processingState == AudioProcessingState.buffering);
        return Semantics(
          button: true,
          label: playing ? 'עצירת השידור החי' : 'האזנה לשידור החי',
          child: Material(
            color: Ly.sky,
            shape: CircleBorder(side: BorderSide(color: Ly.sky.withValues(alpha: 0.3), width: size * 0.08)),
            child: InkWell(
              autofocus: autofocus,
              customBorder: const CircleBorder(),
              focusColor: Colors.white24,
              onTap: () {
                if (playing) {
                  audio.pause();
                } else {
                  audio.playLive(now: scope.state.studio.now, program: scope.state.studio.program);
                }
              },
              child: SizedBox(
                width: size,
                height: size,
                child: loading
                    ? Padding(padding: EdgeInsets.all(size * 0.28), child: const CircularProgressIndicator(color: Ly.night, strokeWidth: 4))
                    : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Ly.night, size: size * 0.6),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SchedulePanel extends StatelessWidget {
  const SchedulePanel({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild on every board refresh: a const widget is not rebuilt by its parent.
    final st = Scope.of(context).state;
    return ListenableBuilder(listenable: st, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final st = Scope.of(context).state;
    final today = DateTime.now().weekday % 7;
    return Panel(
      title: 'לוח התכניות',
      mark: Ly.aegean,
      child: Column(
        children: st.schedule.map((show) {
          final isToday = show.day == today;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isToday ? Ly.sky.withValues(alpha: 0.12) : Ly.card,
              border: isToday ? Border.all(color: Ly.sky.withValues(alpha: 0.5)) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Column(children: [
                  Text(isToday ? 'היום' : 'יום ${kDayNames[show.day!]}', style: const TextStyle(color: Ly.muted, fontSize: 12)),
                  Text(show.start, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
              ),
              const SizedBox(width: 8),
              Artwork(url: show.picture, size: 44, radius: 22, seed: show.name),
              const SizedBox(width: 10),
              Expanded(child: Text(show.name, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (show.end.isNotEmpty) Text('עד ${show.end}', style: const TextStyle(color: Ly.muted, fontSize: 12)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}
