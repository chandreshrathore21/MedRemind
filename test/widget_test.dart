import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders header title and FAB', (WidgetTester tester) async {
    // Render the HomeScreen inside a MaterialApp wrapper
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Verify key UI elements exist
    expect(find.text('MedRemind'), findsOneWidget);
    expect(find.text('Daily Schedule'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
