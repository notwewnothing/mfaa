import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alarm.dart';
import '../models/session.dart';
import '../services/alarm_store.dart';
import '../services/device_usage.dart';
import '../services/session_store.dart';
import '../widgets/slide_up_route.dart';
import '../widgets/tactile.dart';
import 'screen_time_details_page.dart';
import 'session_page.dart';
import 'session_tabs.dart';
import 'time_wheel_page.dart';

const _screen = Color(0xffa8c889);
const _muted = Color(0xff69745f);
const _dim = Color(0xff59644c);
const _barGap = 14.0;

const _navTabs = [
  (Icons.light_mode_outlined, 'Home', 'YOUR ALARMS, ALL IN ONE PLACE'),
  (Icons.headphones_outlined, 'Focus', 'DISTRACTION-FREE TIMERS ARE COMING'),
  (Icons.nightlight_outlined, 'Sleep', 'SLEEP TRACKING IS COMING'),
  (Icons.people_outline, 'Crew', 'SHARED ALARMS WITH FRIENDS ARE COMING'),
];

class ClockDashboard extends StatefulWidget {
  const ClockDashboard({super.key});

  @override
  State<ClockDashboard> createState() => _ClockDashboardState();
}

class _ClockDashboardState extends State<ClockDashboard> {
  static const _week = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  int _selectedTab = 0;

  Future<void> _addAlarm(BuildContext context) async {
    HapticFeedback.lightImpact();
    final store = AlarmScope.of(context);
    final draft = await Navigator.push<AlarmDraft>(
      context,
      slideUpRoute<AlarmDraft>(const TimeWheelPage()),
    );
    if (draft != null) await store.add(draft);
  }

