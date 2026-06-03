#!/usr/bin/env bash
# Generate all PNG icon assets from source files in design/.
#
# Usage (run from repo root):
#   bash scripts/generate-app-icons.sh
#
# Requirements:
#   - macOS (uses sips, which is built in — no installs needed)
#   - design/icon-master.png   — 1024×1024 source for the app icon
#   - design/menu-master.png   — 1024×1024 source for the menu bar icon
#     (see issue #374 to replace this with a scale-optimised small source)
#
# Output:
#   app/Taskmato/Assets.xcassets/AppIcon.appiconset/  — 10 PNGs
#   app/Taskmato/Assets.xcassets/MenuIcon.imageset/   — 2 PNGs
#
# The generated PNGs are committed to the repository. Re-run this script
# whenever a source file in design/ changes, then commit the updated PNGs.
set -euo pipefail

APP_MASTER="design/icon-master.png"
APP_OUT="app/Taskmato/Assets.xcassets/AppIcon.appiconset"

MENU_MASTER="design/menu-master.png"
MENU_OUT="app/Taskmato/Assets.xcassets/MenuIcon.imageset"

# --- App icon (AppIcon.appiconset) ---

if [[ ! -f "$APP_MASTER" ]]; then
  echo "Error: app icon master not found at $APP_MASTER" >&2
  echo "Place a 1024×1024 PNG at $APP_MASTER and re-run." >&2
  exit 1
fi

sips -z 16   16   "$APP_MASTER" --out "$APP_OUT/icon_16x16.png"      > /dev/null
sips -z 32   32   "$APP_MASTER" --out "$APP_OUT/icon_16x16@2x.png"   > /dev/null
sips -z 32   32   "$APP_MASTER" --out "$APP_OUT/icon_32x32.png"      > /dev/null
sips -z 64   64   "$APP_MASTER" --out "$APP_OUT/icon_32x32@2x.png"   > /dev/null
sips -z 128  128  "$APP_MASTER" --out "$APP_OUT/icon_128x128.png"    > /dev/null
sips -z 256  256  "$APP_MASTER" --out "$APP_OUT/icon_128x128@2x.png" > /dev/null
sips -z 256  256  "$APP_MASTER" --out "$APP_OUT/icon_256x256.png"    > /dev/null
sips -z 512  512  "$APP_MASTER" --out "$APP_OUT/icon_256x256@2x.png" > /dev/null
sips -z 512  512  "$APP_MASTER" --out "$APP_OUT/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$APP_MASTER" --out "$APP_OUT/icon_512x512@2x.png" > /dev/null

echo "Generated 10 app icon sizes in $APP_OUT"

# --- Menu bar icon (MenuIcon.imageset) ---

if [[ ! -f "$MENU_MASTER" ]]; then
  echo "Error: menu icon master not found at $MENU_MASTER" >&2
  echo "Place a 1024×1024 PNG at $MENU_MASTER and re-run." >&2
  exit 1
fi

sips -z 18 18 "$MENU_MASTER" --out "$MENU_OUT/menu-icon.png"    > /dev/null
sips -z 36 36 "$MENU_MASTER" --out "$MENU_OUT/menu-icon@2x.png" > /dev/null

echo "Generated 2 menu icon sizes in $MENU_OUT"
