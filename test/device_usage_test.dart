import 'package:flutter_test/flutter_test.dart';
import 'package:mfaaa/services/device_usage.dart';

void main() {
  group('DeviceUsage.computeDistractedSeconds', () {
    test('returns 0 when phoneUsageIncrease is 0', () {
      expect(
        DeviceUsage.computeDistractedSeconds(
          phoneUsageIncrease: 0,
          inAppSeconds: 0,
        ),
        0,
      );
    });

    test('returns 0 when all phone increase is in-app', () {
      expect(
        DeviceUsage.computeDistractedSeconds(
          phoneUsageIncrease: 600,
          inAppSeconds: 600,
        ),
        0,
      );
    });

    test('returns difference when in-app is less than phone increase', () {
      expect(
        DeviceUsage.computeDistractedSeconds(
          phoneUsageIncrease: 600,
          inAppSeconds: 200,
        ),
        400,
      );
    });

    test('returns 0 when in-app exceeds phone increase (clamped)', () {
      expect(
        DeviceUsage.computeDistractedSeconds(
          phoneUsageIncrease: 200,
          inAppSeconds: 600,
        ),
        0,
      );
    });

    test('returns 0 when phoneUsageIncrease is negative', () {
      expect(
        DeviceUsage.computeDistractedSeconds(
          phoneUsageIncrease: -1,
          inAppSeconds: 0,
        ),
        0,
      );
    });

    test('returns full phone increase when no in-app time', () {
      expect(
        DeviceUsage.computeDistractedSeconds(
          phoneUsageIncrease: 300,
          inAppSeconds: 0,
        ),
        300,
      );
    });
  });
}
