#!/usr/bin/env bash
set -e

DEVICE="emulator-5556"
REMOTE_MP4="/sdcard/demo_video.mp4"
LOCAL_MP4="./omnipilot_demo_video.mp4"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Emulator Recordings"

echo "=== 1. Checking Emulator $DEVICE ==="
adb -s "$DEVICE" get-state >/dev/null 2>&1 || { echo "Emulator $DEVICE not found!"; exit 1; }
echo "Emulator $DEVICE is online."

# Ensure permissions and services are active on this emulator
adb -s "$DEVICE" shell appops set com.dartnexuslab.omnipilot SYSTEM_ALERT_WINDOW allow
adb -s "$DEVICE" shell settings put secure enabled_accessibility_services com.dartnexuslab.omnipilot/.AttendanceAccessibilityService
adb -s "$DEVICE" shell settings put secure accessibility_enabled 1

# Clean previous video
adb -s "$DEVICE" shell rm -f "$REMOTE_MP4"

echo "=== 2. Starting High-Quality Screen Recording ==="
adb -s "$DEVICE" shell "screenrecord --time-limit 70 --bit-rate 6000000 $REMOTE_MP4" &
REC_PID=$!
sleep 2

echo "=== 3. Driving OmniPilot UI Demonstration ==="
# Bring OmniPilot to foreground
adb -s "$DEVICE" shell monkey -p com.dartnexuslab.omnipilot -c android.intent.category.LAUNCHER 1
sleep 2.5

# Switch to Cross-App AI tab (x=160, y=200)
adb -s "$DEVICE" shell input tap 160 200
sleep 2.5

# Scroll down smoothly to show In-App Customization Card and Target Apps
adb -s "$DEVICE" shell input swipe 500 1600 500 700 450
sleep 2.5

# Scroll a bit more to show full customization controls & 2-row identity watermark
adb -s "$DEVICE" shell input swipe 500 1400 500 800 400
sleep 2.5

echo "=== 4. Opening Third-Party App (Google Contacts) ==="
# Launch Contacts
adb -s "$DEVICE" shell am start -n com.google.android.contacts/com.android.contacts.activities.PeopleActivity
sleep 2.5

# Tap + to create contact (x=860, y=1900)
adb -s "$DEVICE" shell input tap 860 1900
sleep 2.5

# Tap floating bubble at top-left to expand HUD overlay (x=124, y=410)
echo "=== 5. Expanding OmniPilot AI HUD Overlay ==="
adb -s "$DEVICE" shell input tap 124 410
sleep 2.5

# Type command into the overlay input field (x=400, y=550)
echo "=== 6. Using AI to Write and Fill Forms ==="
adb -s "$DEVICE" shell input tap 400 550
sleep 1
adb -s "$DEVICE" shell input text "Fill%sMuhammad%sAli%sfor%sBISP%sEducation"
sleep 1

# Tap Run AI button (x=850, y=550)
adb -s "$DEVICE" shell input tap 850 550
sleep 5

# Close overlay panel (x=880, y=340) to reveal verified filled fields
echo "=== 7. Revealing Verified Filled Fields in Third-Party App ==="
adb -s "$DEVICE" shell input tap 880 340
sleep 3

echo "=== 8. Returning to OmniPilot ==="
adb -s "$DEVICE" shell monkey -p com.dartnexuslab.omnipilot -c android.intent.category.LAUNCHER 1
sleep 2

# Tap Period Form tab (x=540, y=200)
adb -s "$DEVICE" shell input tap 540 200
sleep 2.5

echo "=== 9. Finalizing Screen Recording ==="
adb -s "$DEVICE" shell pkill -INT screenrecord || true
sleep 3

echo "=== 10. Pulling Video to Mac and iCloud ==="
adb -s "$DEVICE" pull "$REMOTE_MP4" "$LOCAL_MP4"

mkdir -p "$ICLOUD_DIR"
cp -v "$LOCAL_MP4" "$ICLOUD_DIR/omnipilot_demo_video.mp4"

echo "=== Video Demo Ready! Opening... ==="
open "$LOCAL_MP4" || true

