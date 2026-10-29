import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Displays real-time effective & raw attendance percentages, standing badge, and progress bar.
class LiveAttendanceSummaryBanner extends StatelessWidget {
  final double effectivePercentage;
  final double rawPercentage;
  final String selectedStanding;
  final String selectedPeriodType;
  final String startDate;
  final String endDate;
  final String selectedTrend;

  const LiveAttendanceSummaryBanner({
    super.key,
    required this.effectivePercentage,
    required this.rawPercentage,
    required this.selectedStanding,
    required this.selectedPeriodType,
    required this.startDate,
    required this.endDate,
    required this.selectedTrend,
  });

  @override
  Widget build(BuildContext context) {
    final standingColor = StatusBadgeChip.colorForStanding(selectedStanding);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            standingColor.withValues(alpha: 0.12),
            standingColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: standingColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 18, color: standingColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Effective Attendance: ${effectivePercentage.toStringAsFixed(1)}% (Raw: ${rawPercentage.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: standingColor,
                  ),
                ),
              ),
              StatusBadgeChip(
                label: selectedStanding,
                color: standingColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (effectivePercentage / 100.0).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(standingColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Period: $selectedPeriodType ($startDate → $endDate) • Trend: $selectedTrend',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}

