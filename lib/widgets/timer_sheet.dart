import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/session.dart';
import 'minute_ruler.dart';
import 'tactile.dart';

const _mint = Color(0xffa8c889);
const _mintDim = Color(0xff69745f);
const _chipBg = Color(0xff10130d);
const _confirmBg = Color(0xff98ac84);

class TimerSheetResult {
  const TimerSheetResult({required this.config, this.presetName});

  final SessionConfig config;
  final String? presetName;
}

Future<TimerSheetResult?> showTimerSheet(
  BuildContext context, {
  required SessionKind kind,
  required SessionConfig initial,
  bool askName = false,
}) {
  return showModalBottomSheet<TimerSheetResult>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
    ),
    builder: (_) => _TimerSheet(kind: kind, initial: initial, askName: askName),
  );
}

class _TimerSheet extends StatefulWidget {
  const _TimerSheet({
    required this.kind,
    required this.initial,
    required this.askName,
  });

  final SessionKind kind;
  final SessionConfig initial;
  final bool askName;

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  late SessionMode _mode;
  late int _timerMin;
  late int _pomoMin;
  late final TextEditingController _name;

  List<SessionMode> get _modes => widget.kind == SessionKind.focus
      ? SessionMode.values
      : [SessionMode.endless, SessionMode.alarm];

  late int _alarmHour;
  late int _alarmMinute;
  late final FixedExtentScrollController _hourWheel;
  late final FixedExtentScrollController _minuteWheel;

  @override
  void initState() {
    super.initState();
    _mode = _modes.contains(widget.initial.mode)
        ? widget.initial.mode
        : _modes.first;
    _timerMin = widget.initial.mode == SessionMode.alarm
        ? widget.initial.minutes
        : 420;
    _alarmHour = _timerMin ~/ 60;
    _alarmMinute = _timerMin % 60;
    _hourWheel = FixedExtentScrollController(initialItem: _alarmHour);
    _minuteWheel = FixedExtentScrollController(initialItem: _alarmMinute);
    _pomoMin = widget.initial.mode == SessionMode.pomodoro
        ? widget.initial.minutes
        : 25;
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _hourWheel.dispose();
    _minuteWheel.dispose();
    _name.dispose();
    super.dispose();
  }

  SessionConfig get _config => SessionConfig(
    mode: _mode,
    minutes: switch (_mode) {
      SessionMode.endless => 0,
      SessionMode.pomodoro => _pomoMin,
      SessionMode.alarm => _alarmHour * 60 + _alarmMinute,
    },
  );

  void _save() {
    HapticFeedback.mediumImpact();
    final name = _name.text.trim().toUpperCase();
    Navigator.pop(
      context,
      TimerSheetResult(
        config: _config,
        presetName: widget.askName
            ? (name.isEmpty ? 'MY SESSION' : name)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  widget.askName ? 'NEW SHORTCUT' : 'TIMER',
                  style: const TextStyle(
                    fontSize: 26,
                    color: _mint,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Tactile(
                  pressedScale: 0.9,
                  child: IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, color: _mint),
                    style: IconButton.styleFrom(backgroundColor: _chipBg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (final mode in _modes) ...[
                  if (mode != _modes.first) const SizedBox(width: 10),
                  Expanded(
                    child: Tactile(
                      pressedScale: 0.95,
                      child: GestureDetector(
                        onTap: () {
                          if (_mode != mode) {
                            HapticFeedback.selectionClick();
                            setState(() => _mode = mode);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _mode == mode ? _mint : _chipBg,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(23),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 15,
                                color: _mode == mode ? Colors.black : _mintDim,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(_mode),
                children: switch (_mode) {
                  SessionMode.endless => [
                    const Icon(Icons.all_inclusive, size: 44, color: _mint),
                    const SizedBox(height: 10),
                    const Text(
                      'RUNS UNTIL YOU STOP IT',
                      style: TextStyle(fontSize: 15, color: _mintDim),
                    ),
                  ],
                  SessionMode.pomodoro => [
                    Text(
                      '$_pomoMin MIN',
                      style: const TextStyle(
                        fontSize: 48,
                        color: _mint,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'FOCUS BLOCKS + 5 MIN BREAKS',
                      style: TextStyle(fontSize: 14, color: _mintDim),
                    ),
                    const SizedBox(height: 14),
                    MinuteRuler(
                      key: const ValueKey('pomo'),
                      min: 15,
                      max: 60,
                      value: _pomoMin,
                      onChanged: (v) => setState(() => _pomoMin = v),
                    ),
                  ],
                  SessionMode.alarm => [
                    Text(
                      '${(_alarmHour % 12 == 0 ? 12 : _alarmHour % 12).toString().padLeft(2, '0')}:${_alarmMinute.toString().padLeft(2, '0')} ${_alarmHour < 12 ? 'AM' : 'PM'}',
                      style: const TextStyle(
                        fontSize: 48,
                        color: _mint,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'THEN THE SESSION ENDS ON ITS OWN',
                      style: TextStyle(fontSize: 14, color: _mintDim),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 200,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xff36402b),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _wheel(
                                controller: _hourWheel,
                                count: 24,
                                onSelect: (v) => setState(() => _alarmHour = v),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  ':',
                                  style: TextStyle(fontSize: 44, color: _mint),
                                ),
                              ),
                              _wheel(
                                controller: _minuteWheel,
                                count: 60,
                                onSelect: (v) =>
                                    setState(() => _alarmMinute = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                },
              ),
            ),
            if (widget.askName) ...[
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 20, color: _mint),
                cursorColor: _mint,
                decoration: const InputDecoration(
                  hintText: 'SHORTCUT NAME',
                  hintStyle: TextStyle(color: _mintDim),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _mintDim),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _mint),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Tactile(
              pressedScale: 0.97,
              child: SizedBox(
                height: 60,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _confirmBg,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    widget.askName ? 'SAVE SHORTCUT' : 'SAVE',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onSelect,
  }) {
    return SizedBox(
      width: 70,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 60,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.004,
        diameterRatio: 2,
        overAndUnderCenterOpacity: 0.35,
        onSelectedItemChanged: (value) {
          HapticFeedback.selectionClick();
          onSelect(value);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            return Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 40, color: _mint),
              ),
            );
          },
        ),
      ),
    );
  }
}
