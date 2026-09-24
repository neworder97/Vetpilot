#!/usr/bin/env bash
set -euo pipefail
mkdir -p Android/validation
adb install --no-incremental -r Android/app/build/manual/debug/VetPilot-debug.apk
adb shell am instrument -w com.vetpilot.android/.AndroidTestRunner | tee Android/validation/instrumentation.log
adb logcat -d > Android/validation/logcat.log
adb pull /sdcard/Android/data/com.vetpilot.android/files/vetpilot-validation.json Android/validation/emulator.json
adb exec-out screencap -p > Android/validation/tablet.png
python3 - <<'PY'
import json
r=json.load(open('Android/validation/emulator.json'))
assert r['passed'], r
assert r['vectors'] >= 6000, r
print('Android device validation passed:',r['vectors'],'vectors,',r['assertions'],'assertions')
PY
# Install and cold-launch the release variant. The debug key is used only for
# this disposable emulator; distributable releases use the separate private key.
"$ANDROID_HOME/build-tools/35.0.0/apksigner" sign --ks Android/app/build/debug.keystore --ks-pass pass:android --out Android/validation/release-smoke.apk Android/app/build/manual/release/aligned.apk
adb shell am force-stop com.vetpilot.android
adb install --no-incremental -r Android/validation/release-smoke.apk
adb shell am start -n com.vetpilot.android/.MainActivity
sleep 8
adb shell pidof com.vetpilot.android
adb shell uiautomator dump /sdcard/vetpilot-window.xml
adb pull /sdcard/vetpilot-window.xml Android/validation/release-window.xml
adb exec-out screencap -p > Android/validation/release-tablet.png
python3 - <<'PY'
from pathlib import Path
s=Path('Android/validation/release-window.xml').read_text()
assert 'Automatic dose calculator' in s and 'My Clinic' in s, s
assert 'could not start' not in s, s
print('Release APK cold launch passed')
PY
rm Android/validation/release-smoke.apk
