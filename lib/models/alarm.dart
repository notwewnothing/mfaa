enum AlarmRepeat { once, daily, weekdays }

extension AlarmRepeatLabel on AlarmRepeat {
  String get label => switch (this) {
    AlarmRepeat.once => 'NO',
    AlarmRepeat.daily => 'DAILY',
    AlarmRepeat.weekdays => 'WEEKDAYS',
  };
}

class Alarm {
  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.sound = 'WAKE UP',
    this.snoozeMinutes = 10,
    this.repeat = AlarmRepeat.once,
    this.enabled = true,
    this.snoozedUntil,
  });

  final int id;
  int hour;
  int minute;
  String sound;
  int snoozeMinutes;
  AlarmRepeat repeat;
  bool enabled;
  DateTime? snoozedUntil;

  DateTime? nextFire(DateTime from) {
    if (!enabled) return null;

    final snooze = snoozedUntil;
    if (snooze != null && snooze.isAfter(from)) return snooze;

    var candidate = DateTime(from.year, from.month, from.day, hour, minute);
    while (!candidate.isAfter(from) || !_matchesRepeat(candidate)) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + 1,
        hour,
        minute,
      );
    }
    return candidate;
  }

  bool _matchesRepeat(DateTime day) => switch (repeat) {
    AlarmRepeat.weekdays => day.weekday <= DateTime.friday,
    _ => true,
  };

  String get timeLabel24 =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get timeLabel12 {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String get meridiem => hour < 12 ? 'AM' : 'PM';

  Map<String, Object?> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'sound': sound,
    'snoozeMinutes': snoozeMinutes,
    'repeat': repeat.name,
    'enabled': enabled,
    'snoozedUntil': snoozedUntil?.millisecondsSinceEpoch,
  };

  static Alarm fromJson(Map<String, Object?> json) {
    final snoozeMs = json['snoozedUntil'] as int?;
    return Alarm(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      sound: json['sound'] as String? ?? 'WAKE UP',
      snoozeMinutes: json['snoozeMinutes'] as int? ?? 10,
      repeat: AlarmRepeat.values.asNameMap()[json['repeat']] ?? AlarmRepeat.once,
      enabled: json['enabled'] as bool? ?? true,
      snoozedUntil: snoozeMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(snoozeMs),
    );
  }
}

class AlarmDraft {
  const AlarmDraft({
    required this.hour,
    required this.minute,
    required this.sound,
    required this.snoozeMinutes,
    required this.repeat,
  });

  final int hour;
  final int minute;
  final String sound;
  final int snoozeMinutes;
  final AlarmRepeat repeat;
}
