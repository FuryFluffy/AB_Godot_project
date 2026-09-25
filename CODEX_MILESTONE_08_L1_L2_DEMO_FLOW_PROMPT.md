# Milestone 8 — Layer 1 → Jailer → Reverse Layer 2 Demo Flow

## Goal

Turn the existing Layer 1/Layer 2 generator foundation into the intended, fully playable demo route without inventing ordinary room content or changing combat rules.

The route is:

1. A fixed tutorial Layer 1 route, including the existing opening and recruitments, ending at the Blood Nun.
2. After the Blood Nun, the player chooses **Go Up** or **Go Down**.
3. **Go Down** enters an immediate Jailer encounter at the Layer 2 exit/containment side.
4. The Jailer is deliberately overwhelming but genuinely winnable.
5. Jailer defeat establishes the Bloom Refuge and completes the no-Refuge demonstration path.
6. Jailer victory is real: it must not be rewritten as a forced loss. The surviving Refuge-less party continues from the Jailer/end side of Layer 2, traversing the generated layer backwards toward the Farthest Cell, where the Bloom Refuge is established.

Milestone 7's deterministic registered-room graphs remain the source of topology. This milestone makes the route, gates, lifecycle transitions, and recovery boundaries correct.

## Read before editing

Read completely:

- `README.md`
- `docs/LAYER_1_2_GENERATOR_ACTIVATION_2026-08-27.md`
- `docs/ACTIVE_RUN_SAFE_POINTS_AND_CONTINUE_2026-08-26.md`
- `docs/REFUGE_OWNERSHIP_AND_RUN_RESOLUTION_2026-08-26.md`
- `docs/BLOOM_REFUGE_HUB_AND_CAMPAIGN_BOUNDARY_2026-08-10.md`
- `docs/PRODUCTION_SAVE_SLOTS_AND_MAIN_MENU_2026-08-12.md`
- current campaign lifecycle, `RunState`, `MainController`, generator, map graph, Jailer/Refuge screens, and active-run save code
- existing tests, especially layer transition, Jailer/Refuge origin, Bloom Refuge hub, campaign lifecycle, production save slots, and active-run safe-points
- `project_sources/02-04-ABYSSAL_BLOOM_LAYER_1_2_ROOM_AND_BATTLEMAP_VISUAL_SPEC_2026-07-24-1-1-.md`
- `project_sources/04-03-02-00_ABYSSAL_BLOOM_MASTER_REFERENCE_UPDATED_2026-07-23-1-1-1-1-.md`
- `project_sources/05-ABYSSAL_BLOOM_LAYER_NARRATIVE_REFERENCE_L1-L5_2026-08-11-1-.md`

Inspect the repository and write a concise implementation plan before editing. Extend current code; do not introduce a parallel campaign, map, save, or Refuge architecture.

## Canonical route and lifecycle rules

### 1. Refuge-less campaign boundary

- Before the Bloom Refuge exists, the campaign is one continuous **Refuge-less attempt**.
- The first full-party defeat anywhere in that period establishes the Layer 2 Bloom Refuge and irreversibly ends Refuge-less eligibility.
- Preserve Milestones 5–6 ownership and active-run semantics: defeat uses the existing defeat-loss policy; reaching a valid Refuge boundary clears active-run Continue state.
- Never silently reset the campaign, duplicate rewards, duplicate recruitment, or create a second Refuge origin.

### 2. Fixed Layer 1 tutorial route

- Preserve the current executable opening, Corrupted Butler, Wine Cellar/Rusty Key route, Mira and Seraphine recruitments, and Blood Nun route.
- These required anchors must remain reachable and non-probabilistic. A generated map must not strand, bypass, duplicate, or reorder an existing required flow.
- Preserve the current opening/event completion snapshots and reward behavior.
- Do not make unimplemented generic registry rooms into combat, dialogue, loot, or scripted-event content.

### 3. Blood Nun choice

- After a valid Blood Nun victory, show the existing choice boundary: **Go Up** or **Go Down**.
- **Go Up** retains its present clearly gated/deferred behavior; it must not start unimplemented Layer 3 content.
- **Go Down** must enter the immediate Jailer encounter at the Layer 2 containment/exit side. It must not first generate an intake-side Layer 2 run or require an unexplained route through the Dungeon.

### 4. Jailer outcomes

