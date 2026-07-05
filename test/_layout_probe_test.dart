import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mfaaa/main.dart';
import 'package:mfaaa/services/alarm_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadDigitalFont() async {
  await (FontLoader(
    'Digital',
  )..addFont(rootBundle.load('assets/fonts/DS-DIGI.TTF'))).load();
}

void _view(WidgetTester tester, Size logical, {double topInset = 0}) {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3.0;
  if (topInset > 0) {
    tester.view.padding = FakeViewPadding(top: topInset * 3);
  }
  addTearDown(tester.view.reset);
}

Future<AlarmStore> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = AlarmStore(clock: () => DateTime(2026, 7, 6, 8, 0));
  await tester.pumpWidget(AlarmApp(store: store));
  await tester.pump();
  await tester.pump();
  return store;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(_loadDigitalFont);

  for (final (name, size, inset) in [
    ('375x667', const Size(375, 667), 0.0),
    ('360x760+47', const Size(360, 760), 47.0),
  ]) {
    testWidgets('focus + sleep tabs render without overflow at $name', (
      tester,
    ) async {
      _view(tester, size, topInset: inset);
      final store = await _pumpApp(tester);

      await _openTab(tester, 'Focus');
      expect(tester.takeException(), isNull, reason: 'Focus tab $name');
      await _openTab(tester, 'Sleep');
      expect(tester.takeException(), isNull, reason: 'Sleep tab $name');

      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });

    testWidgets('session page renders without overflow at $name', (
      tester,
    ) async {
      _view(tester, size, topInset: inset);
      final store = await _pumpApp(tester);

      await _openTab(tester, 'Focus');
      await tester.tap(
        find.descendant(
          of: find.byType(IconButton),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('FOCUS SESSION'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'Session page $name');

      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });

    testWidgets('timer sheet (config column) no overflow at $name', (
      tester,
    ) async {
      _view(tester, size, topInset: inset);
      final store = await _pumpApp(tester);

      await _openTab(tester, 'Focus');
      await tester.tap(find.text('TIMER').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('SAVE'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Timer sheet $name');

      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });

    testWidgets('NEW shortcut sheet with keyboard open at $name', (
      tester,
    ) async {
      _view(tester, size, topInset: inset);
      final store = await _pumpApp(tester);

      await _openTab(tester, 'Focus');
      await tester.tap(find.text('NEW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('SHORTCUT NAME'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'sheet closed kb $name');

      // Simulate the on-screen keyboard: ~300 logical px bottom inset.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final e = tester.takeException();
      expect(e, isNull, reason: 'sheet with keyboard $name -> $e');

      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }
}
