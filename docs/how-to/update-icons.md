<!-- cspell:words xcassets appiconset imageset LSUIElement -->
# How to update the app and menu bar icons

## Source files

All icon source files live in `design/` at the repo root.

| File                       | Purpose              | Required size                 |
| -------------------------- | -------------------- | ----------------------------- |
| `design/icon-master.png`   | App icon source      | 1024×1024 px                  |
| `design/menu-master.png`   | Menu bar icon source | 1024×1024 px (see note below) |

The app icon master is a red tomato centered in a clock face on a white background.
The menu bar icon master is white artwork on a transparent background so it renders as
a template image (adapts to light and dark menu bar appearance).

> **Note:** `design/menu-master.png` is a temporary stand-in. Issue [#374](https://github.com/richwklein/taskmato/issues/374) tracks replacing it with a small-scale source optimized for 16–18 pt rendering. Update this doc and the script when that work lands.

## Generating the PNGs

Run the generation script from the repo root:

```bash
bash scripts/generate-app-icons.sh
```

This uses `sips` (built into macOS — no installs required) to produce:

- **10 PNGs** in `app/Taskmato/Assets.xcassets/AppIcon.appiconset/`
- **2 PNGs** in `app/Taskmato/Assets.xcassets/MenuIcon.imageset/`

### App icon sizes

| Filename                   | Pixels    | Slot       |
| -------------------------- | --------- | ---------- |
| `icon_16x16.png`           | 16×16     | 16 pt @1x  |
| `icon_16x16@2x.png`        | 32×32     | 16 pt @2x  |
| `icon_32x32.png`           | 32×32     | 32 pt @1x  |
| `icon_32x32@2x.png`        | 64×64     | 32 pt @2x  |
| `icon_128x128.png`         | 128×128   | 128 pt @1x |
| `icon_128x128@2x.png`      | 256×256   | 128 pt @2x |
| `icon_256x256.png`         | 256×256   | 256 pt @1x |
| `icon_256x256@2x.png`      | 512×512   | 256 pt @2x |
| `icon_512x512.png`         | 512×512   | 512 pt @1x |
| `icon_512x512@2x.png`      | 1024×1024 | 512 pt @2x |

### Menu bar icon sizes

| Filename             | Pixels |
| -------------------- | ------ |
| `menu-icon.png`      | 18×18  |
| `menu-icon@2x.png`   | 36×36  |

## Committing the output

The generated PNGs are committed to the repository. CI does not regenerate them. After running the script, stage and commit everything that changed:

```bash
git add app/Taskmato/Assets.xcassets/AppIcon.appiconset/ \
        app/Taskmato/Assets.xcassets/MenuIcon.imageset/
git commit -m "chore(assets): regenerate icon PNGs from updated master"
```

## Verifying the output

Spot-check a size with `sips`:

```bash
sips -g pixelWidth -g pixelHeight \
  app/Taskmato/Assets.xcassets/AppIcon.appiconset/icon_512x512.png
# → pixelWidth: 512 / pixelHeight: 512
```

Then build and run the app. The icon appears in:

- **Finder → Get Info** on `Taskmato.app` (top-left of the info panel)
- **The Dock** — visible only when **Settings → Show Dock icon** is enabled (default off);
  toggle it on before checking, then restore it afterward
- **The menu bar** — the small icon to the left of the timer countdown
