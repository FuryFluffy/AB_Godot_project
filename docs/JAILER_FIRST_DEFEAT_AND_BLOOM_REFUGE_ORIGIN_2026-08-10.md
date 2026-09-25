# Abyssal Bloom — First Jailer Defeat and Bloom Refuge Origin

## Scope

This historical checkpoint implemented the canonical first-run boundary after
the Blood Nun. Its temporary holding screen and authoring backdrops are
superseded by `BLOOM_REFUGE_HUB_AND_CAMPAIGN_BOUNDARY_2026-08-10.md`.

## Route behavior

- Go Up creates a gated Layer 3 Lower Halls threshold.
- Go Down creates the Layer 2 exit threshold, immediately selects the Jailer
  node, and launches combat without presenting a Dungeon intake map.
- The Layer 2 graph contains the threshold and the unresolved Jailer only.

## First Jailer encounter

The Jailer is a real Major Boss encounter. The original first-pass data used
high HP, Plate defense, five Actions, a large Body-based attack pool, and
Containment Crush. The Layer 1 novel-integration calibration supersedes those
numbers: 48 HP, two Actions, Might 6, Body 5/Tier 3, Plate 7/Tier 3, and a +1
flat-damage Containment Crush. The encounter remains hard and uses the ordinary
combat engine, but a prepared, well-played first-run party is now intended to
win reliably; poor preparation or play should still usually lose.

The first confrontation does not yet author the Jailer's later Grapple kit.
That content remains separate from the origin-boundary test.

The temporary battlefield and Refuge backdrops from this checkpoint have now
been replaced by the supplied Jailer room, pre-Refuge cell, and transformed
Refuge artwork.

## Defeat transaction

The first Jailer defeat is not a normal run restart.

1. Combat returns a defeated three-heroine party and applies the existing
   −15 Resolve wipe consequence.
2. HP and MP are restored for the Refuge awakening; Resolve, Corruption, item
   state, equipment condition, progression, recruitment, knowledge, and
   narrative state remain unchanged.
3. The authored origin dialogue plays over the farthest-cell backdrop.
4. Completion sets the save-scoped `refuge_ever_established` flag and resolves
   `layer_2_refuge_origin` atomically.
5. The failed Jailer node is archived unresolved. The Jailer is not marked
   defeated and remains the future Layer 2 exit boss.
6. The screen remains on a minimal Refuge holding boundary.

## Early Jailer victory containment

Developer-forced or extraordinary victory is handled without establishing the
Refuge. The Jailer node clears and the player returns to the Layer 2 threshold;
the continuation beyond that exceptional result is explicitly deferred.

## Validation

`tests/test_layer_transition.gd` verifies the corrected Layer 2/Layer 3 route
split. `tests/test_jailer_refuge_origin.gd` verifies immediate Jailer entry,
encounter composition, atomic Refuge establishment, full HP/MP recovery,
preserved −15 Resolve, and the unresolved archived Jailer node.
