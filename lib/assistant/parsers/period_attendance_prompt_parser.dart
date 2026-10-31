/// Parses human natural-language prompts into a full set of Complex Period Attendance Form values.
class PeriodAttendancePromptParser {
  const PeriodAttendancePromptParser._();

  static Map<String, dynamic> parse(String prompt) {
    final lower = prompt.toLowerCase();

    // 1. Check known presets first
    if (lower.contains('zayd') || (lower.contains('probation') && !lower.contains('ali') && !lower.contains('sara'))) {
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
    } else if (lower.contains('sara') || (lower.contains('medical exemption') && !lower.contains('ali'))) {
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

    // 2. Dynamic Human Language Entity Extraction
    String studentName = 'Ali Asghar';
    final nameRegexes = [
      RegExp(r'(?:student\s*(?:is|named)?|name\s*(?:is|:)?|naam\s*(?:hai|:)?|for)\s+([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)'),
      RegExp(r'(?:put|fill|record)\s+([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)\s+(?:in|as|for)\s+(?:student|name)'),
    ];
    for (final reg in nameRegexes) {
      final m = reg.firstMatch(prompt);
      if (m != null) {
        studentName = m.group(1)!.trim();
        break;
      }
    }

    String rollNo = 'CS-2026-012';
    final rollMatch = RegExp(r'(?:roll|id|registration)\s*(?:no|number)?[:\s]*([A-Za-z0-9\-]+)', caseSensitive: false)
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

    String department = 'Computer Science - BSCS';
    if (lower.contains('pre-engineering') || lower.contains('engineering')) {
      department = 'Grade 11 - Pre-Engineering';
    } else if (lower.contains('pre-medical') || lower.contains('medical')) {
      department = 'Grade 12 - Pre-Medical';
    } else if (lower.contains('class 9') || lower.contains('9th') || lower.contains('grade 9')) {
      department = 'Grade 9 - General Science';
    } else if (lower.contains('class 10') || lower.contains('10th') || lower.contains('matric')) {
      department = 'Grade 10 - Matric Science';
    }

    String section = 'Section A (Morning)';
    if (lower.contains('section b') || lower.contains('sec b') || lower.contains('evening')) {
      section = 'Section B (Evening)';
    } else if (lower.contains('lab group') || lower.contains('group 1')) {
      section = 'Lab Group 1';
    } else if (lower.contains('section c') || lower.contains('sec c')) {
      section = 'Section C (Weekend)';
    }

    // Days Present
    int daysPresent = 22;
    final presentMatch = RegExp(r'(\d+)\s*(?:days?\s*)?(?:present|attended|hazir)', caseSensitive: false).firstMatch(prompt)
        ?? RegExp(r'(?:present|attended|hazir)[:\s]*(\d+)', caseSensitive: false).firstMatch(prompt);
    if (presentMatch != null) {
      daysPresent = int.tryParse(presentMatch.group(1)!) ?? daysPresent;
    }

    // Absent Days
    int unexcusedAbsentDays = 1;
    final absentMatch = RegExp(r'(\d+)\s*(?:days?\s*)?(?:absent|absences|ghair hazir|unexcused)', caseSensitive: false).firstMatch(prompt)
        ?? RegExp(r'(?:absent|absences)[:\s]*(\d+)', caseSensitive: false).firstMatch(prompt);
    if (absentMatch != null) {
      unexcusedAbsentDays = int.tryParse(absentMatch.group(1)!) ?? unexcusedAbsentDays;
    }

    // Approved Leave Days
    int approvedLeaveDays = 1;
    final leaveMatch = RegExp(r'(\d+)\s*(?:days?\s*)?(?:leaves?|approved leave|chutti)', caseSensitive: false).firstMatch(prompt)
        ?? RegExp(r'(?:leaves?|leave)[:\s]*(\d+)', caseSensitive: false).firstMatch(prompt);
    if (leaveMatch != null) {
      approvedLeaveDays = int.tryParse(leaveMatch.group(1)!) ?? approvedLeaveDays;
    }

    // Late Arrivals
    int lateArrivalsCount = 1;
    final lateMatch = RegExp(r'(\d+)\s*(?:late|tardy|late arrivals?)', caseSensitive: false).firstMatch(prompt)
        ?? RegExp(r'(?:late|tardy)[:\s]*(\d+)', caseSensitive: false).firstMatch(prompt);
    if (lateMatch != null) {
      lateArrivalsCount = int.tryParse(lateMatch.group(1)!) ?? lateArrivalsCount;
    }

    // Total Working Days
    int totalWorkingDays = 24;
    final totalMatch = RegExp(r'(?:total|working days?|kul din)[:\s]*(\d+)', caseSensitive: false).firstMatch(prompt)
        ?? RegExp(r'(\d+)\s*(?:total|working days?)', caseSensitive: false).firstMatch(prompt);
    if (totalMatch != null) {
      totalWorkingDays = int.tryParse(totalMatch.group(1)!) ?? totalWorkingDays;
    } else {
      final computed = daysPresent + unexcusedAbsentDays + approvedLeaveDays;
      if (computed > 0) totalWorkingDays = computed;
    }

    // Attendance Standing
    String attendanceStanding = 'Good Standing';
    if (lower.contains('probation')) {
      attendanceStanding = 'Probation Warning';
    } else if (lower.contains('detained') || lower.contains('shortage')) {
      attendanceStanding = 'Shortage / Detained';
    } else if (lower.contains('medical') || lower.contains('exemption')) {
      attendanceStanding = 'Medical Exemption';
    } else {
      final pct = totalWorkingDays > 0 ? ((daysPresent + approvedLeaveDays) / totalWorkingDays) * 100 : 90.0;
      if (pct >= 85) {
        attendanceStanding = 'Good Standing';
      } else if (pct >= 75) {
        attendanceStanding = 'Probation Warning';
      } else {
        attendanceStanding = 'Shortage / Detained';
      }
    }

    // Trend
    String attendanceTrend = 'Consistent';
    if (lower.contains('improving') || lower.contains('better')) {
      attendanceTrend = 'Improving';
    } else if (lower.contains('declining') || lower.contains('dropping') || lower.contains('warning')) {
      attendanceTrend = 'Declining';
    }

    final effectivePct = totalWorkingDays > 0
        ? (((daysPresent + approvedLeaveDays) / totalWorkingDays) * 100).toStringAsFixed(1)
        : '91.7';

    return {
      'studentName': studentName,
      'rollNo': rollNo,
      'periodType': periodType,
      'department': department,
      'section': section,
      'startDate': '2026-10-01',
      'endDate': '2026-10-31',
      'totalWorkingDays': totalWorkingDays,
      'daysPresent': daysPresent,
      'approvedLeaveDays': approvedLeaveDays,
      'unexcusedAbsentDays': unexcusedAbsentDays,
      'lateArrivalsCount': lateArrivalsCount,
      'attendanceStanding': attendanceStanding,
      'attendanceTrend': attendanceTrend,
      'medicalCertSubmitted': approvedLeaveDays > 0,
      'parentNotified': attendanceStanding != 'Good Standing',
      'examEligible': attendanceStanding != 'Shortage / Detained',
      'makeupRequired': attendanceStanding != 'Good Standing',
      'verifiedByAdvisor': true,
      'participationScore': attendanceStanding == 'Good Standing' ? 95.0 : 72.0,
      'advisorRemarks':
          'Period record for $studentName ($rollNo): $daysPresent/$totalWorkingDays days present ($effectivePct% effective). Standing: $attendanceStanding.',
    };
  }
}
