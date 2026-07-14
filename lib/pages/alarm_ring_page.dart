import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alarm.dart';
import '../services/alarm_store.dart';
import '../services/alarm_buzz.dart';
import '../widgets/tactile.dart';

const _mint = Color(0xffa8c889);
const _muted = Color(0xff69745f);
const _stopBg = Color(0xff98ac84);

class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({super.key, this.alarm, this.sleepEndMode = false})
    : assert(alarm != null || sleepEndMode);

  final Alarm? alarm;
  final bool sleepEndMode;

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  final _buzz = AlarmBuzz();
  Timer? _flash;
  Timer? _autoFinish;
  bool _bright = true;

  // Mirrors the native blast schedule: the last blast starts at 29:50 and
  // the service's hard shutdown deadline lands just under 33 minutes.
  static const _sequenceLength = Duration(minutes: 33);

  @override
  void initState() {
    super.initState();

    _buzz.start(alarmId: widget.alarm?.id);

    _flash = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (widget.sleepEndMode) SystemSound.play(SystemSoundType.alert);
      if (mounted) setState(() => _bright = !_bright);
    });

    if (!widget.sleepEndMode) {
      _autoFinish = Timer(_sequenceLength, _finish);
    }
  }

  @override
  void dispose() {
    _flash?.cancel();
    _autoFinish?.cancel();
    if (widget.sleepEndMode) {
      _buzz.stop();
    } else {
      // The native service rings on its own schedule; only the Dart-side
      // fallback timers die with the page.
      _buzz.detach();
    }
    super.dispose();
  }

  // The sequence has played itself out — retire the alarm so once-alarms
  // disable and repeating ones re-arm for their next fire.
  Future<void> _finish() async {
    if (!mounted) return;
    final store = AlarmScope.of(context);
    await _buzz.stop();
    await store.stopRinging(widget.alarm!);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (!widget.sleepEndMode) return;
    await _buzz.stop();
    if (context.mounted) Navigator.of(context).pop('snooze');
  }

  Future<void> _stop(BuildContext context) async {
    HapticFeedback.heavyImpact();
    if (!widget.sleepEndMode) return;
    await _buzz.stop();
    if (context.mounted) Navigator.of(context).pop('stop');
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final displayTime = widget.sleepEndMode
        ? _formatTime(DateTime.now())
        : widget.alarm!.timeLabel24;
    final subtitle = widget.sleepEndMode
        ? 'SLEEP SESSION COMPLETE'
        : widget.alarm!.sound;
    final snoozeLabel = widget.sleepEndMode
        ? 'SNOOZE 10 MIN'
        : 'SNOOZE ${widget.alarm!.snoozeMinutes} MIN';

    return PopScope(
      canPop: widget.sleepEndMode,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return _landscapeBody(displayTime, subtitle, snoozeLabel);
                }
                return Column(
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
                            displayTime,
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
                      subtitle,
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
                            snoozeLabel,
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
                          child: const Text(
                            'STOP',
                            style: TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _landscapeBody(
    String displayTime,
    String subtitle,
    String snoozeLabel,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                      displayTime,
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
                subtitle,
                style: const TextStyle(fontSize: 26, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                      snoozeLabel,
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
      ],
    );
  }
}
