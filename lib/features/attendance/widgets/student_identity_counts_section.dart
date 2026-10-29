import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Section 3 of the Period Form: Student Name, Roll No, Present, Leave, Absent, and Late counts.
class StudentIdentityCountsSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController rollController;
  final TextEditingController daysPresentController;
  final TextEditingController approvedLeavesController;
  final TextEditingController absentDaysController;
  final TextEditingController lateArrivalsController;

  const StudentIdentityCountsSection({
    super.key,
    required this.nameController,
    required this.rollController,
    required this.daysPresentController,
    required this.approvedLeavesController,
    required this.absentDaysController,
    required this.lateArrivalsController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderLabel(
          title: '3. Student Identity & Period Attendance Breakdown',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: TextField(
                controller: rollController,
                decoration: const InputDecoration(
                  labelText: 'Roll / Registration No.',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: daysPresentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Days Present',
                  prefixIcon: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: approvedLeavesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Approved Leaves',
                  prefixIcon: Icon(Icons.medical_information_outlined, color: Colors.teal.shade700, size: 20),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: absentDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Unexcused Absences',
                  prefixIcon: Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 20),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: lateArrivalsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Late Arrivals Count',
                  prefixIcon: Icon(Icons.schedule, color: Colors.orange.shade800, size: 20),
                  border: const OutlineInputBorder(),
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
