import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mfaaa/main.dart';
import 'package:mfaaa/models/alarm.dart';
import 'package:mfaaa/services/alarm_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadDigitalFont() async {
  await (FontLoader(
    'Digital',
  )..addFont(rootBundle.load('assets/fonts/DS-DIGI.TTF'))).load();
}

void _phoneView(WidgetTester tester, [Size size = const Size(1170, 2532)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(_loadDigitalFont);

  testWidgets('dashboard renders without overflow on phone sizes', (
    tester,
  ) async {
    for (final size in const [Size(1170, 2532), Size(1125, 2001)]) {
      SharedPreferences.setMockInitialValues({});
      _phoneView(tester, size);

      final store = AlarmStore();
      await tester.pumpWidget(AlarmApp(store: store));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('NO UPCOMING ALARMS'), findsOneWidget);
      expect(find.text('NO ALARMS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('adding an alarm through the picker shows a card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _phoneView(tester);
    final store = AlarmStore(clock: () => DateTime(2026, 7, 6, 8, 0));

    await tester.pumpWidget(AlarmApp(store: store));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('CHOOSE TIME'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.alarms.length, 1);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.textContaining('THE NEXT ALARM IN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('toggling a card disables the alarm', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phoneView(tester);
    final store = AlarmStore(clock: () => DateTime(2026, 7, 6, 8, 0));
    await store.init();
    await store.add(
      const AlarmDraft(
        hour: 9,
        minute: 50,
        sound: 'WAKE UP',
        snoozeMinutes: 10,
        repeat: AlarmRepeat.once,
      ),
    );

    await tester.pumpWidget(AlarmApp(store: store));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(store.alarms.first.enabled, false);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.textContaining('NO UPCOMING ALARMS'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('focus tab shows score, shortcuts and starts a session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _phoneView(tester);
    final store = AlarmStore(clock: () => DateTime(2026, 7, 6, 8, 0));

    await tester.pumpWidget(AlarmApp(store: store));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Focus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('FOCUS SCORE'), findsOneWidget);
    expect(find.text('DEEP FOCUS'), findsOneWidget);
    expect(find.text('SHORTCUTS'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byIcon(Icons.play_arrow),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('FOCUS SESSION'), findsOneWidget);
    expect(find.text('BLOCK APPS'), findsOneWidget);
    expect(find.text('ACTIVATE STRICT MODE'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('29:5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('FOCUS SCORE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('sleep tab renders and session adds a task', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _phoneView(tester);
    final store = AlarmStore(clock: () => DateTime(2026, 7, 6, 8, 0));

    await tester.pumpWidget(AlarmApp(store: store));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Sleep'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('SLEEP SCORE'), findsOneWidget);
    expect(find.text('DEEP SLEEP'), findsOneWidget);
    expect(find.text('NO ALARM'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byIcon(Icons.play_arrow),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SLEEP SESSION'), findsOneWidget);

    await tester.tap(find.text('ADD TASK'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'WIND DOWN');
    await tester.tap(find.text('ADD'));
    await tester.pump();
    await tester.pump();

    expect(find.text('WIND DOWN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('timeline scrolls horizontally and is effectively infinite', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _phoneView(tester);

    final store = AlarmStore();
    await tester.pumpWidget(AlarmApp(store: store));
    await tester.pump();

    final timeline = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(timeline).position;

    final start = position.pixels;
    await tester.drag(timeline, const Offset(-260, 0));
    await tester.pump();
    expect(position.pixels, greaterThan(start));

    await tester.drag(timeline, const Offset(900, 0));
    await tester.pump();
    expect(position.pixels, lessThan(0));

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
