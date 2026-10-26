import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/playlists.dart';

void playOrOpen(BuildContext context, Episode e) {
  final scope = Scope.of(context);
  if (e.playable) {
    scope.audio.playEpisode(e);
  } else if (e.mixcloud.isNotEmpty) {
    openUrl(e.mixcloud.first);
  } else {
    openUrl(e.link);
  }
}

/// "ארכיון": the shows, then the latest episodes of all shows.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context).state;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => CustomScrollView(slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(child: Text('התכניות', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ShowCard(show: st.shows[i]),
              childCount: st.shows.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _Playlists()),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          sliver: SliverToBoxAdapter(child: Text('פרקים אחרונים', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        ),
        const SliverPadding(padding: EdgeInsets.fromLTRB(16, 0, 16, 24), sliver: SliverToBoxAdapter(child: EpisodeList(show: 0, embedded: true))),
      ]),
    );
  }
}

/// The daily playlists, right under the shows.
class _Playlists extends StatefulWidget {
  const _Playlists();

  @override
  State<_Playlists> createState() => _PlaylistsState();
}

class _PlaylistsState extends State<_Playlists> with PlaylistsLoader {
  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text('פלייליסטים', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: playlists.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) => InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => playOrOpen(context, playlists[i].episode),
            child: PlaylistCard(playlist: playlists[i], size: 150),
          ),
        ),
      ),
    ]);
  }
}

class _ShowCard extends StatelessWidget {
  const _ShowCard({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShowScreen(show: show))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: LayoutBuilder(builder: (context, c) => Artwork(url: show.picture, size: c.maxWidth, radius: 0, seed: show.name))),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(show.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 4),
              Text(show.when.isNotEmpty ? show.when : '${show.count} פרקים', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Ly.muted, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ShowScreen extends StatelessWidget {
  const ShowScreen({super.key, required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(show.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Artwork(url: show.picture, size: 96, radius: 48, seed: show.name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(show.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              if (show.when.isNotEmpty) ...[const SizedBox(height: 6), Pill(show.when, size: 13)],
              const SizedBox(height: 6),
              Text('${show.count} פרקים בארכיון', style: const TextStyle(color: Ly.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        EpisodeList(show: show.id, embedded: true),
      ]),
    );
  }
}

/// Episodes of one show (or all shows when show = 0), 20 at a time with "עוד פרקים".
class EpisodeList extends StatefulWidget {
  const EpisodeList({super.key, required this.show, this.embedded = false});
  final int show;
  final bool embedded;

  @override
  State<EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends State<EpisodeList> {
  final _items = <Episode>[];
  int _page = 0;
  int _pages = 1;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_page == 0 && !_loading) _more();
  }

  Future<void> _more() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await Scope.of(context).state.api.episodes(show: widget.show, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.episodes);
        _page = p.page;
        _pages = p.pages;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'לא הצלחנו לטעון את הארכיון.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ..._items.map((e) => EpisodeTile(episode: e)),
      if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Ly.muted))),
      if (!_loading && _page < _pages) TextButton(onPressed: _more, child: const Text('עוד פרקים')),
      if (!_loading && _items.isEmpty && _error == null)
        const Padding(padding: EdgeInsets.all(16), child: Text('עוד אין פרקים בארכיון.', textAlign: TextAlign.center, style: TextStyle(color: Ly.muted))),
    ]);
  }
}

class EpisodeTile extends StatelessWidget {
  const EpisodeTile({super.key, required this.episode});
  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final e = episode;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => playOrOpen(context, e),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Stack(alignment: Alignment.center, children: [
              Artwork(url: e.picture, size: 64, radius: 12, seed: e.title),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                child: Icon(e.playable ? Icons.play_arrow_rounded : Icons.open_in_new, color: Colors.white, size: e.playable ? 26 : 18),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 4),
                Text(
                  [e.label, if (e.duration > 0) fmtDuration(Duration(seconds: e.duration.round())), if (!e.playable && e.mixcloud.isNotEmpty) 'ב-Mixcloud']
                      .where((x) => x.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(color: Ly.muted, fontSize: 12),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
