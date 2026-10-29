import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'omnipilot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce Quantum Forge authorship & DMCA watermark integrity before booting UI
  OwnershipGuard.enforceOwnershipOrThrow();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Activate Firebase App Check. In debug mode, use the debug provider so
  // local development/testing is never blocked by Play Integrity attestation.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
    );
  } catch (e) {
    debugPrint('App Check initialization note: $e');
  }

  // Auto-initialize demo license document in Firestore if missing
  try {
    await DemoLicenseService().checkAndInitializeLicense();
  } catch (e) {
    debugPrint('Demo license initialization note: $e');
  }

  runApp(const OmniPilotApp());
}

class OmniPilotApp extends StatelessWidget {
  const OmniPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            const FloatingCopyrightWatermark(),
          ],
        );
      },
      home: const AttendanceScreen(),
    );
  }
}
