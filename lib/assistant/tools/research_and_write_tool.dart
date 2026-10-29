import 'package:firebase_ai/firebase_ai.dart';

/// Tool 13: Research on Google & Write Directly into External Android App
final FunctionDeclaration researchAndWriteToExternalAppTool = FunctionDeclaration(
  'researchAndWriteToExternalApp',
  'Searches Google & the web for a topic, synthesizes a structured research note with facts and sources, and writes it directly into the active external Android app (e.g., Fossify Notes, Keep, Docs).',
  parameters: {
    'topic': Schema.string(
      description: 'Topic or query to research on Google (e.g., "Quantum Computing", "Solar System", "Machine Learning").',
    ),
    'createNewNoteTab': Schema.boolean(
      description: 'Set true to create a new titled note tab in the external notes app before writing.',
    ),
  },
  optionalParameters: ['createNewNoteTab'],
);
