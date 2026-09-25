# Milestone 6 — Active-Run Safe Points and Main Menu Continue

You are working on Abyssal Bloom, a production Godot 4.7 desktop project.

Read root AGENTS.md; Milestones 1–5 prompts/completion documents; Save Envelope v3; the map generator and node-entry flow; RunState; run inventory/equipment/refuge ownership state; Main Menu; current save/load controls; dialogue and encounter lifecycle; and relevant tests before editing.

Preserve existing atomic writes, backup recovery, v3 incompatibility behavior, deterministic generation, and established gameplay boundaries.

## Objective

Implement active-run safe-point persistence in Save Envelope v3:

- autosave immediately before entering a map node;
- autosave immediately after a node resolves and map/run state is stable;
- resume the exact safe point from Main Menu Continue;
- if interrupted during a node, restart that node from its pre-node safe point using the same encounter/content seed;
- prohibit normal saves during combat or dialogue;
- remove production Refuge Save/Load controls; Main Menu owns Continue and Load.

This is deterministic safe-point resumption, not mid-combat or mid-dialogue serialization.

## Locked behavior

- Save Envelope remains save_version == 3.
- active_run_snapshot is null when no resumable run exists and a validated Dictionary when one does.
- Autosave before node entry, while map, party, inventory, equipment, keys, Materials, Mementos, and node seed are stable.
- Autosave after node resolution only after all results, rewards, and map-progression changes are stable.
- Do not autosave during dialogue, combat, combat-reward choice, animation, or unresolved room interaction.
- If interrupted while resolving a node, Continue restores the pre-node snapshot and re-enters the node fresh with its saved deterministic seed.
- Continue must not restore partial damage, dice/Grapple/dialogue state, animation state, partial rewards, or combat logs.
- A resolved node must not replay rewards from a post-node safe point.
- Main Menu owns Continue and Load in production.
- Remove or hide production Refuge Save/Load controls. Do not remove test/debug-only controls unless visibly reachable in production.

## Canonical active-run snapshot

Use this logical shape under the existing v3 envelope. Preserve existing field names only where required to extend working serializers; do not create a parallel persistence format.

~~~gdscript
{
    "save_version": 3,
    "slot_id": ...,
    "metadata": ...,
    "campaign_snapshot": ...,
    "refuge_snapshot": ...,
    "active_run_snapshot": {
        "safe_point_kind": "pre_node" | "post_node",
        "campaign_seed": <int>,
        "layer_id": <stable layer identifier>,
        "map_snapshot": <plain serializable current map/progress state>,
        "run_snapshot": <plain serializable active party/run state>,
        "selected_node_id": <node ID or null>,
        "selected_node_seed": <int or null>
    }
}
~~~

Requirements:

- Use a stable internal snapshot revision only if necessary; do not bump the outer save version.
- A pre-node snapshot has non-null selected_node_id and selected_node_seed.
- A post-node snapshot has no unresolved node: use null selected-node fields unless an existing equivalent state is required.
- map_snapshot captures only data required to rebuild the generated map/progress deterministically: generation seed, current Layer/current node, visited/resolved/revealed state, branch/connectivity/progression state, and existing required deterministic data.
- run_snapshot includes all current safe-point party state required by existing models, including HP/MP/Resolve/Corruption/statuses where applicable, plus Milestones 3–4 inventory/equipment state.
- Do not serialize Nodes, Resources, scenes, controls, callables, RNG objects, animation state, active CombatEngine state, dialogue UI state, or combat logs.
- Deep-duplicate and validate incoming snapshots before committing them.
- Reject malformed active-run snapshots transactionally and preserve existing campaign/Refuge state.
- Existing valid v3 envelopes with active_run_snapshot == null remain valid and have no Continue target.

## Determinism

- Find and reuse existing deterministic seed derivation. Do not substitute a new random seed source.
- Persist the exact selected node/content seed before entry.
- Resume pre-node content through the normal node-entry pipeline using that seed.
- Do not generate a different encounter, reward, map branch, event selection, or room content on resume.
- Guard against duplicate node entry and duplicate reward granting.

## Save boundaries and lifecycle

### Pre-node autosave

Create the pre-node snapshot after selecting a legal node but before dialogue, room effects, encounter setup, or rewards begin.

