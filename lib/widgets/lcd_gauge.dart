import 'dart:math';

import 'package:flutter/material.dart';

const _mint = Color(0xffa8c889);
const _mintDim = Color(0xff69745f);
const _ghost = Color(0xff59644c);

class LcdGauge extends StatelessWidget {
  const LcdGauge({
    super.key,
    required this.score,
    required this.title,
    this.subtitle = 'TODAY',
  });

  final int score;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final height = min(box.maxHeight, width * 0.56);
          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: Size(width, height),
                  painter: _GaugePainter(t),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${(t * 100).round().clamp(0, score)}',
                        style: TextStyle(
                          fontSize: height * 0.42,
                          color: _mint,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: (height * 0.11).clamp(12.0, 20.0),
                        color: _mint,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: (height * 0.075).clamp(10.0, 14.0),
                        color: _mintDim,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 33;
    final center = Offset(size.width / 2, size.height - 4);
    final radius = min(size.width / 2, size.height) - 6;
    final tickLen = radius * 0.14;
    final brush = Paint()
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < segments; i++) {
      final f = i / (segments - 1);
      final angle = pi + pi * f;
      final dir = Offset(cos(angle), sin(angle));
      final lit = value > 0 && f <= value;
      brush.color = lit ? _mint : _ghost.withValues(alpha: 0.25);
      canvas.drawLine(
        center + dir * (radius - tickLen),
        center + dir * radius,
        brush,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value;
}
