# Compact Edge Combat HUD Checkpoint — 2026-08-04

## Scope

This is a presentation-only rearrangement of the stable reusable combat HUD.
Combat state, Actions, selection, targeting, item use, reactions, Grapple,
unified RMB/Escape cancellation, and encounter flow are unchanged.

The 1920×1080 design canvas now uses:

- three compact heroine cards stacked vertically at bottom-left;
- a 352×122 two-row Command grid at bottom-right;
- a 372×232 combat Log directly above Commands when opened;
- a 74×384 six-slot item tray along the middle-right edge;
- no enemy cards or enemy names on the battlefield;
- only enemy HP and Action pips above enemy sprites.

## Heroine cards

Each 320×112 card preserves the current live information:

- portrait and name;
- HP and MP;
- Resolve and Corruption;
- remaining Actions;
- selected/defeated state and the existing detailed tooltip.

The complete card remains a selection hit target.

## Item tray

Item slots remain 58×58 for practical clicking. `ItemDefinition` now exposes an
optional `icon: Texture2D`. When an icon is assigned, the square slot displays
it with the stack quantity. Until dedicated item art is assigned, the slot uses
a two-letter name glyph plus quantity. Full item information and availability
remain in the tooltip.

## Log behavior

The existing authored slide animation remains the single Log lifecycle. Its
open position is `(1532, 694)` and its closed position is `(1920, 694)`, placing
the smaller drawer immediately above the Command grid without covering the
centre of the battlefield.

## Focused Web Editor check

1. Run `combat_encounter.tscn` at the 1920×1080 design canvas.
2. Confirm the three heroine cards stack at bottom-left and remain selectable.
3. Confirm Attack, Move, Ability, End and Log fit the bottom-right grid.
4. Enter Grapple context and confirm Struggle, Wait and Submit reflow into the
   same grid.
5. Open and close Log repeatedly before combat and during both phases.
6. Confirm the Log opens above Commands and never overlaps the item tray.
7. Confirm all six item slots remain clickable and show full tooltips.
8. Use an item, then cancel targeting once with RMB and once with Escape.
9. Confirm enemies show HP and Action pips above their sprites, without cards or
   name labels.
10. Repeat in Ruined Chapel and Processing Chapel to check foreground spacing.
