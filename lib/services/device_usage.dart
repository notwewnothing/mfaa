import 'dart:math';

import 'package:app_usage/app_usage.dart';
import 'package:flutter/foundation.dart';

class DeviceUsage {
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<int> totalUsageSeconds(DateTime start, DateTime end) async {
    if (!isSupported) return 0;
    try {
      final infoList = await AppUsage().getAppUsage(start, end);
      int total = 0;
      for (final info in infoList) {
        total += info.usage.inSeconds;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<({String appName, String packageName, int seconds})>>
      appUsageSeconds(DateTime start, DateTime end) async {
    if (!isSupported) return [];
    try {
      final infoList = await AppUsage().getAppUsage(start, end);
      final result = infoList
          .where((info) => info.usage.inSeconds > 0)
          .map(
            (info) => (
              appName: info.appName,
              packageName: info.packageName,
              seconds: info.usage.inSeconds,
            ),
          )
          .toList();
      result.sort((a, b) => b.seconds.compareTo(a.seconds));
      return result;
    } catch (_) {
      return [];
    }
  }

  static int computeDistractedSeconds({
    required int phoneUsageIncrease,
    required int inAppSeconds,
  }) {
    if (phoneUsageIncrease <= 0) return 0;
    return max(0, phoneUsageIncrease - inAppSeconds);
  }
}
