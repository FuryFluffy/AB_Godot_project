# Weapon Family and Rank Resource Migration

## Runtime model

The weapon system now uses four separate layers:

1. `WeaponFamilyDefinition` stores the shared family identity and its ordered rank Resources.
2. `WeaponRankDefinition` stores one rank's Attack dice bonus and family-effect Resources.
3. `WeaponDefinition` stores one actual weapon, its family reference, base check, range, durability and unique-effect Resources.
4. `WeaponState` stores live condition and the effective family rank for one combatant.

Definitions remain immutable during combat. `EquipmentLoadout.main_hand_family_rank` currently supplies the effective test rank. Persistent Refuge/save progression can replace that value later without rewriting any `.tres` definition.

## Implemented family curves

| Family | Rank I | Rank II | Rank III |
| --- | --- | --- | --- |
| Sword | Ignore 1 Dodge | Ignore 2 Dodge, +1d10 Attack | Ignore 3 Dodge, +2d10 Attack |
| Dagger | Ignore 1 Parry | Ignore 2 Parry, +1d10 Attack | Ignore 3 Parry, +2d10 Attack |
| Staff | Remove 1 Action after HP damage | Remove 2 Actions, +1d10 Attack | Remove 3 Actions, +2d10 Attack |

All current heroine and Layer 1 enemy loadouts remain explicitly set to Rank I.

## Unique effects

Unique effects are composed on the individual weapon and do not replace its family effects.

- Knife Footman's dagger: Dagger family plus Bleed after HP damage.
- Blood Nun lash: Bleed after HP damage.
- Red Wax Drip: Burning after HP damage.
- Example Ember Sword: Sword family plus Burning after 3+ HP damage.
- Example Accurate Sword: Sword family plus one flat Attack success after rolling.

## Godot Inspector editing

- Edit shared family identity and rank list in `data/weapon_families/`.
- Edit rank bonuses in `data/weapon_ranks/<family>/`.
- Edit family-effect magnitudes in `data/weapon_effects/families/<family>/`.
- Edit unique weapon effects in `data/weapon_effects/unique/`.
- Edit or duplicate actual weapons in `scripts/data/equipment/weapons/`.
- Set the currently equipped rank in the character's `EquipmentLoadout`.

Refuge-taught techniques remain ordinary `AbilityDefinition` Resources. Set `required_weapon_family_id` and `minimum_weapon_family_rank` on the technique; combat availability then enforces the equipped family and rank. A family also has a `compatible_techniques` array ready to catalogue its Refuge curriculum, but no technique is silently granted by this migration.
