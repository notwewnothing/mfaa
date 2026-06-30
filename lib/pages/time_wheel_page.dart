import 'package:flutter/material.dart';

const _mint = Color(0xffa8c889);
const _slot = Color(0xff36402b);
const _closeBg = Color(0xff10130d);
const _confirmBg = Color(0xff98ac84);

class TimeWheelPage extends StatefulWidget {
  const TimeWheelPage({super.key, this.onPicked});

  final void Function(int hour, int minute)? onPicked;

  @override
  State<TimeWheelPage> createState() => _TimeWheelPageState();
}

class _TimeWheelPageState extends State<TimeWheelPage> {
  late final FixedExtentScrollController _hourWheel;
  late final FixedExtentScrollController _minuteWheel;

  int _hour = 0;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    _hourWheel = FixedExtentScrollController(initialItem: 0);
    _minuteWheel = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void dispose() {
    _hourWheel.dispose();
    _minuteWheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    child: Container(
                      alignment: Alignment.center,
                      width: 200,
                      height: 65,
                      decoration: BoxDecoration(
                        color: _slot,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _wheel(
                          ctrl: _hourWheel,
                          values: List.generate(24, (i) => i),
                          onSelect: (value) {
                            setState(() => _hour = value);
                            widget.onPicked?.call(_hour, _minute);
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(
                            ':',
                            style: TextStyle(fontSize: 40, color: _mint),
                          ),
                        ),
                        _wheel(
                          ctrl: _minuteWheel,
                          values: List.generate(60, (i) => i),
                          onSelect: (value) {
                            setState(() => _minute = value);
                            widget.onPicked?.call(_hour, _minute);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _option(Icons.music_note, 'SOUND\nWAKEUP'),
                  _option(Icons.notifications, 'SNOOZE\nEVERY 10 MIN'),
                  _option(Icons.repeat, 'REPEAT\nNO'),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.green[200]),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(80, 80),
                    backgroundColor: _closeBg,
                  ),
                ),
                Text(
                  'CHOOSE TIME',
                  style: TextStyle(
                    color: Colors.green[200],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.check, color: Colors.black),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(80, 80),
                    backgroundColor: _confirmBg,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(IconData glyph, String caption) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(glyph, color: Colors.green[200], size: 24),
        const SizedBox(height: 4),
        Text(
          caption,
          style: TextStyle(color: Colors.green[200], fontSize: 18),
        ),
      ],
    );
  }

  Widget _wheel({
    required FixedExtentScrollController ctrl,
    required List<int> values,
    required Function(int) onSelect,
  }) {
    return SizedBox(
      width: 70,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 80,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.005,
        diameterRatio: 2.0,
        onSelectedItemChanged: onSelect,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: values.length,
          builder: (context, index) {
            return Center(
              child: Text(
                values[index].toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 60,
                  color: _mint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
