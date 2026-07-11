import 'dart:async';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/session.dart';
import '../services/app_blocker.dart';
import '../services/device_usage.dart';
import '../services/session_store.dart';
import '../widgets/tactile.dart';
import 'alarm_ring_page.dart';

const _mint = Color(0xffa8c889);
const _muted = Color(0xff69745f);
const _dim = Color(0xff59644c);
const _panelBg = Color(0xff10130d);
const _stopBg = Color(0xff36402b);

class SessionPage extends StatefulWidget {
  const SessionPage({super.key, required this.kind, required this.config});

  final SessionKind kind;
  final SessionConfig config;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> with WidgetsBindingObserver {
  Timer? _ticker;
  int _phaseSec = 0;
  int _focusSec = 0;
  int _pausedSec = 0;
  int _inAppSec = 0;
  int _block = 1;
  late final DateTime _sessionStart;
  bool _onBreak = false;
  bool _paused = false;
  bool _completed = false;
  int _remainingSec = 0;
  bool _blink = true;
  bool _appInForeground = true;
  int? _phoneUsageAtStart;
  SessionStore? _store;

  SessionMode get _mode => widget.config.mode;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    final startOfDay = DateTime(
      _sessionStart.year,
      _sessionStart.month,
      _sessionStart.day,
    );
    DeviceUsage.totalUsageSeconds(startOfDay, _sessionStart).then((v) {
      _phoneUsageAtStart = v;
    });
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = SessionScope.of(context);
    if (_store == store) return;
    _store?.removeListener(_syncBlocking);
    _store = store;
    store.addListener(_syncBlocking);
    unawaited(_syncBlocking());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _store?.removeListener(_syncBlocking);
    unawaited(_disableBlocking());
    super.dispose();
  }

  Future<void> _syncBlocking() async {
    final store = _store;
    if (store == null) return;
    await AppBlocker.setBlockingState(
      enabled:
          widget.kind == SessionKind.focus &&
          !_completed &&
          store.blockApps &&
          store.blockedApps.isNotEmpty,
      strictMode: store.strictMode,
      onBreak: _mode == SessionMode.pomodoro && _onBreak,
      blockedPackages: store.blockedApps,
    );
  }

  Future<void> _disableBlocking() => AppBlocker.setBlockingState(
    enabled: false,
    strictMode: false,
    onBreak: false,
    blockedPackages: const [],
  );

  void _tick() {
    if (!mounted || _completed) return;
    setState(() {
      _blink = !_blink;
      if (_appInForeground) _inAppSec++;
      if (_paused) {
        _pausedSec++;
        return;
      }

      if (_remainingSec > 0) {
        _remainingSec--;
        _focusSec++;
        if (_remainingSec <= 0) _complete();
        return;
      }

      _phaseSec++;
      if (!_onBreak) _focusSec++;

      switch (_mode) {
        case SessionMode.alarm:
          if (_alarmSecondsRemaining <= 0) _complete();
        case SessionMode.pomodoro:
          final target = _onBreak ? 5 * 60 : widget.config.minutes * 60;
          if (_phaseSec >= target) _advancePhase();
        case SessionMode.quickNap:
          if (_phaseSec >= widget.config.minutes * 60) _complete();
        case SessionMode.endless:
          break;
      }
    });
  }

