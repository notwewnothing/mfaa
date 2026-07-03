import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alarm.dart';
import '../services/alarm_store.dart';
import '../widgets/tactile.dart';

const _mint = Color(0xffa8c889);
const _muted = Color(0xff69745f);
const _stopBg = Color(0xff98ac84);

class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({super.key, required this.alarm});

  final Alarm alarm;

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  Timer? _pulse;
  bool _bright = true;

  @override
  void initState() {
    super.initState();
    _pulse = Timer.periodic(const Duration(milliseconds: 700), (_) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      if (mounted) setState(() => _bright = !_bright);
    });
  }

  @override
  void dispose() {
    _pulse?.cancel();
    super.dispose();
  }

  Future<void> _snooze(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final store = AlarmScope.of(context);
    await store.snooze(widget.alarm);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _stop(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final store = AlarmScope.of(context);
    await store.stopRinging(widget.alarm);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              AnimatedScale(
                scale: _bright ? 1 : 0.96,
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _bright ? 1 : 0.25,
                  duration: const Duration(milliseconds: 350),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      alarm.timeLabel24,
                      style: const TextStyle(
                        fontSize: 160,
                        color: _mint,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                alarm.sound,
                style: const TextStyle(fontSize: 26, color: _muted),
              ),
              const Spacer(),
              Tactile(
                pressedScale: 0.97,
                child: SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: FilledButton(
                    onPressed: () => _snooze(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff36402b),
                      foregroundColor: _mint,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'SNOOZE ${alarm.snoozeMinutes} MIN',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Tactile(
                pressedScale: 0.97,
                child: SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: FilledButton(
                    onPressed: () => _stop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: _stopBg,
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('STOP', style: TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
