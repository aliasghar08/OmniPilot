import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Section 1 of the Period Form: Academic Period Type, Department, and Section dropdowns.
class PeriodCohortDropdownsSection extends StatelessWidget {
  final String selectedPeriodType;
  final String selectedDepartment;
  final String selectedSection;
  final ValueChanged<String> onPeriodTypeChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onSectionChanged;

  const PeriodCohortDropdownsSection({
    super.key,
    required this.selectedPeriodType,
    required this.selectedDepartment,
    required this.selectedSection,
    required this.onPeriodTypeChanged,
    required this.onDepartmentChanged,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderLabel(title: '1. Academic Period & Cohort (Dropdowns)'),
        const SizedBox(height: 10),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Academic Period Type (Dropdown)',
            prefixIcon: Icon(Icons.calendar_view_month),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedPeriodType,
              isDense: true,
              isExpanded: true,
              items: AppConstants.periodTypeOptions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (val) {
                if (val != null) onPeriodTypeChanged(val);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 460;
            final deptWidget = InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Department / Program',
                prefixIcon: Icon(Icons.school_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDepartment,
                  isDense: true,
                  isExpanded: true,
                  items: AppConstants.departmentOptions
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) onDepartmentChanged(val);
                  },
                ),
              ),
            );

            final sectionWidget = InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Section / Cohort',
                prefixIcon: Icon(Icons.groups_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedSection,
                  isDense: true,
                  isExpanded: true,
                  items: AppConstants.sectionOptions
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) onSectionChanged(val);
                  },
                ),
              ),
            );

            if (isNarrow) {
              return Column(
                children: [
                  deptWidget,
                  const SizedBox(height: 10),
                  sectionWidget,
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 6, child: deptWidget),
                const SizedBox(width: 10),
                Expanded(flex: 5, child: sectionWidget),
              ],
            );
          },
        ),
      ],
    );
  }
}

