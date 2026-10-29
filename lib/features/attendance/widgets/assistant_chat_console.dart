import 'package:flutter/material.dart';
import '../../../models/models.dart';
import 'chat_message_bubble.dart';
import 'prompt_suggestions_bar.dart';

/// Complete OmniPilot Assistant Chat Console with prompt suggestions, message history, and input bar.
class AssistantChatConsole extends StatelessWidget {
  final List<String> promptSuggestions;
  final List<ChatMessageModel> messages;
  final ScrollController scrollController;
  final TextEditingController inputController;
  final bool isProcessing;
  final ValueChanged<String> onSelectSuggestion;
  final VoidCallback onSendMessage;

  const AssistantChatConsole({
    super.key,
    required this.promptSuggestions,
    required this.messages,
    required this.scrollController,
    required this.inputController,
    required this.isProcessing,
    required this.onSelectSuggestion,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PromptSuggestionsBar(
          suggestions: promptSuggestions,
          onSelectPrompt: onSelectSuggestion,
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return ChatMessageBubble(message: messages[index]);
            },
          ),
        ),
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'OmniPilot is reasoning, searching Google & executing tools...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inputController,
                  decoration: InputDecoration(
                    hintText: 'Ask OmniPilot to search Google, fill period forms, or control apps...',
                    hintStyle: const TextStyle(fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onSubmitted: (_) => onSendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: onSendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

