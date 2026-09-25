# Milestone 12 — Dialogue and Cutscene Production Authoring

## Status and branch

This is **Milestone 12 of 15**. Milestones 1–11 are complete; the intervening regression-repair pass restored the isolated Godot suite to **40 passing / 0 failing scripts**.

Work on a new branch created from the committed post-repair baseline:

```bash
git switch -c milestone/12-dialogue-production-authoring
```

Read `AGENTS.md`, `LOCAL_CODEX_START_HERE.md`, this prompt, and the existing dialogue, event-room, campaign-lifecycle, and save code completely before editing. Inspect the relevant Layer 1–2 narrative references and the current executable room registry. Do not commit.

## Goal

Turn the existing, verified `DialogueGraph` foundation into a small, production-quality narrative/exploration slice for the **already playable L1 → Blood Nun → Jailer / Farthest Cell → Bloom Refuge route**.

The game already supports dialogue choices, entry outcomes, ordered automatic routes, once-per-session effects, cycle protection, persistence, and inherited room/battle backgrounds. This milestone authors and safely binds concrete dialogue through those existing seams. It is not a dialogue-engine rewrite and it is not ordinary Layer 2 combat/content activation.

## Canonical guardrails

- Preserve the locked route: Layer 1 boss is the Blood Nun; Go Down enters the Jailer immediately; Go Up remains deferred; the Jailer is Layer 2's boss.
- Preserve the established Refuge origin. The first Refuge-less full-party defeat establishes the Refuge once; reaching Farthest Cell alive establishes it once through the surviving-run path.
- The Blood Nun is sincerely deceived, grieving, and angry—not a knowing mastermind.
- Layer 2's thematic frame is care becoming containment. The source of the voice/mother mystery must remain unresolved.
- Do not invent lore, named characters, reveals, equipment, items, rewards, enemy mechanics, or material interactions where sources are silent. Leave unimplemented registered rooms generic.
- Retain deterministic generation, stable IDs, safe-point semantics, no reward replay, and Save Envelope version 3.

## Required implementation

### 1. Production dialogue authoring model

Use the existing dialogue resource/schema and its persistence model. Extend it only when an authoring need cannot be represented safely today.

- Establish a documented, data-driven convention for authored dialogue IDs, room/battle assignment, and optional background override.
- Validate referenced graph IDs, nodes, choices, automatic routes, and outcomes at project validation time. Invalid references must fail safely rather than fall back to invented text/content.
- Preserve once-per-session/once-per-run behavior through existing state. A resumed safe point must not replay resolved dialogue or duplicate its effect/reward.
- Keep player-visible text in resources/data where the existing architecture permits; do not embed a new content corpus in controller code.

### 2. Author the current playable narrative beats

Author concise production dialogue only for facts already present in the references and executable route. At minimum cover:

1. Lysandra’s established opening/early isolation beat, without contradicting the locked solo opening.
2. Mira and Seraphine recruitment/party-recognition beats only to the extent current executable recruitment state already supports them.
3. Blood Nun pre- or post-encounter context and the existing threshold choice presentation, without changing the Go Up/Go Down rules.
4. Jailer defeat origin and Jailer-victory/reverse-L2 entry context, preserving each existing mechanical outcome.
5. Farthest Cell / Bloom Refuge establishment text, including the established warmth, locked-from-within, Bloom crystal, and “Keep pushing through” presentation where appropriate.
6. A small number of ordinary room observations for already executable event rooms only (for example Wine Cellar or Butler’s Office), with no newly activated rewards.

Every authored graph must have a clear triggering seam and a testable completion condition. If a listed beat cannot be associated with an existing, safe trigger, document it as deferred instead of creating a speculative trigger.

### 3. Choices and outcomes

- Choices may set only existing, validated narrative/campaign state, route to existing nodes, or invoke existing safe outcomes.
- Do not add divergent campaign branches that need unwritten follow-on content.
- Do not turn a text choice into a reward source, equipment grant, Material grant, combat encounter, or gate unless that result already exists authoritatively.
- Provide clear final/return behavior so no dialogue leaves the player in a dead-end UI state.

### 4. Presentation and accessibility

- Use the current dialogue presentation and inherited room/battle background behavior. Add an authored override only when a suitable existing visual asset is explicitly available.
- Do not build animated cutscenes, new character portraits, sprite profiles, combat presentation, voice/audio, or new UI frameworks. Those belong to later milestones.
- Ensure keyboard/controller confirm/cancel behavior, readable wrapping, and safe handling of missing resources remain intact.

### 5. Compatibility and saving

- Save Envelope remains `save_version = 3`; do not add unrelated persistence domains.
- Existing valid v3 saves and active-run snapshots must load through safe defaults when new optional dialogue-state fields are absent.
- Malformed dialogue snapshots/references must be rejected transactionally without changing a valid loaded campaign/refuge/active run.
- Pre-node/post-node Continue must preserve exactly the correct dialogue state and never replay a consumed outcome.

## Explicitly out of scope

- Ordinary generated Layer 2 battles, enemy introduction, and broader ordinary Layer 2 slice activation.
- New dialogue engine architecture, cinematics, animation, voice acting, portraits/sprites, visual-profile data, or static-PNG battle presentation.
- New loot, items, equipment, Mementos, Materials, recipes, shops, training, upgrades, or combat mechanics/balance.
- Changes to Go Up, the Jailer battle composition/reward, deterministic map topology, or Refuge ownership/loss policy.
- Attempting to resolve the Mother/voice mystery, relationship arcs, or any unresolved narrative contract.

## Tests and validation

Start by recording the clean baseline. Add focused tests that prove:

- every production graph validates and can start/finish through its real trigger;
- choices/automatic routes complete exactly once and do not duplicate effects;
- each required route beat preserves its existing campaign outcome;
- save/load and pre-node/post-node Continue preserve dialogue state correctly;
- missing or malformed references/snapshots fail safely and transactionally;
- inherited backgrounds and any valid authored override select correctly.

Run:

```bash
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
python3 tools/run_regression_suite.py --godot /home/fluffy56/.local/bin/godot4
git diff --check
```

Acceptance requires the full suite to remain all passing (update the expected script count only for intentionally added passing tests), no debugger errors, and every new `.uid` to have its matching source file. Keep `.godot/` ignored.

## Manual Godot QA

1. Start a fresh campaign; verify the opening and recruitment flow remain playable and do not repeat after resolving them.
2. Complete Blood Nun; verify correct dialogue, Go Up remains deferred, and Go Down still enters the Jailer immediately.
3. Test both Jailer defeat → Refuge origin and Jailer victory → reverse Layer 2 context.
4. Reach Farthest Cell alive; verify one Refuge establishment, no duplicate dialogue/reward, and normal launch afterward.
5. Resolve each explicitly authored event-room dialogue; revisit and resume around safe points to confirm no replay.
6. Smoke-test Main Menu, slots, Continue, Refuge UI, Item Bar, Key Chain, combat, Grapple, maps, and ordinary event rewards.

## Handoff report

Report authored graph IDs and trigger bindings, every deferred beat and why, modified files, test results, manual QA remaining, save compatibility, and whether any source reference was absent. Do not commit.

Suggested commit message after acceptance:

```text
Implement Milestone 12 dialogue and cutscene production authoring
```
