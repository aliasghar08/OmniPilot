#!/bin/bash
set -e

# Resolve paths
export PATH="/opt/homebrew/bin:$HOME/Library/Android/sdk/platform-tools:$PATH"

PACKAGE_NAME="com.dartnexuslab.omnipilot"
SERVICE_NAME="com.dartnexuslab.omnipilot.AttendanceAccessibilityService"
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
APKS_DIR="build/app/outputs/bundle/release"
APKS_PATH="$APKS_DIR/app-release.apks"

# Target device: Infinix if connected, otherwise default
DEVICE_ID="115413745K001841"
CONNECTED=$(adb devices | grep "$DEVICE_ID" | grep "device$" || true)

if [ -z "$CONNECTED" ]; then
    # Fallback to first available physical device or emulator
    DEVICE_ID=$(adb devices | grep -v "List" | grep "device$" | head -1 | awk '{print $1}')
fi

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Error: No authorized Android device detected. Check USB connection and authorize USB Debugging."
    exit 1
fi

DEVICE_MODEL=$(adb -s "$DEVICE_ID" shell getprop ro.product.model 2>/dev/null || echo "$DEVICE_ID")
echo "📱 Target Device: $DEVICE_MODEL ($DEVICE_ID)"

echo "=== 1. Building Android App Bundle (AAB) ==="
flutter build appbundle --release

echo "=== 2. Converting AAB to Device-Optimized APKs using bundletool ==="
mkdir -p "$APKS_DIR"
rm -f "$APKS_PATH"

bundletool build-apks \
  --bundle="$AAB_PATH" \
  --output="$APKS_PATH" \
  --connected-device \
  --device-id="$DEVICE_ID" \
  --mode=default

echo "=== 3. Installing APKs to $DEVICE_MODEL via bundletool ==="
bundletool install-apks \
  --apks="$APKS_PATH" \
  --device-id="$DEVICE_ID" \
  --allow-downgrade

echo "=== 4. Granting Accessibility & Overlay Permissions Automatically ==="
# Allow restricted settings on Android 13+ (XOS / Transsion)
adb -s "$DEVICE_ID" shell appops set "$PACKAGE_NAME" ACCESS_RESTRICTED_SETTINGS allow 2>/dev/null || true

# Enable Accessibility Service without manual settings digging
adb -s "$DEVICE_ID" shell settings put secure enabled_accessibility_services "$PACKAGE_NAME/$SERVICE_NAME"
adb -s "$DEVICE_ID" shell settings put secure accessibility_enabled 1

# Grant System Overlay (Display Over Other Apps)
adb -s "$DEVICE_ID" shell appops set "$PACKAGE_NAME" SYSTEM_ALERT_WINDOW allow

echo "=== 5. Launching OmniPilot on $DEVICE_MODEL ==="
adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1

echo ""
echo "✅ Successfully installed & launched OmniPilot from AAB on $DEVICE_MODEL!"

