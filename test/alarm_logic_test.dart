import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mfaaa/models/alarm.dart';
import 'package:mfaaa/services/alarm_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alarm.nextFire', () {
    final monday = DateTime(2026, 7, 6, 8, 0);

    test('once fires later today when time is ahead', () {
      final alarm = Alarm(id: 1, hour: 9, minute: 30);
      expect(alarm.nextFire(monday), DateTime(2026, 7, 6, 9, 30));
    });

    test('once rolls to tomorrow when time has passed', () {
      final alarm = Alarm(id: 1, hour: 7, minute: 0);
      expect(alarm.nextFire(monday), DateTime(2026, 7, 7, 7, 0));
    });

    test('weekdays skips the weekend', () {
      final alarm = Alarm(
        id: 1,
        hour: 7,
        minute: 0,
        repeat: AlarmRepeat.weekdays,
      );
      final friday = DateTime(2026, 7, 10, 8, 0);
      expect(alarm.nextFire(friday), DateTime(2026, 7, 13, 7, 0));
    });

    test('disabled alarm never fires', () {
      final alarm = Alarm(id: 1, hour: 9, minute: 0, enabled: false);
      expect(alarm.nextFire(monday), isNull);
    });

    test('active snooze overrides the schedule', () {
      final alarm = Alarm(id: 1, hour: 9, minute: 0)
        ..snoozedUntil = DateTime(2026, 7, 6, 8, 10);
      expect(alarm.nextFire(monday), DateTime(2026, 7, 6, 8, 10));
    });

    test('json round-trip preserves everything', () {
      final alarm = Alarm(
        id: 7,
        hour: 23,
        minute: 5,
        sound: 'RADAR',
        snoozeMinutes: 15,
        repeat: AlarmRepeat.daily,
        enabled: false,
        snoozedUntil: DateTime(2026, 1, 2, 3, 4),
      );
      final copy = Alarm.fromJson(alarm.toJson());
      expect(copy.id, 7);
      expect(copy.hour, 23);
      expect(copy.minute, 5);
      expect(copy.sound, 'RADAR');
      expect(copy.snoozeMinutes, 15);
      expect(copy.repeat, AlarmRepeat.daily);
      expect(copy.enabled, false);
      expect(copy.snoozedUntil, DateTime(2026, 1, 2, 3, 4));
    });
  });

  group('AlarmStore', () {
    const draft = AlarmDraft(
      hour: 9,
      minute: 50,
      sound: 'WAKE UP',
      snoozeMinutes: 10,
      repeat: AlarmRepeat.once,
    );

    test('add, toggle, remove persist across store instances', () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 7, 6, 8, 0);

      final store = AlarmStore(clock: () => now);
      await store.init();
      final alarm = await store.add(draft);
      expect(store.alarms.length, 1);
      expect(store.nextAlarmSubtitle, 'THE NEXT ALARM IN 1 H 50 MIN');

      await store.toggle(alarm);
      expect(store.nextAlarm, isNull);
      store.dispose();

      final reloaded = AlarmStore(clock: () => now);
      await reloaded.init();
      expect(reloaded.alarms.length, 1);
      expect(reloaded.alarms.first.enabled, false);
      expect(reloaded.alarms.first.hour, 9);

      await reloaded.remove(reloaded.alarms.first);
      expect(reloaded.alarms, isEmpty);
      reloaded.dispose();
    });

    test('subtitle formats hours and empty states', () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 7, 6, 6, 0);
      final store = AlarmStore(clock: () => now);
      await store.init();
      expect(store.nextAlarmSubtitle, contains('NO UPCOMING ALARMS'));

      await store.add(
        const AlarmDraft(
          hour: 8,
          minute: 30,
          sound: 'WAKE UP',
          snoozeMinutes: 10,
          repeat: AlarmRepeat.once,
        ),
      );
      expect(store.nextAlarmSubtitle, 'THE NEXT ALARM IN 2 H 30 MIN');
      store.dispose();
    });

    test('ticker fires onRing at alarm time and once-alarm stops after stop',
        () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({});
        var now = DateTime(2026, 7, 6, 9, 48, 30);
        final store = AlarmStore(clock: () => now);
        store.init();
        async.flushMicrotasks();

        store.add(draft);
        async.flushMicrotasks();

        Alarm? rang;
        store.onRing = (alarm) => rang = alarm;

        now = now.add(const Duration(minutes: 1));
        async.elapse(const Duration(seconds: 1));
        expect(rang, isNull);

        now = now.add(const Duration(minutes: 1, seconds: 30));
        async.elapse(const Duration(seconds: 1));
        expect(rang, isNotNull);
        expect(rang!.hour, 9);
        expect(rang!.minute, 50);

        store.stopRinging(rang!);
        async.flushMicrotasks();
        expect(store.nextAlarm, isNull);
        store.dispose();
      });
    });

    test('snooze reschedules and fires again', () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({});
        var now = DateTime(2026, 7, 6, 9, 50, 0);
        final store = AlarmStore(clock: () => now);
        store.init();
        async.flushMicrotasks();

        store.add(draft);
        async.flushMicrotasks();
        final alarm = store.alarms.first;

        store.snooze(alarm);
        async.flushMicrotasks();
        expect(store.untilNext!.inMinutes, 10);

        Alarm? rang;
        store.onRing = (a) => rang = a;
        now = now.add(const Duration(minutes: 10, seconds: 5));
        async.elapse(const Duration(seconds: 1));
        expect(rang, isNotNull);
        store.dispose();
      });
    });

    test('missed once-alarm is disabled on reload', () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 7, 6, 9, 0);
      final store = AlarmStore(clock: () => now);
      await store.init();
      await store.add(draft);
      store.dispose();

      now = DateTime(2026, 7, 6, 12, 0);
      final later = AlarmStore(clock: () => now);
      await later.init();
      expect(later.alarms.first.enabled, false);
      later.dispose();
    });
  });
}
