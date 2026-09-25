# Milestone 5 — Refuge Ownership, Stash, and Run Resolution

You are working on Abyssal Bloom, a production Godot 4.7 desktop project.

Read root `AGENTS.md`; Milestones 1–4 prompts/completion documents; the Save Envelope v3 implementation; the existing Refuge lifecycle; `RunState`, `RunInventoryState`, `RunEquipmentState`, campaign save stores, party setup, and all relevant tests before editing.

This milestone changes persistence ownership. Inspect first, preserve existing atomic writes/backups/recovery, and extend existing Refuge architecture rather than replacing it.

## Objective

Implement the persistent **Refuge ownership state** and explicit **run-resolution policies** required by the locked design:

- persistent heroine preparation inventories and equipment loadouts;
- persistent selected-party order data;
- safe shared Stash;
- banked Materials;
- Story/Lore/Knowledge persistence;
- transferring selected preparation state into a new run;
- explicit voluntary-return and defeat resolution for the domains whose outcomes are already defined.

The canonical Save Envelope remains version 3. This milestone begins using its reserved `refuge_snapshot`; it must not introduce a v4 envelope or active-run persistence.

## Locked ownership and loss rules

### Persistent Refuge state

- Each recruited heroine has a persistent personal preparation inventory: **3 × 5 ordered slots**.
- Each heroine has a persistent personal equipment/loadout ownership record using Milestone 4 equipment instances.
- Selected party IDs and their order are persistent Refuge data. Preserve the current Lysandra → Mira → Seraphine default; do not change encounter composition in this milestone.
- Shared Stash contents are safe and are never put into a run automatically.
- Banked Materials are persistent Refuge-only quantities. Once banked, they cannot be withdrawn into a later run.
- Story, Lore, and Knowledge persist.

### Starting a run

- Only selected active heroines' prepared carried inventory/loadout enters the newly created run.
- Stash contents remain untouched.
- The handoff is a **move**, not a copy: an item cannot exist simultaneously in Refuge preparation and in a run.
- Preserve the current default campaign/new-run behavior. Do not add party-selection or inventory UI.
- If existing content does not provide sufficient ownership data to prepare a non-default party safely, preserve the working default and expose only validated domain APIs.

### Defeat

On a full-party defeat:

- equipped weapon, armor, shield/off-hand equipment, and equipped Mementos survive and return to their persistent Refuge owners;
- six-slot Item Bar contents are lost;
- heroine backpack contents are lost;
- ordinary run keys are lost;
- persistent/non-ordinary keys survive only when their authored persistence scope explicitly says so;
- remaining run Materials are automatically banked;
- Story, Lore, and Knowledge persist;
- broken equipment remains broken; do not repair it implicitly.

### Voluntary return

- Remaining run Materials are automatically banked.
- Equipment/loadouts return to persistent Refuge ownership with their current condition.
- Mementos return to their persistent heroine slots.
- Do not invent a persistence/retention rule for ordinary Item Bar or backpack consumables if the repository has no authoritative existing rule. Preserve existing behavior where it exists, otherwise report the exact design gap and expose no speculative transfer.

## Save Envelope v3 contract

Persist Refuge state exclusively under:

```gdscript
{
    "save_version": 3,
    "slot_id": ...,
    "metadata": ...,
    "campaign_snapshot": ...,
    "refuge_snapshot": <validated persistent Refuge state>,
    "active_run_snapshot": null
}
```

Requirements:

- Keep `save_version == 3`.
- Keep `active_run_snapshot == null`.
- `refuge_snapshot` must be a plain, serializable Dictionary only: Stable IDs, item/equipment instance IDs, quantities, ordered slot indices, heroine IDs, arrays, dictionaries, booleans, numbers, strings, and nulls.
- A v3 save created by Milestone 2 with `refuge_snapshot == {}` remains valid. Initialize a safe default Refuge state when loading it.
- Validate and deep-duplicate snapshots before committing them.
- Malformed Refuge data must be rejected transactionally without partially mutating current campaign/Refuge state.
- Preserve pre-v3 incompatibility behavior unchanged.
- Do not place run/backpack/Item Bar state in `active_run_snapshot` yet. Safe-point persistence is Milestone 6 work.

## Required state domains

Use project naming and existing classes where possible. Do not create duplicate parallel stores.

### Heroine preparation state

For each recruited heroine:

- heroine Stable ID;
- 15 ordered preparation slots;
- owned equipment instances;
- Main Hand, Off Hand, and Armor assignments;
- one Memento assignment;
- validated transfer operations between personal preparation, loadout ownership, and shared Stash where appropriate.

Do not allow the same equipment instance to be simultaneously owned/equipped by multiple heroines or in Stash.

