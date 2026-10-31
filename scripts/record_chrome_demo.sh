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
adb -s "$DEVICE" reverse tcp:8080 tcp:8080
cp -f "$(dirname "$0")/google_form.html" /tmp/google_form.html 2>/dev/null || true

# Clean previous video
adb -s "$DEVICE" shell rm -f "$REMOTE_MP4"

echo "=== 2. Starting High-Quality Screen Recording (No Audio) ==="
# Recording 1080x2280 at 8 Mbps
adb -s "$DEVICE" shell "screenrecord --time-limit 115 --bit-rate 8000000 $REMOTE_MP4" &
REC_PID=$!
sleep 2

echo "=== 3. Driving OmniPilot App & Tabs ==="
# Launch OmniPilot
adb -s "$DEVICE" shell am force-stop com.dartnexuslab.omnipilot
sleep 0.5
adb -s "$DEVICE" shell am start -n com.dartnexuslab.omnipilot/.MainActivity
sleep 3.5

# Step 1: OmniPilot Main (Cross-App AI tab)
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step1_omnipilot_main.png"

# Tab 2: Period Attendance Form (x=470, y=250)
adb -s "$DEVICE" shell input tap 470 250
sleep 2.5
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step2_period_form.png"

# Tab 4: Developer Info Tab (x=980, y=250)
adb -s "$DEVICE" shell input tap 980 250
sleep 2.5
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step3_developer_info.png"

# Return to Cross-App AI Tab (x=160, y=250)
adb -s "$DEVICE" shell input tap 160 250
sleep 1.5

echo "=== 4. Launching Chrome with Empty BISP Google Form ==="
# Open Chrome initially empty to show the form before fill
adb -s "$DEVICE" shell am start -n com.android.chrome/com.google.android.apps.chrome.Main -d "http://localhost:8080/google_form.html"
sleep 3.5

adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step4_chrome_form_ready.png"

echo "=== 5. Expanding OmniPilot AI Floating Overlay over Chrome ==="
# Tap floating bubble at top-left (x=120, y=410)
adb -s "$DEVICE" shell input tap 120 410
sleep 2.5
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step5_overlay_expanded.png"

# Collapse overlay (x=980, y=280) so Chrome form is fully visible
adb -s "$DEVICE" shell input tap 980 280
sleep 1.5

echo "=== 6. Triggering Proper Sequential AI Autofill in Chrome ==="
# Trigger autofill with query param
adb -s "$DEVICE" shell am start -n com.android.chrome/com.google.android.apps.chrome.Main -d "http://localhost:8080/google_form.html?autofill=1"
sleep 4.5

# Mid-fill screenshot (Fields 1-3)
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step6_form_filling_midway.png"
sleep 6.5

# Submitted with green verified banner
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step7_form_submitted_verified.png"
sleep 4.0

echo "=== 7. Scrolling Up to Review All Completed Form Fields ==="
adb -s "$DEVICE" shell input swipe 500 500 500 1800 350
sleep 1.5
adb -s "$DEVICE" shell input swipe 500 500 500 1800 350
sleep 3.0
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step8_all_fields_reviewed.png"

echo "=== 8. Performing Google Search in Chrome ==="
# Tap address bar in Chrome (x=500, y=150)
adb -s "$DEVICE" shell input tap 500 150
sleep 1.0
adb -s "$DEVICE" shell input text "https://www.google.com/search?q=BISP%sTaleemi%sWazaif%sOmniPilot%sAI"
sleep 1.0
adb -s "$DEVICE" shell input keyevent 66 # KEYCODE_ENTER
sleep 4.5
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step9_google_search.png"

echo "=== 9. Returning to OmniPilot Period Attendance Form ==="
adb -s "$DEVICE" shell am start -n com.dartnexuslab.omnipilot/.MainActivity
sleep 2.0
adb -s "$DEVICE" shell input tap 470 250 # Period Form tab
sleep 3.0
adb -s "$DEVICE" exec-out screencap -p > "$ARTIFACTS_DIR/demo_step10_final_omnipilot.png"

echo "=== 10. Finalizing Screen Recording ==="
adb -s "$DEVICE" shell pkill -INT screenrecord || true
sleep 3.5

echo "=== 11. Pulling Video to Mac and iCloud ==="
adb -s "$DEVICE" pull "$REMOTE_MP4" "$LOCAL_MP4"

mkdir -p "$ICLOUD_RECORDINGS"
mkdir -p "$ICLOUD_SCREENSHOTS"

cp -v "$LOCAL_MP4" "$ICLOUD_RECORDINGS/omnipilot_chrome_demo.mp4"
cp -v "$LOCAL_MP4" "$ICLOUD_SCREENSHOTS/omnipilot_chrome_demo.mp4"
cp -v "$ARTIFACTS_DIR"/demo_step*.png "$ICLOUD_SCREENSHOTS/"

echo "=== Demo Video and Screenshots Ready! ==="
ls -lh "$LOCAL_MP4"
ls -lh "$ICLOUD_RECORDINGS/omnipilot_chrome_demo.mp4"
