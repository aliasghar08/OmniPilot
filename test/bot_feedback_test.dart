import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_copilot/omnipilot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.dartnexuslab.omnipilot/accessibility');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Success test: runOmniPilotBot returns concise Done message on valid target action', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'executeCommand') {
        final cmd = (methodCall.arguments as Map)['command'];
        return '✅ Done: $cmd completed.';
      }
      return null;
    });

    final reply = await runOmniPilotBot('Autofill Form');
    expect(reply, '✅ Done: Autofill Form completed.');
    expect(AccessibilityBridge.lastBotFeedback, '✅ Done: Autofill Form completed.');
  });

  test('Failure test: runOmniPilotBot returns Bot Alert when target fields are not found', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'executeCommand') {
        return '⚠️ Bot Alert: Target fields not found.';
      }
      return null;
    });

    final reply = await runOmniPilotBot('Fill empty home screen');
    expect(reply, '⚠️ Bot Alert: Target fields not found.');
  });

  test('Failure test: runOmniPilotBot catches PlatformException when Accessibility is disabled', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      throw PlatformException(
        code: 'SERVICE_DISABLED',
        message: 'Accessibility service is disabled.',
      );
    });

    final reply = await runOmniPilotBot('Click Save');
    expect(reply, '⚠️ Bot Error: Accessibility service is disabled.');
    expect(AccessibilityBridge.lastBotFeedback, '⚠️ Bot Error: Accessibility service is disabled.');
  });

  test('Native onBotFeedback broadcast updates AccessibilityBridge.onBotFeedbackReceived', () async {
    AccessibilityBridge.ensureHandlerRegistered();
    String? receivedFeedback;
    AccessibilityBridge.onBotFeedbackReceived = (msg) {
      receivedFeedback = msg;
    };

    final ByteData messageBytes = const StandardMethodCodec().encodeMethodCall(
      const MethodCall('onBotFeedback', '✅ Done: Quick Fill completed.'),
    );

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'com.dartnexuslab.omnipilot/accessibility',
      messageBytes,
      (ByteData? _) {},
    );

    expect(receivedFeedback, '✅ Done: Quick Fill completed.');
    expect(AccessibilityBridge.lastBotFeedback, '✅ Done: Quick Fill completed.');
  });

  test('TTS method channel calls: setTtsEnabled, isTtsEnabled, and speakTts', () async {
    final calls = <String, dynamic>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls[methodCall.method] = methodCall.arguments;
      if (methodCall.method == 'setTtsEnabled') {
        return true;
      } else if (methodCall.method == 'isTtsEnabled') {
        return true;
      } else if (methodCall.method == 'speakTts') {
        return true;
      }
      return null;
    });

    final setSuccess = await AccessibilityBridge.setTtsEnabled(false);
    expect(setSuccess, isTrue);
    expect(calls['setTtsEnabled'], {'enabled': false});

    final isEnabled = await AccessibilityBridge.isTtsEnabled();
    expect(isEnabled, isTrue);

    final speakSuccess = await AccessibilityBridge.speakTts('Testing OmniPilot voice output');
    expect(speakSuccess, isTrue);
    expect(calls['speakTts'], {'text': 'Testing OmniPilot voice output'});
  });

  test('Per-app permissions bridge: getAuthorizedApps, revokeAppPermission, requestAppPermissionPopup', () async {
    final calls = <String, dynamic>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls[methodCall.method] = methodCall.arguments;
      if (methodCall.method == 'getAuthorizedApps') {
        return [
          {'packageName': 'com.android.chrome', 'label': 'Chrome'},
          {'packageName': 'com.whatsapp', 'label': 'WhatsApp'},
        ];
      } else if (methodCall.method == 'revokeAppPermission') {
        return true;
      } else if (methodCall.method == 'requestAppPermissionPopup') {
        return true;
      }
      return null;
    });

    final apps = await AccessibilityBridge.getAuthorizedApps();
    expect(apps.length, 2);
    expect(apps[0]['label'], 'Chrome');
    expect(apps[1]['packageName'], 'com.whatsapp');

    final revokeSuccess = await AccessibilityBridge.revokeAppPermission('com.android.chrome');
    expect(revokeSuccess, isTrue);
    expect(calls['revokeAppPermission'], {'packageName': 'com.android.chrome'});

    final requestSuccess = await AccessibilityBridge.requestAppPermissionPopup(
      'org.fossify.notes',
      reason: 'Write attendance notes',
    );
    expect(requestSuccess, isTrue);
    expect(calls['requestAppPermissionPopup'], {
      'packageName': 'org.fossify.notes',
      'reason': 'Write attendance notes',
    });
  });
}
