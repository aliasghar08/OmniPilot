import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a customizable third-party app shortcut for cross-app automation.
class AppShortcutItem {
  final String id;
  final String name;
  final String packageOrQuery;
  final String iconKey;

  const AppShortcutItem({
    required this.id,
    required this.name,
    required this.packageOrQuery,
    this.iconKey = 'apps',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'packageOrQuery': packageOrQuery,
        'iconKey': iconKey,
      };

  factory AppShortcutItem.fromJson(Map<String, dynamic> map) => AppShortcutItem(
        id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: map['name']?.toString() ?? 'App',
        packageOrQuery: map['packageOrQuery']?.toString() ?? '',
        iconKey: map['iconKey']?.toString() ?? 'apps',
      );
}

/// Central state management and persistent preferences for OmniPilot's
/// in-app automation engine, floating overlay, and customizable app shortcuts.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._();
  AppSettingsService._();

  static const String _keyDelayMs = 'omni_input_delay_ms';
  static const String _keyAutoSwitch = 'omni_auto_switch';
  static const String _keyVerifyWrites = 'omni_verify_writes';
  static const String _keyTypingStrategy = 'omni_typing_strategy';
  static const String _keyOverlayOpacity = 'omni_overlay_opacity';
  static const String _keyBubbleSize = 'omni_bubble_size';
  static const String _keyShortcuts = 'omni_custom_shortcuts';

  int _inputDelayMs = 150;
  bool _autoSwitchToExternal = true;
  bool _verifyWrites = true;
  String _typingStrategy = 'smart_auto'; // 'smart_auto', 'action_only', 'clipboard'
  double _overlayOpacity = 0.95;
  String _bubbleSize = 'medium'; // 'small', 'medium', 'large'
  List<AppShortcutItem> _shortcuts = [];

  int get inputDelayMs => _inputDelayMs;
  bool get autoSwitchToExternal => _autoSwitchToExternal;
  bool get verifyWrites => _verifyWrites;
  String get typingStrategy => _typingStrategy;
  double get overlayOpacity => _overlayOpacity;
  String get bubbleSize => _bubbleSize;
  List<AppShortcutItem> get shortcuts => List.unmodifiable(_shortcuts);

  bool _isInitialized = false;

  /// Loads persisted settings from device storage.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _inputDelayMs = prefs.getInt(_keyDelayMs) ?? 150;
      _autoSwitchToExternal = prefs.getBool(_keyAutoSwitch) ?? true;
      _verifyWrites = prefs.getBool(_keyVerifyWrites) ?? true;
      _typingStrategy = prefs.getString(_keyTypingStrategy) ?? 'smart_auto';
      _overlayOpacity = prefs.getDouble(_keyOverlayOpacity) ?? 0.95;
      _bubbleSize = prefs.getString(_keyBubbleSize) ?? 'medium';

      final rawList = prefs.getStringList(_keyShortcuts);
      if (rawList != null && rawList.isNotEmpty) {
        _shortcuts = rawList
            .map((s) {
              try {
                return AppShortcutItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<AppShortcutItem>()
            .toList();
      } else {
        // Default set of popular apps for cross-app automation
        _shortcuts = [
          const AppShortcutItem(
            id: 'contacts',
            name: 'Contacts',
            packageOrQuery: 'Contacts',
            iconKey: 'contacts',
          ),
          const AppShortcutItem(
            id: 'notes',
            name: 'Fossify Notes',
            packageOrQuery: 'org.fossify.notes',
            iconKey: 'note_alt',
          ),
          const AppShortcutItem(
            id: 'whatsapp',
            name: 'WhatsApp',
            packageOrQuery: 'com.whatsapp',
            iconKey: 'chat',
          ),
          const AppShortcutItem(
            id: 'sheets',
            name: 'Google Sheets',
            packageOrQuery: 'com.google.android.apps.docs.editors.sheets',
            iconKey: 'table_chart',
          ),
          const AppShortcutItem(
            id: 'chrome',
            name: 'Chrome',
            packageOrQuery: 'com.android.chrome',
            iconKey: 'language',
          ),
        ];
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading AppSettingsService: $e');
    }
  }

  Future<void> setInputDelayMs(int value) async {
    _inputDelayMs = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDelayMs, value);
  }

  Future<void> setAutoSwitchToExternal(bool value) async {
    _autoSwitchToExternal = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSwitch, value);
  }

  Future<void> setVerifyWrites(bool value) async {
    _verifyWrites = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVerifyWrites, value);
  }

  Future<void> setTypingStrategy(String value) async {
    _typingStrategy = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTypingStrategy, value);
  }

  Future<void> setOverlayOpacity(double value) async {
    _overlayOpacity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOverlayOpacity, value);
  }

  Future<void> setBubbleSize(String value) async {
    _bubbleSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBubbleSize, value);
  }

  Future<void> addShortcut(String name, String packageOrQuery) async {
    final newItem = AppShortcutItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      packageOrQuery: packageOrQuery.trim(),
      iconKey: 'apps',
    );
    _shortcuts.add(newItem);
    notifyListeners();
    await _saveShortcuts();
  }

  Future<void> removeShortcut(String id) async {
    _shortcuts.removeWhere((item) => item.id == id);
    notifyListeners();
    await _saveShortcuts();
  }

  Future<void> resetToDefaults() async {
    _inputDelayMs = 150;
    _autoSwitchToExternal = true;
    _verifyWrites = true;
    _typingStrategy = 'smart_auto';
    _overlayOpacity = 0.95;
    _bubbleSize = 'medium';
    _shortcuts = [
      const AppShortcutItem(
        id: 'contacts',
        name: 'Contacts',
        packageOrQuery: 'Contacts',
        iconKey: 'contacts',
      ),
      const AppShortcutItem(
        id: 'notes',
        name: 'Fossify Notes',
        packageOrQuery: 'org.fossify.notes',
        iconKey: 'note_alt',
      ),
      const AppShortcutItem(
        id: 'whatsapp',
        name: 'WhatsApp',
        packageOrQuery: 'com.whatsapp',
        iconKey: 'chat',
      ),
      const AppShortcutItem(
        id: 'sheets',
        name: 'Google Sheets',
        packageOrQuery: 'com.google.android.apps.docs.editors.sheets',
        iconKey: 'table_chart',
      ),
      const AppShortcutItem(
        id: 'chrome',
        name: 'Chrome',
        packageOrQuery: 'com.android.chrome',
        iconKey: 'language',
      ),
    ];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _saveShortcuts();
  }

  Future<void> _saveShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = _shortcuts.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyShortcuts, serialized);
  }
}

