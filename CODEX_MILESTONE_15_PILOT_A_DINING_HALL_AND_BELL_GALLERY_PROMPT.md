# Milestone 15 Pilot A — Dining Hall Battle and Bell Gallery Event

## Purpose

This limited Milestone 15 pass proves Codex can author real Layer 1 content through the systems completed in Milestones 1–14.

Work from the committed Milestone 14 baseline on branch milestone/15-l1-l2-demo-integration. Read AGENTS.md, the authoring guide, room registry, reward-source docs, dialogue catalog, stage docs, and existing L1 examples. Do not commit.

## Exact scope

Activate exactly two ordinary Layer 1 rooms:

| Role | Room | Stable ID |
|---|---|---|
| Battle room | Dining Service Hall | dining_service_hall |
| Event room | Bell-Pull Gallery | bell_pull_gallery |

Do not activate any other generic room.

## Controlled authoring freedom

After inspecting current executable resources, Codex may choose:

- a legal ordinary-L1 enemy composition from existing active L1 battlers and encounter patterns;
- a readable Dining Service Hall battlefield using reviewed battle art, current presentation assets, and a long route with side-alcove/two-lane character;
- existing encounter start positions, reward source, and dialogue/outcome types;
- Bell-Pull Gallery trigger type: entry observation, hotspot interaction, or cancellable delayed-on-enter event;
- concise atmospheric Bell-Pull Gallery text constrained to rows of servant bells and cords moving without visible hands.

Explain every choice and existing source dependency in the handoff report.

## Hard constraints

- Stable IDs, deterministic generation, safe points, Save Envelope v3, victory/defeat/return policies, and normal map/node continuity remain intact.
- Use only active L1 battlers, existing battle rules, existing items/reward sources, current dialogue outcomes, and reviewed art.
- Do not create enemy stats, AI, abilities, items, equipment, Materials, keys, Mementos, rewards, named NPCs, mysteries, or campaign branches.
- Bell-Pull Gallery is a meaningful observation/event but awards no item or reward and starts no combat.
- Dining Service Hall is one map room with separate exploration and linked combat-stage presentations. It returns through the normal outcome path.
- Props are decorative unless an exact matching authored battlefield path/capacity/cover/LOS change is deliberately made and tested. Such a mechanic is not required for this pilot.
- Do not change Blood Nun, Jailer, recruitment, current event rooms, current loot weights, balance, or any other room activation beyond the minimum eligibility registration for these two rooms.
- Do not activate Cell Slime, Chain Warden, held L2 stages, or incomplete content.
- Do not add mid-combat/mid-dialogue saves or scene-only hardcoded grants.

## Required implementation

### Dining Service Hall

1. Finish exploration scene/definition with readable entry and exit.
2. Bind a reviewed Dining Service Hall combat-stage background.
3. Author a valid AuthoredBattlefield: BattleZones, anchors, Positions, reciprocal routes, contacts, legal spawns, and visual depth.
4. Make an EncounterDefinition with only existing ordinary L1 resources.
5. Bind exploration trigger → encounter → normal aftermath through the reusable stage-binding contract.
6. If a reward is appropriate, use an existing deterministic source and normal ownership route; otherwise document no extra reward.
7. Register the completed room in the ordinary L1 eligible pool so it can occur deterministically but is not forced.
8. Test victory, defeat, revisit/retry, safe-point Continue, and no duplicate encounter/reward.

### Bell-Pull Gallery

1. Finish exploration presentation with one clear event/hotspot or other documented trigger plus resolved state.
2. Add concise dialogue/observation using production dialogue catalog and persistence.
3. Add no battle, reward, item, lock, key, status, or new campaign branch.
4. Register it in the ordinary L1 event eligibility path so it can occur deterministically but not universally.
5. Test first entry, trigger, resolved revisit, pre/post-node Continue, and no repeat.

## Tests and validation

Add focused tests proving:

- both rooms resolve through real generated/registered paths;
- Dining Service Hall has valid reciprocal graph, legal spawns, and full encounter lifecycle;
- Bell-Pull Gallery is once-only and restores safely;
- same seed preserves room selection/content;
- reward, if any, never duplicates/rerolls across revisit/retry/Continue;
- malformed bindings fail safely without corrupting an active run.

Run:

python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
python3 tools/run_regression_suite.py --godot /home/fluffy56/.local/bin/godot4
git diff --check

All scripts must pass, no new debugger errors, no orphan UID/import metadata, and .godot remains ignored.

## Manual QA

1. Start several fresh campaigns: both rooms can appear but neither is universal.
2. Dining Service Hall: exploration → battle stage → movement/actions/reactions → victory/defeat → map; test revisit and Continue.
3. Bell-Pull Gallery: resolve event, revisit, and Continue; it neither replays nor grants anything.
4. Smoke-test recruitment, Blood Nun, Jailer, Refuge, Main Menu, slots, Item Bar, Key Chain, Grapple, and existing event rooms.

## Handoff report

Report every selected encounter/reward/trigger choice and its source, active paths, test results, manual QA, and all intentionally inactive content. Do not commit.

Suggested commit message:

Author Dining Service Hall battle and Bell Pull Gallery event

