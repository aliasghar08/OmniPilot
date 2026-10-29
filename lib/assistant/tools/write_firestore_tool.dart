import 'package:firebase_ai/firebase_ai.dart';

/// Tool 2: Write period attendance records directly to Cloud Firestore
final FunctionDeclaration writeFirestoreTool = FunctionDeclaration(
  'saveAttendanceRecord',
  'Saves a period attendance record or class summary directly into Cloud Firestore.',
  parameters: {
    'studentName': Schema.string(description: 'Student name if saving an individual period record'),
    'rollNo': Schema.string(description: 'Roll number if saving an individual period record'),
    'periodType': Schema.string(description: 'Period type (e.g., "Monthly Summary", "Full Semester")'),
    'classId': Schema.string(description: 'Department / Class / Section identifier (e.g., "BSCS - Section A")'),
    'startDate': Schema.string(description: 'Period start date'),
    'endDate': Schema.string(description: 'Period end date'),
    'presentCount': Schema.integer(description: 'Total days present (or students present)'),
    'totalCount': Schema.integer(description: 'Total working days in period (or total class strength)'),
    'approvedLeaveCount': Schema.integer(description: 'Approved leave days in period'),
    'standing': Schema.string(description: 'Attendance standing (e.g., "Good Standing", "Probation Warning")'),
    'ratioPercentage': Schema.number(
      description: 'Calculated attendance percentage (e.g., 91.7)',
    ),
  },
  optionalParameters: [
    'studentName',
    'rollNo',
    'periodType',
    'startDate',
    'endDate',
    'approvedLeaveCount',
    'standing',
    'ratioPercentage',
  ],
);
