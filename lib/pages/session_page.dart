import 'dart:async';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/session.dart';
import '../services/session_store.dart';
import '../widgets/tactile.dart';

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

class _SessionPageState extends State<SessionPage> {
  Timer? _ticker;
  int _phaseSec = 0;
  int _focusSec = 0;
  int _pausedSec = 0;
  int _block = 1;
  bool _onBreak = false;
  bool _paused = false;
  bool _completed = false;
  bool _blink = true;

  SessionMode get _mode => widget.config.mode;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _completed) return;
    setState(() {
      _blink = !_blink;
      if (_paused) {
        _pausedSec++;
        return;
      }
      _phaseSec++;
      if (!_onBreak) _focusSec++;

      switch (_mode) {
        case SessionMode.timer:
          if (_phaseSec >= widget.config.minutes * 60) _complete();
        case SessionMode.pomodoro:
          final target = _onBreak ? 5 * 60 : widget.config.minutes * 60;
          if (_phaseSec >= target) _advancePhase();
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
  }

  void _complete() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    _completed = true;
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
    await store.recordSession(
      widget.kind,
      activeSeconds: widget.kind == SessionKind.focus
          ? _focusSec
          : _focusSec + _pausedSec,
      distractedSeconds: widget.kind == SessionKind.focus ? _pausedSec : 0,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  String get _display {
    final seconds = switch (_mode) {
      SessionMode.endless => _phaseSec,
      SessionMode.pomodoro =>
        ((_onBreak ? 5 : widget.config.minutes) * 60 - _phaseSec).clamp(
          0,
          599940,
        ),
      SessionMode.timer => (widget.config.minutes * 60 - _phaseSec).clamp(
        0,
        599940,
      ),
    };
    final big = seconds >= 6000 ? seconds ~/ 3600 : seconds ~/ 60;
    final small = seconds >= 6000 ? (seconds % 3600) ~/ 60 : seconds % 60;
    return '${big.toString().padLeft(2, '0')}:${small.toString().padLeft(2, '0')}';
  }

  String get _modeLabel {
    if (_completed) return 'SESSION COMPLETE';
    if (_paused) return 'PAUSED — COUNTS AS DISTRACTED';
    return switch (_mode) {
      SessionMode.endless => 'ENDLESS — RUNS UNTIL YOU STOP',
      SessionMode.pomodoro =>
        _onBreak
            ? 'BREAK — BLOCK $_block DONE'
            : 'POMODORO — BLOCK $_block OF FOCUS',
      SessionMode.timer => '${widget.config.minutes} MIN TIMER',
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
                      fit: BoxFit.scaleDown,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '88:88',
                            style: TextStyle(
                              fontSize: 120,
                              color: _dim.withValues(alpha: 0.15),
                              height: 1,
                            ),
                          ),
                          Text(
                            _blink || _paused || _completed
                                ? _display
                                : _display.replaceAll(':', ' '),
                            style: const TextStyle(
                              fontSize: 120,
                              color: _mint,
                              height: 1,
                            ),
                          ),
                        ],
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

  Future<void> _editList(BuildContext context) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController(
      text: store.blockedApps.join(', '),
    );
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'BLOCKED APPS',
          style: TextStyle(color: _mint, fontSize: 22),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 17, color: _mint),
          cursorColor: _mint,
          decoration: const InputDecoration(
            hintText: 'APP NAMES, COMMA SEPARATED',
            hintStyle: TextStyle(color: _muted, fontSize: 14),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _muted),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _mint),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: _muted, fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, [
              for (final app in controller.text.split(','))
                if (app.trim().isNotEmpty) app.trim().toUpperCase(),
            ]),
            child: const Text(
              'SAVE',
              style: TextStyle(color: _mint, fontSize: 18),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await store.setBlockedApps(result);
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
                      onTap: () => _editList(context),
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
                  onChanged: store.setBlockApps,
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
                    store.setStrictMode(!store.strictMode);
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

Future<void> showAddTaskDialog(BuildContext context, SessionStore store) async {
  final controller = TextEditingController();
  var tag = focusTags.first;
  var today = true;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'NEW TASK',
          style: TextStyle(color: _mint, fontSize: 22),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
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
                  label: tag,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setSheet(() {
                      tag =
                          focusTags[(focusTags.indexOf(tag) + 1) %
                              focusTags.length];
                    });
                  },
                ),
                const SizedBox(width: 10),
                _DialogChip(
                  label: today ? 'TODAY' : 'LATER',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setSheet(() => today = !today);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: _muted, fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ADD',
              style: TextStyle(color: _mint, fontSize: 18),
            ),
          ),
        ],
      ),
    ),
  );

  final title = controller.text.trim().toUpperCase();
  controller.dispose();
  if (saved == true && title.isNotEmpty) {
    HapticFeedback.selectionClick();
    await store.addTask(title, tag: tag, today: today);
  }
}

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
