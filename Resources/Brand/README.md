# Tina brand assets

The supplied kit is the source of truth. `Tools/MakeIcon.swift` turns these
files into the iconset, `.icns`, menu bar glyph and in-app mark at build time.

| File | Use |
|---|---|
| `AppIcon-Default.png` | Primary app icon master (lavender, 1024×1024, supplied design) |
| `AppIcon-Variants/*.png` | Alternate palettes: blue, cream, dark, lavender, mint, pink (1024×1024) |
| `MenuBarIcon-Black.png` | Menu bar template source; `MakeIcon` renders `MenuBarIcon.png` / `@2x` from it |
| `MenuBarIcon-White.png` | White silhouette for reference; the status item uses the black template |
| `logo.png` | Transparent portrait used by the DMG background watermark |
| `Source/` | Original transparent portrait PNG and SVG wrapper (the SVG embeds raster, not vector paths) |
| `LaunchpadIcon.icon` | Adaptive Launchpad helper icon (separate from the app icon) |

Notes:

- The app icon ships as the legacy `.icns` on every macOS version. The supplied
  design is a flat 1024 PNG with baked background and margins, so there is no
  `AppIcon.icon` bundle for Icon Composer.
- The menu bar image must stay a monochrome template: `StatusItemController`
  sets `NSImage.isTemplate = true`, so the system applies light/dark tinting.
- Keep the menu bar canvas at 26×20 pt. `MakeIcon` fits the silhouette to a
  17 pt ink height; changing the canvas requires updating
  `BlackHoleGlyph.pointSize`.
- Alternate palettes are not selected at runtime; swapping the primary icon is
  a build-time choice. Copy the desired variant over `AppIcon-Default.png`,
  rebuild and run the tests.