- Jailer defeat establishes the Bloom Refuge at the Farthest Cell, applies the existing defeat policy exactly once, clears active-run state, and reaches the normal Refuge presentation.
- Jailer victory is valid and must never hardcode a loss, overwrite the outcome, establish the Refuge immediately, or delete the surviving party's Refuge-less state.
- On Jailer victory, create/activate the deterministic Layer 2 graph with the player at its Jailer/end-side entry. The intended travel direction is **backward toward the Farthest Cell**.
- Ensure the already-defeated Jailer cannot be replayed, its reward cannot duplicate, and map edges/backtracking remain reciprocal and legal.
- At the Farthest Cell, establish the Bloom Refuge exactly once, clear active-run Continue state, and transition to the existing Refuge hub.

### 5. Persistence and recovery

- Active-run safe points must remain legal only at pre-node/post-node boundaries—never mid-combat, mid-dialogue, or in a half-resolved route transition.
- Continue after a safe point must restore the exact Layer 2 graph, orientation, current/pending node state, and no-duplicate reward behavior.
- Old valid v3 saves and valid Milestone 7 generated graph snapshots must load safely through backwards-safe defaults where necessary.
- Malformed campaign, graph, or active-run snapshots must fail transactionally without corrupting the slot or partial-progressing the campaign.

## Required implementation constraints

- Keep Save Envelope `save_version = 3` unless a narrow, backwards-safe extension is genuinely required. Do not migrate or overwrite v1/v2 slots.
- Preserve deterministic seed derivation, battle seed allocation, retry behavior, and generated node `authored_room_id`/`content_seed` behavior from Milestone 7.
- Preserve the distinction between a generic registered room and executable content. Ordinary battle-room authoring remains outside this milestone.
- Reuse existing scenes, encounter templates, event-room systems, and lifecycle APIs wherever possible.
- Do not modify accepted unrelated failing tests merely to improve the suite.
- Keep `.godot/` ignored. Every new `.uid` must have its source counterpart.

## Explicitly out of scope

- Full Layers 3–10 authoring or activation.
- Ordinary battle-room activation, new encounter templates, enemies, enemy AI, battlefields, sprite/presentation work, or combat/Grapple/balance changes.
- New room dialogue, cutscenes, events, loot tables, reward weighting, items, equipment, Materials, crafting, salvage, or Refuge UI/services.
- Exact novel death sequencing, fixed failed-attempt counts, or forcing a single Mother/Jailer outcome, encounter order, or heroine action.
- Broad test-harness cleanup or unrelated bug fixing.

## Tests and validation

Add focused tests for at least:

1. Blood Nun victory produces the Go Up/Go Down choice without breaking existing Layer 1 progression.
2. Go Down launches the immediate Jailer encounter from the correct Layer 2 end-side boundary.
3. Jailer defeat establishes the Refuge exactly once, applies normal defeat resolution, clears Continue, and cannot duplicate the origin path.
4. Jailer victory is preserved as victory; it creates/resumes the reverse Layer 2 traversal without establishing the Refuge prematurely.
5. The reverse L2 graph begins at the Jailer side, reaches Farthest Cell legally, preserves reciprocal travel/backtracking, and establishes the Refuge there exactly once.
6. Safe-point save → Continue works on both sides of the Jailer-to-reverse-L2 transition; resolved nodes and rewards cannot replay.
7. Existing valid v3 and Milestone 7 generated snapshots remain safe; malformed snapshots reject transactionally.

Run:

- structural validation;
- regression-runner self-tests;
- focused route/lifecycle/save/active-run/room-registry tests;
- the complete Godot 4.7.2 regression suite;
- `git diff --check`.

Compare the full suite script-by-script against the accepted Milestone 7 baseline. No existing script may newly fail or materially worsen. Do not commit.

## Manual Godot QA

1. Start a New Campaign and complete the opening through Blood Nun; confirm existing recruitment/event flow still works.
2. Confirm Go Up remains deferred and does not expose Layer 3 content.
3. Choose Go Down and confirm immediate Jailer entry.
4. Lose to the Jailer; confirm one Refuge establishment, normal defeat-loss behavior, no Continue, and normal Refuge presentation.
5. On a fresh Refuge-less run, defeat the Jailer; confirm victory remains victory and the party enters Layer 2 from the Jailer/end side.
6. Travel backward through Layer 2 to Farthest Cell; confirm legal edges/backtracking, no Jailer replay, and one Refuge establishment at the Cell.
7. Force-close/relaunch at legal pre-node and post-node points before and after the Jailer; confirm Continue resumes exact state without reward duplication.
8. Smoke-test Main Menu, slot load, combat, Grapple, Item Bar, Key Chain, defeat, voluntary return, and Refuge boundaries.

## Completion report

Report changed files, exact route behavior, snapshot compatibility, all test results against the accepted baseline, manual QA still required, and any deliberate deferrals. Do not commit.

Suggested commit message after manual acceptance:

`Implement Milestone 8 L1-Jailer-reverse-L2 demo flow`
