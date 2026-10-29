/// Represents a single message bubble in the OmniPilot Assistant chat console.
class ChatMessageModel {
  final String sender;
  final String text;
  final DateTime timestamp;

  ChatMessageModel({
    required this.sender,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => sender == 'user';
}

