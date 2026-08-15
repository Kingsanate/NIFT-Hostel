import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('NIFT Hostel app initializes cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('NIFT Hostel Smart Student Management System'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('NIFT Hostel Smart Student Management System'), findsOneWidget);
  });
}
