# MP-Powered Weapon Arts and Persistent Progression — 2026-08-03

This checkpoint completes the first playable Refuge weapon-technique slice
without changing the confirmed Rank I weapon properties or Layer 1 enemy
balance.

Weapon arts express internal MP use: each is a normal one-Action attack that
spends 2 MP, rather than a two-Action attack with bonus dice.

## Initial weapon arts

| Family | Technique | Requirement | Cost | Effect |
| --- | --- | --- | --- | --- |
| Sword | Forced Blade | Sword Rank I | 1 Action + 2 MP | +1 flat damage and one additional Dodge success ignored |
| Dagger | Knife Dance | Dagger Rank I | 1 Action + 2 MP | Separate attacks against up to two distinct legal targets; if only one is legal, attack it once; +1 flat damage on each hit |
| Staff | Jaw Break | Staff Rank I | 1 Action + 2 MP | +1 flat damage; a hit Stuns a target that used no Defense |

Flat damage is added after defense only when at least one Attack success
remains, then passes through the normal armor/shield allocation. Knife Dance
rolls separately for each target, and each target receives its own reaction.
The cost is paid once. Jaw Break treats Skip, including an automatic zero-Action
Skip, as no Defense; attempting Dodge, Armor, Shield, or Parry prevents the Stun
condition even when that defense roll fails.

Weapon-art attacks clone the equipped weapon into a transient attack profile.
They therefore retain its family, rank, range, weapon skill and Attribute,
unique effects, and durability rules. Technique-only weapon effects are then
layered on top. Shared `.tres` definitions are never modified during combat.

## Persistent state

`HeroineProgressionState` owns:

- the heroine id;
- per-family weapon ranks;
- unlocked ability ids;
- conversion to and from a save-friendly Dictionary snapshot.

`RunState.heroine_progression_snapshot` carries this data between encounters.
`BattleBootstrap` applies it when constructing each heroine's `BattlerState`,
and `EncounterOutcome` returns it to the run. Restarting a battle preserves the
same progression state.

Innate abilities remain in `BattlerDefinition.abilities`. Refuge-taught
abilities are catalogued separately in `unlockable_abilities` and only become
available when their id is present in the heroine's progression state.

## Temporary developer grants

The main controller exports
`developer_grant_weapon_techniques_on_new_run`, currently enabled for testing.
Directly running the combat scene uses the matching
`developer_grant_weapon_techniques_when_run_directly` flag. Disable the flags
to verify a clean starting kit without removing any Resource or progression
data.

The underlying test API is:

- `RunState.grant_developer_weapon_techniques()`;
- `RunState.unlock_heroine_ability(heroine_id, ability_id)`;
- `RunState.set_heroine_weapon_family_rank(heroine_id, family_id, rank)`.

These methods are the temporary bridge until the Bloom Refuge training UI owns
the same operations and Bloom costs.

## Inspector authoring

- Technique Resources: `data/abilities/weapon_techniques/`
- Technique catalogue: `data/abilities/weapon_technique_catalog.tres`
- Family curricula: `data/weapon_families/`
- Technique-only weapon effects: `data/weapon_effects/techniques/`
- Per-heroine unlockable lists: `data/battlers/heroines/`

Duplicate the closest technique Resource, give it a unique `ability_id`, set
its family/rank requirement, and add it to both the family's
`compatible_techniques` array and the intended heroine's
`unlockable_abilities` array. A completely new combat mechanic still requires
a new effect Resource script; recombining supported attack and weapon effects
does not.
