# Combat Log Text Width Fix

The Log drawer animation and combat progression are unchanged.

The drawer's `ScrollContainer` now disables horizontal scrolling, while its
`Entries` column and generated `Label` nodes use `SIZE_EXPAND_FILL`. This gives
word wrapping the full inner drawer width instead of the former one-pixel
minimum that caused every character to wrap onto a separate line.

Runtime check:

1. Open Log before combat and confirm each startup message occupies a normal
   line.
2. Begin combat and confirm longer roll/result entries wrap at words within
   the drawer.
3. Close and reopen Log and confirm the original slide animation still works.
4. Enter the Knife Footman encounter and confirm Momentum still progresses.
