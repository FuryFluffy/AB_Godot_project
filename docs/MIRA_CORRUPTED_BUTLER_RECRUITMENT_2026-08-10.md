# Mira / Corrupted Butler Recruitment — 2026-08-10

## Implemented flow

1. The required first generated combat node remains the Corrupted Butler encounter in the Lower Kitchen.
   Its reviewed spawn places the Butler at the right service doorway so the
   large foreground heroine silhouettes do not obscure him.
2. Lysandra enters with Mira as a scene-present combat ally.
3. Mira is not added to `NarrativeState.recruited_heroine_ids` by combat setup.
4. A defeat leaves Mira unrecruited and invokes the early full-wipe recovery
   handoff documented in
   `EARLY_WIPE_LOCKED_EXIT_AND_DIALOGUE_FLOW_EXTENSIONS_2026-08-10.md`.
5. A victory offers `Speak with Mira` before the encounter is committed.
6. The aftermath uses the shared `ExplorationHUD`, Item Bar, party cards, dialogue box, portrait, and two actor stages.
7. Mira's locked first line is displayed exactly as authored in the master reference.
8. Selecting Lysandra's acknowledgement completes the mandatory scene and applies recruitment atomically with combat state, inventory, progression, Bloom, narrative state, and node completion.

## Stable IDs

- Encounter: `layer_1_corrupted_butler_opening`
- Story: `layer_1_mira_recruitment_aftermath`
- Resolved interaction: `layer_1_mira_recruitment`
- Choice: `mira_recruitment_continue_together`

## Runtime checks

- Corrupted Butler battle HUD shows Lysandra and Mira, but not Seraphine.
- Losing returns to the beginning of Layer 1 with recovered Lysandra and does
  not add Mira to the party.
- Winning opens the `Speak with Mira` transition.
- The aftermath keeps both party cards, Item Bar, the Lower Kitchen battlefield backdrop, Mira portrait, and both full-body sprites visible.
- Mira speaks the locked first line before any player response.
- Completing the dialogue returns to the map with Mira in the persistent party.
- The cleared Butler node cannot replay its recruitment or Bloom reward.
