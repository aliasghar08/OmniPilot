import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_copilot/omnipilot.dart';

void main() {
  test('All 13 OmniPilot Gemini tools are declared and exported via modular barrel files', () {
    expect(fillFormTool.name, 'autofillScreenFields');
    expect(writeFirestoreTool.name, 'saveAttendanceRecord');
    expect(inspectExternalAppTool.name, 'inspectExternalAppScreen');
    expect(checkExistingWritesTool.name, 'checkExistingWrites');
    expect(fillExternalAppTool.name, 'fillExternalAppFields');
    expect(clickExternalElementTool.name, 'clickExternalAppElement');
    expect(toggleExternalCheckableTool.name, 'toggleExternalCheckable');
    expect(scrollExternalAppTool.name, 'scrollExternalAppScreen');
    expect(systemNavigationTool.name, 'navigateAndroidSystem');
    expect(launchExternalAppTool.name, 'openExternalAndroidApp');
    expect(writeExternalNoteTool.name, 'writeNoteInExternalApp');
    expect(searchGoogleAndWebTool.name, 'searchGoogleAndWeb');
    expect(researchAndWriteToExternalAppTool.name, 'researchAndWriteToExternalApp');
    expect(assistantTools.length, 1);
  });

  test('PeriodAttendancePromptParser and PeriodAttendanceModel compute accurate percentages', () {
    final parsed = PeriodAttendancePromptParser.parse('Zayd Ahmed semester probation');
    expect(parsed['studentName'], 'Zayd Ahmed');
    expect(parsed['periodType'], 'Full Semester');
    expect(parsed['attendanceStanding'], 'Probation Warning');

    const model = PeriodAttendanceModel(
      studentName: 'Ali Asghar',
      rollNo: 'CS-2026-012',
      periodType: 'Monthly Summary',
      department: 'Computer Science - BSCS',
      section: 'Section A (Morning)',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      totalWorkingDays: 24,
      daysPresent: 22,
      approvedLeaveDays: 1,
      unexcusedAbsentDays: 1,
      lateArrivalsCount: 1,
      standing: 'Good Standing',
      trend: 'Consistent',
      medicalCertSubmitted: true,
      parentNotified: false,
      examEligible: true,
      makeupRequired: false,
      verifiedByAdvisor: true,
      participationScore: 95.0,
      advisorRemarks: 'Excellent standing.',
    );

    expect(model.effectivePercentage, closeTo(95.83, 0.05));
    expect(model.rawPercentage, closeTo(91.67, 0.05));
  });
}
