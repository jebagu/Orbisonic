# Orbisonic app logos

Two-color SVG app-logo sources traced from the supplied raster logos. Each SVG
uses a square `viewBox`, a full-size background rect, and one foreground path
with `fill-rule="evenodd"`.

Color is controlled with CSS variables:

- `--logo-bg`
- `--logo-fg`

The source viewBoxes are cropped to the traced mark bounds with a small safety
inset, so the mark sits just inside the bounding square.

## Files

- `logo-surround-option-6.svg`
- `logo-orbital-corners.svg`
- `app-logo-manifest.json`

Preview sheet:

- `docs/app-logo-contact-sheet.png`

Current app icon:

- Mark: `logo-surround-option-6.svg`
- Colors: Primary Dark `#1E212A` background, Primary Green `#2ECC8A` foreground
- Bundle icon source: `Sources/Orbisonic/Resources/AppIcon/Orbisonic.icns`
