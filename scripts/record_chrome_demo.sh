#!/usr/bin/env bash
set -e

DEVICE="emulator-5556"
REMOTE_MP4="/sdcard/chrome_demo_video.mp4"
LOCAL_MP4="./omnipilot_chrome_demo.mp4"
ICLOUD_RECORDINGS="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Emulator Recordings"
ICLOUD_SCREENSHOTS="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Emulator Screenshots"
ARTIFACTS_DIR="/Users/aliasghar08/.gemini/antigravity/brain/a40bcdf1-2491-45e2-8251-feefee2256c3"

echo "=== 1. Checking Emulator $DEVICE ==="
adb -s "$DEVICE" get-state >/dev/null 2>&1 || { echo "Emulator $DEVICE not found!"; exit 1; }
echo "Emulator $DEVICE is online."

# Ensure permissions and services are active on this emulator
adb -s "$DEVICE" shell appops set com.dartnexuslab.omnipilot SYSTEM_ALERT_WINDOW allow
adb -s "$DEVICE" shell settings put secure --user 0 enabled_accessibility_services com.dartnexuslab.omnipilot/com.dartnexuslab.omnipilot.AttendanceAccessibilityService
adb -s "$DEVICE" shell settings put secure --user 0 accessibility_enabled 1
adb -s "$DEVICE" shell settings put secure --user 0 accessibility_shortcut_target_service com.dartnexuslab.omnipilot/com.dartnexuslab.omnipilot.AttendanceAccessibilityService
adb -s "$DEVICE" shell settings put secure --user 0 accessibility_button_targets com.dartnexuslab.omnipilot/com.dartnexuslab.omnipilot.AttendanceAccessibilityService

# Clean previous video
adb -s "$DEVICE" shell rm -f "$REMOTE_MP4"

echo "=== 2. Starting High-Quality Screen Recording (No Audio) ==="
adb -s "$DEVICE" shell "screenrecord --time-limit 80 --bit-rate 6000000 $REMOTE_MP4" &
REC_PID=$!
sleep 2

echo "=== 3. Driving OmniPilot App & Developer Info Tab ==="
# Launch OmniPilot
adb -s "$DEVICE" shell am force-stop com.dartnexuslab.omnipilot
sleep 0.5
adb -s "$DEVICE" shell am start -n com.dartnexuslab.omnipilot/.MainActivity
sleep 3

# Screenshot: OmniPilot Main
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step1_omnipilot_main.png"

# Swipe to Developer Info Tab (Tab 4)
adb -s "$DEVICE" shell input swipe 900 1000 100 1000 200
sleep 0.8
adb -s "$DEVICE" shell input swipe 900 1000 100 1000 200
sleep 0.8
adb -s "$DEVICE" shell input swipe 900 1000 100 1000 200
sleep 2.5

# Screenshot: Developer Info Tab
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step2_developer_info.png"

# Return to Cross-App AI tab (Tab 1)
adb -s "$DEVICE" shell input swipe 100 1000 900 1000 200
sleep 0.8
adb -s "$DEVICE" shell input swipe 100 1000 900 1000 200
sleep 0.8
adb -s "$DEVICE" shell input swipe 100 1000 900 1000 200
sleep 2

# Scroll down to show In-App Customization Card and Target Apps
adb -s "$DEVICE" shell input swipe 500 1600 500 800 350
sleep 2

echo "=== 4. Launching Chrome with Google Form ==="
# Launch Chrome with the BISP Google Form
adb -s "$DEVICE" shell am start -n com.android.chrome/com.google.android.apps.chrome.Main -d "http://localhost:8080/google_form.html"
sleep 3.5

# Screenshot: Chrome Google Form
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step3_chrome_form_ready.png"

echo "=== 5. Expanding OmniPilot AI Overlay over Chrome ==="
# Tap floating bubble at top-left to expand HUD overlay (x=120, y=410)
adb -s "$DEVICE" shell input tap 120 410
sleep 3

# Screenshot: AI HUD Overlay over Chrome
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step4_overlay_expanded.png"

echo "=== 6. Using AI to Write and Fill Form Fields ==="
# Tap "Quick Fill Form" chip in overlay
# On 1080x2280 Pixel 4, the Quick Fill chip is located at approx x=620, y=360
adb -s "$DEVICE" shell input tap 620 360
sleep 4.5

# Screenshot: Autofill Verification in HUD
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step5_autofill_verified.png"

# Close overlay panel (x=980, y=280) to reveal verified filled fields in Chrome
echo "=== 7. Revealing Verified Filled Fields in Chrome ==="
adb -s "$DEVICE" shell input tap 980 280
sleep 2.5

# Hide any soft keyboard that may be up
adb -s "$DEVICE" shell input keyevent 111
sleep 1

# Scroll down inside Chrome to show all filled fields and the Submit button
adb -s "$DEVICE" shell input swipe 500 1600 500 600 400
sleep 2.5

# Screenshot: Filled Google Form in Chrome
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step6_chrome_form_filled.png"

# Tap "Submit Form" button (approx x=200, y=1420 after scroll)
echo "=== 8. Submitting Google Form ==="
adb -s "$DEVICE" shell input tap 220 1420 || adb -s "$DEVICE" shell input tap 220 1500
sleep 2.5

# Screenshot: Form Submitted confirmation
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step7_form_submitted.png"

echo "=== 9. Searching Google in Chrome ==="
# Tap address bar in Chrome (x=500, y=150)
adb -s "$DEVICE" shell input tap 500 150
sleep 1
adb -s "$DEVICE" shell input text "https://www.google.com/search?q=OmniPilot%sAI%sAttendance"
sleep 1
adb -s "$DEVICE" shell input keyevent 66 # KEYCODE_ENTER
sleep 4

# Screenshot: Google Search in Chrome
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step8_google_search.png"

echo "=== 10. Returning to OmniPilot Period Attendance Form ==="
adb -s "$DEVICE" shell am start -n com.dartnexuslab.omnipilot/.MainActivity
sleep 2
# Tap Period Form tab (x=330, y=250)
adb -s "$DEVICE" shell input tap 330 250
sleep 2.5

echo "=== 11. Finalizing Screen Recording ==="
adb -s "$DEVICE" shell pkill -INT screenrecord || true
sleep 3

echo "=== 12. Pulling Video to Mac and iCloud ==="
adb -s "$DEVICE" pull "$REMOTE_MP4" "$LOCAL_MP4"

mkdir -p "$ICLOUD_RECORDINGS"
mkdir -p "$ICLOUD_SCREENSHOTS"

cp -v "$LOCAL_MP4" "$ICLOUD_RECORDINGS/omnipilot_chrome_demo.mp4"
cp -v "$LOCAL_MP4" "$ICLOUD_SCREENSHOTS/omnipilot_chrome_demo.mp4"
cp -v "$ARTIFACTS_DIR"/demo_step*.png "$ICLOUD_SCREENSHOTS/"

echo "=== Demo Video and Screenshots Ready! ==="
ls -lh "$LOCAL_MP4"
