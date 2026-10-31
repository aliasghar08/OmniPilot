#!/usr/bin/env bash
set -e

DEVICE="emulator-5554"
REMOTE_MP4="/sdcard/omnipilot_full_demo.mp4"
LOCAL_MP4="./omnipilot_full_demo.mp4"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Emulator Recordings"

echo "=== 1. Checking Emulator Connection ==="
adb -s "$DEVICE" get-state >/dev/null 2>&1 || { echo "Emulator $DEVICE not found!"; exit 1; }
echo "Emulator $DEVICE is online."

# Ensure permissions and services are active
adb -s "$DEVICE" shell appops set com.dartnexuslab.omnipilot SYSTEM_ALERT_WINDOW allow
adb -s "$DEVICE" shell settings put secure enabled_accessibility_services com.dartnexuslab.omnipilot/.AttendanceAccessibilityService
adb -s "$DEVICE" shell settings put secure accessibility_enabled 1

# Clean any existing recording
adb -s "$DEVICE" shell rm -f "$REMOTE_MP4"

echo "=== 2. Starting Background Screen Recording ==="
adb -s "$DEVICE" shell "screenrecord --time-limit 70 --bit-rate 6000000 $REMOTE_MP4" &
REC_PID=$!
sleep 2

echo "=== 3. Driving OmniPilot UI Demonstration ==="
# Launch OmniPilot
adb -s "$DEVICE" shell monkey -p com.dartnexuslab.omnipilot -c android.intent.category.LAUNCHER 1
sleep 2.5

# Switch to Cross-App AI tab (x=200, y=250)
adb -s "$DEVICE" shell input tap 200 250
sleep 2.5

# Scroll down smoothly to show In-App Customization Card and Target Apps
adb -s "$DEVICE" shell input swipe 600 2000 600 800 450
sleep 3

# Scroll a bit more to show the full customization controls & 2-row identity watermark
adb -s "$DEVICE" shell input swipe 600 1800 600 1000 400
sleep 3

# Launch Google Contacts
echo "=== 4. Demonstrating Control in Google Contacts ==="
adb -s "$DEVICE" shell am start -n com.google.android.contacts/com.android.contacts.activities.PeopleActivity
sleep 2.5

# Tap + to create contact (or open create contact)
adb -s "$DEVICE" shell input tap 1250 2600
sleep 2.5

# Tap floating bubble at top-left to expand HUD overlay (x=140, y=670)
adb -s "$DEVICE" shell input tap 140 670
sleep 2.5

# Type command into the overlay input field
adb -s "$DEVICE" shell input tap 400 750
sleep 1
adb -s "$DEVICE" shell input text "Fill%sMuhammad%sAli%sfor%sBISP%sEducation"
sleep 1
# Tap Run AI button (x=1230, y=750)
adb -s "$DEVICE" shell input tap 1230 750
sleep 5

# Close overlay panel (x=1260, y=440) to reveal verified filled fields
adb -s "$DEVICE" shell input tap 1260 440
sleep 3

echo "=== 5. Demonstrating Control in Google Chrome ==="
# Open Chrome to a live web page
adb -s "$DEVICE" shell am start -a android.intent.action.VIEW -d "https://www.google.com" com.android.chrome
sleep 3

# Tap floating bubble over Chrome (x=140, y=670)
adb -s "$DEVICE" shell input tap 140 670
sleep 3

# Close overlay panel (x=1260, y=440)
adb -s "$DEVICE" shell input tap 1260 440
sleep 2

echo "=== 6. Returning to OmniPilot ==="
adb -s "$DEVICE" shell monkey -p com.dartnexuslab.omnipilot -c android.intent.category.LAUNCHER 1
sleep 2

# Tap Period Form tab (x=720, y=250)
adb -s "$DEVICE" shell input tap 720 250
sleep 3

echo "=== 7. Finalizing Screen Recording ==="
adb -s "$DEVICE" shell pkill -INT screenrecord || true
sleep 3

echo "=== 8. Pulling Video to Mac and iCloud ==="
adb -s "$DEVICE" pull "$REMOTE_MP4" "$LOCAL_MP4"

mkdir -p "$ICLOUD_DIR"
cp -v "$LOCAL_MP4" "$ICLOUD_DIR/omnipilot_full_demo.mp4"

echo "=== Video Demo Ready! Opening... ==="
open "$LOCAL_MP4" || true

