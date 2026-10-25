import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
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
  int _w = 0;
  List<CityWeather> _weather = const [];
  Timer? _tick;
  Timer? _weatherReload;

  @override
  Future<List<Update>> fetch(Api api) => api.updates();

  @override
  void initState() {
    super.initState();
    // A new headline every 6 seconds, the next city every 10.
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final news = t.tick % 6 == 0 && posts.length > 1;
      final city = t.tick % 10 == 0 && _weather.length > 1;
      if (!news && !city) return;
      setState(() {
        if (news) _i = (_i + 1) % posts.length;
        if (city) _w = (_w + 1) % _weather.length;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_weatherReload == null) {
      _loadWeather();
      _weatherReload = Timer.periodic(const Duration(minutes: 30), (_) => _loadWeather());
    }
  }

  Future<void> _loadWeather() async {
    try {
      final w = await Scope.of(context).state.api.israelWeather();
      if (mounted && w.isNotEmpty) setState(() => _weather = w);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    _weatherReload?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.big;
    final fs = big ? 15.0 : 13.0;
    final p = posts.isEmpty ? null : posts[_i % posts.length];
    final w = _weather.isEmpty ? null : _weather[_w % _weather.length];
    return Material(
      color: Ly.night,
      child: InkWell(
        onTap: p == null || big ? null : () => openUrl(p.link),
        child: Container(
          height: big ? 40 : 38,
          padding: EdgeInsets.symmetric(horizontal: big ? 48 : 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ly.line))),
          child: Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: big ? 11 : 9, vertical: 3),
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
            // The weather in Israel's main cities, one city at a time.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: const Offset(0, .5), end: Offset.zero).animate(a), child: child),
              ),
              child: w == null
                  ? const SizedBox.shrink()
                  : Row(key: ValueKey(w.city), mainAxisSize: MainAxisSize.min, children: [
                      Text(w.city, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700)),
                      SizedBox(width: big ? 8 : 6),
                      WeatherIcon(code: w.code, day: w.day, size: fs + 5),
                      SizedBox(width: big ? 6 : 4),
                      Text('\u200E${w.temp}°',
                          style: TextStyle(fontSize: fs, color: Ly.sky, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A coloured icon for a WMO weather code.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({super.key, required this.code, this.day = true, this.size = 18});
  final int code;
  final bool day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (code) {
      0 => day ? (Icons.wb_sunny, Ly.fresh) : (Icons.nightlight_round, const Color(0xFFDDE3EC)),
      1 || 2 => day ? (Icons.wb_cloudy, Ly.fresh) : (Icons.nights_stay, const Color(0xFFDDE3EC)),
      3 => (Icons.cloud, const Color(0xFFC9D2E8)),
      45 || 48 => (Icons.foggy, const Color(0xFFC9D2E8)),
      >= 95 => (Icons.thunderstorm, const Color(0xFFFFD166)),
      >= 71 && <= 77 || 85 || 86 => (Icons.ac_unit, Colors.white),
      >= 51 && <= 67 || >= 80 && <= 82 => (Icons.water_drop, Ly.sky),
      _ => (Icons.wb_cloudy, const Color(0xFFC9D2E8)),
    };
    return Icon(icon, size: size, color: color);
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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        child: p == null
            ? const Center(key: ValueKey(0), child: Text('מהמגזין של לילות יוון', style: TextStyle(color: Ly.muted, fontSize: 20)))
            // The picture fills the card and the headline sits on it, so the slide reads at any width.
            : Stack(key: ValueKey(p.id), fit: StackFit.expand, children: [
                LayoutBuilder(builder: (c, b) => Artwork(url: p.image, size: b.maxWidth, height: b.maxHeight, radius: 0, seed: p.title)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.15, 0.95],
                      colors: [Color(0x00000000), Color(0xEE08122B)],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 14,
                  start: 16,
                  child: Row(children: [
                    const Pill('מהמגזין', size: 12, color: Ly.sky, fg: Ly.night),
                    const SizedBox(width: 10),
                    Text(fmtDate(p.date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6)])),
                  ]),
                ),
                PositionedDirectional(
                  start: 16,
                  end: 84,
                  bottom: 12,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.2)),
                    const SizedBox(height: 4),
                    const Text('לידיעות המלאות ולכתבות נוספות היכנסו לאתר לילות יוון',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Ly.fresh, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
                // The site's logo in a small light square, framed like the station logo on the song cover.
                PositionedDirectional(
                  bottom: 12,
                  end: 12,
                  child: Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E6E6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Ly.night, width: 3),
                    ),
                    child: Image.network(kSiteLogoUrl, fit: BoxFit.contain, webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        errorBuilder: (_, _, _) => const SizedBox.shrink()),
                  ),
                ),
              ]),
      ),
    );
  }
}
