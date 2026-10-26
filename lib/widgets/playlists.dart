import 'package:flutter/material.dart';

import '../api.dart';
import 'common.dart';

/// The colours and icon of each playlist style (design B: a card in its own colour, the logo, the name in a white frame).
const _styles = <String, (Color, Color, String)>{
  'quiet': (Color(0xFF4FC3F7), Color(0xFF0B3A5C), 'moon'),
  'happy': (Color(0xFFFF7043), Color(0xFF5C1D0B), 'bouzouki'),
  'new': (Color(0xFF66BB6A), Color(0xFF123D17), 'sun'),
  'classics': (Color(0xFFBA68C8), Color(0xFF3B1446), 'temple'),
  'top20': (Color(0xFFF4B740), Color(0xFF4A3305), 'laurel'),
  'mega': (Color(0xFFEF5350), Color(0xFF4D0D0D), 'vinyl'),
};

/// A square playlist card, drawn at any [size].
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist, required this.size});
  final Playlist playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (light, dark, icon) = _styles[playlist.key] ?? (const Color(0xFF2A5FB0), const Color(0xFF0D1838), 'vinyl');
    final k = size / 205;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22 * k),
        gradient: LinearGradient(begin: AlignmentDirectional.topEnd, end: AlignmentDirectional.bottomStart, colors: [light, dark]),
      ),
      child: Stack(children: [
        // The style's icon, drawn in the logo's style, in the corner.
        Positioned(top: 10 * k, left: 10 * k, child: Image.asset('assets/playlists/$icon.png', width: 58 * k, height: 58 * k)),
        Positioned.fill(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(height: 22 * k),
            Image.asset('assets/brand/kahol-yavan-logo.png', width: 150 * k),
            SizedBox(height: 14 * k),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16 * k, vertical: 5 * k),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
              child: Text(playlist.title,
                  maxLines: 1, style: TextStyle(color: dark, fontSize: 19 * k, fontWeight: FontWeight.w800, height: 1.25)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// The browser preview shows the six cards before the site serves real playlists.
const kDemoPlaylists = bool.fromEnvironment('DEMO_PLAYLISTS');
const _demo = [
  Playlist(key: 'quiet', title: 'שעה שקטה', audio: ''),
  Playlist(key: 'happy', title: 'שעה שמחה', audio: ''),
  Playlist(key: 'new', title: 'השירים החדשים', audio: ''),
  Playlist(key: 'classics', title: 'קלאסיקות', audio: ''),
  Playlist(key: 'top20', title: 'הטופ 20', audio: ''),
  Playlist(key: 'mega', title: 'מגה להיטים', audio: ''),
];

/// Loads the playlists once per screen.
mixin PlaylistsLoader<T extends StatefulWidget> on State<T> {
  List<Playlist> playlists = const [];
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    Scope.of(context).state.api.playlists().then((p) {
      if (mounted) setState(() => playlists = p.isEmpty && kDemoPlaylists ? _demo : p);
    }, onError: (_) {
      if (mounted && kDemoPlaylists) setState(() => playlists = _demo);
    });
  }
}
