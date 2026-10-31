import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_copilot/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppSettingsService initializes defaults and updates settings', () async {
    final settings = AppSettingsService.instance;
    await settings.init();

    expect(settings.inputDelayMs, 150);
    expect(settings.autoSwitchToExternal, isTrue);
    expect(settings.verifyWrites, isTrue);
    expect(settings.typingStrategy, 'smart_auto');
    expect(settings.shortcuts.length, greaterThanOrEqualTo(5));

    await settings.setInputDelayMs(300);
    expect(settings.inputDelayMs, 300);

    await settings.addShortcut('School ERP', 'com.school.erp');
    expect(settings.shortcuts.any((s) => s.name == 'School ERP'), isTrue);

    final item = settings.shortcuts.firstWhere((s) => s.name == 'School ERP');
    await settings.removeShortcut(item.id);
    expect(settings.shortcuts.any((s) => s.name == 'School ERP'), isFalse);
  });
}

