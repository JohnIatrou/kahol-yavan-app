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

/// Android TV and Google TV declare the "leanback" feature.
Future<bool> _isTv() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.systemFeatures.contains('android.software.leanback');
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
        home: widget.tv ? const TvHome() : MobileHome(key: _home),
        routes: {'/archive': (_) => const Scaffold(body: ArchiveScreen())},
      ),
    );
  }
}
