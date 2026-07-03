import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';

abstract class AlarmScheduler {
  Future<void> syncAll(List<Alarm> alarms);
}

class AlarmStore extends ChangeNotifier {
  AlarmStore({this.scheduler, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _prefsKey = 'alarms.v1';
  static const _idKey = 'alarms.nextId';
  static const _seenKey = 'alarms.lastSeen';

  final AlarmScheduler? scheduler;
  final DateTime Function() _clock;

  final List<Alarm> _alarms = [];
  SharedPreferences? _prefs;
  Timer? _ticker;
  DateTime? _lastTick;
  int _nextId = 1;
  bool _loaded = false;

  void Function(Alarm alarm)? onRing;

  bool get isLoaded => _loaded;

  List<Alarm> get alarms {
    final now = _clock();
    final sorted = [..._alarms];
    sorted.sort((a, b) {
      final fa = a.nextFire(now);
      final fb = b.nextFire(now);
      if (fa == null && fb == null) {
        return (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
      }
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fa.compareTo(fb);
    });
    return List.unmodifiable(sorted);
  }

  Alarm? get nextAlarm {
    final now = _clock();
    Alarm? best;
    DateTime? bestAt;
    for (final alarm in _alarms) {
      final at = alarm.nextFire(now);
      if (at == null) continue;
      if (bestAt == null || at.isBefore(bestAt)) {
        best = alarm;
        bestAt = at;
      }
    }
    return best;
  }

  Duration? get untilNext {
    final at = nextAlarm?.nextFire(_clock());
    return at?.difference(_clock());
  }

  String get nextAlarmSubtitle {
    final remaining = untilNext;
    if (remaining == null) return 'NO UPCOMING ALARMS — TAP + TO ADD';
    final minutes = remaining.inMinutes;
    if (minutes < 1) return 'THE NEXT ALARM IN LESS THAN A MIN';
    if (minutes < 100) return 'THE NEXT ALARM IN $minutes MIN';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return 'THE NEXT ALARM IN $h H $m MIN';
  }

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _alarms
          ..clear()
          ..addAll(
            list.map((e) => Alarm.fromJson((e as Map).cast<String, Object?>())),
          );
      }
      _nextId = _prefs?.getInt(_idKey) ?? 1;
      final seenMs = _prefs?.getInt(_seenKey);
      if (seenMs != null) {
        _reconcileMissedFires(DateTime.fromMillisecondsSinceEpoch(seenMs));
      }
    } catch (_) {}
    _loaded = true;
    _lastTick = _clock();
    _startTicker();
    await _persistAndSync();
    notifyListeners();
  }

  void _reconcileMissedFires(DateTime lastSeen) {
    final now = _clock();
    for (final alarm in _alarms) {
      if (!alarm.enabled) continue;
      final snooze = alarm.snoozedUntil;
      if (snooze != null && !snooze.isAfter(now)) {
        alarm.snoozedUntil = null;
        if (alarm.repeat == AlarmRepeat.once) alarm.enabled = false;
        continue;
      }
      if (alarm.repeat != AlarmRepeat.once || snooze != null) continue;
      final fired = alarm.nextFire(lastSeen);
      if (fired != null && !fired.isAfter(now)) alarm.enabled = false;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    final now = _clock();
    final last = _lastTick ?? now;
    if (now.minute == last.minute && now.hour == last.hour) return;
    _lastTick = now;
    _prefs?.setInt(_seenKey, now.millisecondsSinceEpoch);

    Alarm? ringing;
    for (final alarm in _alarms) {
      final at = alarm.nextFire(last);
      if (at != null && at.isAfter(last) && !at.isAfter(now)) {
        ringing = alarm;
        break;
      }
    }
    if (ringing != null) {
      ringing.snoozedUntil = null;
      onRing?.call(ringing);
    }
    notifyListeners();
  }

  Future<Alarm> add(AlarmDraft draft) async {
    final alarm = Alarm(
      id: _nextId++,
      hour: draft.hour,
      minute: draft.minute,
      sound: draft.sound,
      snoozeMinutes: draft.snoozeMinutes,
      repeat: draft.repeat,
    );
    _alarms.add(alarm);
    await _persistAndSync();
    notifyListeners();
    return alarm;
  }

  Future<void> applyDraft(Alarm alarm, AlarmDraft draft) async {
    alarm
      ..hour = draft.hour
      ..minute = draft.minute
      ..sound = draft.sound
      ..snoozeMinutes = draft.snoozeMinutes
      ..repeat = draft.repeat
      ..enabled = true
      ..snoozedUntil = null;
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> toggle(Alarm alarm) async {
    alarm.enabled = !alarm.enabled;
    alarm.snoozedUntil = null;
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> remove(Alarm alarm) async {
    _alarms.remove(alarm);
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> snooze(Alarm alarm) async {
    alarm.snoozedUntil = _clock().add(Duration(minutes: alarm.snoozeMinutes));
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> stopRinging(Alarm alarm) async {
    alarm.snoozedUntil = null;
    if (alarm.repeat == AlarmRepeat.once) alarm.enabled = false;
    await _persistAndSync();
    notifyListeners();
  }

  Alarm? byId(int id) {
    for (final alarm in _alarms) {
      if (alarm.id == id) return alarm;
    }
    return null;
  }

  Future<void> _persistAndSync() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode([for (final a in _alarms) a.toJson()]),
      );
      await _prefs?.setInt(_idKey, _nextId);
      await _prefs?.setInt(_seenKey, _clock().millisecondsSinceEpoch);
    } catch (_) {}
    try {
      await scheduler?.syncAll(List.unmodifiable(_alarms));
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

class AlarmScope extends InheritedNotifier<AlarmStore> {
  const AlarmScope({super.key, required AlarmStore store, required super.child})
    : super(notifier: store);

  static AlarmStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AlarmScope>();
    assert(scope != null, 'AlarmScope missing from widget tree');
    return scope!.notifier!;
  }
}
