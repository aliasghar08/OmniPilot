import 'package:firebase_ai/firebase_ai.dart';

/// Tool 12: Search Google & Live Web Knowledge (Wide-Purpose Copilot)
final FunctionDeclaration searchGoogleAndWebTool = FunctionDeclaration(
  'searchGoogleAndWeb',
  'Searches Google, Google News, Wikipedia, and the live web to answer any general knowledge, science, technology, history, coding, or current events question.',
  parameters: {
    'query': Schema.string(
      description: 'The search query or topic to look up on Google and the web (e.g., "Quantum Computing", "Photosynthesis", "Artificial Intelligence").',
    ),
    'openInBrowser': Schema.boolean(
      description: 'Set true if the user explicitly wants to open the Google search results page in Chrome browser.',
    ),
  },
  optionalParameters: ['openInBrowser'],
);
