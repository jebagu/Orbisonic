# Orbisonic app-logo studies

Two-color SVG app-logo studies traced from supplied raster logos. Each SVG uses
a square `viewBox`, a full-size background rect, and one foreground path with
`fill-rule="evenodd"`.

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

- Mark: circle-gradient Orbisonic logo
- Bundle icon source: `Sources/Orbisonic/Resources/AppIcon/Orbisonic.icns`
- Bundle icon PNG representations: `Sources/Orbisonic/Resources/AppIcon/Orbisonic.iconset/`

The SVG files in this folder are retained as reference logo studies. They are
not the active bundle icon.
