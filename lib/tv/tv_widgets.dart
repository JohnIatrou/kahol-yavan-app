import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Something the remote can move to and press: grows and gets a light frame when focused.
class TvFocusable extends StatefulWidget {
  const TvFocusable({super.key, required this.child, this.onPressed, this.autofocus = false, this.radius = 16});
  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final double radius;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onFocusChange: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onPressed?.call();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _focused ? 1.06 : 1,
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius + 3),
              border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 3),
              boxShadow: _focused ? [BoxShadow(color: Ly.sky.withValues(alpha: 0.45), blurRadius: 24)] : const [],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// A titled horizontal row of cards, like every TV app.
/// Coming into the row from above or below lands on the card last used there (the first card at the start),
/// not on whichever card happens to sit nearest, which in RTL is often one cut off at the screen's edge.
class TvRow extends StatefulWidget {
  const TvRow({super.key, required this.title, required this.children, this.height = 200});
  final String title;
  final List<Widget> children;
  final double height;

  @override
  State<TvRow> createState() => _TvRowState();
}

class _TvRowState extends State<TvRow> {
  final _slots = <int, FocusNode>{};
  int _last = 0;
  bool _inside = false;

  @override
  void dispose() {
    for (final n in _slots.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _slot(int i) => _slots.putIfAbsent(i, () => FocusNode(skipTraversal: true, debugLabel: 'row slot $i'));

  void _entered(int i) {
    if (_inside) {
      _last = i;
      return;
    }
    _inside = true;
    if (i == _last) return;
    final target = _slots[_last]?.descendants.where((n) => n.canRequestFocus && !n.skipTraversal).firstOrNull;
    if (target == null || target.context == null) {
      _last = i;
      return;
    }
    target.requestFocus();
    Scrollable.ensureVisible(target.context!, alignment: 0.5, duration: const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: widget.height,
          child: Focus(
            skipTraversal: true,
            canRequestFocus: false,
            onFocusChange: (v) {
              if (!v) _inside = false;
            },
            child: FocusTraversalGroup(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                itemCount: children.length,
                separatorBuilder: (_, _) => const SizedBox(width: 18),
                itemBuilder: (_, i) => Focus(
                  focusNode: _slot(i),
                  onFocusChange: (v) {
                    if (v) _entered(i);
                  },
                  child: children[i],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// A song on a TV row (cover, title, artist). Focusable so the row can be browsed, nothing to press.
class TvSongCard extends StatelessWidget {
  const TvSongCard({super.key, required this.title, required this.artist, required this.cover, this.badge});
  final String title;
  final String artist;
  final String cover;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      child: Container(
        width: 130,
        color: Ly.card,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Artwork(url: cover, size: 130, radius: 0, seed: title),
            if (badge != null) Positioned(top: 8, right: 8, child: Pill(badge!, size: 11)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Ly.muted, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

/// The strip at the bottom of the TV screens while an archive episode plays.
class TvEpisodeBar extends StatelessWidget {
  const TvEpisodeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = Scope.of(context).audio;
    return StreamBuilder<MediaItem?>(
      stream: audio.mediaItem,
      builder: (context, snap) {
        final e = audio.episode;
        if (snap.data == null || e == null) return const SizedBox.shrink();
        final player = audio.player;
        return Container(
          padding: const EdgeInsets.fromLTRB(48, 14, 48, 18),
          color: Ly.panel,
          child: Row(children: [
            Artwork(url: e.picture, size: 64, radius: 10, seed: e.title),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, p) {
                    final pos = p.data ?? Duration.zero;
                    final dur = player.duration ?? Duration(seconds: e.duration.round());
                    return Row(children: [
                      Text(fmtDuration(pos), style: const TextStyle(color: Ly.muted)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : null,
                          minHeight: 5,
                          color: Ly.sky,
                          backgroundColor: Ly.line,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(fmtDuration(dur), style: const TextStyle(color: Ly.muted)),
                    ]);
                  },
                ),
              ]),
            ),
            const SizedBox(width: 20),
            _TvButton(label: '‎−15', onPressed: audio.rewind),
            StreamBuilder<bool>(
              stream: player.playingStream,
              builder: (context, p) => _TvButton(
                icon: (p.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onPressed: (p.data ?? false) ? audio.pause : audio.play,
              ),
            ),
            _TvButton(label: '+30', onPressed: audio.fastForward),
            _TvButton(icon: Icons.close, onPressed: audio.stop),
          ]),
        );
      },
    );
  }
}

class _TvButton extends StatelessWidget {
  const _TvButton({this.icon, this.label, required this.onPressed});
  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: TvFocusable(
          radius: 28,
          onPressed: onPressed,
          child: Container(
            width: 56,
            height: 56,
            color: Ly.card,
            alignment: Alignment.center,
            child: icon != null ? Icon(icon, size: 32) : Text(label!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
      );
}
