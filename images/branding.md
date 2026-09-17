# Launcher artwork

The text-free TV mark comes from the existing `twellie-logo.png` reference.
Its license is retained in [twellie-logo-LICENSE.txt](twellie-logo-LICENSE.txt).
The splash keeps that image and uses `#1C2454`, the background color in
Twellie's editable logo source, for the surrounding screen.

The launcher images extend the mark's navy background to fill each canvas:

| File | Pixels |
| --- | --- |
| `channel-icon_FHD.png` | 540 × 405 |
| `channel-icon_HD.png` | 290 × 218 |
| `channel-poster_sd.png` | 246 × 140 |

The background extension was produced with the built-in imagegen tool on
2026-09-17, then center-cropped and downscaled for these exports. No text is
included in any of the images.

Generation prompt:

> Edit this existing app logo only by extending its background horizontally to a wide 16:9 rectangular launcher-icon canvas. Preserve the white smiling TV, dark screen, eyes, mouth, antennae, legs and their exact geometry and colors; do not redesign, round off or simplify the logo. Keep the reference square centered at full canvas height, so the TV itself occupies the same proportion of the image height as the original. Extend the navy background across the entire canvas, using a clean uniform #1C2454 navy everywhere outside the TV. No visible square boundary, no extra textures, no gradient, no text, no words, no additional symbols. Final asset is flat app-icon artwork, not a mockup, without a device frame or rounded canvas corners. Prefer 1792 by 1024 output or a similar landscape 16:9 ratio. This is background extension of an existing mark, not a new logo.
