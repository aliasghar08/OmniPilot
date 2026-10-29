import 'package:firebase_ai/firebase_ai.dart';

/// Tool 11: Create & Write Structured Notes in External Notes Apps
final FunctionDeclaration writeExternalNoteTool = FunctionDeclaration(
  'writeNoteInExternalApp',
  'Writes a multi-line note or document into an external Notes app (e.g., Fossify Notes, Google Keep, Docs). Can optionally click "Create a new note", set its title, click OK, and write the note body.',
  parameters: {
    'noteTitle': Schema.string(
      description: 'Optional title if creating a new titled note via the app dialog.',
    ),
    'noteContent': Schema.string(
      description: 'The full multi-line text content of the note to write.',
    ),
    'createNewNoteFirst': Schema.boolean(
      description: 'Set true to click "Create a new note" button, enter noteTitle, and click OK before writing noteContent.',
    ),
    'append': Schema.boolean(
      description: 'Set true to append to existing note text instead of replacing it.',
    ),
  },
  optionalParameters: ['noteTitle', 'createNewNoteFirst', 'append'],
);
