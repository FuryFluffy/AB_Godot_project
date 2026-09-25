# Milestone 3 — Run Inventory State Domains

You are working on Abyssal Bloom, a production Godot 4.7 desktop project.

Read root `AGENTS.md`, the completed Milestone 1 and Milestone 2 prompt documents, and inspect the existing item, Item Bar, run-state, encounter, exploration, combat, and save-envelope code before editing.

In particular, inspect the current `RunState`, item catalogue/definition model, Item Bar use path, dialogue/event rewards, encounter loadout creation, and Save Envelope v3 boundaries. Extend working ownership models; do not create a parallel inventory implementation.

## Objective

Create the runtime data model and domain operations for the demo's carried-item state:

1. a personal **3 × 5 backpack** for each active heroine;
2. one shared **six-slot Item Bar**;
3. one shared **Key Chain**;
4. one shared run-only **Material Pouch**;
5. one **Memento slot per active heroine**.

This is a state/domain milestone. It establishes safe data ownership and APIs that later UI, Refuge, equipment, defeat, and active-run-save milestones will use.

## Locked domain rules

- All item references use canonical Stable IDs. Do not add aliases or reintroduce legacy IDs.
- The Item Bar has exactly six ordered slots. It is shared by the active party.
- The Item Bar is the only carried inventory domain usable during combat.
- Each active heroine has exactly fifteen ordered backpack slots: 3 columns × 5 rows.
- Backpacks are personal, not shared, and are usable only during exploration. They are not combat-usable.
- Keys are never placed in a backpack or Item Bar. They live only on the shared Key Chain.
- Materials are never placed in a backpack, Item Bar, or Key Chain. They live only in the shared run Material Pouch.
- Each active heroine has at most one equipped Memento reference. Mementos are not Item Bar entries and are not ordinary backpack slots.
- Keep domain state as plain serializable data: Stable IDs, quantities, ordered slot indices, and heroine IDs. Do not store Nodes, Resources, UI controls, or object references.
- Existing initial Item Bar behavior and currently authored reward/use flows must continue to work.

## Scope boundaries

Implement only runtime state and its integration with existing item/reward/use paths.

Do **not** implement:

- drag/drop or a new inventory screen;
- Refuge preparation inventory, Stash, or banked Materials;
- equipment instances, Main Hand/Off Hand, Armor, Shield, equipment condition, or salvage;
- defeat-loss rules or voluntary-return banking;
- item crafting, recipes, upgrades, training, or economy values;
- active-run persistence/autosaves/Continue;
- a Save Envelope v4 or any changes to the v3 envelope contract;
- activation of the 98 art-only workbook items;
- new item effects or balance changes.

`active_run_snapshot` must remain `null` in Save Envelope v3 after this milestone. The new run state is intentionally runtime-only until the active-run safe-point milestone.

## Required model and API behavior

Use the current project naming style and existing classes where appropriate. The following are behavioral requirements, not a demand for specific class names.

### Inventory slots and stacks

- Model an empty slot explicitly and deterministically.
- Represent an occupied item slot with a canonical Stable ID and positive quantity.
- Reject unknown, non-canonical, non-positive, or inappropriate-category item insertions.
- Respect existing item stack-limit metadata where it already exists; do not invent stack limits.
- Adding an item fills compatible existing stacks before empty slots, in deterministic slot order.
- Removing an item consumes from deterministic slot order.
- Moving items between a backpack and Item Bar preserves quantity and respects category/domain restrictions.
- Operations must fail without partially mutating state.

### Item Bar

- Preserve the current six-slot presentation/use contract as far as possible.
- Combat use must resolve items only from the shared Item Bar.
- Existing initial combat loadout must be represented through the new domain state rather than a duplicate legacy list.
- Non-combat-usable items must not enter the Item Bar.

### Backpacks

- Create personal backpacks only for active heroines already established by the current party/run setup.
- Do not silently create a new party-selection system.
- Backpack item use remains unavailable in combat. Do not add a new combat command to expose it.

### Key Chain

- Key-compatible items route to the Key Chain rather than ordinary slots.
- Preserve the currently working Rusty Key generation and lock-consumption behavior, now through the Key Chain.
- Do not implement defeat loss, persistent-key scope, or future key categories beyond representing authored key metadata already present.

### Material Pouch

- Material-compatible items route to the run Material Pouch as Stable ID → positive quantity.
- It is valid for the pouch to be empty in the current playable demo.
- Do not create material definitions, salvage outputs, recipes, banked-material state, or UI.

### Mementos

- Represent a nullable Memento slot per active heroine.
- Reject non-Memento items in that slot.
- Do not implement Memento effects, equipment instances, loading UI, or defeat persistence in this milestone.

### Existing rewards and consumers

Update only necessary existing reward/consumer paths so they route to the correct domain:

- ordinary combat-usable item rewards: Item Bar when space allows;
- exploration-only ordinary items: owner backpack according to the current authored reward context;
- keys: Key Chain;
- materials: Material Pouch;
- Mementos: the appropriate heroine Memento slot only when an authored assignment already exists.

If an authored reward lacks enough ownership information to select a personal backpack or Memento owner safely, preserve the existing behavior and report the design gap. Do not invent a heroine assignment rule.

## Tests

Add focused tests covering at minimum:

- new-run initialization: three active heroine backpacks of 15 slots, one six-slot Item Bar, Key Chain, Material Pouch, and Memento slots;
- Item Bar acceptance/rejection, deterministic stacking, capacity, removal, and transactional failure;
- backpack personal ownership, capacity, deterministic movement, and combat-use exclusion;
- key routing and the existing Rusty Key lock flow;
- material routing and rejection from ordinary item slots;
- Memento slot type/ownership validation;
- canonical Stable-ID validation and no acceptance of legacy IDs;
- preservation of the existing Item Bar’s authored initial loadout and item-use behavior;
- no mutation of Save Envelope v3: `active_run_snapshot` remains `null`.

Keep the existing isolated Godot runner. Do not repair unrelated baseline failures.

## Validation

Run:

- `python3 tools/validate_project.py`
- `python3 tools/test_run_regression_suite.py`
- `python3 tools/run_regression_suite.py`
- `git diff --check`

Compare the full suite to the accepted Milestone 2 baseline: **19 passing / 15 failing across 34 scripts**. No script may newly fail.

## Manual Godot QA

Provide explicit steps to verify:

1. a New Campaign initializes and reaches the opening encounter;
2. the existing Item Bar still displays and consumes its authored items in combat;
3. the Rusty Key reward appears in/uses the Key Chain and opens its authored lock;
4. ordinary rewards still arrive in the correct carried domain;
5. no inventory UI or autosave behavior was accidentally introduced.

## Completion report

Report:

- exact new state domains and their ownership;
- changed files;
- reward-routing decisions and any content-authoring gaps;
- confirmation that Save Envelope v3 is unchanged;
- focused test results and full-suite comparison;
- manual QA results/blockers;
- suggested commit message.

Do not commit. Stop after implementation and report for review.
