import 'package:flutter/material.dart';
import 'advisor_remarks_field.dart';
import 'advisor_signoff_switch_tile.dart';
import 'ai_scenario_presets_bar.dart';
import 'attendance_standing_radio_section.dart';
import 'attendance_trend_radio_section.dart';
import 'compliance_checkboxes_section.dart';
import 'live_attendance_summary_banner.dart';
import 'participation_slider_section.dart';
import 'period_cohort_dropdowns_section.dart';
import 'period_date_range_section.dart';
import 'student_identity_counts_section.dart';

/// Composes all modular sub-sections of the Complex Period Attendance & Compliance Form.
class PeriodAttendanceFormCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController rollController;
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController workingDaysController;
  final TextEditingController daysPresentController;
  final TextEditingController approvedLeavesController;
  final TextEditingController absentDaysController;
  final TextEditingController lateArrivalsController;
  final TextEditingController remarksController;

  final String selectedPeriodType;
  final String selectedDepartment;
  final String selectedSection;
  final String selectedStanding;
  final String selectedTrend;

  final bool medicalCertSubmitted;
  final bool parentNotified;
  final bool examEligible;
  final bool makeupRequired;
  final bool verifiedByAdvisor;
  final double participationScore;

  final double effectivePercentage;
  final double rawPercentage;

  final VoidCallback onReset;
  final ValueChanged<Map<String, dynamic>> onApplyAiScenario;
  final ValueChanged<String> onPeriodTypeChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onSectionChanged;
  final ValueChanged<TextEditingController> onPickDate;
  final ValueChanged<String> onStandingChanged;
  final ValueChanged<String> onTrendChanged;
  final ValueChanged<bool> onMedicalCertChanged;
  final ValueChanged<bool> onParentNotifiedChanged;
  final ValueChanged<bool> onExamEligibleChanged;
  final ValueChanged<bool> onMakeupRequiredChanged;
  final ValueChanged<double> onParticipationScoreChanged;
  final ValueChanged<bool> onVerifiedByAdvisorChanged;
  final VoidCallback onSaveRecord;

  const PeriodAttendanceFormCard({
    super.key,
    required this.nameController,
    required this.rollController,
    required this.startDateController,
    required this.endDateController,
    required this.workingDaysController,
    required this.daysPresentController,
    required this.approvedLeavesController,
    required this.absentDaysController,
    required this.lateArrivalsController,
    required this.remarksController,
    required this.selectedPeriodType,
    required this.selectedDepartment,
    required this.selectedSection,
    required this.selectedStanding,
    required this.selectedTrend,
    required this.medicalCertSubmitted,
    required this.parentNotified,
    required this.examEligible,
    required this.makeupRequired,
    required this.verifiedByAdvisor,
    required this.participationScore,
    required this.effectivePercentage,
    required this.rawPercentage,
    required this.onReset,
    required this.onApplyAiScenario,
    required this.onPeriodTypeChanged,
    required this.onDepartmentChanged,
    required this.onSectionChanged,
    required this.onPickDate,
    required this.onStandingChanged,
    required this.onTrendChanged,
    required this.onMedicalCertChanged,
    required this.onParentNotifiedChanged,
    required this.onExamEligibleChanged,
    required this.onMakeupRequiredChanged,
    required this.onParticipationScoreChanged,
    required this.onVerifiedByAdvisorChanged,
    required this.onSaveRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.date_range, color: Colors.indigo.shade700),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Period Attendance & Compliance Form',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Multi-week / Semester aggregate record with Dropdowns, Radios & Checkboxes',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LiveAttendanceSummaryBanner(
              effectivePercentage: effectivePercentage,
              rawPercentage: rawPercentage,
              selectedStanding: selectedStanding,
              selectedPeriodType: selectedPeriodType,
              startDate: startDateController.text,
              endDate: endDateController.text,
              selectedTrend: selectedTrend,
            ),
            const SizedBox(height: 14),
            AiScenarioPresetsBar(onApplyScenario: onApplyAiScenario),
            const Divider(height: 24),
            PeriodCohortDropdownsSection(
              selectedPeriodType: selectedPeriodType,
              selectedDepartment: selectedDepartment,
              selectedSection: selectedSection,
              onPeriodTypeChanged: onPeriodTypeChanged,
              onDepartmentChanged: onDepartmentChanged,
              onSectionChanged: onSectionChanged,
            ),
            const SizedBox(height: 14),
            PeriodDateRangeSection(
              startDateController: startDateController,
              endDateController: endDateController,
              workingDaysController: workingDaysController,
              onPickDate: onPickDate,
            ),
            const SizedBox(height: 16),
            StudentIdentityCountsSection(
              nameController: nameController,
              rollController: rollController,
              daysPresentController: daysPresentController,
              approvedLeavesController: approvedLeavesController,
              absentDaysController: absentDaysController,
              lateArrivalsController: lateArrivalsController,
            ),
            const Divider(height: 26),
            AttendanceStandingRadioSection(
              selectedStanding: selectedStanding,
              onStandingChanged: onStandingChanged,
            ),
            const SizedBox(height: 14),
            AttendanceTrendRadioSection(
              selectedTrend: selectedTrend,
              onTrendChanged: onTrendChanged,
            ),
            const Divider(height: 26),
            ComplianceCheckboxesSection(
              medicalCertSubmitted: medicalCertSubmitted,
              parentNotified: parentNotified,
              examEligible: examEligible,
              makeupRequired: makeupRequired,
              onMedicalCertChanged: onMedicalCertChanged,
              onParentNotifiedChanged: onParentNotifiedChanged,
              onExamEligibleChanged: onExamEligibleChanged,
              onMakeupRequiredChanged: onMakeupRequiredChanged,
            ),
            const SizedBox(height: 14),
            ParticipationSliderSection(
              participationScore: participationScore,
              onChanged: onParticipationScoreChanged,
            ),
            AdvisorSignoffSwitchTile(
              verifiedByAdvisor: verifiedByAdvisor,
              onChanged: onVerifiedByAdvisorChanged,
            ),
            const SizedBox(height: 14),
            AdvisorRemarksField(
              remarksController: remarksController,
              onSave: onSaveRecord,
            ),
          ],
        ),
      ),
    );
  }
}

