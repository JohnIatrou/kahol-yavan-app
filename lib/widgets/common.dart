import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../audio.dart';
import '../config.dart';
import '../push.dart';
import '../state.dart';
import '../theme.dart';

/// Gives every screen the app state, the player and the notification settings.
class Scope extends InheritedWidget {
  const Scope({super.key, required this.state, required this.push, required super.child});

  final AppState state;
  final Push push;

  RadioHandler get audio => state.audio;

  static Scope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Scope>()!;

  @override
  bool updateShouldNotify(Scope old) => false;
}

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String whatsappUrl(String number, [String text = '']) =>
    'https://wa.me/$number${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}';

/// The station logo, the same picture as the site's player.
class StationLogo extends StatelessWidget {
  const StationLogo({super.key, this.size = 96, this.radius});
  final double size;

  /// Corner radius; rounded to the size by default.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size * 0.18),
      child: Image.network(
        kLogoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, _, _) => _drawn(),
        frameBuilder: (_, child, frame, sync) => frame == null && !sync ? _drawn() : child,
      ),
    );
  }

  /// Shown while the logo loads, or without a connection.
  Widget _drawn() => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF2B9BF0), Ly.aegean], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.radio, color: Colors.white, size: size * 0.32),
          Text('כחול יוון', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.17, height: 1.1)),
        ]),
      );
}


/// The wide station logo from the site's header, on the station's blue.
class StationBadge extends StatelessWidget {
  const StationBadge({super.key, this.width = 56});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: EdgeInsets.all(width * 0.08),
        decoration: BoxDecoration(
          color: Ly.aegean,
          borderRadius: BorderRadius.circular(width * 0.16),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
        ),
        child: Image.network(
          kBadgeUrl,
          fit: BoxFit.contain,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, _, _) => Icon(Icons.radio, color: Colors.white, size: width * 0.5),
        ),
      );
}

/// The song on air: its cover with the station badge in the corner, as on the site's player,
/// or the station logo when the song has no cover.
class NowCover extends StatelessWidget {
  const NowCover({super.key, required this.song, this.size = 150});
  final Song? song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = song;
    if (s == null || s.cover.isEmpty) return StationLogo(size: size);
    // As on the site's player: the square station logo tight in the cover's bottom corner.
    final logo = size * 0.27;
    final r = size * 0.08;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Stack(children: [
        Artwork(url: s.cover, size: size, radius: 0, seed: s.title),
        PositionedDirectional(
          bottom: 0,
          end: 0,
          child: CornerBadge(child: StationLogo(size: logo, radius: 0)),
        ),
      ]),
    );
  }
}

/// A small logo tight in a picture's bottom corner (the end side), framed on its inner edges.
class CornerBadge extends StatelessWidget {
  const CornerBadge({super.key, required this.child, this.radius = 10});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final inner = BorderRadiusDirectional.only(topStart: Radius.circular(radius));
    return Container(
      padding: const EdgeInsetsDirectional.only(top: 2, start: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: inner,
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
      ),
      child: ClipRRect(borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(radius - 2)), child: child),
    );
  }
}

