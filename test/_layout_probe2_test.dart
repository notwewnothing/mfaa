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

void main() {
  setUpAll(_loadDigitalFont);

  testWidgets('session page behind ADD TASK dialog with keyboard, 375x667', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2001);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = AlarmStore(clock: () => DateTime(2026, 7, 6, 8, 0));
    await tester.pumpWidget(AlarmApp(store: store));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Focus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byIcon(Icons.play_arrow),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('FOCUS SESSION'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'session page pre-dialog');

    await tester.tap(find.text('ADD TASK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final e = tester.takeException();
    expect(e, isNull, reason: 'session page with keyboard -> $e');

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
