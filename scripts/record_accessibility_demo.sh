#!/bin/bash
set -e

DEVICE="emulator-5554"
PACKAGE="com.dartnexuslab.omnipilot"
SERVICE="com.dartnexuslab.omnipilot.AttendanceAccessibilityService"
REMOTE_VIDEO="/sdcard/accessibility_demo.mp4"
LOCAL_VIDEO="accessibility_demo.mp4"

export PATH="/opt/homebrew/bin:$HOME/Library/Android/sdk/platform-tools:$PATH"

echo "=== 1. Verifying $DEVICE ==="
if ! adb -s "$DEVICE" get-state &>/dev/null; then
    echo "❌ Error: $DEVICE not detected or offline."
    exit 1
fi

echo "Cleaning previous remote video..."
adb -s "$DEVICE" shell rm -f "$REMOTE_VIDEO"

echo "=== 2. Starting Screen Recording on $DEVICE (max 45s) ==="
adb -s "$DEVICE" shell screenrecord --time-limit 45 --bit-rate 6000000 "$REMOTE_VIDEO" &
RECORD_PID=$!
sleep 2

echo "=== 3. Running Automated Demonstration Flow ==="

# Step A: Launch OmniPilot
echo "Launching OmniPilot..."
adb -s "$DEVICE" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1
sleep 3

# Step B: Show Cross-App AI Permission Card
echo "Navigating to Cross-App AI tab..."
adb -s "$DEVICE" shell input tap 240 380
sleep 2

# Step C: Open Android Accessibility Settings to demonstrate user consent
echo "Opening Android Accessibility Settings..."
adb -s "$DEVICE" shell am start -a android.settings.ACCESSIBILITY_SETTINGS
sleep 3

# Step D: Enable OmniPilot Accessibility Service
echo "Enabling OmniPilot Accessibility Service..."
adb -s "$DEVICE" shell settings put secure enabled_accessibility_services "$PACKAGE/$SERVICE"
adb -s "$DEVICE" shell settings put secure accessibility_enabled 1
sleep 2

# Step E: Return to OmniPilot
echo "Returning to OmniPilot..."
adb -s "$DEVICE" shell input keyevent 4
sleep 2

# Step F: Ensure overlay permission is active
adb -s "$DEVICE" shell appops set "$PACKAGE" SYSTEM_ALERT_WINDOW allow
sleep 1

# Step G: Demonstrate Period Attendance & Compliance Form tab
echo "Demonstrating Period Attendance Form..."
adb -s "$DEVICE" shell input tap 720 380
sleep 2
# Scroll down to showcase inputs, radios, and checkboxes
adb -s "$DEVICE" shell input swipe 720 1800 720 600 400
sleep 2
adb -s "$DEVICE" shell input swipe 720 1800 720 600 400
sleep 2
adb -s "$DEVICE" shell input swipe 720 600 720 1800 300
sleep 1

# Step H: Demonstrate AI Assistant Chat Console
echo "Demonstrating AI Assistant Chat Console..."
adb -s "$DEVICE" shell input tap 1200 380
sleep 3

# Concluding pause
sleep 3

echo "=== 4. Stopping Screen Recording ==="
adb -s "$DEVICE" shell pkill -INT screenrecord || true
sleep 3

echo "=== 5. Pulling Video to Host Mac ==="
adb -s "$DEVICE" pull "$REMOTE_VIDEO" "$LOCAL_VIDEO"
adb -s "$DEVICE" shell rm -f "$REMOTE_VIDEO"

echo "=== 6. Video Ready! ==="
ls -lh "$LOCAL_VIDEO"

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Opening $LOCAL_VIDEO in QuickTime/Preview..."
    open "$LOCAL_VIDEO" || true
fi

echo "✅ Demonstration recorded successfully: $LOCAL_VIDEO"

