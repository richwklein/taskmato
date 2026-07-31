#!/usr/bin/env bash
# Generate all PNG icon assets from source files in design/.
#
# Usage (run from repo root):
#   bash scripts/generate-app-icons.sh
#
# Requirements:
#   - macOS with the Xcode toolchain. The app icon uses the built-in `sips`;
#     the menu bar icon is rasterized from SVG via
#     `swift scripts/rasterize-svg.swift`, which renders through AppKit —
#     no Homebrew, librsvg, ImageMagick, or Inkscape needed.
#   - design/icon-master.png  — 1024×1024 source for the app icon
#   - design/menu-icon-18.svg — scale-tuned 1x source for the menu bar icon
#   - design/menu-icon-36.svg — scale-tuned 2x source for the menu bar icon
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

MENU_SRC_1X="design/menu-icon-18.svg"
MENU_SRC_2X="design/menu-icon-36.svg"
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

for src in "$MENU_SRC_1X" "$MENU_SRC_2X"; do
  if [[ ! -f "$src" ]]; then
    echo "Error: menu icon source not found at $src" >&2
    echo "Place the menu bar SVG at $src and re-run." >&2
    exit 1
  fi
done

# Rasterize each size from its own scale-tuned SVG (leaf detail differs by size),
# at exact 1x/2x pixels — crisper than downscaling one large source. @3x is
# omitted: the macOS status item never requests it.
swift scripts/rasterize-svg.swift "$MENU_SRC_1X" "$MENU_OUT/menu-icon.png"    18
swift scripts/rasterize-svg.swift "$MENU_SRC_2X" "$MENU_OUT/menu-icon@2x.png" 36

echo "Generated 2 menu icon sizes in $MENU_OUT"
