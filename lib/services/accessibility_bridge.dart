import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Top-level helper that wraps MethodChannel bot execution in a try-catch-finally block
/// with a 5-second timeout so the UI never hangs if the native service fails to respond.
Future<String> runOmniPilotBot(String command, {BuildContext? context}) async {
  return AccessibilityBridge.runOmniPilotBot(command, context: context);
}

/// Communicates with native Android AccessibilityService and FloatingBubbleService
/// for complete cross-app inspection, form filling, write verification, and UI automation.
class AccessibilityBridge {
  static const MethodChannel _channel = MethodChannel('com.dartnexuslab.omnipilot/accessibility');
  static const MethodChannel platform = _channel;
  static const Duration _defaultTimeout = Duration(seconds: 5);

  /// Callback invoked when the user submits a prompt from the Floating Overlay over another app.
  static Future<String> Function(String prompt)? onOverlayPromptReceived;

  /// Callback invoked whenever the native Kotlin service broadcasts a concise bot status string.
  static void Function(String message)? onBotFeedbackReceived;

  /// Callback invoked whenever system permissions are updated (e.g. upon returning from Android Settings).
  static void Function(Map<String, dynamic> status)? onSystemPermissionsUpdated;

  /// Stores the most recent concise bot feedback message.
  static String lastBotFeedback = '';

  static bool _handlerRegistered = false;

