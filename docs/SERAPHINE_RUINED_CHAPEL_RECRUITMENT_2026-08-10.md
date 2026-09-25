# Seraphine / Ruined Chapel Recruitment — 2026-08-10

This checkpoint completes the locked Layer 1 heroine recruitment order after
the runtime-confirmed Mira and early-wipe checkpoint.

## Canonical route

1. The Corrupted Butler and Mira remain the first generated map encounter.
2. Every generated route converges on one Ruined Chapel battle node in the
   penultimate map column.
3. The Blood Nun boss cannot be reached without clearing that chapel.
4. Entering the chapel starts Seraphine's pre-battle dialogue.
5. The dialogue records the false-prayer event as run state, automatically
   selects the canonical Mira-present route, and presents Seraphine's locked
   line: "This place remembers prayer, but not mercy."
6. Lysandra, Mira, and scene-present Seraphine fight a Prayer-Rag Novice and a
   Hollow Servant on the existing Ruined Chapel battlefield.
7. Seraphine remains unrecruited during combat.
8. Victory offers `Speak with Seraphine`; completing the neutral aftermath
   recruits her, resolves the interaction, grants the battle reward once, and
   clears the chapel atomically.

## Stable IDs

- Encounter: `layer_1_seraphine_ruined_chapel`
- Prelude: `layer_1_seraphine_recruitment_prelude`
- Prelude run flag: `layer_1_seraphine_false_prayer_witnessed`
- Prelude choice: `seraphine_recruitment_stand_beneath_ward`
- Automatic route: `seraphine_arrival_with_mira`
- Aftermath: `layer_1_seraphine_recruitment_aftermath`
- Resolved interaction: `layer_1_seraphine_recruitment`
- Recruitment choice: `seraphine_recruitment_continue_together`

## Full-wipe recovery

- A chapel defeat excludes unrecruited Seraphine from the recovery party.
- Lysandra and already-recruited Mira return at full HP/MP with their combat
  Resolve, Corruption, and equipment condition retained.
- Recruitment, save flags, persistent flags, choices, and resolved
  interactions survive the restart.
- Run flags, dialogue sessions, and pending story requests reset.
- The temporary opening battle uses the recovered party on later runs, so
  Mira is not discarded by a Lysandra-only outcome.
- Replaying the Butler node with Mira already recruited treats it as an
  ordinary encounter and does not repeat her recruitment dialogue.

## Runtime checks

1. Complete Mira's recruitment and advance through any route.
2. Confirm all branches converge on `Ruined Chapel — False Prayer` before the
   Blood Nun.
3. Enter the chapel and confirm the locked line appears before combat.
4. Confirm the combat HUD contains Lysandra, Mira, and Seraphine.
5. Win, select `Speak with Seraphine`, complete the aftermath, and confirm all
   three heroines appear in the next battle.
6. On a separate run, lose in the chapel and confirm the restart contains
   Lysandra and Mira, applies the 15 Resolve wipe consequence, and does not
   recruit Seraphine.
