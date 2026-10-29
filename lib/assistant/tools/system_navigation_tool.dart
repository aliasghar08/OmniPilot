import 'package:firebase_ai/firebase_ai.dart';

/// Tool 9: Global System Navigation (Back, Home, Recents, Notifications)
final FunctionDeclaration systemNavigationTool = FunctionDeclaration(
  'navigateAndroidSystem',
  'Performs global Android system navigation actions such as BACK, HOME, RECENTS, or NOTIFICATIONS.',
  parameters: {
    'action': Schema.string(
      description: 'One of: "BACK", "HOME", "RECENTS", "NOTIFICATIONS", "QUICK_SETTINGS"',
    ),
  },
);
