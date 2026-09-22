#!/usr/bin/env bash
set -euo pipefail
APP="${1:?usage: restore_original_bundle_resources.sh /path/to/FergusonVetPilot.app}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/PreservedOriginalBundleResources"
for f in Assets.car AppIcon60x60@2x.png 'AppIcon76x76@2x~ipad.png' VetPilotLogoSource.jpg; do
  test -f "$SRC/$f"
  cp -f "$SRC/$f" "$APP/$f"
done
echo "Restored original VetPilot visual bundle resources into $APP"
