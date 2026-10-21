import 'package:flutter_test/flutter_test.dart';
import 'package:kahol_yavan_radio_app/api.dart';

void main() {
  test('studio board parses and falls back to Icecast', () {
    final s = Studio.fromJson({
      'now': {'title': 'Aspirini', 'artist': 'Sakis Rouvas', 'started': 100, 'duration': 200, 'isNew': true},
      'recent': [
        {'title': 'Kalinixta', 'artist': 'Giorgos Mazonakis', 'cover': 'https://x/c.jpg'},
        {'title': '', 'artist': 'skip me'},
      ],
      'show': {'nextName': 'בוקר יווני', 'nextStart': '08:00'},
      'fresh': true,
    });
    expect(s.now!.title, 'Aspirini');
    expect(s.now!.isNew, true);
    expect(s.recent.length, 1);
    expect(s.nextName, 'בוקר יווני');
    expect(s.live, true);
    expect(s.progress(DateTime.fromMillisecondsSinceEpoch(200 * 1000)), 0.5);

    final ice = Studio.empty.withIcecast('Anna Vissi - Agapi Pou Gines Dikopo Maxeri');
    expect(ice.now!.artist, 'Anna Vissi');
    expect(ice.now!.title, 'Agapi Pou Gines Dikopo Maxeri');
  });

  test('episodes: playable audio or Mixcloud', () {
    final a = Episode.fromJson({'id': 6, 'title': 'כחול יוון', 'audio': 'https://x/e.mp3', 'duration': 3612, 'mixcloud': []});
    final b = Episode.fromJson({'id': 5, 'title': 'ישן', 'audio': '', 'mixcloud': ['https://www.mixcloud.com/KaholYavan/a/']});
    expect(a.playable, true);
    expect(b.playable, false);
    expect(b.mixcloud.single, contains('mixcloud'));
  });

  test('time ranges stay in order inside Hebrew', () {
    expect(ltrTimes('בכל שישי 12:00–14:00'), 'בכל שישי \u206612:00–14:00\u2069');
    expect(ltrTimes('בכל שבת 20:00-22:00'), 'בכל שבת \u206620:00–22:00\u2069');
  });

  test('config keeps the stream when the site sends nothing', () {
    final c = AppConfig.fromJson({});
    expect(c.stream, AppConfig.fallback.stream);
  });
}
