import 'package:firebase_ai/firebase_ai.dart';
import 'check_existing_writes_tool.dart';
import 'click_external_element_tool.dart';
import 'fill_external_app_tool.dart';
import 'fill_form_tool.dart';
import 'inspect_external_app_tool.dart';
import 'launch_external_app_tool.dart';
import 'research_and_write_tool.dart';
import 'scroll_external_app_tool.dart';
import 'search_google_and_web_tool.dart';
import 'system_navigation_tool.dart';
import 'toggle_external_checkable_tool.dart';
import 'write_external_note_tool.dart';
import 'write_firestore_tool.dart';

export 'check_existing_writes_tool.dart';
export 'click_external_element_tool.dart';
export 'fill_external_app_tool.dart';
export 'fill_form_tool.dart';
export 'inspect_external_app_tool.dart';
export 'launch_external_app_tool.dart';
export 'research_and_write_tool.dart';
export 'scroll_external_app_tool.dart';
export 'search_google_and_web_tool.dart';
export 'system_navigation_tool.dart';
export 'toggle_external_checkable_tool.dart';
export 'write_external_note_tool.dart';
export 'write_firestore_tool.dart';

/// Pre-bundled list of all assistant tools for full Android app control & Google Search
final List<Tool> assistantTools = [
  Tool.functionDeclarations([
    fillFormTool,
    writeFirestoreTool,
    inspectExternalAppTool,
    checkExistingWritesTool,
    fillExternalAppTool,
    clickExternalElementTool,
    toggleExternalCheckableTool,
    scrollExternalAppTool,
    systemNavigationTool,
    launchExternalAppTool,
    writeExternalNoteTool,
    searchGoogleAndWebTool,
    researchAndWriteToExternalAppTool,
  ]),
];
