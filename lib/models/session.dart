enum SessionKind { focus, sleep }

enum SessionMode { endless, pomodoro, timer }

extension SessionModeLabel on SessionMode {
  String get label => switch (this) {
    SessionMode.endless => 'ENDLESS',
    SessionMode.pomodoro => 'POMODORO',
    SessionMode.timer => 'TIMER',
  };
}

String minutesLabel(int minutes) {
  if (minutes <= 0) return '-';
  if (minutes < 60) return '${minutes}M';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}H';
  return '${h}H ${m.toString().padLeft(2, '0')}M';
}

class SessionConfig {
  const SessionConfig({required this.mode, required this.minutes});

  final SessionMode mode;
  final int minutes;

  String get label => switch (mode) {
    SessionMode.endless => 'ENDLESS',
    SessionMode.pomodoro => '$minutes+5 POMO',
    SessionMode.timer => '$minutes MIN',
  };

  Map<String, Object?> toJson() => {'mode': mode.name, 'minutes': minutes};

  static SessionConfig fromJson(Map<String, Object?> json) => SessionConfig(
    mode: SessionMode.values.asNameMap()[json['mode']] ?? SessionMode.timer,
    minutes: json['minutes'] as int? ?? 30,
  );
}

class SessionPreset {
  SessionPreset({
    required this.id,
    required this.name,
    required this.kind,
    required this.config,
  });

  final int id;
  String name;
  final SessionKind kind;
  SessionConfig config;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'config': config.toJson(),
  };

  static SessionPreset fromJson(Map<String, Object?> json) => SessionPreset(
    id: json['id'] as int,
    name: json['name'] as String? ?? 'SESSION',
    kind: SessionKind.values.asNameMap()[json['kind']] ?? SessionKind.focus,
    config: SessionConfig.fromJson(
      (json['config'] as Map? ?? {}).cast<String, Object?>(),
    ),
  );
}

const focusTags = ['WORK', 'STUDY', 'HOME', 'MIND'];

class FocusTask {
  FocusTask({
    required this.id,
    required this.title,
    this.tag = 'WORK',
    this.today = true,
    this.done = false,
  });

  final int id;
  String title;
  String tag;
  bool today;
  bool done;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'tag': tag,
    'today': today,
    'done': done,
  };

  static FocusTask fromJson(Map<String, Object?> json) => FocusTask(
    id: json['id'] as int,
    title: json['title'] as String? ?? 'TASK',
    tag: json['tag'] as String? ?? 'WORK',
    today: json['today'] as bool? ?? true,
    done: json['done'] as bool? ?? false,
  );
}

class DayStats {
  DayStats({this.focusMin = 0, this.distractedMin = 0, this.sleepMin = 0});

  int focusMin;
  int distractedMin;
  int sleepMin;

  Map<String, Object?> toJson() => {
    'focusMin': focusMin,
    'distractedMin': distractedMin,
    'sleepMin': sleepMin,
  };

  static DayStats fromJson(Map<String, Object?> json) => DayStats(
    focusMin: json['focusMin'] as int? ?? 0,
    distractedMin: json['distractedMin'] as int? ?? 0,
    sleepMin: json['sleepMin'] as int? ?? 0,
  );
}
