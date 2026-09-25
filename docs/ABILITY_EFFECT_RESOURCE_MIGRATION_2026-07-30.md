# Ability Effect Resource Migration

**Date:** 2026-07-30  
**Status:** Implemented checkpoint

## Result

`AbilityDefinition.EffectType` and its controller switch have been removed.
Each ability now owns an ordered `Array[AbilityEffectDefinition]`, and
`AbilityEffectResolver` executes direct effects after the controller validates
the target and commits Action/MP costs once.

The reusable UI was not changed. It continues to read identity, description,
cost and availability from `AbilityDefinition`.

## Migrated without behaviour changes

- Lysandra — Blood Riposte
- Mira — Find the Catch
- Mira — Thrown Dart
- Mira — Blight Bomb, including shared AOE roll and Poison after HP damage
- Seraphine — Light Arrow
- Seraphine — Heal
- Seraphine — Cleanse
- Seraphine — Bless
- Seraphine — Ward of Grace
- Red-Wax Acolyte — Crimson Blessing and Ember Ward
- Blood Nun — Communion

## Retained spell catalogue

`data/abilities/retained_spell_catalog.tres` contains:

- **Dispel Magic** — Novice Light; removes one removable magical status,
  Bless or Ward from either faction in the caster's zone.
- **Slow** — Novice Earth; opposed Earth/Personality versus
  Athletics/Endurance. Success removes one current Action, lowers maximum
  Actions by one and limits Move to one step for three ticks.
- **Regeneration** — Expert Body; restores one HP at side-phase start for
  three ticks, before damage-over-time. It ends at zero HP and can be
  dispelled.
- **Cure** — Master Body; restores HP equal to a Body/Personality check,
  minimum one. It is authored as a future replacement for Heal.

These spells are mechanically executable but are not granted to the starting
Level 1 loadout. This preserves the approved tutorial balance and the RAV tier
boundary. A later progression Resource will add Dispel/Regeneration and
replace Heal with Cure when their unlock nodes are purchased.

## Runtime ownership

- `.tres` files contain immutable definitions only.
- `BattlerState` owns current HP, MP, Actions, Bless, Ward and other battle
  state.
- `StatusInstance` owns status source, duration progress, periodic damage and
  periodic healing.
- Same-source status reapplication refreshes its runtime instance.
- Dispel removes one deterministic eligible effect without mutating its
  source Resource.

## Regression coverage

`tests/test_ability_resources.gd` checks:

- every existing kit uses composed effects;
- Blight Bomb still carries Poison through its attack effect;
- the retained catalogue contains the four approved spells;
- Regeneration ticks before damage effects;
- Dispel removes Regeneration;
- Cure performs roll-scaled healing;
- Slow applies its locked Action and movement penalties.

