/// Represents a complete Period Attendance & Compliance evaluation record.
class PeriodAttendanceModel {
  final String studentName;
  final String rollNo;
  final String periodType;
  final String department;
  final String section;
  final String startDate;
  final String endDate;
  final int totalWorkingDays;
  final int daysPresent;
  final int approvedLeaveDays;
  final int unexcusedAbsentDays;
  final int lateArrivalsCount;
  final String standing;
  final String trend;
  final bool medicalCertSubmitted;
  final bool parentNotified;
  final bool examEligible;
  final bool makeupRequired;
  final bool verifiedByAdvisor;
  final double participationScore;
  final String advisorRemarks;

  const PeriodAttendanceModel({
    required this.studentName,
    required this.rollNo,
    required this.periodType,
    required this.department,
    required this.section,
    required this.startDate,
    required this.endDate,
    required this.totalWorkingDays,
    required this.daysPresent,
    required this.approvedLeaveDays,
    required this.unexcusedAbsentDays,
    required this.lateArrivalsCount,
    required this.standing,
    required this.trend,
    required this.medicalCertSubmitted,
    required this.parentNotified,
    required this.examEligible,
    required this.makeupRequired,
    required this.verifiedByAdvisor,
    required this.participationScore,
    required this.advisorRemarks,
  });

  double get effectivePercentage {
    if (totalWorkingDays <= 0) return 0.0;
    return (((daysPresent + approvedLeaveDays) / totalWorkingDays) * 100.0)
        .clamp(0.0, 100.0);
  }

  double get rawPercentage {
    if (totalWorkingDays <= 0) return 0.0;
    return ((daysPresent / totalWorkingDays) * 100.0).clamp(0.0, 100.0);
  }

  Map<String, dynamic> toFirestoreMap() => {
        'student_name': studentName,
        'roll_no': rollNo,
        'period_type': periodType,
        'department': department,
        'section': section,
        'class_id': '$department • $section',
        'start_date': startDate,
        'end_date': endDate,
        'total_count': totalWorkingDays,
        'present_count': daysPresent,
        'approved_leave_count': approvedLeaveDays,
        'absent_count': unexcusedAbsentDays,
        'late_count': lateArrivalsCount,
        'percentage': double.parse(effectivePercentage.toStringAsFixed(1)),
        'raw_percentage': double.parse(rawPercentage.toStringAsFixed(1)),
        'standing': standing,
        'trend': trend,
        'medical_cert_submitted': medicalCertSubmitted,
        'parent_notified': parentNotified,
        'exam_eligible': examEligible,
        'makeup_required': makeupRequired,
        'verified_by_advisor': verifiedByAdvisor,
        'participation_score': participationScore.round(),
        'advisor_remarks': advisorRemarks,
      };
}

