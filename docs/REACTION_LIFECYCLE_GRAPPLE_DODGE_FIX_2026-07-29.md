# Reaction Lifecycle and Grapple Dodge Fix

This checkpoint corrects the remaining transition defects around reactions.

## Corrected runtime paths

- Preserve/Destroy is now a terminal, single-submit UI decision. The exchange
  closes before damage allocation continues.
- A later equipment choice, Dodge step, or generated attack opens from a clean
  reaction state.
- The combat log drawer animates its right-anchor offsets, so Godot layout
  passes cannot snap it back off-screen.
- The log drawer renders above the bottom HUD and below reaction modals.
- Chained attacks identify their source in the reaction header, including
  `Parry free Attack`, `Counterattack`, and `Move Reaction Attack`.
- Enemy Grapple attempts auto-resolve with Skip when Momentum or another rule
  leaves the heroine with zero reaction Actions.
- A successful Grapple Dodge that prevents attachment offers the same optional
  one-step connected-anchor reposition as ordinary Dodge.
- Accepting or declining the Grapple Dodge step resumes the interrupted enemy
  decision or committed Move Reaction exactly once.

## Focused runtime checks

1. Open and close Log before combat, during an enemy phase, and during a
   reaction.
2. Choose Destroy with one remaining damage. The equipment choices must
   disappear immediately.
3. Repeat with a Dodge that prevents damage. Position selection must appear
   only after the equipment modal has closed.
4. Parry a damaging attack. The next header must say `PARRY FREE ATTACK`, and
   the log must show the next Parry penalty.
5. Enter the Knife Footman encounter with enemy Momentum. Zero-Action heroine
   reactions must resolve automatically instead of stalling.
6. Dodge a Grapple successfully. Choose a highlighted connected Position or
   press Escape to remain in place; either choice must resume combat.

Godot 4.7 runtime execution remains required for these interaction checks.
