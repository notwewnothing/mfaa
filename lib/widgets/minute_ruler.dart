import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _mint = Color(0xffa8c889);
const _mintDim = Color(0xff69745f);

class MinuteRuler extends StatefulWidget {
  const MinuteRuler({
    super.key,
    required this.min,
    required this.max,
    this.step = 5,
    required this.value,
    required this.onChanged,
  });

  final int min;
  final int max;
  final int step;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<MinuteRuler> createState() => _MinuteRulerState();
}

class _MinuteRulerState extends State<MinuteRuler> {
  late final FixedExtentScrollController _controller;

  int get _count => (widget.max - widget.min) ~/ widget.step + 1;

  @override
  void initState() {
    super.initState();
    final initial = ((widget.value - widget.min) ~/ widget.step).clamp(
      0,
      _count - 1,
    );
    _controller = FixedExtentScrollController(initialItem: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // I am in a house like carpet
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: 56,
              perspective: 0.0001,
              diameterRatio: 40,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) {
                HapticFeedback.selectionClick();
                widget.onChanged(widget.min + i * widget.step);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _count,
                builder: (context, i) {
                  final v = widget.min + i * widget.step;
                  final major = v % 10 == 0 && v != widget.value;
                  return RotatedBox(
                    quarterTurns: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (major)
                          Text(
                            '$v',
                            style: const TextStyle(
                              fontSize: 14,
                              color: _mintDim,
                            ),
                          )
                        else
                          const SizedBox(height: 17),
                        const SizedBox(height: 6),
                        Container(
                          width: 2,
                          height: major ? 26 : 16,
                          color: _mintDim.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                size: Size(20, 52),
                painter: _RulerMarkerPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RulerMarkerPainter extends CustomPainter {
  const _RulerMarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final brush = Paint()
      ..color = _mint
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 14), Offset(x, size.height), brush);

    brush.style = PaintingStyle.fill;
    final tip = Path()
      ..moveTo(x, 14)
      ..lineTo(x - 7, 0)
      ..lineTo(x + 7, 0)
      ..close();
    canvas.drawPath(tip, brush);
  }

  @override
  bool shouldRepaint(covariant _RulerMarkerPainter old) => false;
}
