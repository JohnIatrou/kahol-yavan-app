import 'package:audio_service/audio_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'audio.dart';
import 'config.dart';
import 'mobile/archive_screen.dart';
import 'mobile/home.dart';
import 'push.dart';
import 'state.dart';
import 'theme.dart';
import 'tv/tv_home.dart';
import 'tv/tv_platform.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audio = await AudioService.init(
    builder: RadioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.chagil.kahol_yavan_radio_app.audio',
      androidNotificationChannelName: 'השמעה',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );
  final tv = kForceTv || await _isTv();
  if (tv) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }
  final state = AppState(Api(), audio);
  final push = Push();
  runApp(RadioApp(state: state, push: push, tv: tv));
  state.start();
  if (!tv) push.init();
}

/// Android TV and Google TV declare the "leanback" feature, Amazon Fire TV its own one too.
Future<bool> _isTv() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.systemFeatures.contains('android.software.leanback') || info.systemFeatures.contains('amazon.hardware.fire_tv');
  } catch (_) {
    return false;
  }
}

class RadioApp extends StatefulWidget {
  const RadioApp({super.key, required this.state, required this.push, required this.tv});
  final AppState state;
  final Push push;
  final bool tv;

  @override
  State<RadioApp> createState() => _RadioAppState();
}

class _RadioAppState extends State<RadioApp> {
  final _nav = GlobalKey<NavigatorState>();
  final _home = GlobalKey<MobileHomeState>();

  @override
  void initState() {
    super.initState();
    widget.push.onOpen = _openFromNotification;
    if (widget.tv) {
      listenTvRemote(
        back: () {
          final nav = _nav.currentState;
          if (nav == null || !nav.canPop()) return false;
          nav.pop();
          return true;
        },
        playPause: () {
          final a = widget.state.audio;
          a.playbackState.value.playing ? a.pause() : a.play();
        },
      );
    }
  }

  /// A notification was tapped: play the episode, start the live stream, or open the link.
  Future<void> _openFromNotification(Map<String, dynamic> data) async {
    final st = widget.state;
    switch (data['type']) {
      case 'episode':
        _home.currentState?.showTab(1);
        try {
          final page = await st.api.episodes(show: int.tryParse('${data['show']}') ?? 0);
          final id = int.tryParse('${data['id']}');
          final e = page.episodes.where((x) => x.id == id).firstOrNull;
          if (e != null && e.playable) await st.audio.playEpisode(e);
        } catch (_) {}
      case 'url':
        final url = '${data['url'] ?? ''}';
        if (url.isNotEmpty) await openUrl(url);
      default:
        _home.currentState?.showTab(0);
        await st.audio.playLive(now: st.studio.now, program: st.studio.program);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scope(
      state: widget.state,
      push: widget.push,
      child: MaterialApp(
        navigatorKey: _nav,
        title: 'רדיו כחול יוון',
        debugShowCheckedModeBanner: false,
        theme: Ly.theme(),
        locale: const Locale('he'),
        supportedLocales: const [Locale('he')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // The remote's arrows move focus. Web maps them to scrolling by default, which the TV preview build needs to undo.
        shortcuts: widget.tv ? {...WidgetsApp.defaultShortcuts, ..._remoteKeys} : null,
        // Escape stands in for the remote's Back button when the TV app runs in a browser.
        builder: widget.tv
            ? (context, child) => CallbackShortcuts(
                  bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _nav.currentState?.maybePop()},
                  child: _TvZoom(child: child!),
                )
            : null,
        home: widget.tv ? const TvHome() : MobileHome(key: _home),
        routes: {'/archive': (_) => const Scaffold(body: ArchiveScreen())},
      ),
    );
  }
}

/// The TV layout drawn a little smaller than the screen, so it breathes: everything at [zoom] of its size.
class _TvZoom extends StatelessWidget {
  const _TvZoom({required this.child});
  final Widget child;
  static const zoom = 0.85;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size / zoom;
    return FittedBox(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(data: mq.copyWith(size: size), child: child),
      ),
    );
  }
}

const _remoteKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
  SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
  SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
  SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
  SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
};
