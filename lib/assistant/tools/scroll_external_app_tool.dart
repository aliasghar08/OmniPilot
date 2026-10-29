import 'package:firebase_ai/firebase_ai.dart';

/// Tool 8: Scroll or Swipe in App
final FunctionDeclaration scrollExternalAppTool = FunctionDeclaration(
  'scrollExternalAppScreen',
  'Scrolls the active Android app screen in the specified direction ("down", "up", "left", "right").',
  parameters: {
    'direction': Schema.string(description: 'Direction to scroll: "down", "up", "left", or "right"'),
  },
);

