import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';


final Int64List notificationVibrationPattern = Int64List.fromList(
  [0, 1200, 90, 300, 80, 300, 80, 300, 80, 300, 80, 900],
);

const _channel = MethodChannel('mfaaa/alarm_buzz');

const List<int> _pattern = [0, 1200, 90, 300, 80, 300, 80, 300, 90];
const List<int> _amplitudes = [0, 255, 0, 255, 0, 255, 0, 255, 0];

class AlarmBuzz {
  Timer? _keepAlive;
  Timer? _fallback;
  Timer? _cap;
  bool _running = false;

  static Future<void> scheduleAt({
    required int id,
    required int alarmId,
    required DateTime at,
  }) async {
    try {
      await _channel.invokeMethod('schedule', {
        'id': id,
        'alarmId': alarmId,
        'at': at.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  static Future<void> cancelAllScheduled() async {
    try {
      await _channel.invokeMethod('cancelAllScheduled');
    } catch (_) {}
  }


  static Future<int?> activeAlarmId() async {
    try {
      return await _channel.invokeMethod<int>('activeAlarmId');
    } catch (_) {
      return null;
    }
  }

  Future<void> start({int? alarmId}) async {
    if (_running) return;
    _running = true;
    try {
      await _channel.invokeMethod('start', {'alarmId': alarmId ?? -1});
      return;
    } catch (_) {

    }
    await _startPluginFallback();
  }

  // Cancels the Dart-side fallback timers without touching the native
  // service — the ring page dies, the alarm doesn't.
  void detach() {
    _running = false;
    _keepAlive?.cancel();
    _keepAlive = null;
    _fallback?.cancel();
    _fallback = null;
    _cap?.cancel();
    _cap = null;
  }

  Future<void> stop() async {
    detach();
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  Future<void> _startPluginFallback() async {
    // Mirrors the native service's 10-minute vibration window.
    _cap?.cancel();
    _cap = Timer(const Duration(minutes: 10), stop);

    var hasVibrator = false;
    try {
      hasVibrator = await Vibration.hasVibrator();
    } catch (_) {}

    if (!hasVibrator) {
      _startHapticFallback();
      return;
    }

    await _fire();

    _keepAlive = Timer.periodic(const Duration(seconds: 2), (_) => _fire());
  }

  Future<void> _fire() async {
    try {
      var amplitudeControl = false;
      try {
        amplitudeControl = await Vibration.hasAmplitudeControl();
      } catch (_) {}
      await Vibration.vibrate(
        pattern: _pattern,
        intensities: amplitudeControl ? _amplitudes : const [],
        repeat: 0,
      );
    } catch (_) {
      if (_fallback == null) _startHapticFallback();
    }
  }

  void _startHapticFallback() {
    HapticFeedback.heavyImpact();
    _fallback = Timer.periodic(const Duration(milliseconds: 350), (_) {
      HapticFeedback.heavyImpact();
    });
  }
}
