import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../schedule.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/playlists.dart';
import 'archive_screen.dart';
import 'home.dart';

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
              ArchiveStrip(onAll: () => context.findAncestorStateOfType<MobileHomeState>()?.showTab(1)),
              const PlaylistsStrip(inset: 0),
              const SizedBox(height: 8),
              if (s.recent.isNotEmpty)
                Panel(title: 'שודרו לאחרונה', child: Column(children: s.recent.take(8).map((x) => SongTile(song: x)).toList())),
              if (s.most.isNotEmpty)
                Panel(
                  title: 'הכי מושמעים השבוע',
                  mark: Ly.fresh,
                  child: Column(children: s.most.take(10).map((x) => SongTile(song: x, trailing: x.count > 0 ? '${x.count} השמעות' : null)).toList()),
                ),
              if (s.fresh.isNotEmpty)
                Panel(title: 'שירים חדשים בפלייליסט', mark: Ly.wa, child: Column(children: s.fresh.take(10).map((x) => SongTile(song: x)).toList())),
              const SchedulePanel(),
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
    final clock = DateTime.now();
    final next = nextSlot(clock);
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
              if (now?.hebrew.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('"${now!.hebrew}"', style: const TextStyle(color: Ly.sky, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              if (now?.youtube.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => openUrl(now!.youtube),
                    icon: const Icon(Icons.smart_display, color: Color(0xFFFF4E45), size: 20),
                    label: const Text('לשיר ביוטיוב'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Ly.line),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          NowCover(song: now, size: 140),
        ]),
        SongProgress(studio: s),
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
        const ConnectionNotice(),
        if (next != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Ly.cream, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Pill('התכנית הבאה', color: Color(0xFFFFE3A3)),
              const SizedBox(width: 10),
              Expanded(child: Text(next.$1.name, style: const TextStyle(color: Ly.night, fontWeight: FontWeight.w800))),
              const SizedBox(width: 8),
              Text(whenLabel(next.$2, clock), style: const TextStyle(color: Ly.night)),
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
    // Rebuild on every board refresh, so "now" and "today" follow the clock.
    final st = Scope.of(context).state;
    return ListenableBuilder(listenable: st, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final now = DateTime.now();
    final today = now.weekday % 7;
    final onAir = currentSlot(now);
    return Panel(
      title: 'לוח התכניות',
      mark: Ly.aegean,
      child: Column(
        children: kSchedule.map((slot) {
          final live = identical(slot, onAir);
          final isToday = slot.days.contains(today);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: live ? Ly.sky.withValues(alpha: 0.2) : isToday ? Ly.sky.withValues(alpha: 0.08) : Ly.card,
              border: live ? Border.all(color: Ly.sky) : isToday ? Border.all(color: Ly.sky.withValues(alpha: 0.4)) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              SizedBox(
                width: 78,
                child: Column(children: [
                  Text(slot.daysLabel, style: TextStyle(color: isToday ? Ly.sky : Ly.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(slot.start, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('עד ${slot.end}', style: const TextStyle(color: Ly.muted, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(slot.name, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25))),
              if (live) const Padding(padding: EdgeInsetsDirectional.only(start: 8), child: Pill('עכשיו')),
            ]),
          );
        }).toList(),
      ),
    );
  }
}
