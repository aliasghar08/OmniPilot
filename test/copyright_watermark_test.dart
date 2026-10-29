import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_copilot/omnipilot.dart';

void main() {
  test('OwnershipGuard verifies author identity and DMCA watermark integrity', () {
    expect(OwnershipGuard.verifyIntegrity(), isTrue);
    expect(() => OwnershipGuard.enforceOwnershipOrThrow(), returnsNormally);
    expect(FloatingCopyrightWatermark.ownerName, equals('Ali Asghar'));
    expect(FloatingCopyrightWatermark.ownerEmail, equals('aliasgharinnocent@yahoo.com'));
  });

  testWidgets('FloatingCopyrightWatermark renders owner name, email, and DMCA notice',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(child: Text('OmniPilot Content')),
              FloatingCopyrightWatermark(),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(FloatingCopyrightWatermark), findsOneWidget);
    expect(
      find.textContaining('Ali Asghar'),
      findsOneWidget,
    );
    expect(
      find.textContaining('aliasgharinnocent@yahoo.com'),
      findsOneWidget,
    );
    expect(
      find.textContaining('DMCA Protected'),
      findsOneWidget,
    );

    // Ensure the watermark wraps its content in an IgnorePointer so it never blocks UI gestures
    final ignorePointerFinder = find.descendant(
      of: find.byType(FloatingCopyrightWatermark),
      matching: find.byType(IgnorePointer),
    );
    expect(ignorePointerFinder, findsOneWidget);
    final IgnorePointer ignorePointer = tester.widget(ignorePointerFinder);
    expect(ignorePointer.ignoring, isTrue);
  });
}

