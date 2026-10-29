import 'package:firebase_ai/firebase_ai.dart';

/// Tool 7: Toggle Checkboxes / Switches / Radio Buttons
final FunctionDeclaration toggleExternalCheckableTool = FunctionDeclaration(
  'toggleExternalCheckable',
  'Sets a checkbox, switch, or radio button to checked (true) or unchecked (false).',
  parameters: {
    'target': Schema.string(description: 'Label or ID of the checkbox/switch/radio option'),
    'checked': Schema.boolean(description: 'Desired state: true for checked/on, false for unchecked/off'),
  },
);

