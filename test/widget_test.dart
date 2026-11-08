import 'package:flutter_test/flutter_test.dart';
import 'package:forensic_spidercam/app.dart';

void main() {
  testWidgets('ForensicApp loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ForensicApp());

    expect(find.byType(ForensicApp), findsOneWidget);
  });
}