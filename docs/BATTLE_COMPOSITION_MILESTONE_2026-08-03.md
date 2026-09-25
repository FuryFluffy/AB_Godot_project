# Battle Composition Milestone — 2026-08-03

## Outcome

The production combat scene is now a generic session host. It can run
different battlefield/encounter combinations without being edited.

The milestone preserves the runtime-confirmed combat engine, HUD, dice,
reactions, Grapple, item, spell, weapon-family, and weapon-art behavior.

## Runtime composition

1. Seeded graph generation stores an encounter-template ID on every battle
   node; the run creates an `EncounterDefinition` from that stored choice.
2. The definition selects an `EncounterTemplateDefinition` and records the
   concrete battler-to-spawn-slot assignments.
3. The template supplies an `AuthoredBattlefield` scene, enemy group
   rulebook, and ordered party/enemy spawn roles.
4. `CombatEncounter` instantiates that battlefield scene.
5. The battlefield validates the neutral spawn slots and creates a temporary
   `BattlefieldDefinition` snapshot with active concrete placements.
6. `BattlerCatalogDefinition` resolves only the requested battlers.
7. `BattleMarkerFactory` creates only their active views.
8. The unchanged `CombatEngine` consumes the composed snapshot and returns
   the normal `EncounterOutcome` to the map.

## Implemented proof combinations

| Map content | Encounter template | Battlefield scene |
|---|---|---|
| Regular and elite Layer 1 battles | `ruined_chapel_regular` | `ruined_chapel_battlefield.tscn` |
| Blood Nun boss | `blood_nun_processing_chapel_boss` | `processing_chapel_battlefield.tscn` |

The second combination is selected by the real generated map flow. It is not
an alternate combat host.

## Ownership boundary

- Battlefield: art, zones, anchors, positions, neutral spawn slots, visual
  layers.
- Encounter: active party/enemy IDs, battlefield template, group rulebook,
  concrete spawn assignments, seed, node context.
- Combat session: engine, dice, HUD, presenter, overlays, active views,
  outcome.

Production battlefield scenes generate placement-free definitions and contain
no concrete battler IDs in `initial_placements`. The historical
`ruined_chapel_spatial_test.tres` retains concrete placements only because it
is a deterministic mechanics regression fixture.

As of the Visual Battlefield Authoring milestone, the production scene itself
also owns its BattleZone polygons, polygonal Engagement Areas/Positions, and neutral spawn
markers. The earlier `ruined_chapel_runtime.tres` and
`processing_chapel_runtime.tres` compatibility sources have been removed so
there is only one production source of truth.

## Explicitly deferred

- cover authoring;
- line-of-sight blockers;
- foreground-prop cutouts beyond immediate need;
- exploration hotspots and randomized room items;
- dialogue and narrative triggers.

Production battlefield Resources deliberately use empty `terrain_lines`.
The existing engine support is not removed; it is simply outside this
milestone.

## Runtime verification

1. Start a normal/elite map battle and confirm the Ruined Chapel loads.
2. Confirm only the active party and requested enemies exist under
   `Battlefield/MarkerHost`.
3. Start the Blood Nun boss node and confirm the Processing Chapel loads in
   the same `CombatEncounter` host.
4. Exercise Move, range, Blight Bomb, Grapple, reactions, and weapon arts in
   both compositions.
5. Return to the map and confirm party, inventory, progression, and outcome
   persistence are unchanged.
6. Run `python3 tools/validate_project.py`.
7. In Godot 4.7, run `python3 tools/run_regression_suite.py`.
