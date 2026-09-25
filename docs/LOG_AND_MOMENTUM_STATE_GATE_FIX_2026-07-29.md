# Log and Momentum State Gate Fix

This checkpoint corrects two runtime regressions without changing the authored
reusable UI layout or styling.

## Log

The combat Log again uses the reusable UI project's original native behavior:
the Log button directly toggles the drawer with `show()` and `hide()`. The
integration-time anchor animation and resize callbacks were removed.

## Combat progression

`CombatEncounter` now has one deferred progression gate. It runs after combat
state changes and after enemy decisions complete.

The gate:

- waits while a real attack, movement, Dodge-step, or Grapple choice is active;
- automatically resolves reaction prompts whose reactor has no Actions;
- automatically declines an unavailable Move Reaction;
- automatically resolves a pending Grapple response when the target has no
  Actions;
- consumes the losing side's round-one Momentum phase after phase-start effects;
- starts or continues enemy AI only after all blockers are clear.

## Focused runtime check

1. Open and close Log before pressing Begin.
2. Open and close Log during the Butler battle.
3. Complete Butler and enter the Knife Footman encounter.
4. If Enemies win Order with Momentum, observe their full phase.
5. Confirm every zero-Action heroine reaction resolves automatically.
6. Confirm the locked Hero Phase is logged and immediately advances to Round 2.
7. Open Log and confirm the phase transition and incoming attacks are visible.
