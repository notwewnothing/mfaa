@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mfaaa/main.dart';
import 'package:mfaaa/models/alarm.dart';
import 'package:mfaaa/models/session.dart';
import 'package:mfaaa/pages/alarm_ring_page.dart';
import 'package:mfaaa/services/alarm_store.dart';
import 'package:mfaaa/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _fonts() async {
  await (FontLoader(
    'Digital',
  )..addFont(rootBundle.load('assets/fonts/DS-DIGI.TTF'))).load();
  try {
    final b = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    await (FontLoader('MaterialIcons')..addFont(Future.value(b))).load();
  } catch (_) {}
}

void _setSize(WidgetTester tester, [Size size = const Size(1170, 2532)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AlarmStore> _alarmStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = AlarmStore(clock: () => DateTime(2026, 7, 12, 9, 40, 30));
  await store.init();
  await store.add(
    const AlarmDraft(
      hour: 9,
      minute: 50,
      sound: 'KIND OF BLUE',
      snoozeMinutes: 10,
      repeat: AlarmRepeat.once,
    ),
  );
  await store.add(
    const AlarmDraft(
      hour: 10,
      minute: 15,
      sound: 'WAKE UP',
      snoozeMinutes: 10,
      repeat: AlarmRepeat.daily,
    ),
  );
  await store.add(
    const AlarmDraft(
      hour: 22,
      minute: 0,
      sound: 'SUNRISE',
      snoozeMinutes: 5,
      repeat: AlarmRepeat.weekdays,
    ),
  );
  return store;
}

Future<SessionStore> _sessionStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SessionStore(clock: () => DateTime(2026, 7, 12, 14, 0));
  await store.init();
  await store.recordSession(
    SessionKind.focus,
    activeSeconds: 90 * 60,
    distractedSeconds: 10 * 60,
  );
  await store.recordSession(SessionKind.sleep, activeSeconds: 420 * 60);
  await store.addPreset(
    'SPRINT',
    SessionKind.focus,
    const SessionConfig(mode: SessionMode.pomodoro, minutes: 45),
  );
  await store.addPreset(
    'POWER NAP',
    SessionKind.sleep,
    const SessionConfig(mode: SessionMode.quickNap, minutes: 20),
  );
  await store.addTask('WIND DOWN', tag: 'HOME', today: true);
  return store;
}

void main() {
  setUpAll(_fonts);

  testWidgets('home screen', (tester) async {
    _setSize(tester);
    final store = await _alarmStore();
    await tester.pumpWidget(AlarmApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('time picker', (tester) async {
    _setSize(tester);
    SharedPreferences.setMockInitialValues({});
    final store = AlarmStore(clock: () => DateTime(2026, 7, 12, 9, 40));
    await store.init();
    await tester.pumpWidget(AlarmApp(store: store));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/picker.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('ring page', (tester) async {
    _setSize(tester);
    final store = await _alarmStore();
    final alarm = store.alarms.first;
    await tester.pumpWidget(
      AlarmScope(
        store: store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Digital', useMaterial3: true),
          home: AlarmRingPage(alarm: alarm),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/ring.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('focus tab', (tester) async {
    _setSize(tester);
    final alarmStore = await _alarmStore();
    final sessionStore = await _sessionStore();

    await tester.pumpWidget(AlarmApp(store: alarmStore, sessionStore: sessionStore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Focus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/focus_tab.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    alarmStore.dispose();
    sessionStore.dispose();
  });

  testWidgets('sleep tab', (tester) async {
    _setSize(tester);
    final alarmStore = await _alarmStore();
    final sessionStore = await _sessionStore();

    await tester.pumpWidget(AlarmApp(store: alarmStore, sessionStore: sessionStore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Sleep'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/sleep_tab.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    alarmStore.dispose();
    sessionStore.dispose();
  });
}
