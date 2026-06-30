import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xffa8c889),
      child: Scaffold(
        backgroundColor: const Color(0xffa8c889),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 30, 12, 10),
              child: Container(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * 0.6,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(45),
                    topRight: Radius.circular(45),
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        SizedBox(height: 60),
                        Text(
                          "06:14",
                          style: TextStyle(
                            fontSize: 120,
                            color: Color(0xffa8c889),
                            height: 1.05,
                          ),
                        ),
                        Text(
                          "THE NEXT ALARM IN 67 MIN",
                          style: TextStyle(
                            fontSize: 20,

                            letterSpacing: 1,
                            color: Color(0xff69745F),
                            height: 0,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: CustomPaint(
                        painter: ProgressPainter(5),
                        size: Size(double.infinity, 150),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressPainter extends CustomPainter {
  final int totalBars = 40;
  final int currentProgress;
  ProgressPainter(this.currentProgress);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double barSpacing = size.width / totalBars;

    for (int i = 0; i < totalBars; i++) {
      paint.color = i < currentProgress
          ? const Color(0xff222222)
          : const Color(0xffa8c889);
      canvas.drawLine(
        Offset(i * barSpacing, size.height),
        Offset(i * barSpacing, 0),
        paint,
      );
      if (i % 5 == 0 && i != currentProgress) {
        paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xffa8c889).withValues(alpha: 0.4);
        canvas.drawCircle(Offset(i * barSpacing, -30), 3, paint);
        paint.style = PaintingStyle.stroke;
      }
      paint.color = Colors.red;
      canvas.drawLine(
        Offset(currentProgress * barSpacing, size.height),
        Offset(currentProgress * barSpacing, 0),
        paint..strokeWidth = 3,
      );
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.red;
      final path = Path();
      final arrowX = currentProgress * barSpacing;
      path.moveTo(arrowX, -20);
      path.lineTo(arrowX - 10, -40);
      path.lineTo(arrowX + 10, -40);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
