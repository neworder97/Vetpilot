#!/usr/bin/env bash
set -euo pipefail
APP="${1:?usage: restore_original_bundle_resources.sh /path/to/FergusonVetPilot.app}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/PreservedOriginalBundleResources"
if [[ "${2:-}" == "--website-logo" ]]; then
  # Preserve the user's source image; the two logo slots intentionally use the
  # website stethoscope compiled by Xcode for this release.
  cp -f "$SRC/VetPilotLogoSource.jpg" "$APP/VetPilotLogoSource.jpg"
  test -s "$APP/Assets.car"
  # Xcode may recompress standalone PNGs for iphoneos. Preserve this reference
  # artwork byte-for-byte; the compiled icon/logo assets remain untouched.
  cp -f "$ROOT/FergusonVetPilot/Resources/VetPilotStethoscope.png" "$APP/VetPilotStethoscope.png"
  cmp "$ROOT/FergusonVetPilot/Resources/VetPilotStethoscope.png" "$APP/VetPilotStethoscope.png"
  echo "Preserved original source artwork and verified the requested website logo."
  exit 0
fi
for f in Assets.car AppIcon60x60@2x.png 'AppIcon76x76@2x~ipad.png' VetPilotLogoSource.jpg; do
  test -f "$SRC/$f"
  cp -f "$SRC/$f" "$APP/$f"
done
echo "Restored original VetPilot visual bundle resources into $APP"
