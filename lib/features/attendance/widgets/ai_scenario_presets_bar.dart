import 'package:flutter/material.dart';
import '../../../assistant/assistant.dart';

/// Horizontal bar of one-tap AI scenario presets for populating the Period Attendance Form.
class AiScenarioPresetsBar extends StatelessWidget {
  final ValueChanged<Map<String, dynamic>> onApplyScenario;

  const AiScenarioPresetsBar({
    super.key,
    required this.onApplyScenario,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🤖 One-Tap AI Period Form Autofill Scenarios:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.auto_awesome, size: 15, color: Colors.green),
                label: const Text('AI Fill: Ali Asghar (Monthly • Good)', style: TextStyle(fontSize: 11.5)),
                onPressed: () {
                  final data = AssistantController.parsePeriodAttendancePrompt('Ali Asghar monthly good standing');
                  onApplyScenario(data);
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orange),
                label: const Text('AI Fill: Zayd Ahmed (Semester • Probation)', style: TextStyle(fontSize: 11.5)),
                onPressed: () {
                  final data = AssistantController.parsePeriodAttendancePrompt('Zayd Ahmed semester probation');
                  onApplyScenario(data);
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.medical_services_outlined, size: 15, color: Colors.teal),
                label: const Text('AI Fill: Sara Malik (Mid-Term • Medical)', style: TextStyle(fontSize: 11.5)),
                onPressed: () {
                  final data = AssistantController.parsePeriodAttendancePrompt('Sara Malik medical exemption');
                  onApplyScenario(data);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