If saving fails, do not enter the node. Surface the project’s existing save-error behavior and leave the player at a stable map state.

### Post-node autosave

After a node fully resolves:

1. apply all results once;
2. mark map/node state resolved;
3. update stable exploration state;
4. write one post-node snapshot;
5. permit further map input only after that boundary succeeds.

If saving fails, keep stable state in memory and use existing error behavior; do not make the node eligible to replay.

### Refuge, defeat, voluntary return, and completion

- On arrival at Refuge, voluntary return, full-party defeat, campaign completion, or intentional run abandonment, clear active_run_snapshot atomically with the applicable campaign/Refuge update.
- Continue must never offer an already-resolved/cleared run.
- Preserve Milestone 5 defeat and transfer policies exactly.

### New Campaign, Load, and Continue

- New Campaign produces active_run_snapshot == null until its first pre-node autosave.
- Main Menu Load loads valid campaign/Refuge state without manufacturing an active run.
- Main Menu Continue resumes the most recently updated valid slot containing a valid non-null active-run snapshot.
- Incompatible, malformed, corrupt, or invalid-backup active runs must not become Continue targets.
- Preserve normal backup-recovery reporting.

## Production UI scope

- Keep current Main Menu and slot-screen architecture.
- Add/enable Continue only through existing Main Menu production ownership.
- Continue is unavailable when no valid active-run safe point exists.
- Remove/hide production Refuge Save and Load controls and reachable actions.
- Do not build any new inventory, Refuge, party-selection, Stash, crafting, or save-management UI.

## Explicitly out of scope

Do not implement:

- mid-combat, mid-dialogue, mid-animation, or mid-room save/resume;
- Save Envelope v4, cloud saves, multiple active runs, or cross-slot copying;
- inventory/equipment/Refuge UI;
- crafting, salvage, Material spending, recipes, training, upgrades, or economy;
- generator changes, new room/dialogue content, presentation work, balance changes, or combat/Grapple rule changes;
- unrelated baseline-test repairs.

## Tests

Add focused tests for at least:

- valid pre-node and post-node snapshot shape and v3 round trip;
- active_run_snapshot == null compatibility for earlier v3 saves;
- interrupted pre-node resume uses the exact saved node/content seed;
- pre-node resume excludes partial combat/dialogue/reward state;
- post-node resume does not replay resolved nodes or rewards;
- malformed active-run rejection without mutation;
- autosave write failure blocks unsafe node entry or continuation;
- clearing active-run state on Refuge, voluntary return, defeat, and completion;
- Continue selecting newest valid active-run slot and ignoring invalid/incompatible slots;
- valid backup recovery;
- guard against save attempts during combat/dialogue/node resolution;
- production Refuge Save/Load controls are absent or unreachable;
- canonical IDs, run inventory, equipment condition, Mementos, Key Chain, Material Pouch, and Refuge ownership round-trip safely.

Use the isolated Godot runner. Do not repair unrelated baseline failures.

## Validation

Run:

- python3 tools/validate_project.py
- python3 tools/test_run_regression_suite.py
- python3 tools/run_regression_suite.py
- git diff --check

Compare the complete suite against the accepted Milestone 5 baseline: 19 passing / 15 failing across 34 scripts. No script may newly fail.

## Manual Godot QA

Provide exact steps to verify:

1. Start New Campaign, select a map node, force-close before resolution, relaunch, and Continue into the same node with the same generated content.
2. Resolve a node, return to map, relaunch, and Continue without duplicate rewards or replayed resolution.
3. Verify combat and dialogue expose no working save/load controls.
4. Verify Refuge has no production Save/Load controls.
5. Verify Main Menu Continue is unavailable before a safe point and enabled after one.
6. Verify Main Menu Load still works for a valid campaign.
7. Verify voluntary return and defeat clear Continue while preserving Milestone 5 outcomes.
8. Verify Main Menu, combat, Grapple, Item Bar, keys, and Refuge still behave normally.

## Completion report

Report:

- exact active-run snapshot schema;
- save boundaries and lifecycle transitions;
- deterministic node/content seed preservation;
- changed files;
- Continue/Load/Refuge UI behavior;
- focused/full-suite comparison;
- manual QA results/blockers;
- suggested commit message.

Do not commit. Stop after implementation and report for review.
