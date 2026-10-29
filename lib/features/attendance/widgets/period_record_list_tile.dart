import 'package:flutter/material.dart';

/// Displays a single saved period attendance record row inside [SavedPeriodRecordsCard].
class PeriodRecordListTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const PeriodRecordListTile({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final studentName = data['student_name']?.toString() ?? '';
    final periodType = data['period_type']?.toString() ?? 'Period';
    final standing = data['standing']?.toString() ?? 'Good Standing';
    final pct = data['percentage'] ?? 0;
    final present = data['present_count'] ?? 0;
    final total = data['total_count'] ?? 0;
    final leave = data['approved_leave_count'] ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.indigo.shade100,
        child: Icon(Icons.assignment_ind, size: 18, color: Colors.indigo.shade800),
      ),
      title: Text(
        studentName.isNotEmpty
            ? '$studentName (${data['roll_no'] ?? '-'}) • $periodType'
            : 'Class ${data['class_id']}: $present/$total present',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      subtitle: Text(
        'Present: $present/$total (+$leave Leave) • Effective: $pct% • $standing',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.verified, size: 18, color: Colors.green),
    );
  }
}
