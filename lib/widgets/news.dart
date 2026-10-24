import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Reloads a list of posts every few minutes while it is on screen.
mixin _Feed<T extends StatefulWidget> on State<T> {
  List<Update> posts = const [];
  Timer? _reload;

  Future<List<Update>> fetch(Api api);
  Duration get every => const Duration(minutes: 5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reload == null) {
      _load();
      _reload = Timer.periodic(every, (_) => _load());
    }
  }

  Future<void> _load() async {
    try {
      final p = await fetch(Scope.of(context).state.api);
      if (mounted && p.isNotEmpty) setState(() => posts = p);
    } catch (_) {}
  }

  @override
  void dispose() {
    _reload?.cancel();
    super.dispose();
  }
}

/// The site's news line (.nh-ticker): "עדכונים", today's date and the time, and the latest updates one after another.
class NewsTicker extends StatefulWidget {
  const NewsTicker({super.key, this.big = false});

  /// The TV size.
  final bool big;

  @override
  State<NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<NewsTicker> with _Feed {
  int _i = 0;
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  Future<List<Update>> fetch(Api api) => api.updates();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        if (t.tick % 6 == 0 && posts.length > 1) _i = (_i + 1) % posts.length;
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.big;
    final fs = big ? 20.0 : 13.0;
    final p = posts.isEmpty ? null : posts[_i % posts.length];
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = 'יום ${kDayNames[_now.weekday % 7]} ${two(_now.day)}.${two(_now.month)}.${_now.year} · ${two(_now.hour)}:${two(_now.minute)}';
    return Material(
      color: Ly.night,
      child: InkWell(
        onTap: p == null || big ? null : () => openUrl(p.link),
        child: Container(
          height: big ? 54 : 38,
          padding: EdgeInsets.symmetric(horizontal: big ? 48 : 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ly.line))),
          child: Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: big ? 14 : 9, vertical: big ? 5 : 3),
              decoration: BoxDecoration(color: Ly.live, borderRadius: BorderRadius.circular(6)),
              child: Text('עדכונים', style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            SizedBox(width: big ? 16 : 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, .5), end: Offset.zero).animate(a), child: child),
                ),
                child: Align(
                  key: ValueKey(p?.id),
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(p == null ? '' : tickerLine(p),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            SizedBox(width: big ? 16 : 10),
            Text(big ? clock : '${two(_now.day)}.${two(_now.month)} · ${two(_now.hour)}:${two(_now.minute)}',
                style: TextStyle(fontSize: fs, color: Ly.sky, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      ),
    );
  }
}

/// "DD.MM • HH:MM | title", as on the site. The site's titles usually carry it already.
String tickerLine(Update u) {
  if (RegExp(r'^\d{1,2}\.\d{1,2}').hasMatch(u.title) || u.date == null) return u.title;
  final d = u.date!;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)} • ${two(d.hour)}:${two(d.minute)} | ${u.title}';
}

/// TV: the magazine's latest articles as slides, picture and headline, one after another.
class MagazineSlides extends StatefulWidget {
  const MagazineSlides({super.key, this.height = 230});
  final double height;

  @override
  State<MagazineSlides> createState() => _MagazineSlidesState();
}

class _MagazineSlidesState extends State<MagazineSlides> with _Feed {
  int _i = 0;
  Timer? _next;

  @override
  Future<List<Update>> fetch(Api api) async => (await api.magazine()).posts.take(10).toList();

  @override
  Duration get every => const Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
    _next = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && posts.length > 1) setState(() => _i = (_i + 1) % posts.length);
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final p = posts.isEmpty ? null : posts[_i % posts.length];
    return Container(
      height: h,
      decoration: BoxDecoration(color: Ly.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: Ly.line)),
      clipBehavior: Clip.antiAlias,
      child: p == null
          ? const Center(child: Text('מהמגזין של לילות יוון', style: TextStyle(color: Ly.muted, fontSize: 20)))
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: Row(key: ValueKey(p.id), children: [
                SizedBox(
                  width: h * 16 / 10,
                  height: h,
                  child: p.image.isEmpty ? const Center(child: StationLogo(size: 120)) : Artwork(url: p.image, size: h * 16 / 10, height: h, radius: 0),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Pill('מהמגזין', size: 14, color: Ly.sky, fg: Ly.night),
                        const SizedBox(width: 10),
                        Text(fmtDate(p.date), style: const TextStyle(color: Ly.muted, fontSize: 15)),
                        const Spacer(),
                        Text('${_i % posts.length + 1}/${posts.length}', style: const TextStyle(color: Ly.muted, fontSize: 15)),
                      ]),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(p.title,
                            maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.2)),
                      ),
                      const Text('לקריאת הידיעה וכתבות נוספות היכנסו לאפליקציית לילות יוון',
                          style: TextStyle(color: Ly.fresh, fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            ),
    );
  }
}
