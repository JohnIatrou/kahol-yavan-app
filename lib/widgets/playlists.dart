import 'package:flutter/material.dart';

import '../api.dart';
import 'common.dart';

/// The colours of each playlist style (design B: a card in its own colour, the logo, the name in a white frame).
const _styles = <String, (Color, Color)>{
  'quiet': (Color(0xFF4FC3F7), Color(0xFF0B3A5C)),
  'happy': (Color(0xFFFF7043), Color(0xFF5C1D0B)),
  'new': (Color(0xFF66BB6A), Color(0xFF123D17)),
  'classics': (Color(0xFFBA68C8), Color(0xFF3B1446)),
  'top20': (Color(0xFFF4B740), Color(0xFF4A3305)),
  'mega': (Color(0xFFEF5350), Color(0xFF4D0D0D)),
};

/// A square playlist card, drawn at any [size].
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist, required this.size});
  final Playlist playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (light, dark) = _styles[playlist.key] ?? (const Color(0xFF2A5FB0), const Color(0xFF0D1838));
    final k = size / 205;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22 * k),
        gradient: LinearGradient(begin: AlignmentDirectional.topEnd, end: AlignmentDirectional.bottomStart, colors: [light, dark]),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset('assets/brand/kahol-yavan-logo.png', width: 160 * k),
        SizedBox(height: 16 * k),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16 * k, vertical: 5 * k),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
          child: Text(playlist.title,
              maxLines: 1, style: TextStyle(color: dark, fontSize: 19 * k, fontWeight: FontWeight.w800, height: 1.25)),
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

/// The playlists as a titled horizontal strip: on the archive and live screens.
class PlaylistsStrip extends StatefulWidget {
  const PlaylistsStrip({super.key, this.inset = 16});
  final double inset;

  @override
  State<PlaylistsStrip> createState() => _PlaylistsStripState();
}

class _PlaylistsStripState extends State<PlaylistsStrip> with PlaylistsLoader {
  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    final audio = Scope.of(context).audio;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(widget.inset, 8, widget.inset, 8),
        child: const Text('פלייליסטים', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: widget.inset),
          itemCount: playlists.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) => InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => audio.toggleEpisode(playlists[i].episode),
            child: PlaylistCard(playlist: playlists[i], size: 150),
          ),
        ),
      ),
    ]);
  }
}

/// All the playlists on one page, from the "עוד" menu.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> with PlaylistsLoader {
  @override
  Widget build(BuildContext context) {
    final audio = Scope.of(context).audio;
    return Scaffold(
      appBar: AppBar(title: const Text('פלייליסטים')),
      body: LayoutBuilder(builder: (context, c) {
        final size = (c.maxWidth - 16 * 2 - 14) / 2;
        return playlists.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                children: [
                  for (final p in playlists)
                    InkWell(
                      borderRadius: BorderRadius.circular(22 * size / 205),
                      onTap: () => audio.toggleEpisode(p.episode),
                      child: PlaylistCard(playlist: p, size: size),
                    ),
                ],
              );
      }),
    );
  }
}
