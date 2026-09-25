# Log, Momentum, and Butler Runtime Fix

This checkpoint addresses the three regressions reported after the first
successful node-map battle.

## Corrected

- The reusable Log button opens and closes the authored right-side drawer with
  a 0.25-second native Godot tween.
- The log remains available while combat commands are locked.
- The drawer recalculates its open and closed positions when the viewport is
  resized.
- A side reduced to zero opening Actions by Momentum is skipped automatically.
  Round 2 begins without entering a dead player or enemy phase.
- A completed encounter is removed from `CombatHost` immediately before it is
  queued for deletion. Old CanvasLayers and marker input cannot remain over the
  next encounter.
- Full-body enemy hit areas use transparent Button styles. The Corrupted
  Butler's hit area no longer covers his `CharacterArt`.
- The custom reusable HUD frame StyleBox remains unchanged.

## Focused Runtime Check

1. Enter the Corrupted Butler battle and press `Log` before and after `Begin`.
2. Confirm the drawer slides in from the right and a second press closes it.
3. Confirm the Butler sprite is visible underneath its hoverable full-body
   target area.
4. Complete the Butler battle and return to the node map.
5. Enter the next Knife Footman battle.
6. If either side gains Momentum, confirm the losing side's zero-Action phase
   is logged as automatically skipped.
7. Confirm Round 2 begins and combat continues normally.

