import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Section 6 of the Period Form: Multi-select compliance & documentation checkboxes.
class ComplianceCheckboxesSection extends StatelessWidget {
  final bool medicalCertSubmitted;
  final bool parentNotified;
  final bool examEligible;
  final bool makeupRequired;
  final ValueChanged<bool> onMedicalCertChanged;
  final ValueChanged<bool> onParentNotifiedChanged;
  final ValueChanged<bool> onExamEligibleChanged;
  final ValueChanged<bool> onMakeupRequiredChanged;

  const ComplianceCheckboxesSection({
    super.key,
    required this.medicalCertSubmitted,
    required this.parentNotified,
    required this.examEligible,
    required this.makeupRequired,
    required this.onMedicalCertChanged,
    required this.onParentNotifiedChanged,
    required this.onExamEligibleChanged,
    required this.onMakeupRequiredChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderLabel(
          title: '6. Compliance & Documentation Flags (Checkboxes)',
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: const Text('Medical / Leave Certificate Submitted', style: TextStyle(fontSize: 13)),
                secondary: const Icon(Icons.assignment_outlined, size: 18),
                value: medicalCertSubmitted,
                onChanged: (v) => onMedicalCertChanged(v ?? false),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: const Text('Parent / Guardian Notified of Period Status', style: TextStyle(fontSize: 13)),
                secondary: const Icon(Icons.mark_email_read_outlined, size: 18),
                value: parentNotified,
                onChanged: (v) => onParentNotifiedChanged(v ?? false),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: const Text('Cleared & Eligible for Final Assessment', style: TextStyle(fontSize: 13)),
                secondary: const Icon(Icons.verified_outlined, size: 18),
                value: examEligible,
                onChanged: (v) => onExamEligibleChanged(v ?? false),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: const Text('Mandatory Makeup Sessions Required', style: TextStyle(fontSize: 13)),
                secondary: const Icon(Icons.pending_actions_outlined, size: 18),
                value: makeupRequired,
                onChanged: (v) => onMakeupRequiredChanged(v ?? false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

