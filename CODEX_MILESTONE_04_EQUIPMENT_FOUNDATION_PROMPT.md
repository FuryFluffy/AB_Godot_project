# Milestone 4 — Equipment Instances and Personal Loadouts

You are working on Abyssal Bloom, a production Godot 4.7 desktop project.

Read root `AGENTS.md`, Milestones 1–3 prompt files and completion documents, then inspect the current combat equipment, weapons, armor/shield/durability handling, heroine kits, `RunState`, `RunInventoryState`, and relevant tests before editing.

Extend the project’s working combat/equipment architecture. Do not replace current weapon or combat systems for aesthetic cleanliness.

## Objective

Create the runtime foundation for **authored equipment definitions**, **per-instance condition**, and **personal equipment loadouts**.

The target personal loadout model is:

- Main Hand — one slot;
- Off Hand — one slot;
- Armor — one slot;
- Memento — one slot, already represented by Milestone 3’s per-heroine Memento state.

There is deliberately no single generic “Weapon slot.”

This milestone must retain the current working weapons, armor/shield behavior, techniques, and durability flow. It introduces a consistent domain model that later Refuge persistence, Stash, defeat, salvage, crafting, and UI milestones will use.

## Locked rules

- Equipment is authored, not procedural. Do not create random affixes, rolls, upgrades, or generated equipment.
- Equipment ownership is personal to a heroine. Do not make equipment party-shared.
- Main Hand and Off Hand are distinct slots.
- A valid Off Hand may be a shield, off-hand weapon, focus, or other explicitly authored compatible equipment. Do not infer compatibility from display names.
- Each equipment instance must identify its authored definition and track current condition independently.
- Broken equipment loses **all positive base and enchantment effects** but retains **all negative effects**.
- A heroine whose broken Main Hand has no valid replacement uses the existing unarmed fallback; do not invent a new combat action.
- Mementos remain one per active heroine and must not become an ordinary item-stack or Item Bar entry.
- Every destructible equipment definition must explicitly declare `salvage_material_id`. Do not invent material IDs or salvage values for un-authored equipment.
- Equipment definitions and instances use stable IDs. Do not reintroduce legacy item aliases.
- Preserve the existing weapon-durability behavior unless a focused migration is required to express it through the instance model.

## Scope boundaries

Implement the data model, validation, and minimal integration necessary for existing combat equipment to use it.

Do **not** implement:

- a new equipment/inventory/Refuge UI or drag/drop;
- persistent Refuge loadouts, preparation inventory, Stash, or banked Materials;
- active-run autosaves, Continue/resume, or a Save Envelope v4;
- defeat-loss rules, voluntary-return rules, salvaging, or crafting;
- authored demo equipment content that has not already been defined in the repository;
- random affixes, upgrades, enchantment generation, economy values, recipes, or new item effects;
- visual sprite/presentation changes;
- changes to the 98 art-only workbook rows.

Save Envelope v3 must remain structurally unchanged, with `active_run_snapshot == null`.

## Required data and behavior

Use the project’s established naming style and existing Resources/classes. The following are behavioral requirements, not a demand for specific class names.

### Authored definitions

- Extend existing equipment-related Resources where sufficient; avoid duplicate parallel definition types.
- Define explicit authored metadata for:
  - stable definition ID;
  - allowed slot or slots;
  - condition maximum;
  - whether the definition is destructible;
  - `salvage_material_id` when destructible;
  - authored positive effects;
  - authored negative effects.
- Preserve current descriptions, techniques, combat effects, and balance values.
- A non-destructible definition must not require a fake salvage material.
- Reject malformed definitions and invalid slot compatibility through focused validation.

### Equipment instances

- Model each instance separately from its definition.
- An instance must have a deterministic, serializable identity suitable for later persistence; do not use a live object reference as identity.
- An instance records its definition ID and current condition.
- Current condition is clamped to the definition’s valid range.
- Condition mutation must be transactional: invalid damage/repair input must not partially mutate state.
- Instances may expose authored effective effects, but must not invent new effect-handler families.
- At zero condition, effective positive effects are suppressed; negative effects remain effective.

### Personal loadouts

- Each active heroine has independent Main Hand, Off Hand, and Armor slots.
- Integrate the already-established per-heroine Memento slot rather than duplicating Memento state.
- Validate every equip/unequip assignment against the definition’s explicit allowed slots.
- Reject missing heroine IDs, unknown instance IDs, duplicate assignment of one instance to multiple slots, and incompatible slots without partially mutating the loadout.
- Preserve the existing unarmed fallback when no valid Main Hand is equipped.
- Keep the established current combat weapon/armor/shield consumers operating through the new loadout state or a narrow compatibility adapter. Do not leave two divergent authorities.

### Existing combat and durability

- Locate every existing weapon-condition/durability consumer before editing.
- Route current durability changes to the appropriate equipment instance where this can be done without changing gameplay rules.
- Verify that breakage still produces the established combat behavior, now with positive effects suppressed and negative effects retained.
- Do not change damage numbers, action costs, technique targeting, or Grapple mechanics.
- Do not add a combat equipment-change command unless one already exists. If existing combat equip behavior is present, retain its established one-Action cost.

### Runtime-only boundary

- Equipment/loadout state may exist for the current runtime session.
- Do not persist it in `active_run_snapshot`; it remains `null` in v3.
- Do not create a refuge-persistence shortcut. Persistent ownership and defeat policies are Milestone 5 work.

## Tests

Add or extend focused tests for:

- authored definition validation, including destructible salvage-material requirements;
- serializable instance identity and condition clamping;
- personal Main Hand, Off Hand, Armor, and integrated Memento ownership;
- explicit compatibility enforcement and transactional failure;
- prohibition on assigning one instance twice;
- broken-equipment positive-effect suppression and negative-effect retention;
- unarmed fallback after valid Main Hand removal/breakage;
- current weapon/armor/shield/durability behavior remains intact;
- no Save Envelope v3 contract change, especially `active_run_snapshot == null`.

Use the isolated Godot runner already established. Do not repair unrelated baseline failures.

## Validation

Run:

- `python3 tools/validate_project.py`
- `python3 tools/test_run_regression_suite.py`
- `python3 tools/run_regression_suite.py`
- `git diff --check`

Compare the full suite against the accepted Milestone 3 baseline: **19 passing / 15 failing across 34 scripts**. No script may newly fail.

## Manual Godot QA

Provide exact steps to verify:

1. New Campaign still reaches the opening encounter;
2. existing heroine weapons, techniques, armor, shield, and unarmed fallback work exactly as before;
3. condition loss/breakage still occurs without debugger errors;
4. no equipment screen, Stash, crafting, autosave, Continue, or Refuge-persistence behavior was accidentally introduced.

## Completion report

Report:

- exact definition, instance, and loadout ownership model;
- changed files;
- how current combat durability was bridged;
- any equipment-definition authoring gaps deliberately left inactive;
- confirmation that Save Envelope v3 is unchanged;
- focused test results and full-suite comparison;
- manual QA results/blockers;
- suggested commit message.

Do not commit. Stop after implementation and report for review.
