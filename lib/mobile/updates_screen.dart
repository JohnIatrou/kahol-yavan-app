import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A list of the site's posts with pictures, page after page: "עדכונים" (news, weather, events in Greece)
/// and "מגזין" (all the magazine's articles).
class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key, required this.load, this.empty = 'אין עדכונים כרגע.'});

  final Future<PostPage> Function(Api api, int page) load;
  final String empty;

  static Widget updates() => PostsScreen(load: (api, page) => api.updatesPage(page: page));
  static Widget magazine() => PostsScreen(load: (api, page) => api.magazine(page: page), empty: 'אין כתבות כרגע.');

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final _posts = <Update>[];
  int _page = 0;
  int _pages = 1;
  bool _loading = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_page == 0 && !_loading) _more();
  }

  Future<void> _more({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    final page = reset ? 1 : _page + 1;
    try {
      final r = await widget.load(Scope.of(context).state.api, page);
      if (!mounted) return;
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(r.posts.where((p) => !_posts.any((q) => q.id == p.id)));
        _page = page;
        _pages = r.pages;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => _more(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 600 && _page < _pages && !_failed) _more();
          return false;
        },
        child: _posts.isEmpty
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(_failed ? 'לא הצלחנו לטעון. משכו למטה כדי לנסות שוב.' : widget.empty,
                      textAlign: TextAlign.center, style: const TextStyle(color: Ly.muted)),
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length + (_page < _pages ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _posts.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _failed
                            ? TextButton(onPressed: _more, child: const Text('טעינת כתבות נוספות'))
                            : const CircularProgressIndicator(),
                      ),
                    );
                  }
                  return PostCard(post: _posts[i]);
                },
              ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});
  final Update post;

  @override
  Widget build(BuildContext context) {
    final u = post;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openUrl(u.link),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (u.image.isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: LayoutBuilder(builder: (c, b) => Artwork(url: u.image, size: b.maxWidth, radius: 0))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmtDate(u.date), style: const TextStyle(color: Ly.sky, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(u.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.25)),
              if (u.excerpt.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(u.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC9D2E8), height: 1.4)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
