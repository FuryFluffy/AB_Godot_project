# Abyssal Bloom — RAV Spell and Weapon Adaptation Review

**Date:** 2026-07-30  
**Status:** Design proposal for approval; not yet canonical  
**Source reviewed:** `RAV_Rulebook_Translated.md`, all 108 spells

## 1. Decisions already preserved

- The existing Level 1 heroine kits remain intact.
- Mira retains **Blight Bomb** as a non-magical, thrown BattleZone AOE.
- Seraphine retains **Light Arrow**, **Heal**, **Bless**, **Cleanse**, and
  **Ward of Grace**.
- Lysandra retains **Blood Riposte**.
- Chained Parry is treated as provisionally working. Its penalty remains
  `-1d10`, then `-2d10`, then `-3d10`, without reopening the implementation.
- Tabletop RAV content is not automatically canonical. Every adopted spell is
  rewritten for the digital combat rules.

## 2. Layer 1 tutorial balance rule

Layer 1 enemies receive `-1`, to a minimum of zero, in:

- all five Attributes;
- every Skill Level;
- every protection proficiency level;
- Order.

The following are deliberately unchanged:

- HP and MP;
- maximum Actions;
- equipment and condition;
- abilities and AI rulebooks;
- status values;
- Grapple stages and Grapple effects;
- enemy category.

This lowers enemy accuracy, damage, Dodge, Armor/Shield Defense, Parry,
spellcasting, Grapple entry pools, and Momentum frequency without erasing
enemy identity or turning every encounter into a one-hit fight.

| Enemy | Attributes after pass (M/A/E/I/P) | Order | Skill levels | Protection |
| --- | --- | ---: | --- | --- |
| Hollow Servant | 2 / 0 / 2 / 0 / 0 | 1 | Unarmed 2, Athletics 0 | Cloth 0 |
| Knife Footman | 1 / 3 / 1 / 0 / 0 | 3 | Dagger 2, Athletics 2, Awareness 1 | Leather 0, Shield 0 |
| Prayer-Rag Novice | 0 / 1 / 1 / 1 / 3 | 2 | Dark 2, Mind 1, Staff 0, Knowledge 1 | Cloth 0 |
| Corrupted Butler | 2 / 2 / 3 / 1 / 3 | 4 | Unarmed 2, Slings 2, Athletics 2, Awareness 1 | Cloth 0 |
| Red-Wax Acolyte | 1 / 1 / 3 / 2 / 4 | 3 | Light 3, Body 2, Staff 1, Awareness 2 | Cloth 1 |
| Blood Nun | 3 / 2 / 4 / 3 / 5 | 3 | Lash 3, Light 3, Body 3, Athletics 2, Awareness 3 | Chain 2 |

## 3. Digital spell rules

These rules apply to every adopted spell:

1. Casting normally costs 1 Action plus the listed MP.
2. Damaging spells use the relevant Magic Skill and the heroine's authored
   casting Attribute.
3. Magic cannot be Parried. Projectile, line, and AOE spells may be Dodged,
   blocked with Armor, or blocked with a Shield unless the spell explicitly
   changes those permissions.
4. AOE spells make one shared attack roll. Each affected target resolves its
   own Defense against that result.
5. Hostile non-damaging magic must never apply major control automatically.
   It uses a Resist reaction or an opposed resistance check.
6. Tabletop minutes become combat ticks, activations, rounds, encounters, or
   descent-level limits.
7. Full invulnerability, unavoidable damage, permanent control, instant kills,
   resurrection, and unrestricted battlefield-wide damage are not ported
   literally.
8. Multiple RAV checks become one roll with a dice modifier. This preserves the
   locked one-roll AOE rule and makes the log understandable.
9. Elemental protection reduces matching HP/equipment damage by a small fixed
   amount. It is represented by one reusable effect type, not four hard-coded
   controller branches.
10. Every spell is a Godot Resource composed from reusable targeting, cost,
    roll, damage, healing, status, movement, summon, and duration effects.

## 4. Catalogue decisions

### Decision key

- **Keep now:** useful to the current trio or required by the shared spell
  foundation.
- **Keep later:** canonical concept for a later heroine, enemy, or exploration
  system.
- **Rework now/later:** retain the fantasy and name, but replace unsafe or
  tabletop-only mechanics.
- **Merge:** retain the function inside another spell, status, template, or
  upgrade; do not create a separate command.
- **Drop:** not useful or incompatible with Abyssal Bloom.

