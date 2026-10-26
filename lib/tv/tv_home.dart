import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/news.dart';
import '../widgets/playlists.dart';
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
        const NewsTicker(big: true),
        Expanded(
          child: ListenableBuilder(
            listenable: st,
            builder: (context, _) {
              final s = st.studio;
              return ListView(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                children: [
                  const _Hero(),
                  const SizedBox(height: 20),
                  TvRow(
                    title: 'התכניות בארכיון',
                    height: 240,
                    children: st.shows.map((sh) => _ShowCard(show: sh)).toList(),
                  ),
                  const _Playlists(),
                  // Not focusable: the remote moves from the archive straight on to the next row, and the page scrolls past this one.
                  const Padding(
                    padding: EdgeInsets.fromLTRB(48, 0, 48, 24),
                    child: Row(children: [
                      Expanded(child: MagazineSlides()),
                      SizedBox(width: 20),
                      _StudioQr(),
                    ]),
                  ),
                  const _LatestEpisodes(),
                  TvRow(title: 'הכי מושמעים השבוע', height: 200, children: s.most.map(_song).toList()),
                  TvRow(title: 'שירים חדשים', height: 200, children: s.fresh.map(_song).toList()),
                  TvRow(title: 'לוח התכניות', height: 130, children: _fromToday(st.schedule).map((sh) => _ScheduleCard(show: sh)).toList()),
                ],
              );
            },
          ),
        ),
        const TvEpisodeBar(),
      ]),
    );
  }

  /// The week starting today, so the next shows are the first cards in the row.
  static List<Show> _fromToday(List<Show> week) {
    final today = DateTime.now().weekday % 7;
    return [...week.where((x) => x.day! >= today), ...week.where((x) => x.day! < today)];
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Ly.panel, Ly.night], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Ly.line),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
        NowCover(song: now, size: 170),
        const SizedBox(width: 24),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const LiveBadge(big: true),
              Text(c.name, style: const TextStyle(color: Ly.sky, fontSize: 24, fontWeight: FontWeight.w800)),
              if (s.program.isNotEmpty) Text('•  ${s.program}', style: const TextStyle(color: Ly.muted, fontSize: 18)),
            ]),
            const SizedBox(height: 8),
            const Text('עכשיו בשידור', style: TextStyle(color: Ly.muted, fontSize: 16)),
            Row(children: [
              Flexible(
                child: Text(now?.title ?? 'מוזיקה יוונית 24 שעות',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
              ),
              if (now?.isNew == true) const Padding(padding: EdgeInsets.only(right: 12), child: Pill('חדש', size: 16)),
            ]),
            if (now?.artist.isNotEmpty == true)
              Text(now!.artist, style: const TextStyle(fontSize: 20, color: Color(0xFFC9D2E8))),
            if (now?.hebrew.isNotEmpty == true)
              Text('"${now!.hebrew}"', style: const TextStyle(fontSize: 18, color: Ly.sky, fontWeight: FontWeight.w700)),
            SongProgress(studio: s, big: true),
          ]),
        ),
        if (s.recent.isNotEmpty) ...[
          const SizedBox(width: 20),
          _RecentColumn(songs: s.recent.take(5).toList()),
        ],
        const SizedBox(width: 24),
        const _TvLiveButton(),
        ]),
        // The hosts and the next show across the whole player, under the recent songs too.
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ly.line))),
          child: Row(children: [
            Expanded(
              child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (c.hostsImg.isNotEmpty) Artwork(url: c.hostsImg, size: 40, radius: 20),
                Text(c.hostsNames, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Pill(c.hostsWhen, size: 13),
              ]),
            ),
            if (s.nextName.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Pill('התכנית הבאה: ${s.nextName} · ${s.nextStart}', size: 13, color: Ly.cream),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Scan with the phone to write to the studio on WhatsApp: song requests, questions, contact.
class _StudioQr extends StatelessWidget {
  const _StudioQr();

  @override
  Widget build(BuildContext context) {
    final c = Scope.of(context).state.config;
    return Container(
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Ly.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: Ly.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: QrImageView(
            data: whatsappUrl(c.whatsapp, 'שלום מהטלוויזיה! אני מאזין/ה לרדיו כחול יוון'),
            size: 130,
            padding: EdgeInsets.zero,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Ly.night),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Ly.night),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 190,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Row(children: [
              Icon(Icons.chat, color: Ly.wa, size: 26),
              SizedBox(width: 8),
              Flexible(child: Text('דברו עם האולפן', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 8),
            const Text('סרקו את הברקוד בטלפון ושלחו לנו בוואטסאפ', style: TextStyle(fontSize: 14, color: Color(0xFFC9D2E8), height: 1.3)),
            const SizedBox(height: 10),
            const Text('בקשות שירים · פניות · יצירת קשר', style: TextStyle(fontSize: 13, color: Ly.sky, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_phone(c.whatsapp), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 15, color: Ly.muted)),
          ]),
        ),
      ]),
    );
  }

  /// 972529964040 → 052-996-4040
  static String _phone(String n) {
    final local = n.startsWith('972') ? '0${n.substring(3)}' : n;
    return local.length == 10 ? '${local.substring(0, 3)}-${local.substring(3, 6)}-${local.substring(6)}' : local;
  }
}

/// "שודרו לאחרונה" inside the player: the last songs with the time they were played. Only to read, not to select.
class _RecentColumn extends StatelessWidget {
  const _RecentColumn({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsetsDirectional.only(start: 16),
      decoration: const BoxDecoration(border: BorderDirectional(start: BorderSide(color: Ly.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('שודרו לאחרונה', style: TextStyle(color: Ly.muted, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final x in songs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                width: 42,
                child: Text(x.airTime,
                    style: const TextStyle(color: Ly.sky, fontSize: 13, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
              ),
              x.cover.isEmpty ? const StationLogo(size: 32, radius: 7) : Artwork(url: x.cover, size: 32, radius: 7, seed: x.title),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(x.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Ly.muted, fontSize: 11)),
                ]),
              ),
            ]),
          ),
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
            width: 88,
            height: 88,
            color: Ly.sky,
            alignment: Alignment.center,
            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 56, color: Ly.night),
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

/// The daily playlists, right under the archive.
class _Playlists extends StatefulWidget {
  const _Playlists();

  @override
  State<_Playlists> createState() => _PlaylistsState();
}

class _PlaylistsState extends State<_Playlists> with PlaylistsLoader {
  @override
  Widget build(BuildContext context) => TvRow(
        title: 'פלייליסטים',
        height: 196,
        children: [
          for (final p in playlists)
            TvFocusable(
              radius: 22 * 180 / 205,
              onPressed: () => Scope.of(context).audio.playEpisode(p.episode),
              child: PlaylistCard(playlist: p, size: 180),
            ),
        ],
      );
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