  Future<void> _editAlarm(BuildContext context, Alarm alarm) async {
    HapticFeedback.selectionClick();
    final store = AlarmScope.of(context);
    final draft = await Navigator.push<AlarmDraft>(
      context,
      slideUpRoute<AlarmDraft>(
        TimeWheelPage(
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
    HapticFeedback.heavyImpact();
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
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return Row(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
                    child: _landscapeDock(context, store),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    top: true, bottom: true, left: false, right: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (current, previous) => Stack(
                          fit: StackFit.expand,
                          children: [...previous, ?current],
                        ),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_selectedTab),
                          child: switch (_selectedTab) {
                             0 => Padding(
                               padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                               child: _landscapeHomeBody(context, store, today, topInset),
                             ),
                            1 => const Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                              child: FocusPage(),
                            ),
                            2 => const Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                              child: SleepPage(),
                            ),
                            _ => Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                              child: _placeholderPanel(_navTabs[_selectedTab]),
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_selectedTab),
                    child: switch (_selectedTab) {
                      0 => _homeBody(context, store, today, topInset),
                      1 => const Padding(
                        padding: EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: FocusPage(),
                      ),
                      2 => const Padding(
                        padding: EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: SleepPage(),
                      ),
                      _ => Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: _placeholderPanel(_navTabs[_selectedTab]),
                      ),
                    },
                  ),
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
          );
        },
      ),
    );
  }

  Widget _landscapeDock(BuildContext context, AlarmStore store) {
    final action = switch (_selectedTab) {
      0 => (Icons.add, () => _addAlarm(context)),
      1 => (Icons.play_arrow, () => _startSession(context, SessionKind.focus)),
      2 => (Icons.play_arrow, () => _startSession(context, SessionKind.sleep)),
      _ => null,
    };

    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < _navTabs.length; i++)
                  Expanded(
                      child: _NavItem(
                      icon: _navTabs[i].$1,
                      label: _navTabs[i].$2,
                      selected: _selectedTab == i,
                      onTap: () {
                        if (i != _selectedTab) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = i);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Tactile(
                pressedScale: 0.9,
                child: IconButton(
                  onPressed: action.$2,
                  icon: Icon(action.$1, color: _screen),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xff36402b),
                    fixedSize: const Size(56, 56),
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 56),
        ],
      ),
    );
  }

  Widget _homeBody(
    BuildContext context,
    AlarmStore store,
    int today,
    double topInset,
  ) {
    return Column(
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
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontFamily: 'Digital',
                    fontSize: 20,
                    color: today == i + 1
                        ? Colors.black
                        : _dim.withValues(alpha: 0.3),
                  ),
                  child: Text(_week[i]),
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
                  onToggle: () {
                    HapticFeedback.mediumImpact();
                    store.toggle(alarms[i]);
                  },
                  onEdit: () => _editAlarm(context, alarms[i]),
                  onDelete: () => _confirmDelete(context, alarms[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _landscapeHomeBody(
    BuildContext context,
    AlarmStore store,
    int today,
    double topInset,
  ) {
    final alarms = store.alarms;

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
        padding: EdgeInsets.fromLTRB(14, topInset + 4, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Flexible(
                    flex: 3,
                    child: LayoutBuilder(
                      builder: (context, box) => FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: box.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _LiveClock(),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  store.nextAlarmSubtitle,
                                  key: ValueKey(store.nextAlarmSubtitle),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: _muted,
                                    height: -4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _InfiniteTimeline()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  const Expanded(flex: 2, child: _StatsBoard()),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < _week.length; i++)
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontFamily: 'Digital',
                            fontSize: 20,
                            color: today == i + 1
                                ? _screen
                                : _dim.withValues(alpha: 0.3),
                          ),
                          child: Text(_week[i]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: LayoutBuilder(
                      builder: (context, strip) {
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
                            onToggle: () {
                              HapticFeedback.mediumImpact();
                              store.toggle(alarms[i]);
                            },
                            onEdit: () => _editAlarm(context, alarms[i]),
                            onDelete: () => _confirmDelete(context, alarms[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderPanel((IconData, String, String) tab) {
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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.$1, size: 72, color: _screen),
            const SizedBox(height: 20),
            Text(
              tab.$2.toUpperCase(),
              style: const TextStyle(fontSize: 34, color: _screen),
            ),
            const SizedBox(height: 10),
            Text(
              tab.$3,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: _muted),
            ),
          ],
        ),
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
              flex: 3,
              child: LayoutBuilder(
                builder: (context, box) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: box.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LiveClock(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            store.nextAlarmSubtitle,
                            key: ValueKey(store.nextAlarmSubtitle),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              color: _muted,
                              height: -4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Expanded(flex: 2, child: _StatsBoard()),
            const SizedBox(height: 12),
            const SizedBox(height: 72, child: _InfiniteTimeline()),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Tactile(
      pressedScale: 0.98,
      child: DottedBorder(
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
      ),
    );
  }

  void _startSession(BuildContext context, SessionKind kind) {
    HapticFeedback.mediumImpact();
    final store = SessionScope.of(context);
    Navigator.push(
      context,
      slideUpRoute(SessionPage(kind: kind, config: store.lastConfig(kind))),
    );
  }

  Widget _dock(BuildContext context, AlarmStore store) {
    final action = switch (_selectedTab) {
      0 => (Icons.add, () => _addAlarm(context)),
      1 => (Icons.play_arrow, () => _startSession(context, SessionKind.focus)),
      2 => (Icons.play_arrow, () => _startSession(context, SessionKind.sleep)),
      _ => null,
    };

    return Row(
      children: [
        Expanded(
          child: _NavBar(
            selected: _selectedTab,
            onSelect: (i) {
              if (i != _selectedTab) {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = i);
              }
            },
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: action != null
                ? Padding(
                    key: ValueKey(action.$1),
                    padding: const EdgeInsets.only(left: 12),
                    child: Tactile(
                      pressedScale: 0.9,
                      child: IconButton(
                        onPressed: action.$2,
                        icon: Icon(action.$1, color: _screen),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black,
                          fixedSize: const Size(64, 64),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.all(Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < _navTabs.length; i++)
            Expanded(
              child: _NavItem(
                icon: _navTabs[i].$1,
                label: _navTabs[i].$2,
                selected: selected == i,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final target = selected ? 1.0 : 0.0;

    return Tactile(
      pressedScale: 0.93,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: target, end: target),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            final color = Color.lerp(_muted, _screen, t)!;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: _screen.withValues(alpha: 0.0 * t),
                borderRadius: const BorderRadius.all(Radius.circular(28)),
                
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: 1 + 0.12 * t,
                    child: Icon(icon, size: 22, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyle(fontSize: 13, color: color)),
                ],
              ),
            );
          },
        ),
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(24 * (1 - t), 0),
          child: child,
        ),
      ),
      child: Tactile(
        pressedScale: 0.975,
        child: DottedBorder(
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
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
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
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                              child: Icon(
                                alarm.enabled ? Icons.play_arrow : Icons.pause,
                                key: ValueKey(alarm.enabled),
                                size: 54,
                                color: Colors.black,
                              ),
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
        ),
      ),
    );
  }
}

class _StatsBoard extends StatefulWidget {
  const _StatsBoard();

  @override
  State<_StatsBoard> createState() => _StatsBoardState();
}

class _StatsBoardState extends State<_StatsBoard> {
  int? _screenMinutes;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _fetchScreenTime();
  }

  Future<void> _fetchScreenTime() async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final totalSec = await DeviceUsage.totalUsageSeconds(startDate, now);
      if (mounted) {
        setState(() {
          _screenMinutes = totalSec ~/ 60;
          _unavailable = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unavailable = true;
          _screenMinutes = 0;
        });
      }
    }
  }

  void _openUsageSettings() {
    const intent = AndroidIntent(
      action: 'android.settings.USAGE_ACCESS_SETTINGS',
    );
    intent.launch();
  }

  static double _staggered(double t, int i) {
    final start = i * 0.13;
    return Curves.easeOutCubic.transform(((t - start) / 0.61).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final sessions = SessionScope.of(context);

    // Default to 0 while loading
    final currentMinutes = _screenMinutes ?? 0;

    final screenTimeLabel = _unavailable
        ? 'UNAVAILABLE'
        : '${currentMinutes ~/ 60}H ${(currentMinutes % 60).toString().padLeft(2, '0')}M';

    final screenTimeFraction = _unavailable ? 0.0 : currentMinutes / 120;

    final stats = <(String, String, double, VoidCallback?)>[
      (
        'SCREEN TIME',
        screenTimeLabel,
        screenTimeFraction,
        _unavailable
            ? _openUsageSettings
            : () => Navigator.push(
              context,
              slideUpRoute(const ScreenTimeDetailsPage()),
            ),
      ),
      (
        'DISTRACTED',
        '${sessions.distractedPct}%',
        sessions.distractedPct / 100,
        null,
      ),
      (
        'FOCUS SCORE',
        '${sessions.focusScore}/100',
        sessions.focusScore / 100,
        null,
      ),
      (
        'SLEEP SCORE',
        '${sessions.sleepScore}/100',
        sessions.sleepScore / 100,
        null,
      ),
    ];
    return _board(stats);
  }

  Widget _board(List<(String, String, double, VoidCallback?)> stats) {
    return LayoutBuilder(
      builder: (context, box) {
        final rowSpace = box.maxHeight / stats.length;
        final fontSize = ((rowSpace - 12) / 1.4).clamp(9.0, 17.0);
        final barHeight = (rowSpace * 0.2).clamp(4.0, 7.0);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1400),
          builder: (context, t, _) => Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < stats.length; i++)
                _StatRow(
                  stat: stats[i],
                  reveal: _staggered(t, i),
                  fontSize: fontSize,
                  barHeight: barHeight,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.stat,
    required this.reveal,
    required this.fontSize,
    required this.barHeight,
  });

  final (String, String, double, VoidCallback?) stat;
  final double reveal;
  final double fontSize;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final hasAction = stat.$4 != null;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              stat.$1,
              style: TextStyle(fontSize: fontSize, color: _muted, height: 1.1),
            ),
            Row(
              children: [
                Text(
                  stat.$2,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: hasAction ? _screen : _screen,
                    height: 1.1,
                  ),
                ),
                if (hasAction)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.settings,
                      size: fontSize * 0.9,
                      color: _screen,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          child: SizedBox(
            height: barHeight,
            width: double.infinity,
            child: ColoredBox(
              color: _dim.withValues(alpha: 0.15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (stat.$3 * reveal).clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: const ColoredBox(color: _screen),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (hasAction) {
      content = GestureDetector(
        onTap: stat.$4,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return Opacity(
      opacity: reveal,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - reveal)),
        child: content,
      ),
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
    final hour12 = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final fgStr =
        '${hour12.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final meridiem = _now.hour < 12 ? 'AM' : 'PM';

    return FittedBox(
      fit: BoxFit.fitWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(bgStr.length, (i) {
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
                    color: _dim.withValues(alpha: 0.15),
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
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 52),
            child: Text(
              meridiem,
              style: const TextStyle(fontSize: 34, color: _screen),
            ),
          ),
        ],
      ),
    );
  }
} // lain

class _InfiniteTimeline extends StatefulWidget {
  const _InfiniteTimeline();

  @override
  State<_InfiniteTimeline> createState() => _InfiniteTimelineState();
} // why are you crying lain

class _SpringScrollPhysics extends ScrollPhysics {
  final double Function() restOffset;

  const _SpringScrollPhysics({super.parent, required this.restOffset});

  @override
  _SpringScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SpringScrollPhysics(
        parent: buildParent(ancestor),
        restOffset: restOffset,
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position, double velocity) {
    final rest = restOffset();
    if (velocity.abs() < 1 && (position.pixels - rest).abs() < 1) return null;
    return SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 80, damping: 10),
      position.pixels, rest, velocity,
    );
  }
}

class _InfiniteTimelineState extends State<_InfiniteTimeline> {
  final _centerKey = UniqueKey();
  final _controller = ScrollController();
  Timer? _ticker;
  double _travelled = 0;
  int _hourOffset = 0;
  int _lastCheckedMinute = DateTime.now().minute;
  late final DateTime _startTime;
  late final int _refHour;
  double _markerX = 0;
  bool _jumped = false;

  double get _restOffset => _hourOffset * _barGap - _markerX + 7;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startTime = now;
    _refHour = now.hour;
    _lastCheckedMinute = now.minute;
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _tickTimer());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _tickTimer() {
    final now = DateTime.now();
    if (now.minute == _lastCheckedMinute) return;
    _lastCheckedMinute = now.minute;
    final elapsed = now.difference(_startTime).inMinutes;
    final expected = elapsed ~/ 60;
    if (expected > _hourOffset) {
      final delta = expected - _hourOffset;
      setState(() => _hourOffset = expected);
      _controller
          .animateTo(
            _restOffset,
            duration: Duration(
              milliseconds: (delta * 200 + 100).clamp(300, 1500),
            ),
            curve: Curves.easeOutCubic,
          )
          .catchError((_) {});
    }
  }

  // don't cry lain
  bool _tick(ScrollUpdateNotification note) {
    _travelled += (note.scrollDelta ?? 0).abs();
    if (_travelled >= _barGap * 5) {
      _travelled = 0;
      HapticFeedback.selectionClick();
    }
    return false;
  }

  Color? _dotForHour(int hour, List<Alarm> alarms) {
    bool normal = false;
    bool muted = false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    for (final alarm in alarms) {
      if (alarm.hour != hour) continue;
      if (!alarm.enabled) { muted = true; continue; }
      switch (alarm.repeat) {
        case AlarmRepeat.daily:
          normal = true;
        case AlarmRepeat.weekdays:
          if (now.weekday <= DateTime.friday) {
            normal = true;
          } else {
            muted = true;
          }
        case AlarmRepeat.once:
          final fire = alarm.nextFire(todayStart);
          if (fire != null && fire.isBefore(tomorrowStart)) {
            normal = true;
          } else {
            muted = true;
          }
      }
    }
    if (normal) return _screen;
    if (muted) return const Color.fromARGB(92, 105, 116, 95);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final alarms = AlarmScope.of(context).alarms;

    return LayoutBuilder(
      builder: (context, box) {
        final markerX = box.maxWidth * 0.16;
        if (_markerX != markerX) {
          _markerX = markerX;
          if (!_jumped) {
            _jumped = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _controller.jumpTo(_restOffset);
            });
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            NotificationListener<ScrollUpdateNotification>(
              onNotification: _tick,
              child: CustomScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                center: _centerKey,
                physics: _SpringScrollPhysics(
                  restOffset: () => _restOffset,
                ),
                slivers: [
                  SliverFixedExtentList(
                    itemExtent: _barGap,
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final hour = (_refHour - 1 - i) % 24;
                        return _Bar(dotColor: _dotForHour(hour, alarms));
                      },
                    ),
                  ),
                  SliverFixedExtentList(
                    key: _centerKey,
                    itemExtent: _barGap,
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final hour = (_refHour + i) % 24;
                        return _Bar(dotColor: _dotForHour(hour, alarms));
                      },
                    ),
                  ),
                ],
              ),
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
  const _Bar({this.dotColor});

  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarPainter(dotColor),
      child: const SizedBox.expand(),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter(this.dotColor);

  final Color? dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final brush = Paint()
      ..color = _screen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 22), Offset(x, size.height), brush);

    if (dotColor != null) {
      brush
        ..color = dotColor!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, 6), dotColor == _screen ? 3.5 : 2.5, brush);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.dotColor != dotColor;
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
