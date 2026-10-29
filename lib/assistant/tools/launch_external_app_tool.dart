import 'package:firebase_ai/firebase_ai.dart';

/// Tool 10: Open or Launch Any Installed Android App
final FunctionDeclaration launchExternalAppTool = FunctionDeclaration(
  'openExternalAndroidApp',
  'Opens and launches an installed Android application by its name (e.g., "Contacts", "Notes", "Chrome", "Settings") or package name.',
  parameters: {
    'appNameOrPackage': Schema.string(
      description: 'Name or package of the app to launch (e.g., "Notes", "Contacts", "org.fossify.notes")',
    ),
  },
);
