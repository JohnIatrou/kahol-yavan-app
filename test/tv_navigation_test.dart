import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kahol_yavan_radio_app/api.dart';
import 'package:kahol_yavan_radio_app/audio.dart';
import 'package:kahol_yavan_radio_app/main.dart';
import 'package:kahol_yavan_radio_app/push.dart';
import 'package:kahol_yavan_radio_app/state.dart';

/// The site's answers, saved from the test site (test/fixtures).
MockClient fakeSite() => MockClient((req) async {
      final route = req.url.queryParameters['rest_route'] ?? '';
      final name = route.split('/').last;
      final f = File('test/fixtures/$name.json');
      if (!f.existsSync()) return http.Response('{}', 404);
      return http.Response.bytes(f.readAsBytesSync(), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<AppState> pumpApp(WidgetTester tester, {required bool tv}) async {
  final state = AppState(Api(client: fakeSite()), RadioHandler());
  await tester.pumpWidget(RadioApp(state: state, push: Push(), tv: tv));
  await tester.runAsync(() => state.start());
  await tester.pump(const Duration(milliseconds: 300));
  return state;
}

String? focusedText(WidgetTester tester) {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return null;
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && w.data != null) texts.add(w.data!);
    e.visitChildren(visit);
  }
  (ctx as Element).visitChildren(visit);
  return texts.join(' | ');
}

void main() {
  testWidgets('TV: the remote reaches the archive and plays an episode', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await pumpApp(tester, tv: true);
    final episodes = (await tester.runAsync(() => state.api.episodes()))!.episodes.where((e) => e.playable).toList();
    expect(episodes.length, greaterThan(1));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Starts on the big play button.
    expect(focusedText(tester), isEmpty);

    // Down: the archive row ("ארכיון תכניות", the latest episodes), on its first card, not the nearest one.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedText(tester), startsWith(episodes[0].title), reason: 'down from the play button lands on the first episode');

    // RTL: the next episode is to the left.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedText(tester), startsWith(episodes[1].title), reason: 'arrows move along the row');

    // OK plays it. The player itself is native, so answer its calls with nothing.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (_) async => {});
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), null));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(state.audio.episode?.id, episodes[1].id);
    state.dispose();
  });

  testWidgets('Phone: every tab opens', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final state = await pumpApp(tester, tv: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text(state.studio.now!.title), findsOneWidget);
    for (final tab in ['ארכיון', 'מגזין', 'עדכונים', 'עוד', 'שידור חי']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    state.dispose();
  });
}
