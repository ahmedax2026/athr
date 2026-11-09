// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athr/main.dart';

void main() {
  testWidgets('three prayers show acceptance then open the home screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AthrApp());
    await tester.pumpAndSettle();

    expect(find.text('على روح المغفور له بإذن الله'), findsOneWidget);
    expect(find.text('عبدالوكيل عبدالسيد محمد'), findsOneWidget);
    expect(find.text('اللهم اغفر له وارحمه وعافه واعف عنه، وأكرم نزله ووسع مدخله'),
        findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    final prayerButton = find.byKey(const ValueKey('welcome-pray-button'));
    for (var tap = 0; tap < 3; tap++) {
      await tester.ensureVisible(prayerButton);
      await tester.tap(prayerButton);
      await tester.pump();
    }

    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('اللهم تقبل'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('أهلًا بك في أثر لا ينقطع'), findsOneWidget);
    expect(find.text('القرآن الكريم'), findsOneWidget);
    expect(find.text('الأذكار'), findsOneWidget);
    expect(find.text('السبحة'), findsOneWidget);
    expect(find.text('مواقيت الصلاة'), findsOneWidget);
    expect(find.text('الختمات الجماعية'), findsOneWidget);
  });

  testWidgets('welcome screen fits a narrow phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AthrApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
