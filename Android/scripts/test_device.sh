#!/usr/bin/env bash
set -euo pipefail
mkdir -p Android/validation
adb install -r Android/app/build/manual/debug/VetPilot-debug.apk
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