/// A cover or photo from the site, or a coloured tile when there is none.
class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.url, this.size = 56, this.height, this.radius = 10, this.seed = ''});
  final String url;
  final double size;

  /// Height when the picture is not square (width = size).
  final double? height;
  final double radius;
  final String seed;

  static const _tiles = [
    [Color(0xFFE8963A), Color(0xFFC9502E)],
    [Color(0xFF3D7BE8), Color(0xFF3046C9)],
    [Color(0xFFA54BE8), Color(0xFF7A2FD0)],
    [Color(0xFF2E9E6A), Color(0xFF1C6B4A)],
    [Color(0xFF1D3F7A), Color(0xFF0F2551)],
    [Color(0xFFB8673E), Color(0xFF7E3F22)],
  ];

  @override
  Widget build(BuildContext context) {
    final c = _tiles[seed.hashCode.abs() % _tiles.length];
    final fallback = Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      alignment: Alignment.center,
      child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.7), size: (height ?? size) * 0.4),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: height ?? size,
        child: url.isEmpty
            ? fallback
            : kIsWeb
                // In a browser, pictures from other sites show as plain <img> elements, which need no CORS.
                ? Image.network(url, fit: BoxFit.cover, webHtmlElementStrategy: WebHtmlElementStrategy.fallback, errorBuilder: (_, _, _) => fallback)
                : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, _, _) => fallback, placeholder: (_, _) => fallback),
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.big = false});
  final bool big;

  @override
  Widget build(BuildContext context) {
    final fs = big ? 18.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fs * 0.7, vertical: fs * 0.2),
      decoration: BoxDecoration(
        color: Ly.live.withValues(alpha: 0.15),
        border: Border.all(color: Ly.live.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('LIVE', style: TextStyle(color: Ly.live, fontWeight: FontWeight.w900, fontSize: fs, letterSpacing: 1)),
        SizedBox(width: fs * 0.4),
        Container(width: fs * 0.5, height: fs * 0.5, decoration: const BoxDecoration(color: Ly.live, shape: BoxShape.circle)),
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Ly.fresh, this.fg = const Color(0xFF2A1A00), this.size = 12});
  final String text;
  final Color color;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.7, vertical: size * 0.15),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size)),
      );
}

/// A rounded panel with a title and a coloured mark, like the boxes on the site's radio board.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, this.mark = Ly.sky, this.action});
  final String title;
  final Widget child;
  final Color mark;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Ly.panel.withValues(alpha: 0.6),
        border: Border.all(color: Ly.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 5, height: 22, decoration: BoxDecoration(color: mark, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ?action,
        ]),
        const SizedBox(height: 10),
        // Its own Material, so list tiles inside show their ink on the panel's colour.
        Material(type: MaterialType.transparency, child: child),
      ]),
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({super.key, required this.song, this.trailing});
  final Song song;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Ly.card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        if (song.rank > 0)
          SizedBox(
            width: 28,
            child: Text('${song.rank}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Ly.sky)),
          ),
        // The site leaves covers out unless they are its own, so most songs show the station's logo.
        song.cover.isEmpty ? const StationLogo(size: 52, radius: 10) : Artwork(url: song.cover, size: 52, seed: song.title),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              if (song.isNew) ...[const SizedBox(width: 6), const Pill('חדש', size: 10)],
            ]),
            if (song.artist.isNotEmpty)
              Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Ly.muted, fontSize: 13)),
          ]),
        ),
        if (trailing != null) Text(trailing!, style: const TextStyle(color: Ly.muted, fontSize: 12)),
        if (song.youtube.isNotEmpty)
          IconButton(
            tooltip: 'ביוטיוב',
            onPressed: () => openUrl(song.youtube),
            icon: const Icon(Icons.smart_display, color: Color(0xFFFF5A5F)),
          ),
      ]),
    );
  }
}

/// How far the song on air is: a bar with the minutes played and the song's length.
class SongProgress extends StatelessWidget {
  const SongProgress({super.key, required this.studio, this.big = false});
  final Studio studio;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final p = studio.progress(DateTime.now());
        if (p == null) return const SizedBox.shrink();
        final total = Duration(milliseconds: (studio.duration * 1000).round());
        final style = TextStyle(color: Ly.muted, fontSize: big ? 16 : 12, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]);
        return Padding(
          padding: EdgeInsets.only(top: big ? 10 : 12),
          // Time runs left to right, as on the site's player.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              Text(fmtDuration(total * p), style: style),
              SizedBox(width: big ? 12 : 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: p, minHeight: big ? 6 : 4, backgroundColor: Ly.line, color: Ly.sky),
                ),
              ),
              SizedBox(width: big ? 12 : 8),
              Text(fmtDuration(total), style: style),
            ]),
          ),
        );
      },
    );
  }
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String fmtDate(DateTime? d) => d == null ? '' : '${d.day}.${d.month}.${d.year}';