### Stash

- Stash may contain ordinary eligible item stacks and unequipped equipment instances.
- Stash must not contain Key Chain entries, banked Materials, or equipped Mementos.
- Stash is persistent and never lost on defeat.
- Enforce canonical IDs, stack limits, capacity rules if one already exists, and transactional movement.
- Do not invent a visible grid size if none has been authored. Use a deterministic unbounded data-domain collection unless existing architecture already provides a bound.

### Key persistence

- Preserve the shared Key Chain as the only key location.
- Use explicitly authored key persistence metadata only.
- Existing Rusty Key is ordinary and must be lost on defeat.
- Do not infer persistence from key names or rarity.
- If a currently registered key lacks authored persistence metadata, treat it as ordinary only when that preserves existing behavior; document every such fallback.

### Banked Materials

- Transfer all remaining run Material Pouch quantities into banked Materials on both voluntary return and defeat.
- Banked Materials cannot be moved to a run, Item Bar, backpack, Key Chain, Memento slot, or Stash.
- Do not implement recipes, crafting, services, salvage output generation, or Material UI.

### Story/Lore/Knowledge

- Persist these authored facts/collectibles in Refuge state or the existing campaign-persistent state, whichever is already the project authority.
- They must survive voluntary return and defeat.
- Do not create new narrative content or invent display behavior.

## Existing system integration

- Locate the current Refuge arrival, New Campaign, defeat, campaign lifecycle, and voluntary-return boundaries before editing.
- Add narrow, testable resolution methods. A failed resolution must not partially transfer or delete state.
- Keep gameplay state separate from UI. Existing Refuge scenes may call the new service, but do not redesign their UI.
- Preserve current combat, Grapple, encounter, map, dialogue, room, item, and equipment behavior unless directly required for a correct state transfer.
- Do not alter the 98 art-only items or activate incomplete content.

## Explicitly out of scope

Do **not** implement:

- active-run autosaves, pre-node/post-node safe points, Continue/resume, or changes to Main Menu ownership;
- inventory, Stash, loadout, party-selection, crafting, training, or upgrade UI;
- recipes, salvage actions, salvage material assignments, material spending, economy values, or authored demo equipment content;
- new combat actions, balance changes, effects, or new event types;
- new dialogue content or room activation;
- a save-version bump.

## Tests

Add focused tests for at least:

- v3 round-trip persistence of populated Refuge state;
- compatibility loading of existing v3 envelopes with `refuge_snapshot == {}`;
- transactional malformed-Refuge rejection;
- selected-party order persistence and current default order;
- preparation-to-run move semantics with no duplication;
- Stash safety and transactional item/equipment moves;
- persistent loadout/equipment instance ownership;
- defeat: equipment and Mementos survive, Item Bar/backpacks/ordinary Rusty Key are lost, Materials bank, Story/Lore/Knowledge persist;
- voluntary return: Materials bank and equipment/Mementos return with condition preserved;
- banked Materials cannot be withdrawn into a run;
- Save Envelope v3 remains at version 3 and `active_run_snapshot == null`;
- existing new-campaign, save-slot, Item Bar, Rusty Key, and campaign-lifecycle behavior remains valid.

Use the isolated Godot runner. Do not fix unrelated baseline failures.

## Validation

Run:

- `python3 tools/validate_project.py`
- `python3 tools/test_run_regression_suite.py`
- `python3 tools/run_regression_suite.py`
- `git diff --check`

Compare the complete suite to the accepted Milestone 4 baseline: **19 passing / 15 failing across 34 scripts**. No script may newly fail.

## Manual Godot QA

Provide concrete steps to verify:

1. New Campaign and default party order still work;
2. reaching the Refuge creates/persists a valid v3 Refuge snapshot;
3. a save/load round trip preserves Refuge-owned equipment condition, loadouts, preparation state, Stash, and banked Materials;
4. voluntary return banks Materials and returns equipment/Mementos correctly;
5. defeat loses only the explicitly disposable run domains and preserves protected domains;
6. Main Menu, existing saves, Item Bar, keys, combat, and Refuge screens still work;
7. no inventory/Stash UI, crafting, active-run autosave, Continue/resume, or new room content was accidentally introduced.

## Completion report

Report:

- exact Refuge snapshot schema and state ownership;
- changed files;
- run-start, voluntary-return, and defeat transfer rules implemented;
- any unspecified ordinary-consumable return policy left intentionally unchanged;
- compatibility behavior for empty Milestone 2 v3 Refuge snapshots;
- focused/full-suite test comparison;
- manual QA results/blockers;
- suggested commit message.

Do not commit. Stop after implementation and report for review.
