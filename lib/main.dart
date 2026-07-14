import 'package:flutter/material.dart';
// i hate this app :/
import 'models/alarm.dart';
import 'pages/alarm_ring_page.dart';
import 'pages/clock_dashboard.dart';
import 'services/alarm_buzz.dart';
import 'services/alarm_store.dart';
import 'services/notification_service.dart';
import 'services/session_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlarmApp());
}

class AlarmApp extends StatefulWidget {
  const AlarmApp({super.key, this.store, this.sessionStore});

  final AlarmStore? store;
  final SessionStore? sessionStore;

  @override
  State<AlarmApp> createState() => _AlarmAppState();
}

class _AlarmAppState extends State<AlarmApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final AlarmStore _store;
  late final SessionStore _sessions;
  NotificationService? _notifications;
  bool _ringOpen = false;

  @override
  void initState() {
    super.initState();
    final injected = widget.store;
    if (injected != null) {
      _store = injected;
    } else {
      _notifications = NotificationService(onAlarmTap: _openRingById);
      _store = AlarmStore(scheduler: _notifications);
    }
    _sessions = widget.sessionStore ?? SessionStore();
    _store.onRing = _openRing;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _notifications?.init();
    if (!_store.isLoaded) await _store.init();
    if (!_sessions.isLoaded) await _sessions.init();
    final launchId = await _notifications?.launchedByAlarm();
    if (launchId != null) _openRingById(launchId);
    
    final buzzing = await AlarmBuzz.activeAlarmId();
    if (buzzing != null) _openRingById(buzzing);
  }

  void _openRingById(int id) {
    final alarm = _store.byId(id);
    if (alarm != null) _openRing(alarm);
  }

  void _openRing(Alarm alarm) {
    if (_ringOpen) return;
    final nav = _navigator.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRing(alarm));
      return;
    }

    _ringOpen = true;
    nav
        .push(
          PageRouteBuilder(
            fullscreenDialog: true,
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, _, _) => AlarmRingPage(alarm: alarm),
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
        )
        .whenComplete(() => _ringOpen = false);
  }

  @override
  void dispose() {
    _store.onRing = null;
    if (widget.store == null) _store.dispose();
    if (widget.sessionStore == null) _sessions.dispose();
    super.dispose();
  }

  // i use arch btw
  @override
  Widget build(BuildContext context) {
    return AlarmScope(
      store: _store,
      child: SessionScope(
        store: _sessions,
        child: MaterialApp(
          title: 'Alarm Clock',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigator,
          theme: ThemeData(
            fontFamily: 'Digital',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xffa8c889),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const ClockDashboard(),
        ),
      ),
    );
  }
}
 