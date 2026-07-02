import 'dart:async';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../services/alarm_store.dart';
import 'time_wheel_page.dart';

const _screen = Color(0xffa8c889);
const _muted = Color(0xff69745f);
const _dim = Color(0xff59644c);
const _barGap = 9.0;

class ClockDashboard extends StatelessWidget {
  const ClockDashboard({super.key});

  static const _week = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  Future<void> _addAlarm(BuildContext context) async {
    final store = AlarmScope.of(context);
    final draft = await Navigator.push<AlarmDraft>(
      context,
      MaterialPageRoute(builder: (_) => const TimeWheelPage()),
    );
    if (draft != null) await store.add(draft);
  }

  Future<void> _editAlarm(BuildContext context, Alarm alarm) async {
    final store = AlarmScope.of(context);
    final draft = await Navigator.push<AlarmDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => TimeWheelPage(
          initial: AlarmDraft(
            hour: alarm.hour,
            minute: alarm.minute,
            sound: alarm.sound,
            snoozeMinutes: alarm.snoozeMinutes,
            repeat: alarm.repeat,
          ),
        ),
      ),
    );
    if (draft != null) await store.applyDraft(alarm, draft);
  }

  Future<void> _confirmDelete(BuildContext context, Alarm alarm) async {
    final store = AlarmScope.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'DELETE ALARM ${alarm.timeLabel24}?',
          style: const TextStyle(color: _screen, fontSize: 22),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'KEEP',
              style: TextStyle(color: _muted, fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Color(0xffe57373), fontSize: 18),
            ),
          ),
        ],
      ),
    );
    if (yes == true) await store.remove(alarm);
  }

  @override
  Widget build(BuildContext context) {
    final store = AlarmScope.of(context);
    final today = DateTime.now().weekday;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _screen,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: _panel(store, topInset),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < _week.length; i++)
                  Text(
                    _week[i],
                    style: TextStyle(
                      fontSize: 20,
                      color: today == i + 1
                          ? Colors.black
                          : _dim.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: LayoutBuilder(
              builder: (context, strip) {
                final alarms = store.alarms;
                final cardWidth = strip.maxWidth * 0.82;
                if (alarms.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _emptyCard(context),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: alarms.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _AlarmCard(
                    alarm: alarms[i],
                    width: cardWidth,
                    onToggle: () => store.toggle(alarms[i]),
                    onEdit: () => _editAlarm(context, alarms[i]),
                    onDelete: () => _confirmDelete(context, alarms[i]),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: _dock(context, store),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(AlarmStore store, double topInset) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topInset + 10, 24, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LiveClock(),
                  Text(
                    store.nextAlarmSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      color: _muted,
                      height: -4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 96, child: _InfiniteTimeline()),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return DottedBorder(
      color: Colors.grey,
      strokeWidth: 2,
      dashPattern: const [5, 5],
      borderType: BorderType.RRect,
      radius: const Radius.circular(6),
      child: InkWell(
        onTap: () => _addAlarm(context),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('NO ALARMS', style: TextStyle(fontSize: 42, color: _dim)),
              SizedBox(height: 6),
              Text(
                'TAP HERE OR + TO SET ONE',
                style: TextStyle(fontSize: 18, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dock(BuildContext context, AlarmStore store) {
    final next = store.nextAlarm?.nextFire(DateTime.now());
    final remaining = store.untilNext;
    double? fraction;
    if (remaining != null) {
      final mins = remaining.inMinutes.clamp(0, 60);
      fraction = 1 - mins / 60;
    }

    return Row(
      children: [
        _roundButton(
          icon: Icons.calendar_month,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          onTap: () {},
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 58,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.all(Radius.circular(29)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _NowLabel(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CustomPaint(
                      size: const Size(double.infinity, 22),
                      painter: _DockTrackPainter(fraction),
                    ),
                  ),
                ),
                Text(
                  next == null
                      ? '--:--'
                      : '${next.hour}:${next.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 16, color: _screen),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _roundButton(
          icon: Icons.add,
          shape: const CircleBorder(),
          onTap: () => _addAlarm(context),
        ),
      ],
    );
  }

  Widget _roundButton({
    required IconData icon,
    required OutlinedBorder shape,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: _screen),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black,
        fixedSize: const Size(58, 58),
        shape: shape,
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.alarm,
    required this.width,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Alarm alarm;
  final double width;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = alarm.repeat == AlarmRepeat.once
        ? alarm.sound
        : '${alarm.sound} • ${alarm.repeat.label}';

    return DottedBorder(
      color: Colors.grey,
      strokeWidth: 2,
      dashPattern: const [5, 5],
      borderType: BorderType.RRect,
      radius: const Radius.circular(6),
      child: InkWell(
        onTap: onEdit,
        onLongPress: onDelete,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Opacity(
              opacity: alarm.enabled ? 1 : 0.35,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alarm.timeLabel12,
                            style: const TextStyle(
                              fontSize: 54,
                              color: Colors.black,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 2),
                            child: Text(
                              alarm.meridiem,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: onToggle,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          alarm.enabled ? Icons.play_arrow : Icons.pause,
                          size: 54,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 18, color: _muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NowLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Text(
      '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      style: const TextStyle(fontSize: 16, color: _screen),
    );
  }
}

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _ticker;
  late DateTime _now = DateTime.now();
  bool _showColon = true;

  @override
  void initState() {
    super.initState();

    _ticker = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
          _showColon = !_showColon;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgStr = '88:88';
    final fgStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return FittedBox(
      fit: BoxFit.fitWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(bgStr.length, (i) {
          final isColon = bgStr[i] == ':';
          final isActive = !isColon || _showColon;
          final isOne = fgStr[i] == '1';

          return Stack(
            alignment: Alignment.centerRight,
            children: [
              Text(
                bgStr[i],
                style: TextStyle(
                  fontSize: 150,
                  color: _dim.withValues(alpha: 0.27),
                  height: 1.6,
                ),
              ),
              Transform.translate(
                // fix for the "1" being slightly to the left
                offset: isOne ? const Offset(7, 0) : Offset.zero,
                child: Text(
                  fgStr[i],
                  style: TextStyle(
                    fontSize: 150,
                    color: isActive ? _screen : Colors.transparent,
                    height: 1,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _InfiniteTimeline extends StatefulWidget {
  const _InfiniteTimeline();

  @override
  State<_InfiniteTimeline> createState() => _InfiniteTimelineState();
}

class _InfiniteTimelineState extends State<_InfiniteTimeline> {
  final _centerKey = UniqueKey();
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final markerX = box.maxWidth * 0.16;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CustomScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              center: _centerKey,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFixedExtentList(
                  itemExtent: _barGap,
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _Bar(dot: (i + 1) % 5 == 0),
                  ),
                ),
                SliverFixedExtentList(
                  key: _centerKey,
                  itemExtent: _barGap,
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _Bar(dot: i % 5 == 0),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              top: 22,
              bottom: 0,
              width: markerX,
              child: const IgnorePointer(
                child: ColoredBox(color: Color(0xd0000000)),
              ),
            ),
            Positioned(
              left: markerX - 10,
              top: 0,
              bottom: 0,
              width: 20,
              child: const IgnorePointer(
                child: CustomPaint(
                  painter: _MarkerPainter(),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.dot});

  final bool dot;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarPainter(dot),
      child: const SizedBox.expand(),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter(this.dot);

  final bool dot;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final brush = Paint()
      ..color = _screen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 22), Offset(x, size.height), brush);

    if (dot) {
      brush.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, 6), 2.5, brush);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.dot != dot;
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final brush = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 20), Offset(x, size.height), brush);

    brush.style = PaintingStyle.fill;
    final tip = Path()
      ..moveTo(x, 20)
      ..lineTo(x - 9, 2)
      ..lineTo(x + 9, 2)
      ..close();
    canvas.drawPath(tip, brush);
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter old) => false;
}

class _DockTrackPainter extends CustomPainter {
  const _DockTrackPainter(this.fraction);

  final double? fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final brush = Paint()
      ..color = _muted
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const ticks = 18;
    final gap = size.width / (ticks - 1);
    for (var n = 0; n < ticks; n++) {
      canvas.drawLine(
        Offset(n * gap, mid - 3),
        Offset(n * gap, mid + 3),
        brush,
      );
    }

    final f = fraction;
    if (f != null) {
      brush
        ..color = Colors.red
        ..strokeWidth = 2.5;
      final x = size.width * f.clamp(0.02, 0.98);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), brush);
    }
  }

  @override
  bool shouldRepaint(covariant _DockTrackPainter old) =>
      old.fraction != fraction;
}
