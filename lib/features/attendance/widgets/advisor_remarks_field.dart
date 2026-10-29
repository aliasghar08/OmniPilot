import 'package:flutter/material.dart';

/// Multiline Faculty Advisor Remarks text field and primary Save button.
class AdvisorRemarksField extends StatelessWidget {
  final TextEditingController remarksController;
  final VoidCallback onSave;

  const AdvisorRemarksField({
    super.key,
    required this.remarksController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: remarksController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Faculty Advisor Period Evaluation Remarks',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(Icons.comment_outlined),
            ),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: onSave,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text(
              'Save Period Attendance Record',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
