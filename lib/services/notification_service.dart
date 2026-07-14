import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm.dart';
import 'alarm_buzz.dart';
import 'alarm_store.dart';

class NotificationService implements AlarmScheduler {
  NotificationService({this.onAlarmTap});

  final _plugin = FlutterLocalNotificationsPlugin();
  final void Function(int alarmId)? onAlarmTap;
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {}

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
        onDidReceiveNotificationResponse: _handleTap,
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      _ready = true;
    } catch (e) {
      debugPrint('notifications unavailable: $e');
    }
  }

  Future<int?> launchedByAlarm() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return int.tryParse(details?.notificationResponse?.payload ?? '');
      }
    } catch (_) {}
    return null;
  }

  void _handleTap(NotificationResponse response) {
    final id = int.tryParse(response.payload ?? '');
    if (id != null) onAlarmTap?.call(id);
  }

  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(

      'alarms_loud',
      'Alarms',
      channelDescription: 'Scheduled alarm clock notifications',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      enableVibration: true,
      vibrationPattern: notificationVibrationPattern,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  @override
  Future<void> syncAll(List<Alarm> alarms) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();


      await AlarmBuzz.cancelAllScheduled();
      for (final alarm in alarms) {
        await _schedule(alarm);
      }
    } catch (e) {
      debugPrint('alarm sync failed: $e');
    }
  }

  Future<void> _schedule(Alarm alarm) async {
    if (!alarm.enabled) return;

    final now = DateTime.now();
    final snooze = alarm.snoozedUntil;
    if (snooze != null && snooze.isAfter(now)) {
      await _zoned(
        id: alarm.id * 100 + 99,
        alarm: alarm,
        at: snooze,
        title: 'ALARM (SNOOZED) — ${alarm.timeLabel24}',
      );
      if (alarm.repeat == AlarmRepeat.once) return;
    }

    switch (alarm.repeat) {
      case AlarmRepeat.once:
        final at = alarm.nextFire(now);
        if (at == null) return;
        await _zoned(id: alarm.id * 100, alarm: alarm, at: at);
      case AlarmRepeat.daily:
        final at = _nextWallClock(now, alarm.hour, alarm.minute);
        await _zoned(
          id: alarm.id * 100,
          alarm: alarm,
          at: at,
          match: DateTimeComponents.time,
        );
      case AlarmRepeat.weekdays:
        for (var day = DateTime.monday; day <= DateTime.friday; day++) {
          var at = _nextWallClock(now, alarm.hour, alarm.minute);
          while (at.weekday != day) {
            at = at.add(const Duration(days: 1));
          }
          await _zoned(
            id: alarm.id * 100 + day,
            alarm: alarm,
            at: at,
            match: DateTimeComponents.dayOfWeekAndTime,
          );
        }
    }
  }

  DateTime _nextWallClock(DateTime now, int hour, int minute) {
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  Future<void> _zoned({
    required int id,
    required Alarm alarm,
    required DateTime at,
    String? title,
    DateTimeComponents? match,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      title: title ?? 'ALARM — ${alarm.timeLabel24}',
      body: '${alarm.sound} • NO SNOOZE. NO STOP. GET UP',
      payload: alarm.id.toString(),
      matchDateTimeComponents: match,
    );

    await AlarmBuzz.scheduleAt(id: id, alarmId: alarm.id, at: at);
  }
}
