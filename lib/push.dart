import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The notification topics the site sends to (includes/app.php in Leylot Modern).
enum PushTopic {
  episodes('episodes', 'פרקים חדשים בארכיון', 'כשתכנית חדשה עולה לארכיון'),
  shows('shows', 'תזכורת לפני תכנית', 'כמה דקות לפני שתכנית מתחילה בשידור'),
  news('news', 'הודעות מהתחנה', 'אורחים באולפן, הופעות ואירועים מיוחדים');

  const PushTopic(this.id, this.title, this.subtitle);
  final String id;
  final String title;
  final String subtitle;
}

/// Firebase Cloud Messaging. Everything here is optional: without the Firebase files in the build the app
/// works the same, only without notifications.
class Push extends ChangeNotifier {
  bool available = false;
  final Map<PushTopic, bool> enabled = {for (final t in PushTopic.values) t: true};

  /// Called with the message data when the user opens the app from a notification.
  void Function(Map<String, dynamic> data)? onOpen;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    for (final t in PushTopic.values) {
      enabled[t] = prefs.getBool('push_${t.id}') ?? true;
    }
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      available = perm.authorizationStatus != AuthorizationStatus.denied;
      for (final t in PushTopic.values) {
        await _apply(t);
      }
      FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen?.call(m.data));
      final first = await fm.getInitialMessage();
      if (first != null) {
        Future.delayed(const Duration(milliseconds: 800), () => onOpen?.call(first.data));
      }
    } catch (e) {
      debugPrint('Push not available: $e');
      available = false;
    }
    notifyListeners();
  }

  Future<void> set(PushTopic t, bool on) async {
    enabled[t] = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_${t.id}', on);
    if (available) await _apply(t);
  }

  Future<void> _apply(PushTopic t) async {
    try {
      final fm = FirebaseMessaging.instance;
      if (enabled[t]!) {
        await fm.subscribeToTopic(t.id);
      } else {
        await fm.unsubscribeFromTopic(t.id);
      }
    } catch (e) {
      debugPrint('Topic ${t.id}: $e');
    }
  }
}