### 4.1 Fire

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Flame Arrow | Keep later | Standard 1-zone Fire projectile; HP damage may enable later Burning upgrades. |
| Novice | Torch | Keep later | Exploration interaction/light state, not a battle command. |
| Novice | Flame Tongue | Keep later | Weapon enchantment for 3 ticks; +1 Fire damage after HP damage and Burning at a threshold. |
| Novice | Fire Protection | Merge | Instance of the shared Elemental Protection effect. |
| Expert | Haste | Rework later | +1d10 Defense and one once-per-round action enhancement; applies Slow when it expires, not a full Stun. |
| Expert | Engulf | Keep later | Short-range Fire attack; sufficient HP damage applies Burning. |
| Expert | Fireball | Rework later | Target one BattleZone; one shared Fire roll, individual Defenses, normal friendly fire, Burning on HP damage. |
| Master | Flame Shield | Keep later | Fire protection plus 1 retaliatory Fire damage against an adjacent attacker, capped once per attack. |
| Master | Hellfire | Rework later | Line AOE with one Fire roll and a dice bonus; no separate roll per target. |
| Grand Master | Black Flame Storm | Rework later | Ultimate selecting one safe BattleZone and attacking all other eligible zones; once per battle, high MP, normal friendly fire. |

### 4.2 Air

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Feather Fall | Keep later | Negates falling and authored pit/height terrain damage for 3 ticks. |
| Novice | Detect Smells | Merge | Exploration-sense upgrade; no separate combat button. |
| Novice | Wind Arrow | Keep later | 1-zone Air projectile that ignores 1 Armor or Shield Defense success. |
| Novice | Air Protection | Merge | Instance of the shared Elemental Protection effect. |
| Expert | Levitate | Keep later | Ignores ground hazards and ground-triggered reactions; does not grant unrestricted movement. |
| Expert | Wind Shield | Rework later | The next incoming attack loses a fixed number of successes; no absolute damage immunity. |
| Expert | Storm Arrow | Rework later | Single-target Air attack with reduced splash damage to other occupants of the target Anchor/Zone. |
| Master | Fly | Keep later | Requires authored vertical terrain; grants hazard immunity and special movement, not free movement anywhere. |
| Master | Invisibility | Rework later | Hidden status; cannot be directly targeted, remains vulnerable to AOE, ends after a hostile action. |
| Grand Master | Star Storm | Rework later | High-cost target-zone AOE using one shared Air roll with a large dice bonus. |

### 4.3 Water

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Water Arrow | Keep later | Standard 1-zone Water projectile. |
| Novice | Find Water | Merge | Exploration-sense interaction; no separate battle command. |
| Novice | Awake | Merge | Cleanse upgrade that removes Sleep or similar incapacitation. |
| Novice | Water Protection | Merge | Instance of the shared Elemental Protection effect. |
| Expert | Acid Arrow | Keep later | Water attack; after Defense, damages the equipment that absorbed damage or torso armor if none was used. |
| Expert | Water Walk | Keep later | Authored water-terrain traversal; no effect on maps without water. |
| Expert | Poison Mist | Rework later | BattleZone AOE with one shared roll; HP damage applies Poison; normal friendly fire. |
| Master | Ice Arrow | Rework later | Water projectile applying Slow/Frozen to metal-armored targets after HP or equipment damage. |
| Master | Town Portal | Drop | Conflicts with the node-map/descent structure and Refuge-return rules. |
| Grand Master | Boil Blood | Rework later | Ignores equipment absorption but remains Dodge/Resist eligible; boss-immune or reduced against bloodless targets. |

### 4.4 Earth

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Rock Arrow | Keep later | Standard 1-zone Earth projectile. |
| Novice | Tremorsense | Merge | Exploration sense plus detection through authored sight blockers. |
| Novice | Slow | Keep now | Uses the existing Slow status: remove one current Action and halve movement for its duration. |
| Novice | Earth Protection | Merge | Instance of the shared Elemental Protection effect. |
| Expert | Stone Skin | Keep later | +1d10 to Defense for 3 ticks. |
| Expert | Insect Swarm | Rework later | Caster-zone AOE using one shared Earth roll; normal friendly fire. |
| Expert | Stun | Rework later | Opposed control spell; on success applies the existing bounded Stunned status. |
| Master | Rock Blast | Keep later | Target-zone AOE with one shared Earth roll. |
| Master | Turn to Stone | Rework later | Short petrification with resistance and boss protection; never permanent, normally ends after one activation or on damage. |
| Grand Master | Stone to Flesh | Merge | A Cleanse/Remove Curse interaction for Petrified; no reason for a permanent command without Petrified content. |

