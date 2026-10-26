import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'tv_widgets.dart';

/// One show on TV: a grid of its episodes; OK plays, Back returns to the home screen.
class TvShowScreen extends StatefulWidget {
  const TvShowScreen({super.key, required this.show});
  final Show show;

  @override
  State<TvShowScreen> createState() => _TvShowScreenState();
}

class _TvShowScreenState extends State<TvShowScreen> {
  final _items = <Episode>[];
  int _page = 0;
  int _pages = 1;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_page == 0 && !_loading) _more();
  }

  Future<void> _more() async {
    setState(() => _loading = true);
    try {
      final p = await Scope.of(context).state.api.episodes(show: widget.show.id, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.episodes.where((e) => e.playable));
        _page = p.page;
        _pages = p.pages;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.show;
    return Scaffold(
      body: Column(children: [
        Expanded(
          child: CustomScrollView(scrollCacheExtent: const ScrollCacheExtent.pixels(10000), slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(48, 36, 48, 24),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Artwork(url: show.picture, size: 130, radius: 65, seed: show.name),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ארכיון התכניות', style: TextStyle(color: Ly.sky, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(show.name, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                      if (show.when.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Pill(show.when, size: 16)),
                    ]),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisSpacing: 24, crossAxisSpacing: 24, childAspectRatio: 1.05),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => TvEpisodeCard(episode: _items[i], autofocus: i == 0),
                  childCount: _items.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(32),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : _page < _pages
                          ? TvFocusable(
                              onPressed: _more,
                              radius: 24,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                color: Ly.card,
                                child: const Text('עוד פרקים', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              ),
                            )
                          : _items.isEmpty
                              ? const Text('לתכנית הזאת עוד אין פרקים להאזנה באפליקציה.', style: TextStyle(color: Ly.muted, fontSize: 18))
                              : const SizedBox.shrink(),
                ),
              ),
            ),
          ]),
        ),
        const TvEpisodeBar(),
      ]),
    );
  }
}

class TvEpisodeCard extends StatelessWidget {
  const TvEpisodeCard({super.key, required this.episode, this.autofocus = false});
  final Episode episode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final e = episode;
    return TvFocusable(
      autofocus: autofocus,
      onPressed: () => Scope.of(context).audio.toggleEpisode(e),
      child: Container(
        width: 240,
        color: Ly.card,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(alignment: Alignment.center, children: [
            Artwork(url: e.picture, size: 240, height: 135, radius: 0, seed: e.title),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, size: 40),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              [e.label, if (e.duration > 0) fmtDuration(Duration(seconds: e.duration.round()))].join(' · '),
              maxLines: 1,
              style: const TextStyle(color: Ly.muted, fontSize: 12),
            ),
          ),
          if (e.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Text(e.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
        ]),
      ),
    );
  }
}
