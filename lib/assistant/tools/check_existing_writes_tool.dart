import 'package:firebase_ai/firebase_ai.dart';

/// Tool 4: Check & Verify Existing Writes in Fields
final FunctionDeclaration checkExistingWritesTool = FunctionDeclaration(
  'checkExistingWrites',
  'Reads and verifies what text is currently written inside all editable fields of the active app.',
  parameters: {
    'fieldNames': Schema.string(
      description: 'Optional comma-separated field labels to specifically verify (e.g. "Student Name, Roll Number, Days Present")',
    ),
    'switchToExternal': Schema.boolean(
      description: 'Set true to focus the last external app before checking field values.',
    ),
  },
  optionalParameters: ['fieldNames', 'switchToExternal'],
);
