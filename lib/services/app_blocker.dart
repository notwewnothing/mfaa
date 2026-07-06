import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({required this.label, required this.packageName});

  final String label;
  final String packageName;

  static InstalledApp fromMap(Map<Object?, Object?> map) => InstalledApp(
    label: map['label'] as String? ?? '',
    packageName: map['packageName'] as String? ?? '',
  );
}

class AppBlocker {
  static const _channel = MethodChannel('mfaaa/app_blocker');

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<List<InstalledApp>> installedApps() async {
    if (!isSupported) return const [];
    try {
      final result = await _channel.invokeListMethod<Object?>(
        'getInstalledApps',
      );
      return [
        for (final item in result ?? const [])
          if (item is Map) InstalledApp.fromMap(item.cast<Object?, Object?>()),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  static Future<bool> isAccessibilityEnabled() async {
    if (!isSupported) return true;
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> setBlockingState({
    required bool enabled,
    required bool strictMode,
    required bool onBreak,
    required List<String> blockedPackages,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setBlockingState', {
        'enabled': enabled,
        'strictMode': strictMode,
        'onBreak': onBreak,
        'blockedPackages': blockedPackages,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
