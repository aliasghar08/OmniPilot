import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Section 2 of the Period Form: Start Date, End Date, and Total Working Days inputs.
class PeriodDateRangeSection extends StatelessWidget {
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController workingDaysController;
  final ValueChanged<TextEditingController> onPickDate;

  const PeriodDateRangeSection({
    super.key,
    required this.startDateController,
    required this.endDateController,
    required this.workingDaysController,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderLabel(
          title: '2. Evaluation Period Date Range & Working Days',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: startDateController,
                decoration: InputDecoration(
                  labelText: 'Period Start Date',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.event, size: 18),
                    onPressed: () => onPickDate(startDateController),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: endDateController,
                decoration: InputDecoration(
                  labelText: 'Period End Date',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.event_available, size: 18),
                    onPressed: () => onPickDate(endDateController),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: TextField(
                controller: workingDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Working Days',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
