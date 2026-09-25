# Reaction, Struggle, and Marker Layout Fix

This checkpoint corrects four presentation defects without changing combat
resolution or command behavior.

- The reaction popup is now a compact floating-window root rather than a
  full-viewport Control containing a movable card. Its Frame fills only the
  430×170 window, so a later HUD layout pass cannot stretch it vertically.
- The Struggle popup now uses the same floating-root pattern. Its inner Frame
  is measured after track-selector visibility changes and both the root and
  Frame are collapsed to that content height, leaving only the authored bottom
  margin below Endurance.
- Reaction copy uses font-safe wording (`Actor uses Action on Target`) instead
  of the unsupported right-arrow glyph.
- Battler faction rings are no longer permanent. A gold ring is drawn only for
  a legal Attack target or the currently focused reaction battler.

## Runtime check

1. Receive a normal Attack and a Grapple attempt near the centre and both screen
   edges. Confirm the reaction card remains compact and fully visible.
2. Open Struggle and confirm the frame ends immediately below Endurance.
3. Confirm reaction text contains no missing-glyph box.
4. Confirm ordinary battlers have no circles beneath them; contextual gold
   targeting/reaction emphasis may still appear while choosing an action.
