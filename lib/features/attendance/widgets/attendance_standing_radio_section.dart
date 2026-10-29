import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Section 4 of the Period Form: Radio buttons for Period Attendance Standing.
class AttendanceStandingRadioSection extends StatelessWidget {
  final String selectedStanding;
  final ValueChanged<String> onStandingChanged;

  const AttendanceStandingRadioSection({
    super.key,
    required this.selectedStanding,
    required this.onStandingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderLabel(
          title: '4. Period Attendance Standing (Radio Buttons)',
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: RadioGroup<String>(
            groupValue: selectedStanding,
            onChanged: (val) {
              if (val != null) onStandingChanged(val);
            },
            child: Column(
              children: AppConstants.standingOptions.map((option) {
                final subtitle = switch (option) {
                  'Good Standing' => 'Meets ≥ 85% requirement • Cleared for exams',
                  'Probation Warning' => '75% – 84% • Requires faculty monitoring',
                  'Shortage / Detained' => '< 75% attendance • Condonation or makeup required',
                  _ => 'Approved medical/official period exemption',
                };
                return RadioListTile<String>(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    option,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
                  value: option,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

