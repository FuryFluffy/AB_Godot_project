# Party Strip, Wipe Recovery, and Dialogue Backdrops — 2026-08-10

This checkpoint follows the runtime-confirmed Seraphine recruitment milestone.

## Adaptive exploration Party Strip

- The shared Exploration HUD retains the authored 320×112 heroine cards.
- Its frame now collapses to the visible one-, two-, or three-member party.
- All layouts remain bottom-left aligned and preserve the six-slot Item Bar.
- Scene-present but unrecruited heroines appear only when their story outcome
  supplies them in the current dialogue snapshot.

## Full-wipe recovery

- Every ordinary Layer 1 combat defeat, including the Blood Nun boss, now
  offers **Return to the Beginning**.
- The restart uses the existing full-wipe recovery transaction: full HP/MP,
  combat-returned Resolve/Corruption/equipment state, the same seed, and a
  fresh map/run-local narrative state.
- Previously recruited heroines remain recruited. Therefore Mira correctly
  survives a failed Seraphine recruitment attempt, while unrecruited
  Seraphine is excluded.
- A Blood Nun wipe restarts with all three heroines because all three have
  already been recruited before the boss.

## Dialogue settings

- Event-room dialogue continues to use the active Event-room presentation.
- Mira's Corrupted Butler aftermath now uses the Butler's Office background.
- Seraphine's prelude and aftermath use the Ruined Chapel background.
- Opening Hallway remains exclusive to the actual opening encounter.

## Runtime checks

1. Before Seraphine joins, confirm the Party Strip frame fits Lysandra + Mira
   without an empty third slot.
2. Confirm Mira's post-Butler dialogue uses Butler's Office.
3. Confirm Seraphine's prelude and aftermath use Ruined Chapel.
4. Lose to the Blood Nun, choose **Return to the Beginning**, and confirm all
   three heroines restart at full HP/MP with the 15 Resolve wipe consequence.
5. Lose Seraphine's recruitment battle and confirm Mira remains recruited
   while Seraphine does not.
