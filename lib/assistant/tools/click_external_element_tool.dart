import 'package:firebase_ai/firebase_ai.dart';

/// Tool 6: Click or Long-Press Any Button / Dropdown / Radio Button in App
final FunctionDeclaration clickExternalElementTool = FunctionDeclaration(
  'clickExternalAppElement',
  'Clicks or long-presses any button, dropdown menu item, radio button, tab, or control by its visible text, content description, ID, or index (#0, #1).',
  parameters: {
    'target': Schema.string(
      description: 'Visible label, resource ID, or #index of the element to click (e.g., "Good Standing", "Full Semester", "Save").',
    ),
    'longPress': Schema.boolean(
      description: 'Set true to perform a long-click instead of a regular tap.',
    ),
  },
  optionalParameters: ['longPress'],
);
