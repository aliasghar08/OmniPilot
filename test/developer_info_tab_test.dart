import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_copilot/omnipilot.dart';

void main() {
  testWidgets('DeveloperInfoTab renders owner name, email, DMCA protection, and token',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeveloperInfoTab(),
        ),
      ),
    );

    expect(find.byType(DeveloperInfoTab), findsOneWidget);
    expect(find.text(FloatingCopyrightWatermark.ownerName), findsOneWidget);
    expect(find.text(FloatingCopyrightWatermark.ownerEmail), findsOneWidget);
    expect(find.text('DMCA Protected & Copyright'), findsOneWidget);
    expect(find.text('Quantum Forge Integrity'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text(OwnershipGuard.computeRuntimeToken()), findsOneWidget);
  });

  test('PeriodAttendancePromptParser extracts human language entities dynamically', () {
    final parsed = PeriodAttendancePromptParser.parse(
      'student is Kamran roll 44 class 9 18 days attended 2 absent 1 late',
    );
    expect(parsed['studentName'], equals('Kamran'));
    expect(parsed['rollNo'], equals('44'));
    expect(parsed['department'], contains('Grade 9'));
    expect(parsed['daysPresent'], equals(18));
    expect(parsed['unexcusedAbsentDays'], equals(2));
    expect(parsed['lateArrivalsCount'], equals(1));
  });
}

