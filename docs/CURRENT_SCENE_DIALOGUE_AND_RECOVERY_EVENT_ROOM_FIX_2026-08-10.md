# Current-Scene Dialogue Background and Recovery Event-Room Fix — 2026-08-10

This checkpoint follows the runtime-confirmed heroine recruitment and generic
Layer 1 wipe recovery work.

## Dialogue background ownership

- Story dialogue now uses the background of the scene that launched it.
- Post-battle dialogue reads the active `AuthoredBattlefield` background.
- A pre-battle dialogue resolves the background from the pending encounter's
  battlefield template, so the prelude and battle use the same artwork.
- Dialogue running inside an Event room continues over that already-loaded
  room presentation.
- `DialogueDefinition.background_override` is optional and is reserved for an
  intentional cutaway or a scene whose setting differs from its caller.
- The main scene no longer assigns a dedicated backdrop scene to each
  recruitment conversation.

## Recovery Event-room entry

- Butler's Office is exercised with both recovered party shapes:
  Lysandra + Mira and Lysandra + Mira + Seraphine.
- Optional room loot/event preparation reports a warning but does not suppress
  the base room presentation, HUD, interactables, or exit.
- A genuinely fatal room-preparation error is printed and rolls an uncleared
  Event-room entry back to its entrance node. The player is no longer left in
  a pending node-map state with no room on screen.

Recruitment persistence is unchanged: Mira survives the failed Seraphine
recruitment attempt, and all three recruited heroines survive a Blood Nun wipe.
The locked full-wipe consequence remains full HP/MP recovery with the already
applied -15 Resolve penalty preserved.

## Runtime gate

1. Lose Seraphine's recruitment battle and restart with Lysandra + Mira.
2. Complete the opening fight, enter Butler's Office, and confirm the room and
   two-card Party Strip load.
3. Recruit Seraphine, lose to the Blood Nun, and restart with all three.
4. Enter Butler's Office again and confirm the room and three-card Party Strip
   load.
5. Confirm Seraphine's prelude and aftermath use the same Ruined Chapel
   background as her battle.
6. Confirm Mira's aftermath uses the background visible during the Corrupted
   Butler battle unless its dialogue resource is given an explicit override.
