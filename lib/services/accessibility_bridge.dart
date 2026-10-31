import 'package:flutter/services.dart';

/// Communicates with native Android AccessibilityService and FloatingBubbleService
/// for complete cross-app inspection, form filling, write verification, and UI automation.
class AccessibilityBridge {
  static const MethodChannel _channel = MethodChannel('com.dartnexuslab.omnipilot/accessibility');

  /// Callback invoked when the user submits a prompt from the Floating Overlay over another app.
  static Future<String> Function(String prompt)? onOverlayPromptReceived;

  static bool _handlerRegistered = false;

  /// Ensures incoming calls from the native FloatingBubbleService are routed to Flutter.
  static void ensureHandlerRegistered() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onOverlayPrompt') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final prompt = args?['prompt']?.toString() ?? '';
        if (onOverlayPromptReceived != null && prompt.isNotEmpty) {
          return await onOverlayPromptReceived!(prompt);
        }
        return 'Assistant not initialized.';
      }
      return null;
    });
  }

  /// Checks if the Accessibility Service is active, running and bound to Android OS.
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns detailed accessibility status: whether service is actively bound and running,
  /// and whether the toggle is switched ON in Android Settings.
  static Future<Map<String, bool>> getAccessibilityStatus() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getAccessibilityStatus');
      return {
        'isBound': (res?['isBound'] as bool?) ?? false,
        'isSettingEnabled': (res?['isSettingEnabled'] as bool?) ?? false,
      };
    } catch (_) {
      return {'isBound': false, 'isSettingEnabled': false};
    }
  }

  /// Opens the system Accessibility Settings screen so the user can enable the service.
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  /// Checks if "Display over other apps" (SYSTEM_ALERT_WINDOW) is granted.
  static Future<bool> canDrawOverlays() async {
    try {
      final bool? allowed = await _channel.invokeMethod<bool>('canDrawOverlays');
      return allowed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the System Alert Window settings screen for this app.
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// Opens the App Info details settings in Android (where restricted settings & OEM popups are managed).
  static Future<void> openAppInfoSettings() async {
    try {
      await _channel.invokeMethod('openAppInfoSettings');
    } catch (_) {}
  }

  /// Opens the battery optimization settings so the user can exempt OmniPilot from background killers (e.g. XOS Power Marathon).
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Opens proprietary OEM Auto-Start / Background App Management screen on Xiaomi, Oppo, Vivo, Huawei, Transsion, or Samsung.
  static Future<bool> openAutoStartSettings() async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>('openAutoStartSettings');
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Traverses the active external window and returns metadata for all editable fields.
  static Future<List<Map<String, dynamic>>> inspectActiveWindow() async {
    final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>('inspectActiveWindow');
    if (raw == null) return [];
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Captures a comprehensive snapshot of the active screen including:
  /// - activePackage, windowTitle, lastExternalPackage
  /// - editableFields (index, label, hint, text/actualValue, isPopulated, bounds)
  /// - clickableElements (buttons, checkboxes, switches, tabs)
  /// - screenTexts (all visible static text on screen)
  static Future<Map<String, dynamic>> getScreenSnapshot({
    bool preferExternal = true,
    bool switchToExternal = false,
  }) async {
    final Map<dynamic, dynamic>? raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getScreenSnapshot',
      {
        'preferExternal': preferExternal,
        'switchToExternal': switchToExternal,
      },
    );
    if (raw == null) return {};
    return _deepCastMap(raw);
  }

  /// Reads and verifies existing writes in all editable fields on the active screen.
  static Future<Map<String, dynamic>> checkExistingWrites({
    List<String>? targets,
    bool switchToExternal = false,
  }) async {
    final Map<dynamic, dynamic>? raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'checkExistingWrites',
      {
        'targets': targets,
        'switchToExternal': switchToExternal,
      },
    );
    if (raw == null) return {};
    return _deepCastMap(raw);
  }

  /// Legacy simple boolean map filler.
  static Future<Map<String, bool>> fillExternalFields(Map<String, String> fields) async {
    final Map<dynamic, dynamic>? raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'fillExternalFields',
      {'fields': fields},
    );
    if (raw == null) return {};
    return raw.map((key, value) => MapEntry(key.toString(), value == true));
  }

  /// Universal multi-field writer that supports arbitrary field labels, hints, IDs, or indices (#0, #1),
  /// and verifies that the written text actually took effect in the target app.
  static Future<Map<String, dynamic>> writeFieldsWithVerification(
    Map<String, String> fields, {
    bool append = false,
    bool switchToExternal = false,
  }) async {
    final Map<dynamic, dynamic>? raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'writeFieldsWithVerification',
      {
        'fields': fields,
        'append': append,
        'switchToExternal': switchToExternal,
      },
    );
    if (raw == null) return {};
    return _deepCastMap(raw);
  }

  /// Clicks a button, tab, list item, or interactive element matching [targetLabel] or index (#0).
  static Future<bool> clickElement(String targetLabel) async {
    try {
      final bool? clicked = await _channel.invokeMethod<bool>(
        'clickElement',
        {'target': targetLabel},
      );
      return clicked ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Long-presses an element matching [targetLabel].
  static Future<bool> longClickElement(String targetLabel) async {
    try {
      final bool? clicked = await _channel.invokeMethod<bool>(
        'longClickElement',
        {'target': targetLabel},
      );
      return clicked ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Toggles a checkbox, switch, or radio button to [checked].
  static Future<Map<String, dynamic>> setCheckableState(String targetLabel, bool checked) async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setCheckableState',
        {'target': targetLabel, 'checked': checked},
      );
      if (raw == null) return {'success': false};
      return _deepCastMap(raw);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Scrolls the active screen in [direction] ('down', 'up', 'left', 'right').
  static Future<bool> scrollScreen(String direction) async {
    try {
      final bool? scrolled = await _channel.invokeMethod<bool>(
        'scrollScreen',
        {'direction': direction},
      );
      return scrolled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Taps exact screen coordinates (x, y).
  static Future<bool> tapCoordinates(double x, double y) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'tapCoordinates',
        {'x': x, 'y': y},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Swipes from (startX, startY) to (endX, endY).
  static Future<bool> swipeCoordinates({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    int durationMs = 350,
  }) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'swipeCoordinates',
        {
          'startX': startX,
          'startY': startY,
          'endX': endX,
          'endY': endY,
          'durationMs': durationMs,
        },
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Performs global Android navigation: 'BACK', 'HOME', 'RECENTS', 'NOTIFICATIONS', 'QUICK_SETTINGS'.
  static Future<bool> performSystemNavigation(String action) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'performSystemNavigation',
        {'action': action},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the last external app is brought to the foreground if OmniPilot is covering it.
  static Future<bool> ensureExternalAppFocused() async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>('ensureExternalAppFocused');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Lists installed launchable apps matching an optional [query].
  static Future<List<Map<String, String>>> getInstalledApps({String? query}) async {
    try {
      final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
        {'query': query},
      );
      if (raw == null) return [];
      return raw.map((item) {
        final m = Map<dynamic, dynamic>.from(item as Map);
        return m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Launches an external Android app by app name (e.g. "Contacts") or package name.
  static Future<bool> launchExternalApp(String appNameOrPackage) async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>(
        'launchExternalApp',
        {'app': appNameOrPackage},
      );
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launches the floating assistant overlay bubble.
  static Future<bool> startFloatingBubble() async {
    try {
      final bool? started = await _channel.invokeMethod<bool>('startFloatingBubble');
      return started ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Dismisses the floating assistant overlay bubble.
  static Future<bool> stopFloatingBubble() async {
    try {
      final bool? stopped = await _channel.invokeMethod<bool>('stopFloatingBubble');
      return stopped ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the floating bubble is currently visible.
  static Future<bool> isFloatingBubbleRunning() async {
    try {
      final bool? running = await _channel.invokeMethod<bool>('isFloatingBubbleRunning');
      return running ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens a live Google Search query in the Android browser (Chrome).
  static Future<bool> openGoogleSearchInBrowser(String query) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'openGoogleSearchInBrowser',
        {'query': query},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _deepCastMap(Map<dynamic, dynamic> source) {
    final result = <String, dynamic>{};
    source.forEach((key, value) {
      result[key.toString()] = _deepCastValue(value);
    });
    return result;
  }

  static dynamic _deepCastValue(dynamic value) {
    if (value is Map) {
      return _deepCastMap(value);
    } else if (value is List) {
      return value.map(_deepCastValue).toList();
    }
    return value;
  }
}
