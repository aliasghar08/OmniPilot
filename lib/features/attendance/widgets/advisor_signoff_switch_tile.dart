import 'package:flutter/material.dart';

/// Faculty Advisor Sign-Off Switch tile in the Period Attendance Form.
class AdvisorSignoffSwitchTile extends StatelessWidget {
  final bool verifiedByAdvisor;
  final ValueChanged<bool> onChanged;

  const AdvisorSignoffSwitchTile({
    super.key,
    required this.verifiedByAdvisor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      title: const Text(
        'Lock & Verify Period Record (Faculty Sign-Off)',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        verifiedByAdvisor
            ? 'Verified by Advisor • Ready for Registrar Sync'
            : 'Draft • Awaiting Advisor Verification',
        style: const TextStyle(fontSize: 11.5),
      ),
      value: verifiedByAdvisor,
      onChanged: onChanged,
    );
  }
}

