/// Global application constants, author metadata, and complex form options for OmniPilot.
class AppConstants {
  const AppConstants._();

  static const String appName = 'OmniPilot';
  static const String appTagline =
      'Universal Android Cross-App AI Copilot, Live Google Search & Period Attendance Engine';
  static const String appVersion = '1.0.0+1';
  static const String appIconAsset = 'assets/omnipilot_icon_square.png';

  // Author & Copyright Metadata (Quantum Forge Security Standard)
  static const String ownerName = 'Ali Asghar';
  static const String ownerEmail = 'aliasgharinnocent@yahoo.com';
  static const String ownerGitHub = 'https://github.com/aliasghar08/OmniPilot';
  static const String copyrightNotice =
      'OmniPilot © Ali Asghar · aliasgharinnocent@yahoo.com · All Rights Reserved · DMCA Protected';

  // Complex Period Attendance Form Dropdown Options
  static const List<String> periodTypeOptions = [
    'Monthly Summary',
    'Mid-Term Period',
    'Full Semester',
    'Quarterly Review',
    'Custom Date Range',
  ];

  static const List<String> departmentOptions = [
    'Computer Science - BSCS',
    'Grade 10 - Science',
    'Grade 11 - Pre-Engineering',
    'Grade 12 - Humanities',
    'MBA Executive',
  ];

  static const List<String> sectionOptions = [
    'Section A (Morning)',
    'Section B (Evening)',
    'Lab Group 1',
    'Honors Cohort',
  ];

  // Radio Button Options
  static const List<String> standingOptions = [
    'Good Standing',
    'Probation Warning',
    'Shortage / Detained',
    'Medical Exemption',
  ];

  static const List<String> trendOptions = [
    'Improving',
    'Consistent',
    'Declining',
  ];

  // Default Prompt Suggestions for OmniPilot Assistant Console
  static const List<String> defaultPromptSuggestions = [
    'Search Google for Quantum Computing breakthroughs and summarize',
    'Search Google for Artificial Intelligence and write into Notes app',
    'What is Photosynthesis and how does it work?',
    'Inspect active screen fields and readable texts',
    'Check existing writes in the active external app',
    'Scroll down and tap the Submit button',
  ];

  static const String welcomeMessage =
      '👋 Hello! I am **OmniPilot** — your Wide-Purpose Android AI Copilot.\n\n'
      '• **🌐 Live Google & Web Search**: Ask me any question (science, tech, news, history, coding) and I will fetch live info from Google Search, Google News, and Wikipedia.\n'
      '• **📝 Google Research → External Apps**: Ask me to research any topic on Google and automatically write it into **Fossify Notes**, Docs, or any open app!\n'
      '• **🤖 Universal Android Control**: Turn on the Sliding Menu to command me directly over any third-party app with full click, text-fill, and gesture automation!';
}

