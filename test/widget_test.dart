import 'package:flutter_test/flutter_test.dart';
import 'package:nift_hostel_flutter/main.dart';

void main() {
  testWidgets('NIFT Hostel chat page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const NiftHostelApp());
    await tester.pump();

    expect(find.text('NIFT Hostel'), findsWidgets);
    expect(find.text('Hosteller Entry'), findsOneWidget);
    expect(find.text('Total Entries'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);

    // Pump with a duration to let animations complete and clean up timers
    await tester.pump(const Duration(seconds: 2));
  });
}
