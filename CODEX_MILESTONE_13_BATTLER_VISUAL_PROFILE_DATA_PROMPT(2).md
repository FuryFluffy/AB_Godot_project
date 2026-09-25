# Milestone 13 — Battler Visual Profile Data

## Status

This is **Milestone 13 of 15**. Milestones 1–12 are committed. The isolated Godot 4.7.2 regression suite is currently fully green.

Create a branch from that clean baseline:

```bash
git switch -c milestone/13-battler-visual-profile-data
```

Read `AGENTS.md`, this prompt, the battle presentation code, `AuthoredBattlefield` code/data, battler definitions, and the L1/L2 combat-room/prop handoff before editing. Inspect the actual asset inventory before registering a path. Do not commit.

## Goal

Create the data and validation layer that lets later combat presentation render every battler as a correctly placed static-PNG visual, without letting filenames, scenes, or missing art alter combat rules.

Milestone 14 will implement the renderer and connect exploration-room encounters to their linked combat-stage variants. This milestone defines the stable battler-facing contracts it will consume.

## Locked presentation and ownership model

- `CombatEngine` and `AuthoredBattlefield` remain authoritative for combat state, legal anchors/positions, paths, capacity, contact, cover, and LOS. Visual data may describe them; it must never calculate or replace them.
- An exploration room remains the map/event context. When it launches combat, the encounter will use a linked **combat-stage variant** retaining the room identity but allowed a different tactical composition. That binding is Milestone 14 work.
- The 20 restyled L1/L2 combat rooms and 25 shared props are future battle-presentation assets, not exploration-room replacements.
- Props that ultimately block a route, reduce anchor capacity, supply cover, or obstruct LOS require matching `AuthoredBattlefield` data. Do not add those mechanics here.
- Presentation is fixed-camera painterly 2.5D: foreground → background depth bands; static PNG pose-state swaps; short timing/crossfades; explicit z-order with optional bounded Y-sort within a band.

## Required implementation

### 1. Visual profile schema

Add a validated, data-driven `BattlerVisualProfile` (or compatible project-native equivalent) referenced by stable battler/visual IDs, not display names.

At minimum represent:

- stable profile and battler IDs;
- supported pose/state keys and facing/orientation mapping;
- texture reference per available state-orientation pair;
- floor-contact pivot, baseline scale, and optional per-state offset/scale correction;
- default depth-band/z-order policy compatible with an authored battlefield position;
- deterministic fallback chain for intentionally missing poses;
- optional modular Grapple-overlay metadata, without a renderer;
- explicit development-placeholder status and useful diagnostics.

Use typed data and serializable references. Do not guess by filename, node name, or display name.

### 2. Conservative roster coverage

Register profiles only where assets actually exist. Provide safe coverage/fallback behavior for:

- Lysandra, Mira Voss, Seraphine;
- Hollow Servant, Knife Footman, Prayer-Rag Novice, Corrupted Butler, Red-Wax Acolyte, Blood Nun;
- Chain Thrall, Iron-Masked Guard, Cell Slime, Chain Warden, and the Jailer.

Where final PNGs are absent, register no false production claim. Use an explicit development placeholder/fallback policy that keeps combat playable and produces validator/development diagnostics. Do not author new art or promote unreviewed assets.

### 3. Pose and fallback contract

Define only justified pose keys:

- idle, move, attack/cast, defend/block, hurt, defeated;
- front/back or another precisely documented orientation set where assets support it;
- modular Grapple subject/holder/overlay roles as metadata only.

Fallbacks must be deterministic and visually safe. A missing move may use correctly faced idle; a missing profile must never crash battle startup. Visual fallbacks must not change action, hit, movement, Grapple, or defeat rules.

### 4. Battlefield presentation hooks only

Add minimal non-rendering hooks for a future presenter to request:

- battler profile;
- pose intent derived from authoritative battle events/state;
- facing/depth intent derived from authoritative battlefield position;
- stable render key.

Do not create a new battle scene, replace HUD, attach PNGs to battlers, animate movement, or bind combat rooms/props. Existing presentation must be unchanged except for safe development diagnostics.

### 5. Validation and documentation

Extend validation to check:

- duplicate/missing IDs and profile-to-battler references;
- allowed pose/orientation keys and resolvable asset paths;
- valid non-cyclic pivots/scales/fallbacks;
- required coverage or explicit allowed placeholders;
- no profile defines gameplay contacts, path blocks, capacities, cover, or LOS.

Document schema, fallback policy, art-catalog entry process, and the strict boundary between visual props and battlefield mechanics.

## Out of scope

- Registering/rendering combat rooms, shared props, foreground assets, parallax, masks, or occlusion scenes.
- Encounter-to-stage bindings or changes to anchors, paths, capacity, cover, or LOS.
- Renderer, animation/crossfades, sprite movement, camera, Grapple overlays, or pose effects.
- Combat rules, encounters, loot, maps, dialogue, saves, Refuge changes, or new art production.

## Tests and validation

Start from the green baseline. Add focused tests for profile resolution, state/orientation mapping, deterministic fallback, missing-profile/asset safety, and malformed/cyclic-data rejection. Confirm battle startup works without renderer activation.

Run:

```bash
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
python3 tools/run_regression_suite.py --godot /home/fluffy56/.local/bin/godot4
git diff --check
```

Acceptance requires every registered script to pass, no headless startup debugger errors, and no orphan `.uid` files. Keep `.godot/` ignored.

## Manual Godot QA

1. Start a fresh campaign and enter normal combat; no missing-resource/debugger errors.
2. Exercise movement, attack, defense, hurt, defeat, and a Grapple sequence; rules/log/HUD stay unchanged.
3. Verify an intentionally missing optional art state takes its documented safe development fallback.
4. Smoke-test Main Menu, Continue, Refuge, Event Rooms, maps, Item Bar, Key Chain, and both L1/L2 routes.

## Handoff report

Report schema/resources, registered profiles and explicit placeholders, coverage/fallback results, validation failures tested, changed files, suite comparison, manual QA remaining, and deferred asset/battlefield tasks. Do not commit.

Suggested commit message after acceptance:

```text
Implement Milestone 13 battler visual profile data
```