### 4.5 Light

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Light Arrow | Keep now | Already implemented: 1-zone Light/Personality attack, 1 MP, cannot be Parried. |
| Novice | Turn Undead | Rework later | Applies Repelled to undead in the caster's zone after resistance; does not permanently disable their AI. |
| Novice | Dispel Magic | Keep now | Removes one removable magical effect from an ally or enemy in the caster's zone. |
| Novice | Bless | Keep now | Already implemented: the target's next Attack deals at least 1 HP/equipment damage after resolution. |
| Expert | Prayer | Rework later | Sanctuary effect that heavily reduces the next attack; no total invulnerability. |
| Expert | Bright Arrow | Keep later | Light Arrow upgrade that ignores magical wards/protection, not ordinary Armor or Dodge. |
| Expert | Destroy Undead | Rework later | Executes a low-HP Standard undead target; Elites/Bosses instead take bonus Light damage. |
| Master | Sun Arrow | Rework later | Radiant line attack. The tabletop “cannot be used indoors” restriction is removed because the game is set inside the Castle. |
| Master | The Hour of Life | Merge | Long-duration Bless becomes an upgrade to Bless, not another ability button. |
| Grand Master | The Day of Life | Rework later | Once-per-descent group heal, MP recovery, and curse cleanse with capped values; never a full reset during battle. |

### 4.6 Dark

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Dark Arrow | Keep later | Standard 1-zone Dark projectile. |
| Novice | Curse | Keep later | Target loses 1 success from its next Attack after a successful hostile spell check. |
| Novice | Vampiric Aura | Keep later | Weapon enchantment healing 1 HP after each qualifying damage threshold, capped once per attack. |
| Novice | Reanimate | Rework later | Creates one temporary summon from a defeated non-boss enemy; strict summon cap. |
| Expert | Death Cloud | Rework later | Target-zone Dark AOE with one shared roll and normal friendly fire. |
| Expert | Control Undead | Merge | Upgrade/command mode for Reanimate summons, not a separate spell slot. |
| Expert | Death Curse | Keep later | Target takes +1 damage from qualifying attacks for a bounded duration after resistance. |
| Master | Pain Mirror | Rework later | Reflects a capped amount of HP damage and cannot reflect reflected damage. |
| Master | Dark Blessing | Merge | Multi-element version of shared Elemental Protection. |
| Grand Master | Sacrifice | Rework later | Consumes one defeated enemy for capped party HP/MP restoration; does not use the target's full maximum pools. |

### 4.7 Body

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Heal | Keep now | Already implemented: restore 1 HP in the caster's BattleZone for 1 MP. |
| Novice | Harm | Keep later | Short-range Body attack dealing physical/magical HP damage. |
| Novice | Speed | Rework later | Target gains one enhanced Move command or bonus step; does not duplicate unrestricted Actions. |
| Novice | Cleanse | Keep now | Already removes Poison; shared effect architecture later expands it to other authored removable statuses. |
| Expert | Regeneration | Keep now | Restore 1 HP at the target's activation start for 3 ticks; ends at zero HP. |
| Expert | Empower | Rework later | +1d10 to checks using one selected Attribute for 3 ticks; does not mutate the base sheet. |
| Expert | Wound | Keep later | Blocks healing for one activation after resistance; bosses may shorten the duration. |
| Master | Cure | Keep now | Rolled Body/Personality heal; this is an upgrade path from Heal rather than a second permanent button. |
| Master | Break | Rework later | Physical execute against low-HP Standards in the caster's zone; Elites/Bosses take fixed bonus damage instead. |
| Grand Master | Life Bloom | Rework later | Group heal in the caster's zone using one Body roll with a dice bonus and a high MP cost. |

### 4.8 Mind

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Hear Thoughts | Keep later | Dialogue/exploration interaction and enemy-intent insight where authored. |
| Novice | Mind Blast | Keep later | Mind attack resisted by Personality; ignores equipment absorption but not resistance. |
| Novice | Fear | Keep later | Applies Fear for one activation after resistance. |
| Novice | Brave | Merge | Cleanse/Resolve-support effect that removes Fear and grants brief Fear immunity. |
| Expert | Frenzy | Rework later | After resistance, target spends its next available Action attacking the nearest legal creature; never an indefinite AI takeover. |
| Expert | Charm | Rework later | Prevents hostile actions against the caster for one activation after resistance; target does not become a controllable ally. |
| Expert | Accuracy | Keep later | +1d10 to Attack checks for 3 ticks or until a capped number of attacks. |
| Master | Feeblemind | Rework later | Silence plus a penalty to Mind/spell checks for one activation; no undefined “cannot think rationally” state. |
| Master | Psychic Blast | Rework later | Strong Mind attack that ignores equipment but remains resistible. |
| Grand Master | Enslave | Rework later | Short, resisted control reserved for bosses/specialists; direct control lasts at most one activation and never uses a simple Attribute threshold. |

