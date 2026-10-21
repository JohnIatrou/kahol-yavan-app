import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'tv_show_screen.dart';
import 'tv_widgets.dart';

/// Android TV / Google TV: the live stream fills the top, rows of the radio board and the archive below.
/// Everything is reached with the remote's arrows and OK; the play/pause button works too.
class TvHome extends StatelessWidget {
  const TvHome({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context).state;
    return Scaffold(
      body: Column(children: [
        Expanded(
          child: ListenableBuilder(
            listenable: st,
            builder: (context, _) {
              final s = st.studio;
              return ListView(
                padding: const EdgeInsets.only(top: 32, bottom: 24),
                children: [
                  const _Hero(),
                  const SizedBox(height: 28),
                  TvRow(
                    title: 'התכניות בארכיון',
                    height: 240,
                    children: st.shows.map((sh) => _ShowCard(show: sh)).toList(),
                  ),
                  const _LatestEpisodes(),
                  TvRow(title: 'שודרו לאחרונה', height: 200, children: s.recent.map(_song).toList()),
                  TvRow(title: 'הכי מושמעים השבוע', height: 200, children: s.most.map(_song).toList()),
                  TvRow(
                    title: 'טופ 5 – המצעד היווני',
                    height: 200,
                    children: s.top.take(5).map((x) => TvSongCard(title: x.title, artist: x.artist, cover: x.cover, badge: '#${x.rank}')).toList(),
                  ),
                  TvRow(title: 'שירים חדשים', height: 200, children: s.fresh.map(_song).toList()),
                  TvRow(title: 'לוח התכניות', height: 130, children: st.schedule.map((sh) => _ScheduleCard(show: sh)).toList()),
                ],
              );
            },
          ),
        ),
        const TvEpisodeBar(),
      ]),
    );
  }

  static Widget _song(Song x) => TvSongCard(title: x.title, artist: x.artist, cover: x.cover, badge: x.isNew ? 'חדש' : null);
}

class _Hero extends StatelessWidget {
  const _Hero();

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
      margin: const EdgeInsets.symmetric(horizontal: 48),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Ly.panel, Ly.night], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Ly.line),
      ),
      child: Row(children: [
        now?.cover.isNotEmpty == true ? Artwork(url: now!.cover, size: 150, radius: 22, seed: now.title) : const StationLogo(size: 150),
        const SizedBox(width: 32),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const LiveBadge(big: true),
              Text(c.name, style: const TextStyle(color: Ly.sky, fontSize: 24, fontWeight: FontWeight.w800)),
              if (s.program.isNotEmpty) Text('•  ${s.program}', style: const TextStyle(color: Ly.muted, fontSize: 18)),
            ]),
            const SizedBox(height: 16),
            const Text('עכשיו בשידור', style: TextStyle(color: Ly.muted, fontSize: 16)),
            Row(children: [
              Flexible(
                child: Text(now?.title ?? 'מוזיקה יוונית 24 שעות',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.1)),
              ),
              if (now?.isNew == true) const Padding(padding: EdgeInsets.only(right: 12), child: Pill('חדש', size: 16)),
            ]),
            if (now?.artist.isNotEmpty == true)
              Text(now!.artist, style: const TextStyle(fontSize: 24, color: Color(0xFFC9D2E8))),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (c.hostsImg.isNotEmpty) Artwork(url: c.hostsImg, size: 44, radius: 22),
              Text(c.hostsNames, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Pill(c.hostsWhen, size: 13),
              if (s.nextName.isNotEmpty) Pill('התכנית הבאה: ${s.nextName} · ${s.nextStart}', size: 13, color: Ly.cream),
            ]),
          ]),
        ),
        const SizedBox(width: 24),
        const _TvLiveButton(),
      ]),
    );
  }
}

class _TvLiveButton extends StatelessWidget {
  const _TvLiveButton();

  @override
  Widget build(BuildContext context) {
    final scope = Scope.of(context);
    final audio = scope.audio;
    return StreamBuilder<PlaybackState>(
      stream: audio.playbackState,
      builder: (context, snap) {
        final playing = audio.isLive && (snap.data?.playing ?? false);
        return TvFocusable(
          autofocus: true,
          radius: 60,
          onPressed: () => playing ? audio.pause() : audio.playLive(now: scope.state.studio.now, program: scope.state.studio.program),
          child: Container(
            width: 104,
            height: 104,
            color: Ly.sky,
            alignment: Alignment.center,
            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 66, color: Ly.night),
          ),
        );
      },
    );
  }
}

class _ShowCard extends StatelessWidget {
  const _ShowCard({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvShowScreen(show: show))),
      child: Container(
        width: 160,
        color: Ly.card,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Artwork(url: show.picture, size: 160, radius: 0, seed: show.name),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Text(show.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(show.when.isNotEmpty ? show.when : '${show.count} פרקים',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Ly.muted, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

class _LatestEpisodes extends StatefulWidget {
  const _LatestEpisodes();

  @override
  State<_LatestEpisodes> createState() => _LatestEpisodesState();
}

class _LatestEpisodesState extends State<_LatestEpisodes> {
  Future<EpisodePage>? _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _f ??= Scope.of(context).state.api.episodes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EpisodePage>(
      future: _f,
      builder: (context, snap) => TvRow(
        title: 'פרקים אחרונים',
        height: 215,
        children: (snap.data?.episodes ?? const []).where((e) => e.playable).map((e) => TvEpisodeCard(episode: e)).toList(),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday % 7 == show.day;
    return TvFocusable(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        color: today ? Ly.aegean : Ly.card,
        child: Row(children: [
          Artwork(url: show.picture, size: 70, radius: 35, seed: show.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${today ? 'היום' : 'יום ${kDayNames[show.day!]}'} ${show.start}', style: const TextStyle(color: Ly.fresh, fontWeight: FontWeight.w800)),
              Text(show.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}
