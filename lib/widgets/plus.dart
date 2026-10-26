import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

const _gold = Color(0xFFF4B740);

/// How the "+" of "כחול יוון +" comes alive.
enum PlusEffect {
  /// Pops up like a bubble and settles, with a golden glow and a flash of light across it (the news line).
  bubbleGlow,

  /// Grows with a golden glow and a flash of light across it (the opening screen).
  glow,
}

/// The yellow "+" pill of the station's logo, drawn from two bars like in the logo file.
/// Every [every] it plays its [effect] once; with [every] null it plays only when [play] is called.
class PlusBadge extends StatefulWidget {
  const PlusBadge({super.key, required this.width, this.effect = PlusEffect.bubbleGlow, this.every, this.firstAfter = const Duration(seconds: 2)});
  final double width;
  final PlusEffect effect;
  final Duration? every;
  final Duration firstAfter;

  @override
  State<PlusBadge> createState() => PlusBadgeState();
}

class PlusBadgeState extends State<PlusBadge> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Timer? _first;
  Timer? _again;

  late final Animation<double> _scale = TweenSequence<double>(widget.effect == PlusEffect.bubbleGlow
          ? [
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5).chain(CurveTween(curve: Curves.easeOut)), weight: 16),
              TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.82), weight: 12),
              TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.14), weight: 12),
              TweenSequenceItem(tween: Tween(begin: 1.14, end: 0.97), weight: 12),
              TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 48),
            ]
          : [
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
              TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
              TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
            ])
      .animate(_c);

  late final Animation<double> _glow = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.35), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.35, end: 0.0), weight: 40),
  ]).animate(_c);

  // Where the flash of light is, from before the pill's start to past its end.
  late final Animation<double> _shine = Tween(begin: -0.6, end: 1.4).animate(CurvedAnimation(parent: _c, curve: const Interval(0.1, 0.7, curve: Curves.easeInOut)));

  @override
  void initState() {
    super.initState();
    final every = widget.every;
    if (every != null) {
      _first = Timer(widget.firstAfter, () {
        play();
        _again = Timer.periodic(every, (_) => play());
      });
    }
  }

  void play() {
    if (mounted) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _first?.cancel();
    _again?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * 20 / 32;
    final k = w / 32;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(h / 2),
            boxShadow: _glow.value > 0 ? [BoxShadow(color: _gold.withValues(alpha: 0.8 * _glow.value), blurRadius: 18 * k, spreadRadius: 2 * k * _glow.value)] : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(h / 2),
            child: Stack(alignment: Alignment.center, children: [
              for (final (bw, bh) in [(12 * k, 4 * k), (4 * k, 12 * k)])
                Container(width: bw, height: bh, decoration: BoxDecoration(color: Ly.night, borderRadius: BorderRadius.circular(1.5 * k))),
              if (_c.isAnimating)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: _shine.value * w,
                  width: w * 0.4,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)], begin: Alignment(-1, -0.3), end: Alignment(1, 0.3)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The opening screen: the logo zooms in, the "+" pops up beside it and glows, the app's name comes in under it,
/// and a thin bar fills for five seconds while the app loads behind it. Then it fades into [child].
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key, required this.name, required this.child});
  final String name;
  final Widget child;

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  bool _started = false;
  final _plus = GlobalKey<PlusBadgeState>();
  bool _gone = false;
  bool _fading = false;

  late final _logo = CurvedAnimation(parent: _c, curve: const Interval(0, 0.14, curve: Curves.easeOutBack));
  late final _pop = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 14),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5), weight: 5),
    TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.85), weight: 3),
    TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.1), weight: 3),
    TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 3),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 72),
  ]).animate(_c);
  late final _name = CurvedAnimation(parent: _c, curve: const Interval(0.22, 0.32, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _fading = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Start once the logo is ready, so it zooms in instead of appearing halfway; don't wait more than a second for it.
    Future.any([
      precacheImage(const AssetImage('assets/brand/kahol-yavan-logo-big.png'), context),
      Future<void>.delayed(const Duration(seconds: 1)),
    ]).whenComplete(_start);
  }

  void _start() {
    if (!mounted) return;
    _c.forward();
    // The glow and flash of light, twice while the screen is up.
    for (final at in const [1700, 3500]) {
      Future.delayed(Duration(milliseconds: at), () => _plus.currentState?.play());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // The app builds and loads underneath from the first moment.
      Positioned.fill(child: widget.child),
      if (!_gone)
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: _fading ? 0 : 1,
            duration: const Duration(milliseconds: 500),
            onEnd: () => setState(() => _gone = true),
            child: AbsorbPointer(child: _screen(context)),
          ),
        ),
    ]);
  }

  Widget _screen(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoW = (size.width * (size.width > size.height ? 0.44 : 0.62)).clamp(160.0, 560.0);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -0.2), radius: 0.9, colors: [Color(0xFF173A7A), Ly.deep]),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(_logo),
                  child: FadeTransition(opacity: _logo, child: Image.asset('assets/brand/kahol-yavan-logo-big.png', width: logoW)),
                ),
                SizedBox(width: logoW * 0.02),
                ScaleTransition(scale: _pop, child: PlusBadge(key: _plus, width: logoW * 0.2, effect: PlusEffect.glow)),
              ]),
              SizedBox(height: logoW * 0.08),
              FadeTransition(
                opacity: _name,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(_name),
                  child: Text(widget.name, style: TextStyle(fontSize: (logoW * 0.085).clamp(20.0, 44.0), fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.08,
            child: Center(
              child: SizedBox(
                width: logoW * 0.7,
                height: 4,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => LinearProgressIndicator(value: _c.value, color: Ly.sky, backgroundColor: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
