import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

import 'time_wheel_page.dart';

const _screen = Color(0xffa8c889);
const _muted = Color(0xff69745f);
const _dim = Color(0xff59644c);
const _filledBar = Color(0xff333333);

class ClockDashboard extends StatefulWidget {
  const ClockDashboard({super.key});

  @override
  State<ClockDashboard> createState() => _ClockDashboardState();
}

class _ClockDashboardState extends State<ClockDashboard> {
  static const _week = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      color: _screen,
      child: Scaffold(
        backgroundColor: _screen,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 10.0,
                right: 10.0,
                top: 30.0,
                bottom: 10.0,
              ),
              child: Container(
                width: double.infinity,
                height: media.size.height * 0.6,
                padding: EdgeInsets.only(top: media.padding.top),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(55),
                    topRight: Radius.circular(55),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      children: [
                        SizedBox(height: 60),
                        Text(
                          '09:42',
                          style: TextStyle(
                            fontSize: 120,
                            color: _screen,
                            height: 0,
                          ),
                        ),
                        Text(
                          'THE NEXT ALARM CLOCK IN 19 MIN',
                          style: TextStyle(fontSize: 18, color: _muted),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0, left: 15.0),
                      child: CustomPaint(
                        painter: TimelinePainter(5),
                        size: const Size(double.infinity, 150),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _week
                  .map(
                    (label) => Text(
                      label,
                      style: TextStyle(
                        fontSize: 22,
                        color:
                            DateTime.now().weekday == _week.indexOf(label) + 1
                            ? Colors.black
                            : _dim,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: List.generate(3, (_) => _alarmTile())),
              ),
            ),
          ],
        ),
        persistentFooterButtons: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.calendar_month, color: _screen),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black,
                  fixedSize: const Size(60, 60),
                ),
              ),
              SizedBox(
                width: 250,
                child: FloatingActionButton.extended(
                  onPressed: () {},
                  label: const Text('09:42', style: TextStyle(fontSize: 24)),
                  shape: const StadiumBorder(),
                  backgroundColor: Colors.black,
                  foregroundColor: _screen,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TimeWheelPage()),
                ),
                icon: const Icon(Icons.add, color: _screen),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black,
                  fixedSize: const Size(60, 60),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alarmTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: DottedBorder(
        color: Colors.grey,
        strokeWidth: 2,
        dashPattern: const [5, 5],
        borderType: BorderType.RRect,
        child: Container(
          padding: const EdgeInsets.all(8),
          width: 350,
          height: 150,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('09:42', style: TextStyle(fontSize: 60)),
                  Icon(Icons.play_arrow, size: 70),
                ],
              ),
              Text(
                'VATINOFE KIND OF BLUE',
                style: TextStyle(fontSize: 24, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimelinePainter extends CustomPainter {
  TimelinePainter(this.active);

  final int active;
  final int _tickTotal = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final brush = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final gap = size.width / _tickTotal;

    for (var n = 0; n < _tickTotal; n++) {
      brush.color = n < active ? _filledBar : _screen;
      canvas.drawLine(Offset(n * gap, size.height), Offset(n * gap, 0), brush);

      if (n % 5 == 0 && n != active) {
        brush
          ..style = PaintingStyle.fill
          ..color = _screen;
        canvas.drawCircle(Offset(n * gap, -30), 3, brush);
        brush.style = PaintingStyle.stroke;
      }

      brush.color = Colors.red;
      canvas.drawLine(
        Offset(active * gap, size.height),
        Offset(active * gap, 0),
        brush..strokeWidth = 3,
      );

      brush
        ..style = PaintingStyle.fill
        ..color = Colors.red;

      final tipX = active * gap;
      final tip = Path()
        ..moveTo(tipX, -20)
        ..lineTo(tipX - 10, -40)
        ..lineTo(tipX + 10, -40)
        ..close();

      canvas.drawPath(tip, brush);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
