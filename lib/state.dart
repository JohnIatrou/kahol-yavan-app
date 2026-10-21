import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'audio.dart';

/// What every screen reads: the site's settings, the radio board (refreshed every 20 seconds) and the shows.
class AppState extends ChangeNotifier {
  AppState(this.api, this.audio);

  final Api api;
  final RadioHandler audio;

  AppConfig config = AppConfig.fallback;
  Studio studio = Studio.empty;
  List<Show> shows = const [];
  bool offline = false;
  Timer? _timer;

  Future<void> start() async {
    await Future.wait([_loadConfig(), refreshStudio(), loadShows()]);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refreshStudio());
  }

  Future<void> _loadConfig() async {
    try {
      config = await api.config();
      audio.setConfig(config);
      notifyListeners();
    } catch (_) {
      // The fallback settings keep the stream playing.
    }
  }

  Future<void> refreshStudio() async {
    try {
      var s = await api.studio();
      if (!s.live) {
        try {
          s = s.withIcecast(await api.icecastTitle(config.status));
        } catch (_) {}
      }
      studio = s;
      offline = false;
      audio.updateLive(s.now, s.program);
    } catch (_) {
      offline = true;
    }
    notifyListeners();
  }

  Future<void> loadShows() async {
    try {
      shows = await api.shows();
      notifyListeners();
    } catch (_) {}
  }

  /// The weekly schedule: shows that have a day and an hour, Sunday first.
  List<Show> get schedule {
    final s = shows.where((x) => x.day != null && x.start.isNotEmpty).toList()
      ..sort((a, b) {
        final d = a.day!.compareTo(b.day!);
        return d != 0 ? d : a.start.compareTo(b.start);
      });
    return s;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

const kDayNames = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
