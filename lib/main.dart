import 'package:flutter/material.dart';
import 'package:mfaaa/pages/clock_dashboard.dart';

void main() => runApp(const AlarmApp());

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm Clock',
      theme: ThemeData(
        fontFamily: 'Digital',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ClockDashboard(),
    );
  }
}
