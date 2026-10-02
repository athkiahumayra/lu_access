// Basic Flutter widget test for LUAccessApp.

import 'package:flutter_test/flutter_test.dart';
import 'package:lu_access/main.dart';

void main() {
  testWidgets('App loads splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LUAccessApp());

    // Verify LU Access text appears on splash screen.
    expect(find.text('LU Access'), findsOneWidget);
  });
}
