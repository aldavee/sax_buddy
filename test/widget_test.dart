import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sax_buddy/features/sax/presentation/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HomeScreen renders Sax Buddy and starter practice items',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sax Buddy'), findsOneWidget);
    expect(find.text('Welcome to Sax Buddy Studio'), findsOneWidget);
    expect(find.text('Daily Saxophone Warmup Checklist'), findsOneWidget);
  });

  testWidgets('HomeScreen renders without overflow on compact mobile screens',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sax Buddy'), findsOneWidget);
    expect(find.text('Welcome to Sax Buddy Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
