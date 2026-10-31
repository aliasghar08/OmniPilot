import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Section 5 of the Period Form: Horizontal radio button group for Attendance Trend.
class AttendanceTrendRadioSection extends StatelessWidget {
  final String selectedTrend;
  final ValueChanged<String> onTrendChanged;

  const AttendanceTrendRadioSection({
    super.key,
    required this.selectedTrend,
    required this.onTrendChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderLabel(
          title: '5. Period Attendance Trend (Radio Group)',
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 400;
              final tiles = AppConstants.trendOptions.map((trend) {
                final tile = RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    trend,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  value: trend,
                );
                return isNarrow ? tile : Expanded(child: tile);
              }).toList();

              return RadioGroup<String>(
                groupValue: selectedTrend,
                onChanged: (val) {
                  if (val != null) onTrendChanged(val);
                },
                child: isNarrow ? Column(children: tiles) : Row(children: tiles),
              );
            },
          ),
        ),
      ],
    );
  }
}

