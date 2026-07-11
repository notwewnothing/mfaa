import 'package:flutter/services.dart';

class AppIcons {
  static const _channel = MethodChannel('mfaaa/app_icons');

  static Future<Uint8List?> getIcon(String packageName) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'getAppIcon',
        {'packageName': packageName},
      );
    } catch (_) {
      return null;
    }
  }
}
