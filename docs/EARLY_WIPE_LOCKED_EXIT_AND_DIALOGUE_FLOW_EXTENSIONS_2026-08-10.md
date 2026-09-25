# Early Wipe, Locked Exit, and Dialogue Flow Extensions — 2026-08-10

This checkpoint follows the runtime-confirmed Mira recruitment build.

## Early full-wipe recovery

- Opening-corridor and unrecruited-Mira Butler defeats now return to the
  beginning of Layer 1 instead of returning a zero-HP Lysandra to the map.
- The same run seed is regenerated.
- The combat lifecycle's existing 15 Resolve full-wipe penalty is preserved.
- HP and MP restore to the heroine definition maximum for the recovery.
- Corruption and equipment condition remain as returned by combat.
- Only heroines recruited before the failed encounter enter the recovery
  snapshot. Mira therefore remains absent after losing her recruitment battle.
- This is the temporary vertical-slice handoff for the future Bloom Refuge.

## Wine Cellar locked exit

The bypass came from dialogue cleanup, not inventory handling. Ending dialogue
previously enabled every ExplorationInteractable, including the exit hotspot
behind the locked Wine Cellar door.

The screen now captures each hotspot's enabled state before dialogue and
restores that exact state afterward. It also reasserts each authored
RoomLockHotspot/RoomExitHotspot relationship. As a second guard, an exit request
linked to a still-locked lock is rejected before any room outcome is emitted.

The intended flow remains:

1. click the locked door to inspect it;
2. explicitly select the Rusty Key;
3. click the lock to consume the key and persist the unlocked state;
4. click the now-enabled open exit to complete the room.

## Dialogue graph extensions

DialogueNodeDefinition now supports:

- `entry_outcomes`, applied when the node is entered;
- `apply_entry_outcomes_once_per_session`, enabled by default;
- ordered `automatic_transitions` with stable transition IDs, condition groups,
  optional outcomes, and a destination node ID.

Entry outcomes resolve before automatic transition conditions. The first
matching automatic transition wins; an unconditional fallback must be last.
Automatic routes may chain through several invisible routing nodes before the
next presented line. Runtime cycle detection reports an authoring error instead
of hanging the conversation.

DialogueSessionState persists entry-outcome application and automatic-route
history. DialogueResult exposes entered node IDs, automatic transition IDs,
outcomes, and any routing error so the exploration owner can apply and save the
same transactional result used by choices and dialogue items.

## Regression coverage

The existing focused suites now cover:

- HP/MP recovery with Resolve/Corruption persistence;
- exclusion of unrecruited Mira from a failed-run recovery snapshot;
- recovery snapshot handoff into the restarted opening;
- locked-exit state restoration after dialogue;
- exit-handler rejection while the linked door remains locked;
- node-entry outcomes applying before condition evaluation;
- ordered automatic route selection;
- once-per-session entry outcomes surviving session restoration.
