import 'dart:convert';
import 'dart:io';

import 'package:dunya/core/learning.dart';
import 'package:dunya/core/world.dart';
import 'package:dunya/main.dart';
import 'package:dunya/state.dart';
import 'package:dunya/ui/common.dart';
import 'package:dunya/ui/globe_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final world = World.fromJson(jsonDecode(File('assets/world.json').readAsStringSync()) as Map<String, dynamic>);

Future<AppState> pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  // Reduced motion: the sky and globe stand still, so tests can wait for animations to finish.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  SharedPreferences.setMockInitialValues({});
  final state = AppState(world, await SharedPreferences.getInstance())..setLang('de');
  await tester.pumpWidget(DunyaApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Country selectedCountry(WidgetTester tester) => world.byIso(tester.widget<GlobeView>(find.byType(GlobeView).last).selected!)!;

Future<void> openExploreAndPickRandom(WidgetTester tester) async {
  await tester.tap(find.text('Welt entdecken'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Zufälliges Land'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('explore: naming the country colours it lightly, the capital completes it', (tester) async {
    final state = await pump(tester);
    await openExploreAndPickRandom(tester);
    final c = selectedCountry(tester);
    expect(find.text('Welches Land ist das?'), findsOneWidget);

    await tester.tap(find.widgetWithText(AnswerButton, c.name('de')));
    await tester.pump();
    expect(state.progressOf(c.iso), Progress.country);
    await tester.pump(const Duration(milliseconds: 1200)); // on to the capital
    await tester.pumpAndSettle();
    expect(find.text('Was ist die Hauptstadt von ${c.name('de')}?'), findsOneWidget);

    await tester.tap(find.widgetWithText(AnswerButton, c.capital('de')));
    await tester.pumpAndSettle();
    expect(state.progressOf(c.iso), Progress.complete);
    expect(find.text('1 von 195 Ländern'), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Hauptstadt'), findsOneWidget, reason: 'the info card shows what was learned');
  });

  testWidgets('explore: a wrong guess shows the answer and leaves the country grey', (tester) async {
    final state = await pump(tester);
    await openExploreAndPickRandom(tester);
    final c = selectedCountry(tester);
    final wrong = tester
        .widgetList<AnswerButton>(find.byType(AnswerButton))
        .firstWhere((b) => b.text != c.name('de'));
    await tester.tap(find.widgetWithText(AnswerButton, wrong.text));
    await tester.pumpAndSettle();
    expect(state.progressOf(c.iso), Progress.none);
    expect(find.textContaining('Das ist ${c.name('de')}.'), findsOneWidget);
  });

  testWidgets('flags: a perfect round sets a record', (tester) async {
    final state = await pump(tester);
    await tester.tap(find.text('Flaggen'));
    await tester.pumpAndSettle();
    for (var i = 1; i <= 10; i++) {
      expect(find.text('Flagge $i von 10'), findsOneWidget);
      final c = tester.widget<Flag>(find.byType(Flag)).country;
      await tester.tap(find.widgetWithText(AnswerButton, c.name('de')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Neuer Rekord!'), findsOneWidget);
    expect(state.bestFlags, 10);
  });

  testWidgets('higher or lower: the right pick extends the streak, a wrong one ends it', (tester) async {
    final state = await pump(tester);
    await tester.tap(find.text('Mehr oder weniger?'));
    await tester.pumpAndSettle();

    List<Country> shown() => tester.widgetList<Flag>(find.byType(Flag)).map((f) => f.country).toList();
    var [a, b] = shown();
    await tester.tap(find.text((a.population! > b.population! ? a : b).name('de')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    [a, b] = shown();
    await tester.tap(find.text((a.population! > b.population! ? b : a).name('de')));
    await tester.pumpAndSettle();
    expect(find.text('Neuer Rekord!'), findsOneWidget);
    expect(state.bestStreak, 1);
  });

  testWidgets('progress survives a restart', (tester) async {
    final state = await pump(tester);
    state.advance('DE', Progress.complete);
    state.advance('FR', Progress.country);
    state.advance('DE', Progress.country); // never goes back
    final again = AppState(world, await SharedPreferences.getInstance());
    expect([again.progressOf('DE'), again.progressOf('FR'), again.progressOf('IT')], [Progress.complete, Progress.country, Progress.none]);
  });
}
