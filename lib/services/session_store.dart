import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

class SessionStore extends ChangeNotifier {
  SessionStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _prefsKey = 'sessions.v1';
  static const focusGoalMin = 120;
  static const sleepGoalMin = 480;

  final DateTime Function() _clock;

  final List<SessionPreset> _presets = [];
  final List<FocusTask> _tasks = [];
  final Map<String, DayStats> _days = {};
  final Map<SessionKind, SessionConfig> _lastConfig = {
    SessionKind.focus: const SessionConfig(
      mode: SessionMode.alarm,
      minutes: 420,
    ),
    SessionKind.sleep: const SessionConfig(
      mode: SessionMode.quickNap,
      minutes: 30,
    ),
  };

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _disposed = false;
  bool _blockApps = false;
  bool _strictMode = false;
  List<String> _blockedApps = [];
  int _nextId = 1;

  bool get isLoaded => _loaded;
  bool get blockApps => _blockApps;
  bool get strictMode => _strictMode;
  List<String> get blockedApps => List.unmodifiable(_blockedApps);

  List<FocusTask> get tasks => List.unmodifiable(_tasks);
  List<FocusTask> get todayTasks =>
      List.unmodifiable(_tasks.where((t) => t.today));
  List<FocusTask> get laterTasks =>
      List.unmodifiable(_tasks.where((t) => !t.today));

  List<SessionPreset> presets(SessionKind kind) =>
      List.unmodifiable(_presets.where((p) => p.kind == kind));

  SessionConfig lastConfig(SessionKind kind) => _lastConfig[kind]!;

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  DayStats _statsFor(DateTime day) =>
      _days.putIfAbsent(_dayKey(day), DayStats.new);

  DayStats get _today => _statsFor(_clock());

  int get focusedTodayMin => _today.focusMin;
  int get distractedTodayMin => _today.distractedMin;

  int get sleepLastMin {
    final today = _today.sleepMin;
    if (today > 0) return today;
    final yesterday =
        _days[_dayKey(_clock().subtract(const Duration(days: 1)))];
    return yesterday?.sleepMin ?? 0;
  }

  int get focusScore =>
      ((focusedTodayMin / focusGoalMin).clamp(0.0, 1.0) * 100).round();

  int get sleepScore =>
      ((sleepLastMin / sleepGoalMin).clamp(0.0, 1.0) * 100).round();

  int get distractedPct {
    final total = focusedTodayMin + distractedTodayMin;
    if (total == 0) return 0;
    return (distractedTodayMin / total * 100).round();
  }

  int get sleepDaysThisWeek {
    var count = 0;
    final now = _clock();
    for (var i = 0; i < 7; i++) {
      final stats = _days[_dayKey(now.subtract(Duration(days: i)))];
      if (stats != null && stats.sleepMin > 0) count++;
    }
    return count;
  }