### 4.9 Spirit

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Find Souls | Merge | Exploration detection shared with other sense effects. |
| Novice | Spirit Arrow | Keep later | Standard 1-zone Spirit projectile. |
| Novice | Luck | Drop | Abyssal Bloom removed the Luck resource. |
| Novice | Fate | Merge | If rerolls return later, implement as a general Fate effect; do not create it now. |
| Expert | Misfortune | Merge | Function overlaps Curse; use the shared next-check penalty effect. |
| Expert | Soul Arrow | Keep later | Spirit Arrow upgrade that ignores 1 Defense success. |
| Expert | Remove Curse | Keep later | Removes one removable curse in battle or powers a Refuge/exploration service. |
| Master | Spirit Whip | Rework later | Applies temporary Wounded/max-HP reduction after resistance; cannot permanently alter the character sheet. |
| Master | Share Life | Rework later | Redistributes current HP among living allies in the caster's zone; cannot revive or reduce an ally below 1 HP. |
| Grand Master | Resurrection | Drop | Abyssal Bloom uses zero-HP defeat and explicit revival, not RAV death/resurrection. |

### 4.10 Nature's Veil

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Speak with Nature | Keep later | Authored dialogue/exploration interaction for the future Druid. |
| Novice | Find Haldjas | Drop | Depends on RAV ancestry/lore that is not part of Abyssal Bloom. |
| Novice | Vine Grasp | Keep later | Earth attack that can apply Entangled after HP damage or resistance. |
| Novice | Glamour | Keep later | Authored illusion interaction and temporary Hidden/Disguise state. |
| Expert | Whispering Wind | Drop | Has no meaningful function in the current party-based, room-scale structure. |
| Expert | Barkskin | Rework later | +2d10 Armor Defense through a temporary bark layer with its own bounded condition. |
| Expert | Entangle | Rework later | Applies reduced movement to creatures in a target BattleZone after individual resistance; normal friendly fire. |
| Master | Call of the Forest | Keep later | Summons one authored animal companion using the shared summon system. |
| Master | Growth Spurt | Rework later | Creates a temporary zone hazard that blocks or increases the cost of enemy movement. |
| Grand Master | Wrath of the Forest | Rework later | High-cost multi-zone storm using one shared roll; applies movement and attack penalties, with a selected safe zone. |

### 4.11 Essence Shaping

| Tier | Spell | Decision | Digital adaptation |
| --- | --- | --- | --- |
| Novice | Stone Shape | Keep later | Authored environment interaction; may create a temporary cover prop where allowed. |
| Novice | Cave Sense | Merge | Exploration-sense effect shared with Tremorsense. |
| Novice | Harden | Keep later | Protects an authored terrain prop or cover object for a bounded duration. |
| Expert | Earthquake | Rework later | Target-zone control effect applying Slow or Knockdown after individual resistance. |
| Expert | Stone Armor | Merge | Stronger branch of Stone Skin/shared temporary armor rather than a separate core effect. |
| Expert | Tunneling | Drop | Free tunneling would invalidate authored rooms, node routes, keys, and event gating. |
| Master | Stone Knowledge | Keep later | Lore/exploration interaction for authored stone structures. |
| Grand Master | Cave Dominion | Drop | World-altering GM fiat is incompatible with authored tactical maps and roguelite routes. |

## 5. Recommended implementation slice

Do not implement all 108 spells at once.

The first spell-system milestone should support the existing Seraphine kit and
only these additions:

1. **Dispel Magic**
2. **Slow** as a test hostile status spell
3. **Regeneration**
4. **Cure** as the first roll-scaled heal/Heal upgrade

This slice exercises:

- ally and enemy targeting;
- damaging and non-damaging magic;
- effect removal;
- periodic effects;
- hostile status resistance;
- rolled healing;
- upgrade replacement without filling the command panel with obsolete spells.

Mira's Blight Bomb remains in the same generic ability system but remains
Alchemy, not magic.

## 6. Required ability architecture

The current `AbilityDefinition.EffectType` enum has one hard-coded controller
branch for each implemented effect. That is acceptable for the prototype but
will not scale to a spell catalogue.

