import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mfaaa/main.dart';

void main() {
  testWidgets('dashboard renders the clock', (WidgetTester tester) async {
    final loader = FontLoader('Digital')
      ..addFont(rootBundle.load('assets/fonts/DS-DIGI.TTF'));
    await loader.load();

    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AlarmApp());

    expect(find.text('09:42'), findsWidgets);
    expect(find.text('THE NEXT ALARM CLOCK IN 19 MIN'), findsOneWidget);
  });
}
