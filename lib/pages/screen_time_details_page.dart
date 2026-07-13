import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/app_icons.dart';
import '../services/device_usage.dart';
import '../widgets/tactile.dart';

const _screen = Color(0xffa8c889);
const _muted = Color(0xff69745f);
const _dim = Color(0xff59644c);

class _AppUsageData {
  _AppUsageData({
    required this.appName,
    required this.seconds,
    this.iconBytes,
  });

  final String appName;
  final int seconds;
  final Uint8List? iconBytes;
}

class ScreenTimeDetailsPage extends StatefulWidget {
  const ScreenTimeDetailsPage({super.key});

  @override
  State<ScreenTimeDetailsPage> createState() => _ScreenTimeDetailsPageState();
}

class _ScreenTimeDetailsPageState extends State<ScreenTimeDetailsPage>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  List<_AppUsageData> _apps = [];
  int _totalSeconds = 0;
  bool _loading = true;
  double _dragDistance = 0;
  late AnimationController _snapController;

  static const _dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _snapController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData();
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final end = start.add(const Duration(days: 1));

    final raw = await DeviceUsage.appUsageSeconds(start, end);
    int total = 0;
    for (final app in raw) {
      total += app.seconds;
    }

    final futures = raw.map((app) async {
      final icon = await AppIcons.getIcon(app.packageName);
      return _AppUsageData(
        appName: app.appName,
        seconds: app.seconds,
        iconBytes: icon,
      );
    });
    final apps = await Future.wait(futures);

    if (mounted) {
      setState(() {
        _apps = apps;
        _totalSeconds = total;
        _loading = false;
      });
    }
  }

  void _selectDate(DateTime date) {
    if (date.isAtSameMomentAs(_selectedDate)) return;
    setState(() => _selectedDate = date);
    _fetchData();
  }

  double get _effectiveOffset => _dragDistance * (1 - _snapController.value);

  void _onDragStart(DragStartDetails details) {
    if (_snapController.isAnimating) {
      _snapController.stop();
    }
    _dragDistance = _effectiveOffset;
    _snapController.reset();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragDistance = (_dragDistance + details.delta.dy).clamp(0, 300);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragDistance > 120) {
      Navigator.pop(context);
    } else {
      _snapController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dragFraction = (_dragDistance / 120).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _screen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Container(
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
            child: Opacity(
              opacity: 1 - dragFraction * 0.3,
              child: Transform.translate(
                offset: Offset(0, _effectiveOffset),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      if (orientation == Orientation.landscape) {
                        return Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onVerticalDragStart: _onDragStart,
                                    onVerticalDragUpdate: _onDragUpdate,
                                    onVerticalDragEnd: _onDragEnd,
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _dragHandle(),
                                        const SizedBox(height: 20),
                                        _dateRow(today),
                                        const SizedBox(height: 24),
                                        _totalHeader(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: _appList(),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          GestureDetector(
                            onVerticalDragStart: _onDragStart,
                            onVerticalDragUpdate: _onDragUpdate,
                            onVerticalDragEnd: _onDragEnd,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _dragHandle(),
                                const SizedBox(height: 20),
                                _dateRow(today),
                                const SizedBox(height: 24),
                                _totalHeader(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: _appList()),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _dim.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _dateRow(DateTime today) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final date = today.subtract(Duration(days: 6 - i));
        final isSelected = date.isAtSameMomentAs(_selectedDate);
        final isToday = date.isAtSameMomentAs(today);
        final label = isToday ? 'TODAY' : _dayLabels[date.weekday - 1];

        return Tactile(
          pressedScale: 0.93,
          child: GestureDetector(
            onTap: () => _selectDate(date),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: TextStyle(
                fontFamily: 'Digital',
                fontSize: 18,
                color: isSelected
                    ? _screen
                    : _dim.withValues(alpha: 0.35),
                decoration: isToday && !isSelected
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: _screen,
                decorationThickness: 1.5,
              ),
              child: Text(label),
            ),
          ),
        );
      }),
    );
  }

  Widget _totalHeader() {
    final h = _totalSeconds ~/ 3600;
    final m = (_totalSeconds % 3600) ~/ 60;
    final label = '${h}H ${m.toString().padLeft(2, '0')}M';
    final fraction = _totalSeconds > 0 ? 1.0 : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TOTAL SCREEN TIME',
              style: const TextStyle(fontSize: 15, color: _muted, height: 1.1),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: _screen,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          child: SizedBox(
            height: 6,
            width: double.infinity,
            child: ColoredBox(
              color: _dim.withValues(alpha: 0.15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  heightFactor: 1,
                  child: const ColoredBox(color: _screen),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _appList() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _muted,
          ),
        ),
      );
    }

    if (_apps.isEmpty) {
      return Center(
        child: Text(
          'NO USAGE DATA',
          style: TextStyle(
            fontSize: 22,
            color: _dim.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, _) => ListView.separated(
        itemCount: _apps.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) {
          final reveal = _staggered(t, i);
          final app = _apps[i];
          final fraction = _totalSeconds > 0
              ? app.seconds / _totalSeconds
              : 0.0;
          return _AppUsageRow(
            appName: app.appName,
            seconds: app.seconds,
            fraction: fraction,
            reveal: reveal,
            iconBytes: app.iconBytes,
          );
        },
      ),
    );
  }

  static double _staggered(double t, int i) {
    final start = i * 0.13;
    return Curves.easeOutCubic.transform(
      ((t - start) / 0.61).clamp(0.0, 1.0),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({
    required this.appName,
    required this.seconds,
    required this.fraction,
    required this.reveal,
    this.iconBytes,
  });

  final String appName;
  final int seconds;
  final double fraction;
  final double reveal;
  final Uint8List? iconBytes;

  @override
  Widget build(BuildContext context) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final label = '${h}H ${m.toString().padLeft(2, '0')}M';

    return Opacity(
      opacity: reveal,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - reveal)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _appIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _muted,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _screen,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              child: SizedBox(
                height: 5,
                width: double.infinity,
                child: ColoredBox(
                  color: _dim.withValues(alpha: 0.15),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: const ColoredBox(color: _screen),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appIcon() {
    if (iconBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          iconBytes!,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    final colors = [
      const Color(0xffa8c889),
      const Color(0xff69745f),
      const Color(0xff59644c),
      const Color(0xff8a9b7a),
      const Color(0xff7b8a6b),
    ];
    final color = colors[appName.hashCode.abs() % colors.length];

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        appName.isNotEmpty ? appName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}