Replace it with composition:

```text
AbilityDefinition
├── identity, tags, school, tier
├── costs and targeting
├── roll/defense profile
└── effects: Array[AbilityEffectDefinition]
    ├── DamageEffect
    ├── HealEffect
    ├── ApplyStatusEffect
    ├── RemoveStatusEffect
    ├── ModifyCheckEffect
    ├── ModifyDefenseEffect
    ├── MoveEffect
    ├── SummonEffect
    └── TerrainEffect
```

Each effect remains an Inspector-editable Godot Resource. The controller
validates and commits the ability once, then a resolver executes its effects
in authored order. Existing abilities are migrated without visual UI changes.

The progression resource should store unlocked ability IDs. Upgrade nodes may:

- replace a lower spell with an upgraded version;
- add an effect to the spell;
- increase range, duration, dice, or effect magnitude;
- reduce MP cost;
- change targeting.

## 7. Weapon families, upgrades, and Refuge techniques

Weapon identity and learned technique must remain separate:

- **Weapon family property:** always active while that family is equipped.
- **Weapon rank:** improved at the Bloom Refuge and stored in runtime/save
  weapon state.
- **Technique:** learned at the Bloom Refuge, stored on the heroine, and usable
  only while a compatible weapon family is equipped.
- **Unique weapon:** may add extra effects such as Burning on a damage
  threshold without replacing the family property.

The current single `WeaponDefinition.property` enum always has magnitude 1.
Replace it with an array of Inspector-editable property resources plus an
upgrade curve.

### Proposed rank progression

| Family | Rank I identity | Rank II | Rank III |
| --- | --- | --- | --- |
| Sword | Ignore 1 Dodge success | Ignore 2 Dodge; +1d10 Attack | Ignore 3 Dodge; +2d10 Attack |
| Dagger | Ignore 1 Parry success | Ignore 2 Parry; +1d10 Attack | Ignore 3 Parry; +2d10 Attack |
| Axe | Ignore 1 Armor success | Ignore 2 Armor; +1d10 Attack | Ignore 3 Armor; +2d10 Attack |
| Mace | Ignore 1 Shield success | Ignore 2 Shield; +1d10 Attack | Ignore 3 Shield; +2d10 Attack |
| Staff | Remove 1 current Action after qualifying HP damage | Lower the damage threshold; +1d10 Attack | Trigger on any HP damage; +2d10 Attack; still remove at most 1 Action |
| Bow | +1d10 at long range | +2d10 at long range; +1d10 otherwise | +3d10 at long range; +2d10 otherwise |
| Unarmed | Existing critical follow-up identity | +1d10 Attack and improved trigger | +2d10 Attack and one capped follow-up per round |
| Slings/Darts | Reduce shared-engagement ranged penalty by 1d10 | Ignore the penalty; +1d10 Attack | Ignore the penalty; +2d10 Attack |
| Lash | Reach and Bleed identity | +1d10 Attack; easier Bleed threshold | +2d10 Attack; stronger/capped Bleed |

Action denial, free attacks, and statuses need individual caps; they should not
blindly scale to magnitude 3 just because Dodge/Armor/Parry negation does.

### Example Refuge-taught techniques

| Heroine/family | Early technique | Later technique |
| --- | --- | --- |
| Lysandra — Sword | Dread Slash: committed heavy Sword attack with a dice bonus | Crimson Lunge: Move one step and make a Sword attack as one authored action |
| Lysandra — Dagger | Guardbreaker: Dagger attack with additional Parry negation | Reversal: conditional counter-technique after a successful Parry |
| Mira — Dagger | Feint: mark a target and improve the next Dagger attack | Twin Cut: two attack pools against one target with one Defense |
| Mira — Slings/Darts | Pinning Dart: HP damage applies Slow | Ricochet: secondary reduced attack against another legal target |
| Seraphine — Staff | Rebuke: Staff attack that pushes or removes one current Action | Processional Guard: defensive Staff stance supporting an adjacent ally |

These names/effects are proposals. They should be approved separately from the
RAV spell catalogue.

## 8. Next implementation order

1. Approve or adjust this catalogue.
2. Refactor abilities into composed effect Resources while preserving all
   current kits.
3. Implement Dispel Magic, Slow, Regeneration, and Cure.
4. Add weapon family/rank property Resources.
5. Add persistent Refuge technique unlocks.
6. Author the first real Layer 1 BattleZone layout and use it to test spell
   range, line, AOE, hazards, and movement techniques.
