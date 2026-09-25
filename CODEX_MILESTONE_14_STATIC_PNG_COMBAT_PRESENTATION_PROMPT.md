# Milestone 14 — Static-PNG Combat Presentation and Linked Battle Stages

This is **Milestone 14 of 15**. Milestones 1–13 are committed and the isolated Godot suite is green.

Create branch:

\`\`\`bash
git switch -c milestone/14-static-png-combat-presentation
\`\`\`

Read AGENTS.md, the current authoring guide, the room/prop handoff, visual-profile documentation/catalog, battle scenes/controllers, event-room flow, and authored battlefield data before editing. Inspect actual assets before binding them. Do not commit.

## Goal

Connect the already executable game to authored visual presentation:

- exploration room → interaction or cancellable timed trigger → linked combat stage;
- static PNG battlers driven by Milestone 13 profiles;
- authored backgrounds, depth bands, and limited prop occlusion;
- normal combat outcome;
- return to the original exploration room in its resolved aftermath state;
- return to the node map.

The map node and room identity stay continuous. A combat stage is a battle-specific variant of an exploration room, not a replacement room.

## Authority boundaries

- CombatEngine, encounter state, and AuthoredBattlefield remain authoritative for movement, contacts, routes, capacity, cover, LOS, Grapple, resolution, rewards, and outcomes.
- CombatPresenter/views observe state. Art files, pose fallbacks, and visual depth must not alter rules.
- Decorative props change no mechanics. A prop that blocks route, limits capacity, provides cover, or blocks LOS must make the exact matching AuthoredBattlefield change.
- Preserve deterministic seeds, safe points, duplicate prevention, Save Envelope v3, and Refuge/defeat/return behavior.
- Do not activate unfinished rooms, encounters, battlers, items, or rewards just because art exists.

## Required implementation

### Reusable battle presentation

Implement a reusable component layer consuming AuthoredBattlefield position/anchor state, BattlerVisualProfile resolution, authoritative pose/facing intent, and authored stage background/prop placements.

It must:

- place each battler with profile floor-contact pivot at its authoritative Position;
- resolve idle, move, attack/cast, defend, hurt, defeated, and Grapple intent through profile data;
- use only short static swaps/crossfades;
- use BattleMarker safely when profile is marker-only or missing, including Chain Warden;
- preserve HUD, input, log, overlays, debug geometry, and accessibility;
- avoid missing-resource errors or console spam.

### Existing playable route first

Wire the pipeline through every complete production-reachable path before adding ordinary content:

- Lysandra opening / Opening Servant Corridor;
- Ruined Chapel recruitment battle;
- Blood Nun Processing Chapel;
- immediate Jailer and victory/defeat paths;
- any other already reachable battlefield with a complete encounter.

Use a reviewed matching combat stage. Do not force a restyled asset onto an active battlefield until its tactical composition is approved. Each outcome returns to the correct exploration/map/campaign state.

### Data-driven exploration-to-stage transition

Add reusable data binding for:

- exploration room and trigger ID;
- encounter ID;
- combat stage and battlefield ID;
- trigger type: interaction, dialogue result, route, or delayed-on-enter;
- optional delay duration;
- completion/aftermath state and return target.

A delayed trigger must cancel when resolved, exited, dialogue opens, mode changes, or restored state shows it fired. It fires once only. Continue restores existing safe points only and never replays completed battle/reward/dialogue.

### Backgrounds, depth, and props

Use only reviewed assets. The 20 combat rooms and 25 props are candidate assets; held-back L2 rooms remain inactive.

Implement:

- 1920×1080 fixed stage composition;
- explicit near/mid/rear bands and z-order; limited Y-sort inside a band only;
- background plus rear/mid/foreground layers;
- placement data: prop/stage ID, transform, depth band, floor anchor, optional front mask/rear part;
- a front-mask occlusion test for one L1 table/pew and one L2 iron divider;
- optional foreground curtains/chains behind a disabled-by-default feature flag. Do not ship cursor parallax without readability QA.

For any test prop declared mechanical, add and test the matching battlefield route/capacity/cover/LOS change. Never infer geometry from the image.

### Lifecycle safety

Clean up visual nodes, timers, tweens, and deferred callbacks across encounter start, movement/actions/reactions, victory, defeat/Refuge origin, Jailer victory, Farthest Cell, and Continue. No stale callback may act on another scene or produce null-node errors.

### Validation and documentation

Validate stage references, profile/background/prop assets, duplicate IDs, depth/mask relationships, profile fallbacks, and mechanical props paired with matching battlefield rules. Ensure incomplete or held assets are not activation-bound.

Document stage bindings, layer order, prop policy, asset registration, fallback gaps, and a room-to-stage authoring recipe.

## Out of scope

- Bulk activation of the 20 rooms or ordinary generated L1/L2 combat content.
- New battlers, Cell Slime activation, Chain Warden art, items/rewards/equipment/materials, balance, AI, or combat mechanics.
- New HUD, gameplay camera panning, voice, full animation, or cinematics.
- Mid-combat/mid-dialogue saves or Save Envelope changes.

## Tests and validation

Add focused tests for profile pose/marker fallback, authoritative movement presentation, interaction/timed trigger once-only behavior, outcome/Continue return lifecycle, and L1/L2 prop occlusion plus matching mechanics.

Run:

\`\`\`bash
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
python3 tools/run_regression_suite.py --godot /home/fluffy56/.local/bin/godot4
git diff --check
\`\`\`

All scripts must pass, no startup/gameplay debugger errors, no orphan UID/import files, and .godot remains ignored.

## Manual QA

1. Fresh campaign: opening, Ruined Chapel, Blood Nun, and Jailer use correct stages and art/fallbacks.
2. Exercise movement, attack/cast, defense, hurt, defeat, and Grapple; visuals follow without rule changes.
3. Verify L1 and L2 prop test stages: occlusion is clear and all claimed mechanical effect matches actual legality.
4. Test interaction and delayed triggers with cancel, safe-point force-close, Continue, victory, and revisit: no duplicate battle/reward.
5. Test Jailer defeat → Refuge, Jailer victory → reverse L2, Farthest Cell, menu, slots, Continue, Refuge, inventory, maps, and event rewards.

## Handoff report

Report active stage bindings, backgrounds/props, marker fallbacks, mechanical prop mappings, changed files, suite results, QA, deferred assets, and absent sources. Do not commit.

Suggested commit message:

\`\`\`text
Implement Milestone 14 static PNG combat presentation
\`\`\`

