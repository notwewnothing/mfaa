import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mfaaa/main.dart';
import 'package:mfaaa/models/alarm.dart';
import 'package:mfaaa/pages/alarm_ring_page.dart';
import 'package:mfaaa/services/alarm_store.dart';
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

void main() {
  setUpAll(_fonts);

  Future<AlarmStore> seeded() async {
    SharedPreferences.setMockInitialValues({});
    final store = AlarmStore(clock: () => DateTime(2026, 7, 2, 9, 40, 30));
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
    return store;
  }

  Future<void> shoot(
    WidgetTester t,
    Widget Function(AlarmStore) build,
    String f, {
    Size size = const Size(1170, 2532),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final store = await seeded();
    await t.pumpWidget(build(store));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$f'),
    );
    await t.pumpWidget(const SizedBox.shrink());
    store.dispose();
  }

  testWidgets('home', (t) => shoot(t, (s) => AlarmApp(store: s), 'home.png'));

  testWidgets('picker', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AlarmStore(clock: () => DateTime(2026, 7, 2, 9, 40));
    await store.init();
    await t.pumpWidget(AlarmApp(store: store));
    await t.pump();
    await t.tap(find.byIcon(Icons.add));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/picker.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('ring', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = await seeded();
    final alarm = store.alarms.first;
    await t.pumpWidget(
      AlarmScope(
        store: store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Digital', useMaterial3: true),
          home: AlarmRingPage(alarm: alarm),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/ring.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