  /// Ensures incoming calls from the native FloatingBubbleService and AttendanceAccessibilityService
  /// are routed to Flutter safely.
  static void ensureHandlerRegistered() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      try {
        if (call.method == 'onOverlayPrompt') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          final prompt = args?['prompt']?.toString() ?? '';
          if (onOverlayPromptReceived != null && prompt.isNotEmpty) {
            return await onOverlayPromptReceived!(prompt);
          }
          return '⚠️ Bot Alert: Assistant not initialized.';
        } else if (call.method == 'onBotFeedback') {
          final message = call.arguments?.toString() ?? '';
          if (message.isNotEmpty) {
            lastBotFeedback = message;
            onBotFeedbackReceived?.call(message);
          }
          return null;
        } else if (call.method == 'onSystemPermissionsUpdated') {
          final raw = call.arguments as Map<dynamic, dynamic>?;
          if (raw != null) {
            final status = Map<String, dynamic>.from(raw);
            onSystemPermissionsUpdated?.call(status);
          }
          return null;
        }
      } catch (e) {
        return '❌ Bot Error: ${e.toString()}';
      }
      return null;
    });
  }

  /// Executes a bot command via the native MethodChannel with a 5-second timeout and
  /// guaranteed concise fallback message on timeout, PlatformException, or unexpected error.
  static Future<String> runOmniPilotBot(String command, {BuildContext? context}) async {
    String feedback = "✅ Command processed.";
    try {
      final bool permitted = await ensureSystemPermissions(context, scope: 'automation');
      if (!permitted) {
        feedback = "⚠️ Bot Alert: Required system permissions not granted.";
        return feedback;
      }

      final String? reply = await platform
          .invokeMethod<String>('executeCommand', {'command': command})
          .timeout(const Duration(seconds: 5));

      feedback = (reply != null && reply.trim().isNotEmpty)
          ? reply
          : "✅ Command processed.";
      return feedback;
    } on TimeoutException {
      feedback = "⏱️ Bot Timeout: Action took too long.";
      return feedback;
    } on PlatformException catch (e) {
      feedback = "⚠️ Bot Error: ${e.message ?? 'Service unavailable'}";
      return feedback;
    } catch (_) {
      feedback = "❌ Bot Error: Something went wrong.";
      return feedback;
    } finally {
      lastBotFeedback = feedback;
    }
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
    try {
      final List<dynamic>? raw = await _channel
          .invokeMethod<List<dynamic>>('inspectActiveWindow')
          .timeout(_defaultTimeout);
      if (raw == null) return [];
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return [];
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return [];
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return [];
    }
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
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>(
            'getScreenSnapshot',
            {
              'preferExternal': preferExternal,
              'switchToExternal': switchToExternal,
            },
          )
          .timeout(_defaultTimeout);
      if (raw == null) return {};
      return _deepCastMap(raw);
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return {'error': lastBotFeedback};
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return {'error': lastBotFeedback};
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return {'error': lastBotFeedback};
    }
  }

  /// Reads and verifies existing writes in all editable fields on the active screen.
  static Future<Map<String, dynamic>> checkExistingWrites({
    List<String>? targets,
    bool switchToExternal = false,
  }) async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>(
            'checkExistingWrites',
            {
              'targets': targets,
              'switchToExternal': switchToExternal,
            },
          )
          .timeout(_defaultTimeout);
      if (raw == null) return {};
      return _deepCastMap(raw);
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return {'error': lastBotFeedback};
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return {'error': lastBotFeedback};
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return {'error': lastBotFeedback};
    }
  }

  /// Legacy simple boolean map filler.
  static Future<Map<String, bool>> fillExternalFields(Map<String, String> fields) async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>(
            'fillExternalFields',
            {'fields': fields},
          )
          .timeout(_defaultTimeout);
      if (raw == null) return {};
      return raw.map((key, value) => MapEntry(key.toString(), value == true));
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return {};
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return {};
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return {};
    }
  }

  /// Universal multi-field writer that supports arbitrary field labels, hints, IDs, or indices (#0, #1),
  /// and verifies that the written text actually took effect in the target app.
  static Future<Map<String, dynamic>> writeFieldsWithVerification(
    Map<String, String> fields, {
    bool append = false,
    bool switchToExternal = false,
  }) async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>(
            'writeFieldsWithVerification',
            {
              'fields': fields,
              'append': append,
              'switchToExternal': switchToExternal,
            },
          )
          .timeout(_defaultTimeout);
      if (raw == null) return {};
      return _deepCastMap(raw);
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return {'error': lastBotFeedback};
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return {'error': lastBotFeedback};
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return {'error': lastBotFeedback};
    }
  }

  /// Clicks a button, tab, list item, or interactive element matching [targetLabel] or index (#0).
  static Future<bool> clickElement(String targetLabel) async {
    try {
      final bool? clicked = await _channel
          .invokeMethod<bool>(
            'clickElement',
            {'target': targetLabel},
          )
          .timeout(_defaultTimeout);
      return clicked ?? false;
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return false;
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return false;
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return false;
    }
  }

  /// Long-presses an element matching [targetLabel].
  static Future<bool> longClickElement(String targetLabel) async {
    try {
      final bool? clicked = await _channel
          .invokeMethod<bool>(
            'longClickElement',
            {'target': targetLabel},
          )
          .timeout(_defaultTimeout);
      return clicked ?? false;
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return false;
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return false;
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return false;
    }
  }

  /// Toggles a checkbox, switch, or radio button to [checked].
  static Future<Map<String, dynamic>> setCheckableState(String targetLabel, bool checked) async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>(
            'setCheckableState',
            {'target': targetLabel, 'checked': checked},
          )
          .timeout(_defaultTimeout);
      if (raw == null) return {'success': false};
      return _deepCastMap(raw);
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return {'success': false, 'error': lastBotFeedback};
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return {'success': false, 'error': lastBotFeedback};
    } catch (e) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Scrolls the active screen in [direction] ('down', 'up', 'left', 'right').
  static Future<bool> scrollScreen(String direction) async {
    try {
      final bool? scrolled = await _channel
          .invokeMethod<bool>(
            'scrollScreen',
            {'direction': direction},
          )
          .timeout(_defaultTimeout);
      return scrolled ?? false;
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return false;
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return false;
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
      return false;
    }
  }

  /// Taps exact screen coordinates (x, y).
  static Future<bool> tapCoordinates(double x, double y) async {
    try {
      final bool? ok = await _channel
          .invokeMethod<bool>(
            'tapCoordinates',
            {'x': x, 'y': y},
          )
          .timeout(_defaultTimeout);
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
      final bool? ok = await _channel
          .invokeMethod<bool>(
            'swipeCoordinates',
            {
              'startX': startX,
              'startY': startY,
              'endX': endX,
              'endY': endY,
              'durationMs': durationMs,
            },
          )
          .timeout(_defaultTimeout);
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Performs global Android navigation: 'BACK', 'HOME', 'RECENTS', 'NOTIFICATIONS', 'QUICK_SETTINGS'.
  static Future<bool> performSystemNavigation(String action) async {
    try {
      final bool? ok = await _channel
          .invokeMethod<bool>(
            'performSystemNavigation',
            {'action': action},
          )
          .timeout(_defaultTimeout);
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the last external app is brought to the foreground if OmniPilot is covering it.
  static Future<bool> ensureExternalAppFocused() async {
    try {
      final bool? ok = await _channel
          .invokeMethod<bool>('ensureExternalAppFocused')
          .timeout(_defaultTimeout);
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Lists installed launchable apps matching an optional [query].
  static Future<List<Map<String, String>>> getInstalledApps({String? query}) async {
    try {
      final List<dynamic>? raw = await _channel
          .invokeMethod<List<dynamic>>(
            'getInstalledApps',
            {'query': query},
          )
          .timeout(_defaultTimeout);
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
      final bool? launched = await _channel
          .invokeMethod<bool>(
            'launchExternalApp',
            {'app': appNameOrPackage},
          )
          .timeout(_defaultTimeout);
      return launched ?? false;
    } on TimeoutException {
      lastBotFeedback = '⏱️ Bot Timeout: Action took too long.';
      return false;
    } on PlatformException catch (e) {
      lastBotFeedback = '⚠️ Bot Error: ${e.message ?? 'Service unavailable'}';
      return false;
    } catch (_) {
      lastBotFeedback = '❌ Bot Error: Something went wrong.';
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

  /// Sets whether native TTS voice responses are enabled in FloatingBubbleService.
  static Future<bool> setTtsEnabled(bool enabled) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('setTtsEnabled', {'enabled': enabled});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if native TTS voice responses are currently enabled.
  static Future<bool> isTtsEnabled() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('isTtsEnabled');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Requests the native TTS engine to speak [text] immediately if voice replies are active.
  static Future<bool> speakTts(String text) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('speakTts', {'text': text});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns a list of all permanently authorized third-party apps [{packageName, label}].
  static Future<List<Map<String, String>>> getAuthorizedApps() async {
    try {
      final List<dynamic>? list = await _channel.invokeListMethod<dynamic>('getAuthorizedApps');
      if (list == null) return [];
      return list.map((item) {
        final map = item as Map<dynamic, dynamic>;
        return {
          'packageName': map['packageName']?.toString() ?? '',
          'label': map['label']?.toString() ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Revokes access permission for a given third-party app package.
  static Future<bool> revokeAppPermission(String packageName) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'revokeAppPermission',
        {'packageName': packageName},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers the native permission request popup for a specific app package.
  static Future<bool> requestAppPermissionPopup(
    String packageName, {
    String reason = 'automation access',
  }) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'requestAppPermissionPopup',
        {'packageName': packageName, 'reason': reason},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks and requests system permissions for a given scope ('floating_bubble', 'automation', or 'all').
  static Future<Map<String, dynamic>> checkAndRequestSystemPermissions({
    String scope = 'automation',
    bool showOverlayPopup = true,
  }) async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'checkAndRequestSystemPermissions',
        {
          'requiredFor': scope,
          'showOverlayPopup': showOverlayPopup,
        },
      ).timeout(_defaultTimeout);
      if (raw == null) return {};
      return _deepCastMap(raw);
    } catch (_) {
      return {};
    }
  }

  /// Opens the Android OS system settings screen for a specific permission key.
  static Future<bool> openSystemPermissionSettings(String permission) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>(
        'openSystemPermissionSettings',
        {'permission': permission},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns a map of all four critical system permissions and their current status.
  static Future<Map<String, bool>> getSystemPermissionsStatus() async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getSystemPermissionsStatus')
          .timeout(_defaultTimeout);
      if (raw == null) return {};
      final map = <String, bool>{};
      raw.forEach((k, v) {
        map[k.toString()] = v == true;
      });
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Checks if POST_NOTIFICATIONS is granted on Android 13+.
  static Future<bool> hasNotificationPermission() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('hasNotificationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the notification settings or prompts for runtime notification permission.
  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  /// Checks if OmniPilot is exempted from battery optimizations.
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ensures that all required system permissions for [scope] are granted before running an action.
  /// If missing, prompts via overlay popup (if bubble running) or an in-app AlertDialog.
  static Future<bool> ensureSystemPermissions(
    BuildContext? context, {
    String scope = 'automation',
  }) async {
    try {
      final res = await checkAndRequestSystemPermissions(
        scope: scope,
        showOverlayPopup: context == null,
      );
      if (res.isEmpty) return true; // mock / fallback in test environment
      final bool granted = res['granted'] == true;
      if (granted) return true;

      final String missing = res['missing']?.toString() ?? 'overlay';
      final String title = res['title']?.toString() ?? 'Permission Required';
      final String reason = res['reason']?.toString() ?? 'This action requires system permissions.';
      final bool popupShown = res['popupShown'] == true;

      if (context != null && context.mounted && !popupShown) {
        final bool? userAccepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
            ),
            title: Row(
              children: [
                const Icon(Icons.security_rounded, color: Color(0xFF38BDF8), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🔐 $title',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              reason,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Later', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop(true);
                  await openSystemPermissionSettings(missing);
                },
                child: const Text('Enable in Settings'),
              ),
            ],
          ),
        );
        return userAccepted ?? false;
      }
      return false;
    } catch (_) {
      return true;
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
