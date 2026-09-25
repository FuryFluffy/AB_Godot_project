# Command Bar Icons and HUD Portrait Crop — 2026-08-04

This checkpoint keeps the compact edge HUD behavior and changes presentation only.

## Command bar

- The normal command bar is a vertical five-button stack at bottom-right.
- The buttons are icon-only: Attack, Move, Ability, End Phase and Log.
- Icons preserve their aspect ratio inside 68 × 68 authored buttons.
- Tooltips retain command names and contextual labels.
- Grapple mode preserves the same five-slot geometry. Struggle, Wait and Submit replace the first three commands with matching icon-only controls.

## Party strip

- The manually confirmed bottom-left placement is unchanged.
- Each heroine now uses a dedicated 3:4 HUD portrait crop centered on her face and shoulders.
- The original full portrait textures remain unchanged.

## Log

- The drawer is 320 × 220 authored pixels.
- It opens directly above and right-aligned with the vertical command bar.

## Runtime checklist

1. Confirm all five normal command icons are visible and undistorted.
2. Hover each icon and confirm its tooltip.
3. Confirm disabled commands retain visible icons.
4. Open and close Log; it must not overlap the command stack.
5. Enter Grapple context and confirm Struggle, Wait and Submit remain distinguishable.
6. Confirm each heroine portrait clearly shows the face at the normal 1280 × 720 Web Editor preview size.
