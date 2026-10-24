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
import 'package:kahol_yavan_radio_app/tv/tv_show_screen.dart';

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
  testWidgets('TV: the remote reaches the archive and opens a show', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await pumpApp(tester, tv: true);
    expect(state.shows, isNotEmpty);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Starts on the big play button.
    expect(focusedText(tester), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final first = focusedText(tester)!;
    final i = state.shows.indexWhere((s) => first.contains(s.name));
    expect(i, 0, reason: 'down from the play button lands on the first show, not the nearest one');

    // RTL: the next show is to the left, the previous one to the right.
    await tester.sendKeyEvent(i > 0 ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedText(tester), contains(state.shows[i > 0 ? i - 1 : i + 1].name), reason: 'arrows move along the row');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.byType(TvShowScreen), findsOneWidget);
    expect(find.byType(TvEpisodeCard), findsWidgets);

    // The remote's Back button (a system back on Android TV) returns home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TvShowScreen), findsNothing);
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
