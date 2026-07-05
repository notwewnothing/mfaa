import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/session.dart';
import '../services/alarm_store.dart';
import '../services/session_store.dart';
import '../widgets/lcd_gauge.dart';
import '../widgets/slide_up_route.dart';
import '../widgets/tactile.dart';
import '../widgets/timer_sheet.dart';
import 'session_page.dart';

const _mint = Color(0xffa8c889);
const _muted = Color(0xff69745f);
const _dim = Color(0xff59644c);
const _circleBg = Color(0xff10130d);

class FocusPage extends StatelessWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final openTasks = store.todayTasks.where((t) => !t.done).length;

    return _TabPanel(
      gauge: LcdGauge(score: store.focusScore, title: 'FOCUS SCORE'),
      nudge: store.focusScore == 0
          ? 'START A SESSION TO GROW YOUR SCORE'
          : 'FOCUSED TIME IS ADDING UP — KEEP GOING',
      stats: [
        ('FOCUSED', minutesLabel(store.focusedTodayMin)),
        ('DISTRACTED', minutesLabel(store.distractedTodayMin)),
        ('GOAL', minutesLabel(SessionStore.focusGoalMin)),
      ],
      kind: SessionKind.focus,
      configColumns: [
        (Icons.shield_outlined, 'SCHEDULE', 'NO TIME SET', null),
        (
          Icons.timer_outlined,
          'TIMER',
          store.lastConfig(SessionKind.focus).label,
          () async {
            HapticFeedback.selectionClick();
            final result = await showTimerSheet(
              context,
              kind: SessionKind.focus,
              initial: store.lastConfig(SessionKind.focus),
            );
            if (result != null) {
              await store.setLastConfig(SessionKind.focus, result.config);
            }
          },
        ),
        (
          Icons.checklist_outlined,
          'TASKS',
          '$openTasks TODAY • ${store.laterTasks.length} LATER',
          null,
        ),
      ],
    );
  }
}

class SleepPage extends StatelessWidget {
  const SleepPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final alarms = AlarmScope.of(context);
    final next = alarms.nextAlarm;

    return _TabPanel(
      gauge: LcdGauge(score: store.sleepScore, title: 'SLEEP SCORE'),
      nudge: store.sleepScore == 0
          ? 'RUN A SLEEP SESSION TONIGHT TO TRACK REST'
          : 'REST IS ON RECORD — SLEEP TIGHT',
      stats: [
        ('SLEEP TIME', minutesLabel(store.sleepLastMin)),
        ('REGULARITY', store.regularityLabel),
        ('GOAL', minutesLabel(SessionStore.sleepGoalMin)),
      ],
      kind: SessionKind.sleep,
      configColumns: [
        (Icons.shield_outlined, 'SCHEDULE', 'NO TIME SET', null),
        (
          Icons.alarm_outlined,
          'ALARM',
          next == null ? 'NO ALARM' : '${next.timeLabel12} ${next.meridiem}',
          null,
        ),
        (
          Icons.timer_outlined,
          'TIMER',
          store.lastConfig(SessionKind.sleep).label,
          () async {
            HapticFeedback.selectionClick();
            final result = await showTimerSheet(
              context,
              kind: SessionKind.sleep,
              initial: store.lastConfig(SessionKind.sleep),
            );
            if (result != null) {
              await store.setLastConfig(SessionKind.sleep, result.config);
            }
          },
        ),
      ],
    );
  }
}

class _TabPanel extends StatelessWidget {
  const _TabPanel({
    required this.gauge,
    required this.nudge,
    required this.stats,
    required this.kind,
    required this.configColumns,
  });

  final Widget gauge;
  final String nudge;
  final List<(String, String)> stats;
  final SessionKind kind;
  final List<(IconData, String, String, Future<void> Function()?)>
  configColumns;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

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
        padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: gauge)),
            Center(
              child: Text(
                nudge,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            const SizedBox(height: 16),
            _TrioStats(stats: stats),
            const SizedBox(height: 18),
            const Text(
              'SHORTCUTS',
              style: TextStyle(fontSize: 13, color: _muted, letterSpacing: 3),
            ),
            const SizedBox(height: 10),
            _ShortcutsRow(kind: kind),
            const SizedBox(height: 16),
            _ConfigCard(columns: configColumns),
          ],
        ),
      ),
    );
  }
}

class _TrioStats extends StatelessWidget {
  const _TrioStats({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, stat) in stats.indexed) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 6),
                Container(height: 2, color: _dim.withValues(alpha: 0.35)),
                const SizedBox(height: 8),
                Text(
                  stat.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, color: _mint),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ShortcutsRow extends StatelessWidget {
  const _ShortcutsRow({required this.kind});

  final SessionKind kind;

  Future<void> _deletePreset(
    BuildContext context,
    SessionStore store,
    SessionPreset preset,
  ) async {
    HapticFeedback.heavyImpact();
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'DELETE ${preset.name}?',
          style: const TextStyle(color: _mint, fontSize: 22),
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
    if (yes == true) await store.removePreset(preset);
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final presets = store.presets(kind);

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final preset in presets) ...[
            _ShortcutButton(
              icon: Icons.play_arrow,
              label: preset.name,
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  slideUpRoute(SessionPage(kind: kind, config: preset.config)),
                );
              },
              onLongPress: () => _deletePreset(context, store, preset),
            ),
            const SizedBox(width: 16),
          ],
          _ShortcutButton(
            icon: Icons.add,
            label: 'NEW',
            onTap: () async {
              HapticFeedback.lightImpact();
              final result = await showTimerSheet(
                context,
                kind: kind,
                initial: store.lastConfig(kind),
                askName: true,
              );
              if (result != null) {
                await store.addPreset(
                  result.presetName ?? 'MY SESSION',
                  kind,
                  result.config,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tactile(
      pressedScale: 0.92,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _circleBg,
                shape: BoxShape.circle,
                border: Border.all(color: _dim.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: _mint, size: 26),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 74,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.columns});

  final List<(IconData, String, String, Future<void> Function()?)> columns;

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      color: _dim,
      strokeWidth: 1.5,
      dashPattern: const [5, 5],
      borderType: BorderType.RRect,
      radius: const Radius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            for (final (i, column) in columns.indexed) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 56,
                  color: _dim.withValues(alpha: 0.3),
                ),
              Expanded(
                child: Tactile(
                  pressedScale: 0.94,
                  child: InkWell(
                    onTap: column.$4 == null ? null : () => column.$4!(),
                    child: Column(
                      children: [
                        Text(
                          column.$2,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(height: 8),
                        Icon(column.$1, color: _mint, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          column.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _mint),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
