import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forensic_spidercam/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen navigates to the case route after the configured delay',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const SplashScreen(),
        routes: {
          '/case': (_) => const Scaffold(
            body: Center(
              child: Text('Case route loaded'),
            ),
          ),
        },
      ),
    );

    expect(find.text('SPIDERCAM'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Case route loaded'), findsOneWidget);
  });
}