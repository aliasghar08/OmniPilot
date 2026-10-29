import 'package:firebase_ai/firebase_ai.dart';

/// Tool 1: Populate the complex Period Attendance & Compliance Form (Dropdowns, Radio Buttons, Checkboxes, Switch, Slider, Dates & Counts)
final FunctionDeclaration fillFormTool = FunctionDeclaration(
  'autofillScreenFields',
  'Fills the complex Period Attendance & Compliance Form on screen, including Dropdowns, Radio Buttons, Checkboxes, Switches, Date Ranges, and Period Attendance counts.',
  parameters: {
    'studentName': Schema.string(description: 'Full name of the student (e.g., "Ali Asghar")'),
    'rollNo': Schema.string(description: 'Student roll or registration number (e.g., "CS-2026-012")'),
    'periodType': Schema.string(
      description: 'Dropdown value for academic period: "Monthly Summary", "Mid-Term Period", "Full Semester", "Quarterly Review", or "Custom Date Range"',
    ),
    'department': Schema.string(
      description: 'Dropdown value for department/grade: "Computer Science - BSCS", "Grade 10 - Science", "Grade 11 - Pre-Engineering", or "Grade 12 - Humanities"',
    ),
    'section': Schema.string(
      description: 'Dropdown value for section/cohort: "Section A (Morning)", "Section B (Evening)", or "Lab Group 1"',
    ),
    'startDate': Schema.string(description: 'Period start date in YYYY-MM-DD format (e.g., "2026-10-01")'),
    'endDate': Schema.string(description: 'Period end date in YYYY-MM-DD format (e.g., "2026-10-31")'),
    'totalWorkingDays': Schema.integer(description: 'Total working or lecture days in the period (e.g., 24)'),
    'daysPresent': Schema.integer(description: 'Number of days the student was present in the period (e.g., 21)'),
    'approvedLeaveDays': Schema.integer(description: 'Number of approved medical or official leave days (e.g., 2)'),
    'unexcusedAbsentDays': Schema.integer(description: 'Number of unexcused absent days (e.g., 1)'),
    'lateArrivalsCount': Schema.integer(description: 'Number of late arrivals during the period (e.g., 2)'),
    'attendanceStanding': Schema.string(
      description: 'Radio button selection for standing: "Good Standing", "Probation Warning", "Shortage / Detained", or "Medical Exemption"',
    ),
    'attendanceTrend': Schema.string(
      description: 'Radio button selection for trend over period: "Improving", "Consistent", or "Declining"',
    ),
    'medicalCertSubmitted': Schema.boolean(description: 'Checkbox: Medical Certificate Submitted'),
    'parentNotified': Schema.boolean(description: 'Checkbox: Parent / Guardian Notified'),
    'examEligible': Schema.boolean(description: 'Checkbox: Eligible for Final Exam'),
    'makeupRequired': Schema.boolean(description: 'Checkbox: Attendance Makeup Required'),
    'verifiedByAdvisor': Schema.boolean(description: 'Switch: Lock & Verify Period Record by Faculty Advisor'),
    'participationScore': Schema.number(description: 'Slider value (0 to 100) for class participation & punctuality'),
    'advisorRemarks': Schema.string(description: 'Multiline faculty advisor evaluation remarks for the period'),
  },
  optionalParameters: [
    'periodType',
    'department',
    'section',
    'startDate',
    'endDate',
    'totalWorkingDays',
    'daysPresent',
    'approvedLeaveDays',
    'unexcusedAbsentDays',
    'lateArrivalsCount',
    'attendanceStanding',
    'attendanceTrend',
    'medicalCertSubmitted',
    'parentNotified',
    'examEligible',
    'makeupRequired',
    'verifiedByAdvisor',
    'participationScore',
    'advisorRemarks',
  ],
);
