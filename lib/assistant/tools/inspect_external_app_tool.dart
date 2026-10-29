import 'package:firebase_ai/firebase_ai.dart';

/// Tool 3: Full Screen Inspection (Fields, Current Values, Buttons, Static Text)
final FunctionDeclaration inspectExternalAppTool = FunctionDeclaration(
  'inspectExternalAppScreen',
  'Inspects the active Android app screen and returns all editable input fields (with their current written values), clickable buttons/dropdowns/radio buttons/checkboxes, and visible screen text.',
  parameters: {
    'switchToExternal': Schema.boolean(
      description: 'Set true if OmniPilot is currently in front and we should switch back to the previous external app first.',
    ),
  },
  optionalParameters: ['switchToExternal'],
);

