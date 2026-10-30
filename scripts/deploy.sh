#!/bin/bash
set -e

# Resolve ADB path if not in current PATH
if ! command -v adb &> /dev/null; then
    if [ -f "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
        export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
    fi
fi

PACKAGE_NAME="com.dartnexuslab.omnipilot"
SERVICE_NAME="com.dartnexuslab.omnipilot.AttendanceAccessibilityService"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

echo "=== 1. Checking ADB Device Connection ==="
DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device$" | wc -l | tr -d ' ')

if [ "$DEVICE_COUNT" -eq "0" ]; then
    echo "Error: No Android device detected via USB. Enable USB Debugging in Developer Options and reconnect."
    exit 1
fi

echo "Connected device found ($DEVICE_COUNT device(s))."

echo "=== 2. Building Release APK ==="
flutter build apk --release

echo "=== 3. Installing APK via ADB (Bypassing Play Protect) ==="
# -r: Replace existing app
# -d: Allow version code downgrade
# -g: Grant all runtime permissions automatically
adb install -r -d -g "$APK_PATH"

echo "=== 4. Auto-Bypassing Restricted Settings via ADB Shell ==="
# Unrestrict settings for Android 13+ (API 33+) sideloaded apps
adb shell appops set "$PACKAGE_NAME" ACCESS_RESTRICTED_SETTINGS allow 2>/dev/null || true

# Enable Accessibility Service without manual settings navigation
adb shell settings put secure enabled_accessibility_services "$PACKAGE_NAME/$SERVICE_NAME"
adb shell settings put secure accessibility_enabled 1

# Grant System Overlay (Display Over Other Apps) permission directly
adb shell appops set "$PACKAGE_NAME" SYSTEM_ALERT_WINDOW allow

echo "=== 5. Launching OmniPilot ==="
adb shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1

echo "Deployment complete. OmniPilot is installed and all system permissions are activated."
