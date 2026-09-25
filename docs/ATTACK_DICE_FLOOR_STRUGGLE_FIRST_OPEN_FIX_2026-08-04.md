# Attack Dice Floor and Struggle First-Open Fix — 2026-08-04

## Attack pool

Every legal committed Attack now rolls at least `1d10` after all Attack-pool
bonuses and penalties are combined. A penalty may reduce an Attack to the
minimum pool, but it may not spend the Action and produce an empty roll.

This fixes the Corrupted Butler's Silver Tray while engaged. Its `2d10`
Agility pool receives the ordinary engaged-ranged `-2d10` modifier and has
Slings manipulation suppressed, leaving the universal minimum of `1d10`.

## Struggle first opening

Struggle now becomes visible at zero opacity, waits for two complete Godot
container-layout frames, measures the settled content, positions itself, and
only then plays its opening animation. A generation guard prevents a deferred
first-open callback from reopening or resizing a panel that was already closed
or replaced by a newer selection.

The panel's exported width, command offset, gap, authored button styling and
direct Might/Agility/Endurance interaction remain unchanged.
