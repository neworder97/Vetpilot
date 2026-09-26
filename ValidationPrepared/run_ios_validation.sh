#!/usr/bin/env bash
# Prepared, NOT executed in the Linux audit environment. No IPA is published.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Requires a Mac with Xcode and iOS Simulator." >&2; exit 2; }
command -v xcodebuild >/dev/null
command -v xcodegen >/dev/null
OUT="$ROOT/ValidationResults"
mkdir -p "$OUT" FergusonVetPilotTests/Fixtures
FIXTURE=FergusonVetPilotTests/Fixtures/dog_thorax_vd_test.jpg
curl --fail --location --retry 2 'https://upload.wikimedia.org/wikipedia/commons/e/e1/Radiographie_thoracique_ventro-dorsale.jpg' -o "$FIXTURE"
echo "4ceffb1d1ce052cdaeb52d08d8142fc1b62975ab  $FIXTURE" | shasum -a 1 -c -
# Fixture attribution is in FergusonVetPilotTests/Fixtures/ATTRIBUTION.md.
# Missing/changed fixture fails this run; no synthetic or injected diagnosis.
xcodegen generate
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; a=[r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]; a.sort(key=lambda r:tuple(int(v) for v in r["version"].split("."))); print(a[-1]["identifier"])')
DEVICE=$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; a=[r for r in json.load(sys.stdin)["devicetypes"] if r["name"].startswith("iPhone")]; print(next((r["identifier"] for r in a if r["name"]=="iPhone 16"),a[-1]["identifier"]))')
SIM=$(xcrun simctl create "VetPilotSafetyAudit-$$" "$DEVICE" "$RUNTIME")
cleanup() {
  if [[ -d "$OUT/Tests.xcresult" ]]; then
    xcrun xcresulttool export attachments --path "$OUT/Tests.xcresult" --output-path "$OUT/Attachments" >/dev/null 2>&1 || true
  fi
  if [[ -d "$OUT/ScribeTests.xcresult" ]]; then
    xcrun xcresulttool export attachments --path "$OUT/ScribeTests.xcresult" --output-path "$OUT/ScribeAttachments" >/dev/null 2>&1 || true
  fi
  xcrun simctl io "$SIM" screenshot "$OUT/simulator-final.png" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$SIM" >/dev/null 2>&1 || true
  xcrun simctl delete "$SIM" >/dev/null 2>&1 || true
}
trap cleanup EXIT
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b
xcrun simctl addmedia "$SIM" "$FIXTURE"
xcodebuild -version | tee "$OUT/xcode-version.txt"
xcrun simctl getenv "$SIM" HOME > "$OUT/simulator-home.txt"
test ! -e "$OUT/Tests.xcresult" || { echo 'Use a clean ValidationResults directory before rerunning.' >&2; exit 2; }
# Exercise the newly changed workflow first, then every remaining unit/UI test.
# Both commands must succeed; no test class is omitted from the release gate.
xcodebuild test -project FergusonVetPilot.xcodeproj -scheme FergusonVetPilot -destination "platform=iOS Simulator,id=$SIM" -parallel-testing-enabled NO -only-testing:FergusonVetPilotUITests/ScribeUITests -only-testing:FergusonVetPilotUITests/FergusonVetPilotUITests/testCoreVetPilotFlow -resultBundlePath "$OUT/ScribeTests.xcresult" CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$OUT/xcodebuild-scribe.log"
xcodebuild test -project FergusonVetPilot.xcodeproj -scheme FergusonVetPilot   -destination "platform=iOS Simulator,id=$SIM" -parallel-testing-enabled NO   -skip-testing:FergusonVetPilotUITests/ScribeUITests -skip-testing:FergusonVetPilotUITests/FergusonVetPilotUITests/testCoreVetPilotFlow -resultBundlePath "$OUT/Tests.xcresult" CODE_SIGNING_ALLOWED=NO   2>&1 | tee "$OUT/xcodebuild-end-to-end.log"
echo 'Both unit and UI targets executed; inspect xcresult for failures, skips, and attachments.'