  void _advancePhase() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
    _onBreak = !_onBreak;
    if (!_onBreak) _block++;
    _phaseSec = 0;
    unawaited(_syncBlocking());
  }

  void _complete() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    _completed = true;
    unawaited(_syncBlocking());
    if (widget.kind == SessionKind.sleep) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSleepEndRing();
      });
    }
  }

  // how did i forgor this :/
  Future<void> _showSleepEndRing() async {
    final action = await Navigator.of(context).push<String>(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const AlarmRingPage(sleepEndMode: true),
        transitionsBuilder: (_, animation, _, child) {
          final eased = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: eased,
            child: ScaleTransition(
              scale: Tween(begin: 1.08, end: 1.0).animate(eased),
              child: child,
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (action == 'stop') {
      final store = SessionScope.of(context);
      await _stop(context, store);
    } else if (action == 'snooze') {
      setState(() {
        _remainingSec = 600;
        _completed = false;
        _paused = false;
      });
    }
  }

  Future<bool> _strictAllows(BuildContext context, SessionStore store) async {
    if (!store.strictMode || _completed) return true;
    HapticFeedback.heavyImpact();
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'BREAK STRICT MODE?',
          style: TextStyle(color: _mint, fontSize: 22),
        ),
        content: const Text(
          'THIS SESSION IS LOCKED. LEAVING NOW DEFEATS THE POINT.',
          style: TextStyle(color: _muted, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'STAY',
              style: TextStyle(color: _muted, fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'BREAK',
              style: TextStyle(color: Color(0xffe57373), fontSize: 18),
            ),
          ),
        ],
      ),
    );
    return yes == true;
  }

  Future<void> _togglePause(BuildContext context, SessionStore store) async {
    if (!_paused && !await _strictAllows(context, store)) return;
    HapticFeedback.mediumImpact();
    if (mounted) setState(() => _paused = !_paused);
  }

  Future<void> _stop(BuildContext context, SessionStore store) async {
    if (!_completed && !await _strictAllows(context, store)) return;
    HapticFeedback.heavyImpact();
    final deviceDistracted =
        widget.kind == SessionKind.focus && _phoneUsageAtStart != null
        ? await _computeDeviceDistracted()
        : 0;
    await store.recordSession(
      widget.kind,
      activeSeconds: widget.kind == SessionKind.focus
          ? _focusSec - (_pausedSec + deviceDistracted)
          : _focusSec + _pausedSec,
      distractedSeconds: widget.kind == SessionKind.focus
          ? _pausedSec + deviceDistracted
          : 0,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<int> _computeDeviceDistracted() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final totalNow = await DeviceUsage.totalUsageSeconds(startOfDay, now);
    final increase = totalNow - (_phoneUsageAtStart ?? 0);
    return DeviceUsage.computeDistractedSeconds(
      phoneUsageIncrease: increase,
      inAppSeconds: _inAppSec,
    );
  }

  int get _alarmSecondsRemaining {
    final now = DateTime.now();
    final targetMin = widget.config.minutes;
    final currentMin = now.hour * 60 + now.minute;
    var diffMin = targetMin - currentMin;
    if (diffMin < 0) diffMin += 1440;
    var diffSec = diffMin * 60 - now.second;
    if (diffSec < 0) diffSec = 0;
    return diffSec.clamp(0, 599940);
  }

  String get _display {
    if (_remainingSec > 0) {
      final big = _remainingSec ~/ 60;
      final small = _remainingSec % 60;
      return '${big.toString().padLeft(2, '0')}:${small.toString().padLeft(2, '0')}';
    }
    final seconds = switch (_mode) {
      SessionMode.endless => _phaseSec,
      SessionMode.pomodoro =>
        ((_onBreak ? 5 : widget.config.minutes) * 60 - _phaseSec).clamp(
          0,
          599940,
        ),
      SessionMode.quickNap => (widget.config.minutes * 60 - _phaseSec).clamp(
        0,
        599940,
      ),
      SessionMode.alarm => _alarmSecondsRemaining,
    };
    final big = seconds >= 6000 ? seconds ~/ 3600 : seconds ~/ 60;
    final small = seconds >= 6000 ? (seconds % 3600) ~/ 60 : seconds % 60;
    return '${big.toString().padLeft(2, '0')}:${small.toString().padLeft(2, '0')}';
  }

  String get _modeLabel {
    if (_remainingSec > 0) {
      final min = (_remainingSec / 60).ceil();
      return 'SNOOZING — $min MIN LEFT';
    }
    if (_completed) return 'SESSION COMPLETE';
    if (_paused) return 'PAUSED — COUNTS AS DISTRACTED';
    return switch (_mode) {
      SessionMode.endless => 'ENDLESS — RUNS UNTIL YOU STOP',
      SessionMode.pomodoro =>
        _onBreak
            ? 'BREAK — BLOCK $_block DONE'
            : 'POMODORO — BLOCK $_block OF FOCUS',
      SessionMode.quickNap =>
        'QUICK NAP — ${minutesLabel(widget.config.minutes)}',
      SessionMode.alarm => 'ALARM — ENDS AT ${widget.config.label}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final tasks = store.todayTasks;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stop(context, store);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            // overflow fix
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.kind == SessionKind.focus
                      ? 'FOCUS SESSION'
                      : 'SLEEP SESSION',
                  style: const TextStyle(
                    fontSize: 16,
                    color: _muted,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _paused ? 0.35 : 1,
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Builder(
                        builder: (context) {
                          const bgStr = '88:88';
                          final fgStr = _display;
                          final showColon = _blink || _paused || _completed;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...List.generate(bgStr.length, (i) {
                                final isColon = bgStr[i] == ':';
                                final isActive = !isColon || showColon;
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
                                      offset: isOne
                                          ? const Offset(7, 0)
                                          : Offset.zero,
                                      child: Text(
                                        fgStr[i],
                                        style: TextStyle(
                                          fontSize: 150,
                                          color: isActive
                                              ? _mint
                                              : Colors.transparent,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _modeLabel,
                    key: ValueKey(_modeLabel),
                    style: const TextStyle(fontSize: 14, color: _muted),
                  ),
                ),
                const SizedBox(height: 18),
                _BlockCard(store: store),
                const SizedBox(height: 18),
                Text(
                  'TODAY — ${tasks.where((t) => t.done).length}/${tasks.length} DONE',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: [
                      for (final task in tasks)
                        _TaskRow(
                          task: task,
                          onToggle: () {
                            HapticFeedback.selectionClick();
                            store.toggleTask(task);
                          },
                          onRemove: () {
                            HapticFeedback.heavyImpact();
                            store.removeTask(task);
                          },
                        ),
                      _AddTaskButton(store: store),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Tactile(
                      pressedScale: 0.9,
                      child: IconButton(
                        onPressed: () => _stop(context, store),
                        icon: Icon(
                          _completed ? Icons.check : Icons.stop,
                          size: 30,
                          color: _mint,
                        ),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(64, 64),
                          backgroundColor: _stopBg,
                        ),
                      ),
                    ),
                    Tactile(
                      pressedScale: 0.9,
                      child: IconButton(
                        onPressed: _completed
                            ? null
                            : () => _togglePause(context, store),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            _paused ? Icons.play_arrow : Icons.pause,
                            key: ValueKey(_paused),
                            size: 40,
                            color: Colors.black,
                          ),
                        ),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(80, 80),
                          backgroundColor: _completed
                              ? _dim.withValues(alpha: 0.4)
                              : const Color(0xff98ac84),
                        ),
                      ),
                    ),
                    if (_mode == SessionMode.pomodoro && !_completed)
                      Tactile(
                        pressedScale: 0.9,
                        child: IconButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(_advancePhase);
                          },
                          icon: const Icon(
                            Icons.fast_forward,
                            size: 30,
                            color: _mint,
                          ),
                          style: IconButton.styleFrom(
                            fixedSize: const Size(64, 64),
                            backgroundColor: _stopBg,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 64, height: 64),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.store});

  final SessionStore store;

  Future<bool> _editList(BuildContext context) async {
    HapticFeedback.selectionClick();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _BlockedAppsDialog(initial: store.blockedApps),
    );
    if (result == null) return false;
    await store.setBlockedApps(result);
    return true;
  }

  Future<void> _toggleBlocking(BuildContext context, bool value) async {
    if (value && store.blockedApps.isEmpty) {
      final saved = await _editList(context);
      if (!saved || store.blockedApps.isEmpty) return;
    }
    if (value &&
        !await AppBlocker.isAccessibilityEnabled() &&
        context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            'ENABLE APP BLOCKING',
            style: TextStyle(color: _mint, fontSize: 22),
          ),
          content: const Text(
            'TURN ON MFAAA APP BLOCKER IN ACCESSIBILITY SETTINGS.',
            style: TextStyle(color: _muted, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'LATER',
                style: TextStyle(color: _muted, fontSize: 18),
              ),
            ),
            TextButton(
              onPressed: () {
                unawaited(AppBlocker.openAccessibilitySettings());
                Navigator.pop(context);
              },
              child: const Text(
                'OPEN',
                style: TextStyle(color: _mint, fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }
    await store.setBlockApps(value);
  }

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      color: _dim,
      strokeWidth: 1.5,
      dashPattern: const [5, 5],
      borderType: BorderType.RRect,
      radius: const Radius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.app_blocking_outlined, color: _mint, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Tactile(
                    pressedScale: 0.97,
                    child: InkWell(
                      onTap: () => unawaited(_editList(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BLOCK APPS',
                            style: TextStyle(fontSize: 18, color: _mint),
                          ),
                          Text(
                            store.blockedApps.isEmpty
                                ? 'TAP TO EDIT LIST'
                                : 'BLOCKING ${store.blockedApps.length} APPS',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _LcdSwitch(
                  value: store.blockApps,
                  onChanged: (value) =>
                      unawaited(_toggleBlocking(context, value)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Tactile(
              pressedScale: 0.97,
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    unawaited(store.setStrictMode(!store.strictMode));
                  },
                  icon: Icon(
                    store.strictMode ? Icons.lock : Icons.lock_outline,
                    size: 20,
                    color: store.strictMode ? Colors.black : _mint,
                  ),
                  label: Text(
                    store.strictMode
                        ? 'STRICT MODE ON'
                        : 'ACTIVATE STRICT MODE',
                    style: TextStyle(
                      fontSize: 17,
                      color: store.strictMode ? Colors.black : _mint,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: store.strictMode ? _mint : _panelBg,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LcdSwitch extends StatelessWidget {
  const _LcdSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tactile(
      pressedScale: 0.92,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 56,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? _mint : _panelBg,
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            border: Border.all(color: value ? _mint : _dim),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? Colors.black : _dim,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onRemove,
  });

  final FocusTask task;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Tactile(
      pressedScale: 0.98,
      child: InkWell(
        onTap: onToggle,
        onLongPress: onRemove,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: task.done ? 0.4 : 1,
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    task.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    key: ValueKey(task.done),
                    color: _mint,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      color: _mint,
                      decoration: task.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: _mint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${task.tag}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({required this.store});

  final SessionStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: Tactile(
          pressedScale: 0.95,
          child: TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              showAddTaskDialog(context, store);
            },
            icon: const Icon(Icons.add_task, size: 20, color: _mint),
            label: const Text(
              'ADD TASK',
              style: TextStyle(fontSize: 16, color: _mint),
            ),
          ),
        ),
      ),
    );
  }
}

void _closeInputDialog<T>(BuildContext context, [T? result]) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.of(context).pop(result);
}

Future<void> showAddTaskDialog(BuildContext context, SessionStore store) async {
  final result = await showDialog<_AddTaskResult>(
    context: context,
    builder: (context) => const _AddTaskDialog(),
  );
  if (result != null) {
    HapticFeedback.selectionClick();
    await store.addTask(result.title, tag: result.tag, today: result.today);
  }
}

class _AddTaskResult {
  const _AddTaskResult({
    required this.title,
    required this.tag,
    required this.today,
  });

  final String title;
  final String tag;
  final bool today;
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  late final TextEditingController _controller;
  var _tag = focusTags.first;
  var _today = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim().toUpperCase();
    if (title.isEmpty) {
      _closeInputDialog(context);
      return;
    }
    _closeInputDialog(
      context,
      _AddTaskResult(title: title, tag: _tag, today: _today),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: const Text(
        'NEW TASK',
        style: TextStyle(color: _mint, fontSize: 22),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 18, color: _mint),
              cursorColor: _mint,
              decoration: const InputDecoration(
                hintText: 'WHAT NEEDS DOING?',
                hintStyle: TextStyle(color: _muted, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _muted),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _mint),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _DialogChip(
                  label: _tag,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _tag =
                          focusTags[(focusTags.indexOf(_tag) + 1) %
                              focusTags.length];
                    });
                  },
                ),
                const SizedBox(width: 10),
                _DialogChip(
                  label: _today ? 'TODAY' : 'LATER',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _today = !_today);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _closeInputDialog(context),
          child: const Text(
            'CANCEL',
            style: TextStyle(color: _muted, fontSize: 18),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(
            'ADD',
            style: TextStyle(color: _mint, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class _BlockedAppsDialog extends StatefulWidget {
  const _BlockedAppsDialog({required this.initial});

  final List<String> initial;

  @override
  State<_BlockedAppsDialog> createState() => _BlockedAppsDialogState();
}

class _BlockedAppsDialogState extends State<_BlockedAppsDialog> {
  late final Future<List<InstalledApp>> _apps;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _apps = AppBlocker.installedApps();
    _selected = {...widget.initial};
  }

  void _toggle(String packageName) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.add(packageName)) _selected.remove(packageName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: const Text(
        'BLOCKED APPS',
        style: TextStyle(color: _mint, fontSize: 22),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: FutureBuilder<List<InstalledApp>>(
          future: _apps,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: _mint),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'COULD NOT LOAD APPS',
                  style: TextStyle(color: _muted, fontSize: 16),
                ),
              );
            }
            final apps = snapshot.data ?? const [];
            if (apps.isEmpty) {
              return const Center(
                child: Text(
                  'NO APPS FOUND',
                  style: TextStyle(color: _muted, fontSize: 16),
                ),
              );
            }
            return ListView.separated(
              itemCount: apps.length,
              separatorBuilder: (_, _) => const Divider(color: _dim, height: 1),
              itemBuilder: (context, index) {
                final app = apps[index];
                final selected = _selected.contains(app.packageName);
                return ListTile(
                  onTap: () => _toggle(app.packageName),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    app.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _mint, fontSize: 18),
                  ),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  trailing: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? _mint : _dim,
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(_selected.clear);
          },
          child: const Text(
            'CLEAR',
            style: TextStyle(color: _muted, fontSize: 18),
          ),
        ),
        TextButton(
          onPressed: () => _closeInputDialog(context),
          child: const Text(
            'CANCEL',
            style: TextStyle(color: _muted, fontSize: 18),
          ),
        ),
        TextButton(
          onPressed: () => _closeInputDialog(context, _selected.toList()),
          child: const Text(
            'SAVE',
            style: TextStyle(color: _mint, fontSize: 18),
          ),
        ),
      ],
    );
  }
}
// I am the number one most impactfull programmer of our generation
// Goo Goo

class _DialogChip extends StatelessWidget {
  const _DialogChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tactile(
      pressedScale: 0.93,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _panelBg,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: _dim),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: _mint),
          ),
        ),
      ),
    );
  }
}
