/// Parses natural-language prompts into a full set of Complex Period Attendance Form values.
class PeriodAttendancePromptParser {
  const PeriodAttendancePromptParser._();

  static Map<String, dynamic> parse(String prompt) {
    final lower = prompt.toLowerCase();

    // Detect student preset or parse from prompt
    if (lower.contains('zayd') || lower.contains('probation')) {
      return {
        'studentName': 'Zayd Ahmed',
        'rollNo': 'CS-2026-019',
        'periodType': 'Full Semester',
        'department': 'Computer Science - BSCS',
        'section': 'Section B (Evening)',
        'startDate': '2026-09-01',
        'endDate': '2026-12-20',
        'totalWorkingDays': 48,
        'daysPresent': 35,
        'approvedLeaveDays': 2,
        'unexcusedAbsentDays': 11,
        'lateArrivalsCount': 6,
        'attendanceStanding': 'Probation Warning',
        'attendanceTrend': 'Declining',
        'medicalCertSubmitted': false,
        'parentNotified': true,
        'examEligible': false,
        'makeupRequired': true,
        'verifiedByAdvisor': true,
        'participationScore': 68.0,
        'advisorRemarks':
            'Attendance dropped to 77.1% during mid-semester. Parent notified; 4 makeup lab sessions required for final exam clearance.',
      };
    } else if (lower.contains('sara') || lower.contains('medical exemption')) {
      return {
        'studentName': 'Sara Malik',
        'rollNo': 'ME-2026-004',
        'periodType': 'Mid-Term Period',
        'department': 'Grade 11 - Pre-Engineering',
        'section': 'Lab Group 1',
        'startDate': '2026-10-01',
        'endDate': '2026-11-15',
        'totalWorkingDays': 32,
        'daysPresent': 22,
        'approvedLeaveDays': 8,
        'unexcusedAbsentDays': 2,
        'lateArrivalsCount': 1,
        'attendanceStanding': 'Medical Exemption',
        'attendanceTrend': 'Improving',
        'medicalCertSubmitted': true,
        'parentNotified': true,
        'examEligible': true,
        'makeupRequired': false,
        'verifiedByAdvisor': true,
        'participationScore': 88.0,
        'advisorRemarks':
            'Approved 8-day hospital recovery leave with verified medical certificate. Effective attendance 93.8% including excused medical leave.',
      };
    }

    // Default / Ali Asghar Monthly or custom parsed values
    String studentName = 'Ali Asghar';
    final nameMatch =
        RegExp(r'(?:for|student[:\s]+)\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)').firstMatch(prompt);
    if (nameMatch != null) {
      studentName = nameMatch.group(1)!;
    }

    String rollNo = 'CS-2026-012';
    final rollMatch = RegExp(r'roll\s*(?:no|number)?[:\s]*([A-Za-z0-9\-]+)', caseSensitive: false)
        .firstMatch(prompt);
    if (rollMatch != null) {
      rollNo = rollMatch.group(1)!;
    }

    String periodType = 'Monthly Summary';
    if (lower.contains('semester')) {
      periodType = 'Full Semester';
    } else if (lower.contains('mid-term') || lower.contains('midterm')) {
      periodType = 'Mid-Term Period';
    } else if (lower.contains('quarter')) {
      periodType = 'Quarterly Review';
    } else if (lower.contains('custom')) {
      periodType = 'Custom Date Range';
    }

    return {
      'studentName': studentName,
      'rollNo': rollNo,
      'periodType': periodType,
      'department': 'Computer Science - BSCS',
      'section': 'Section A (Morning)',
      'startDate': '2026-10-01',
      'endDate': '2026-10-31',
      'totalWorkingDays': 24,
      'daysPresent': 22,
      'approvedLeaveDays': 1,
      'unexcusedAbsentDays': 1,
      'lateArrivalsCount': 1,
      'attendanceStanding': 'Good Standing',
      'attendanceTrend': 'Consistent',
      'medicalCertSubmitted': true,
      'parentNotified': false,
      'examEligible': true,
      'makeupRequired': false,
      'verifiedByAdvisor': true,
      'participationScore': 95.0,
      'advisorRemarks':
          'Outstanding period attendance (95.8% effective). Active lab contributor and punctual across all October sessions.',
    };
  }
}
