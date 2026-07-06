import 'package:flutter_test/flutter_test.dart';
import 'package:mfaaa/models/session.dart';
import 'package:mfaaa/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime fixed() => DateTime(2026, 7, 4, 10, 0);

  test('fresh store seeds default shortcuts and zero scores', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(clock: fixed);
    await store.init();

    expect(store.presets(SessionKind.focus).map((p) => p.name), ['DEEP FOCUS']);
    expect(store.presets(SessionKind.sleep).map((p) => p.name), ['DEEP SLEEP']);
    expect(store.focusScore, 0);
    expect(store.sleepScore, 0);
    expect(store.distractedPct, 0);
    expect(store.regularityLabel, '-');
    store.dispose();
  });

  test('recording focus sessions drives score and distraction', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(clock: fixed);
    await store.init();

    await store.recordSession(
      SessionKind.focus,
      activeSeconds: 60 * 60,
      distractedSeconds: 20 * 60,
    );

    expect(store.focusedTodayMin, 60);
    expect(store.distractedTodayMin, 20);
    expect(store.focusScore, 50);
    expect(store.distractedPct, 25);
    store.dispose();
  });

  test('recording sleep drives sleep score and regularity', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(clock: fixed);
    await store.init();

    await store.recordSession(SessionKind.sleep, activeSeconds: 240 * 60);

    expect(store.sleepLastMin, 240);
    expect(store.sleepScore, 50);
    expect(store.regularityLabel, '1/7 DAYS');
    store.dispose();
  });

  test('sleep recorded yesterday still counts as last sleep', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 7, 3, 23, 0);
    final store = SessionStore(clock: () => now);
    await store.init();

    await store.recordSession(SessionKind.sleep, activeSeconds: 480 * 60);
    now = DateTime(2026, 7, 4, 9, 0);

    expect(store.sleepLastMin, 480);
    expect(store.sleepScore, 100);
    store.dispose();
  });

  test('tasks, presets, config and settings survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(clock: fixed);
    await store.init();

    final task = await store.addTask('SHIP IT', tag: 'WORK', today: true);
    await store.toggleTask(task);
    await store.addTask('READ', tag: 'MIND', today: false);
    await store.addPreset(
      'SPRINT',
      SessionKind.focus,
      const SessionConfig(mode: SessionMode.pomodoro, minutes: 45),
    );
    await store.setLastConfig(
      SessionKind.focus,
      const SessionConfig(mode: SessionMode.alarm, minutes: 90),
    );
    await store.setBlockApps(true);
    await store.setStrictMode(true);
    await store.setBlockedApps(['SOCIAL', 'GAMES']);
    await store.recordSession(SessionKind.focus, activeSeconds: 30 * 60);
    store.dispose();

    final reloaded = SessionStore(clock: fixed);
    await reloaded.init();

    expect(reloaded.todayTasks.single.title, 'SHIP IT');
    expect(reloaded.todayTasks.single.done, true);
    expect(reloaded.laterTasks.single.tag, 'MIND');
    expect(reloaded.presets(SessionKind.focus).map((p) => p.name), [
      'DEEP FOCUS',
      'SPRINT',
    ]);
    expect(reloaded.lastConfig(SessionKind.focus).minutes, 90);
    expect(reloaded.lastConfig(SessionKind.focus).mode, SessionMode.alarm);
    expect(reloaded.blockApps, true);
    expect(reloaded.strictMode, true);
    expect(reloaded.blockedApps, ['SOCIAL', 'GAMES']);
    expect(reloaded.focusedTodayMin, 30);
    reloaded.dispose();
  });

  test('removing tasks and presets persists', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore(clock: fixed);
    await store.init();

    final task = await store.addTask('DROP ME');
    await store.removeTask(task);
    await store.removePreset(store.presets(SessionKind.focus).single);

    expect(store.tasks, isEmpty);
    expect(store.presets(SessionKind.focus), isEmpty);
    expect(store.presets(SessionKind.sleep).length, 1);
    store.dispose();
  });

  test('minutesLabel formats hours and minutes', () {
    expect(minutesLabel(0), '-');
    expect(minutesLabel(45), '45M');
    expect(minutesLabel(60), '1H');
    expect(minutesLabel(65), '1H 05M');
    expect(minutesLabel(480), '8H');
  });
}
