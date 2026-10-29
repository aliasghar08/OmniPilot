import 'package:flutter/material.dart';

/// Horizontal bar of suggested prompts at the top of the OmniPilot Assistant console.
class PromptSuggestionsBar extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelectPrompt;

  const PromptSuggestionsBar({
    super.key,
    required this.suggestions,
    required this.onSelectPrompt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((prompt) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                label: Text(
                  prompt,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => onSelectPrompt(prompt),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