  String get regularityLabel =>
      sleepDaysThisWeek == 0 ? '-' : '$sleepDaysThisWeek/7 DAYS';

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final data = (jsonDecode(raw) as Map).cast<String, Object?>();
        _presets
          ..clear()
          ..addAll(
            (data['presets'] as List? ?? []).map(
              (e) => SessionPreset.fromJson((e as Map).cast<String, Object?>()),
            ),
          );
        _tasks
          ..clear()
          ..addAll(
            (data['tasks'] as List? ?? []).map(
              (e) => FocusTask.fromJson((e as Map).cast<String, Object?>()),
            ),
          );
        _days.clear();
        ((data['days'] as Map? ?? {})).forEach((key, value) {
          _days[key as String] = DayStats.fromJson(
            (value as Map).cast<String, Object?>(),
          );
        });
        ((data['lastConfig'] as Map? ?? {})).forEach((key, value) {
          final kind = SessionKind.values.asNameMap()[key];
          if (kind != null) {
            _lastConfig[kind] = SessionConfig.fromJson(
              (value as Map).cast<String, Object?>(),
            );
          }
        });
        _blockApps = data['blockApps'] as bool? ?? false;
        _strictMode = data['strictMode'] as bool? ?? false;
        _blockedApps = [...(data['blockedApps'] as List? ?? []).cast<String>()];
        _nextId = data['nextId'] as int? ?? 1;
      }
    } catch (_) {}
    if (_disposed) return;
    if (_presets.isEmpty && _prefs?.getString(_prefsKey) == null) {
      _presets.addAll([
        SessionPreset(
          id: _nextId++,
          name: 'DEEP FOCUS',
          kind: SessionKind.focus,
          config: const SessionConfig(mode: SessionMode.endless, minutes: 30),
        ),
        SessionPreset(
          id: _nextId++,
          name: 'DEEP SLEEP',
          kind: SessionKind.sleep,
          config: const SessionConfig(mode: SessionMode.quickNap, minutes: 30),
        ),
      ]);
    }
    _loaded = true;
    await _save();
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> recordSession(
    SessionKind kind, {
    required int activeSeconds,
    int distractedSeconds = 0,
  }) async {
    final active = (activeSeconds / 60).round();
    final distracted = (distractedSeconds / 60).round();
    if (active == 0 && distracted == 0) return;
    final stats = _today;
    if (kind == SessionKind.focus) {
      stats.focusMin += active;
      stats.distractedMin += distracted;
    } else {
      stats.sleepMin += active;
    }
    await _save();
    if (_disposed) return;
    notifyListeners();
  }

  Future<FocusTask> addTask(
    String title, {
    String tag = 'WORK',
    bool today = true,
  }) async {
    final task = FocusTask(id: _nextId++, title: title, tag: tag, today: today);
    _tasks.add(task);
    await _save();
    if (!_disposed) notifyListeners();
    return task;
  }

  Future<void> toggleTask(FocusTask task) async {
    task.done = !task.done;
    await _save();
    if (!_disposed) notifyListeners();
  }

  Future<void> removeTask(FocusTask task) async {
    _tasks.remove(task);
    await _save();
    if (!_disposed) notifyListeners();
  }

  Future<SessionPreset> addPreset(
    String name,
    SessionKind kind,
    SessionConfig config,
  ) async {
    final preset = SessionPreset(
      id: _nextId++,
      name: name,
      kind: kind,
      config: config,
    );
    _presets.add(preset);
    await _save();
    if (!_disposed) notifyListeners();
    return preset;
  }

  Future<void> removePreset(SessionPreset preset) async {
    _presets.remove(preset);
    await _save();
    if (!_disposed) notifyListeners();
  }

  Future<void> setLastConfig(SessionKind kind, SessionConfig config) async {
    _lastConfig[kind] = config;
    await _save();
    if (!_disposed) notifyListeners();
  }

  Future<void> setBlockApps(bool value) async {
    _blockApps = value;
    await _save();
    if (!_disposed) notifyListeners();
  }

  Future<void> setStrictMode(bool value) async {
    _strictMode = value;
    await _save();
    if (!_disposed) notifyListeners();
  }

  Future<void> setBlockedApps(List<String> apps) async {
    _blockedApps = [...apps];
    await _save();
    if (!_disposed) notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode({
          'presets': [for (final p in _presets) p.toJson()],
          'tasks': [for (final t in _tasks) t.toJson()],
          'days': _days.map((key, value) => MapEntry(key, value.toJson())),
          'lastConfig': _lastConfig.map(
            (key, value) => MapEntry(key.name, value.toJson()),
          ),
          'blockApps': _blockApps,
          'strictMode': _strictMode,
          'blockedApps': _blockedApps,
          'nextId': _nextId,
        }),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SessionScope extends InheritedNotifier<SessionStore> {
  const SessionScope({
    super.key,
    required SessionStore store,
    required super.child,
  }) : super(notifier: store);

  static SessionStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope missing from widget tree');
    return scope!.notifier!;
  }
}
