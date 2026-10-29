import 'package:flutter/material.dart';

/// Reusable pill badge displaying an attendance standing or verification status.
class StatusBadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadgeChip({
    super.key,
    required this.label,
    required this.color,
  });

  /// Resolves the semantic color for a given period attendance standing string.
  static Color colorForStanding(String standing) {
    return switch (standing) {
      'Good Standing' => Colors.green.shade700,
      'Probation Warning' => Colors.orange.shade800,
      'Shortage / Detained' => Colors.red.shade700,
      _ => Colors.teal.shade700,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
