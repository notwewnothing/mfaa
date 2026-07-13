import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alarm.dart';
import '../widgets/tactile.dart';

const _mint = Color(0xffa8c889);
const _mintDim = Color(0xff69745f);
const _slot = Color(0xff36402b);
const _closeBg = Color(0xff10130d);
const _confirmBg = Color(0xff98ac84);

const _sounds = ['WAKE UP', 'KIND OF BLUE', 'SUNRISE', 'RADAR'];
const _snoozes = [5, 10, 15];

class TimeWheelPage extends StatefulWidget {
  const TimeWheelPage({super.key, this.initial});

  final AlarmDraft? initial;

  @override
  State<TimeWheelPage> createState() => _TimeWheelPageState();
}

class _TimeWheelPageState extends State<TimeWheelPage> {
  late final FixedExtentScrollController _hourWheel;
  late final FixedExtentScrollController _minuteWheel;

  late int _hour;
  late int _minute;
  late String _sound;
  late int _snooze;
  late AlarmRepeat _repeat;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? _defaultDraft();
    _hour = initial.hour;
    _minute = initial.minute;
    _sound = _sounds.contains(initial.sound) ? initial.sound : _sounds.first;
    _snooze = _snoozes.contains(initial.snoozeMinutes)
        ? initial.snoozeMinutes
        : 10;
    _repeat = initial.repeat;
    _hourWheel = FixedExtentScrollController(initialItem: _hour);
    _minuteWheel = FixedExtentScrollController(initialItem: _minute);
  }

  static AlarmDraft _defaultDraft() {
    final soon = DateTime.now().add(const Duration(minutes: 5));
    final minute = (soon.minute + 4) ~/ 5 * 5;
    return AlarmDraft(
      hour: minute >= 60 ? (soon.hour + 1) % 24 : soon.hour,
      minute: minute % 60,
      sound: _sounds.first,
      snoozeMinutes: 10,
      repeat: AlarmRepeat.once,
    );
  }

  @override
  void dispose() {
    _hourWheel.dispose();
    _minuteWheel.dispose();
    super.dispose();
  }

  void _cycleSound() {
    HapticFeedback.selectionClick();
    final i = _sounds.indexOf(_sound);
    setState(() => _sound = _sounds[(i + 1) % _sounds.length]);
  }

  void _cycleSnooze() {
    HapticFeedback.selectionClick();
    final i = _snoozes.indexOf(_snooze);
    setState(() => _snooze = _snoozes[(i + 1) % _snoozes.length]);
  }

  void _cycleRepeat() {
    HapticFeedback.selectionClick();
    final i = AlarmRepeat.values.indexOf(_repeat);
    setState(
      () => _repeat = AlarmRepeat.values[(i + 1) % AlarmRepeat.values.length],
    );
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      AlarmDraft(
        hour: _hour,
        minute: _minute,
        sound: _sound,
        snoozeMinutes: _snooze,
        repeat: _repeat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 250,
                          height: 90,
                          decoration: BoxDecoration(
                            color: _slot,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _wheel(
                                controller: _hourWheel,
                                count: 24,
                                onSelect: (value) => setState(() => _hour = value),
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
                                onSelect: (value) => setState(() => _minute = value),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _Option(
                                  icon: Icons.music_note,
                                  title: 'SOUND',
                                  value: _sound,
                                  onTap: _cycleSound,
                                ),
                              ),
                              Expanded(
                                child: _Option(
                                  icon: Icons.notifications,
                                  title: 'SNOOZE',
                                  value: 'EVERY $_snooze MIN',
                                  onTap: _cycleSnooze,
                                ),
                              ),
                              Expanded(
                                child: _Option(
                                  icon: Icons.repeat,
                                  title: 'REPEAT',
                                  value: _repeat.label,
                                  onTap: _cycleRepeat,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Tactile(
                                pressedScale: 0.92,
                                child: IconButton(
                                  onPressed: _dismiss,
                                  icon: Icon(Icons.close, color: Colors.green[200]),
                                  style: IconButton.styleFrom(
                                    fixedSize: const Size(60, 60),
                                    backgroundColor: _closeBg,
                                  ),
                                ),
                              ),
                              Tactile(
                                pressedScale: 0.92,
                                child: IconButton(
                                  onPressed: _confirm,
                                  icon: const Icon(Icons.check, color: Colors.black),
                                  style: IconButton.styleFrom(
                                    fixedSize: const Size(60, 60),
                                    backgroundColor: _confirmBg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 250,
                        height: 90,
                        decoration: BoxDecoration(
                          color: _slot,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _wheel(
                              controller: _hourWheel,
                              count: 24,
                              onSelect: (value) => setState(() => _hour = value),
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
                              onSelect: (value) => setState(() => _minute = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Option(
                          icon: Icons.music_note,
                          title: 'SOUND',
                          value: _sound,
                          onTap: _cycleSound,
                        ),
                      ),
                      Expanded(
                        child: _Option(
                          icon: Icons.notifications,
                          title: 'SNOOZE',
                          value: 'EVERY $_snooze MIN',
                          onTap: _cycleSnooze,
                        ),
                      ),
                      Expanded(
                        child: _Option(
                          icon: Icons.repeat,
                          title: 'REPEAT',
                          value: _repeat.label,
                          onTap: _cycleRepeat,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Tactile(
                        pressedScale: 0.92,
                        child: IconButton(
                          onPressed: _dismiss,
                          icon: Icon(Icons.close, color: Colors.green[200]),
                          style: IconButton.styleFrom(
                            fixedSize: const Size(76, 76),
                            backgroundColor: _closeBg,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'CHOOSE TIME',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green[200],
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Tactile(
                        pressedScale: 0.92,
                        child: IconButton(
                          onPressed: _confirm,
                          icon: const Icon(Icons.check, color: Colors.black),
                          style: IconButton.styleFrom(
                            fixedSize: const Size(76, 76),
                            backgroundColor: _confirmBg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
      width: 96,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 84,
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
          builder: (context, index) => Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 60,
                color: _mint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tactile(
      pressedScale: 0.94,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.green[200], size: 26),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(color: Colors.green[200], fontSize: 17),
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  value,
                  key: ValueKey(value),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _mintDim, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
