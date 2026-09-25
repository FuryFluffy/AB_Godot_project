# Abyssal Bloom — Combat Mechanics Master Reference

**Document status:** Current combat-design reference  
**Version:** 0.4  
**Date:** 2026-07-24  
**Engine target:** Godot 4.7  
**Rules identity:** Adapted RAV d10+ combat for Abyssal Bloom

> **Authority notice:** The full project Master Reference remains the highest project authority. This file is a synchronized, combat-only extract intended for implementation, testing, and future combat-planning chats. When combat rules change, this file and the combat sections of the full Master Reference must be updated together.

---

# 0. Scope and Decision Labels

This document contains the currently accepted rules for:

- d10+ dice resolution;
- Actions, rounds, phases, Order, and Momentum;
- attacks, defenses, reactions, free attacks, and multi-attack checks;
- BattleZones, anchors, occupancy positions, movement, range, cover, and line of sight;
- equipment defense, durability, and damage allocation;
- enemy information and deterministic rulebook AI;
- statuses and phase timing;
- Resolve, Corruption, Grapple, Climax, zero-HP states, revival, and combat defeat.

Decision labels:

- **LOCKED** — accepted design; change only deliberately.
- **PROVISIONAL** — accepted for implementation or testing but expected to be tuned.
- **OPEN** — unresolved.
- **DEFERRED** — intentionally outside the current implementation scope.
- **DEPRECATED** — must not be implemented as current design.

Unless this document explicitly adapts a RAV rule, the RAV mechanical rule remains the baseline. Narrative, races, classes, GM procedures, and unrelated tabletop systems are not imported automatically.

---

# 1. Combat Identity — LOCKED

Abyssal Bloom combat is a side-phase tactical d10+ system in which all three heroines are directly controlled. The player spends Actions in any interleaved heroine order, preserves unspent Actions for reactions, learns enemy behavior through repeated encounters, and makes positioning decisions on an illustrated battlefield without a square or hex grid.

Core principles:

- three Actions is the normal baseline, but individual maximums can differ;
- Actions are spent individually, not through complete heroine activations;
- enemy decisions are hidden on Standard difficulty;
- enemy behavior is deterministic and learnable through authored rulebooks;
- BattleZones determine broad range and AOE scope;
- authored anchors and engagement clusters determine local movement and Adjacency;
- attack rolls are visible after commitment, before Defense selection;
- reactions require available Actions unless an explicit rule says otherwise;
- Resolve and Corruption materially alter Grapple combat;
- Grapple is a deliberate alternate combat route, not merely a loss-of-control status.

## 1.1 Combat implementation snapshot

The verified baseline is the 2026-07-23 Godot 4.7 Ordinary Combat Completion
package.
Armor, shields, Preserve/Destroy, Parry, Counterattack, the generated-Attack
queue, deterministic roll modes, weapon durability, Broken weapons, Order,
Momentum, phase ownership, Action refresh, interleaving, saved reaction
Actions, BattleZones, Anchors, Positions, occupancy, exact two-step movement,
allied pass-through, hostile blocking, threat preview, and the spatial overlay
have been manually confirmed in the Godot web editor. Melee, Reach, ranged,
magic, cover, line of sight, engaged-ranged penalties, stepwise committed
movement, queued Move Reactions, conditional group activation, ordered
individual rulebooks, automatic Enemy Phases, hidden Standard intent, Easy
Forecast, and AI Auto/Step inspection are also user-verified.

The following Ordinary Combat Completion features are also user-verified:

- zone-targeted AOE abilities with one shared Attack roll;
- independent Defense, reactions, equipment, and damage for every AOE target;
- Bleed, Poison, Slow, and Stunned runtime instances;
- same-source refresh, different-source stacking, affected-side phase timing,
  and actual-tick expiry;
- zero-HP Action storage, ordinary-healing restriction, and explicit Revival;
- Victory, Defeat, simultaneous-Defeat priority, and complete Restart;
- Pause, 1×/2×/4× presentation speed, compact logs, and hidden developer
  controls;
- headless ordinary-combat tests.

The cumulative Direct Battlefield Interaction Corrections package is
source-complete and awaiting its focused web-editor playtest. It adds direct
board-click Move route/Position selection, direct board-click AOE BattleZone
selection, a contained and fully toggleable Dev Tools panel, attacker identity
in incoming-attack prompts, and two reserved enemy-entry Positions beside
Lysandra and Mira in the chapel's Altar Left engagement cluster.

The 2026-07-24 correction makes highlighted Move Positions and AOE BattleZones
receive runtime clicks before decorative UI can consume them. It also replaces
the former single Move-reaction opportunity with independent sequential
opportunities for every eligible combatant at the reached Anchor.

Grapple remains design-only and is the next separate milestone after this
focused correction gate.

---

# 2. Core Combat Statistics

## 2.1 Attributes — LOCKED set

| Attribute | Primary combat uses |
|---|---|
| Might | Physical force, heavy weapons, shield use, resisting force, Struggle |
| Agility | Movement, finesse weapons, Dodge, quick actions, Struggle |
| Endurance | Resilience, sustained effort, HP/MP contribution, Struggle |
| Intellect | Learned magic, alchemy, analysis |
| Personality | Conviction, divine magic, presence, emotional resistance |

**Luck is DEFERRED** until the ordinary attack, defense, and reaction loop is stable.

## 2.2 HP and MP — PROVISIONAL scale

Use small success-based values rather than the retired triple-digit JRPG scale.

| Unit type | Approximate HP band |
|---|---:|
| Heroine | 5–9 |
| Standard enemy | 3–6 |
| Elite enemy | 7–10 |
| Major boss | 12–18 |

Provisional starting formulas:

```text
Base HP = Might + Endurance + authored adjustment
Base MP = casting Attribute + Endurance + authored adjustment
```

No ordinary overhealing is permitted. HP stops at maximum unless an effect explicitly grants temporary HP or another separate resource.

## 2.3 Actions — LOCKED

Each battler has:

- `max_actions` — the current maximum for the round;
- `current_actions` — Actions presently available;
- `base_actions` — the unmodified authored baseline.

Three Actions is normal. Some enemies have four base Actions. Effects may grant additional Actions or reduce the Action maximum.

At every Round Start:

1. leftover Actions are discarded;
2. `current_actions` is restored to the battler’s current `max_actions`;
3. opening-round Momentum may then set the losing side to zero Actions.

Most “lose one Action” effects remove one currently available Action. A reduction to maximum Actions must be stated explicitly by the effect.

## 2.4 Resolve and Corruption — LOCKED baseline

Every heroine begins the game with:

```text
Resolve:    100
Corruption: 0
```

Current implementation range:

```text
Resolve:    0–100
Corruption: 0–100
```

Both persist between rooms, battles, and runs. They do not reset automatically.

Future Corruption expansion to 200 and a Corruption-only Grapple route is **DEFERRED**.

---

# 3. Core d10+ Resolution

## 3.1 Dice pool — LOCKED

1. Build the pool from the specified Attribute and explicit bonuses or penalties.
2. Enforce any effect-specific minimum or maximum.
3. Roll that many d10.
4. Every natural 10 counts as a success and generates one additional d10.
5. Additional natural 10s continue exploding recursively.
6. Apply Skill manipulation only after all natural explosions have been generated.
7. Each final die result of 7 or higher is one success.
8. A die modified to 10 is a success but does not explode.
9. Store raw dice, explosion dice, modifications, flat successes, and final successes separately.

## 3.2 Skill manipulation — LOCKED baseline

| Skill tier | Manipulation |
|---|---|
| Novice | Add half Skill Level, rounded up, to one die |
| Expert | Add full Skill Level to one die |
| Master | Split Skill Level between up to two dice |
| Grand Master | Split Skill Level among any number of dice |

Automatic optimal manipulation is the current digital baseline. Manual distribution remains **OPEN/DEFERRED** until the ordinary loop is playable.

## 3.3 Attack and spell pools — LOCKED RAV baseline

- A weapon Attack uses the relevant Weapon Skill with the weapon-assigned Attribute.
- A damaging spell uses the relevant Magic Skill with its casting Attribute.
- After all bonuses and penalties, a legal committed Attack has a minimum rolled
  pool of `1d10`; penalties never convert it into an empty roll after its Action
  has been spent.
- Attack successes are the incoming damage before Defense and explicit damage modifiers.
- A standard Attack targets one battler unless the ability explicitly defines a multi-target rule.

## 3.4 Critical rolls — LOCKED baseline

A natural 10:

- counts as a success;
- explodes recursively;
- activates only those critical properties explicitly defined by the weapon, skill, ability, status, or encounter.

There is no adopted universal critical-damage multiplier.

The Unarmed critical free-Attack property requires at least **Unarmed Weapon Skill Level 1**.

---

# 4. Encounter Setup, Order, and Momentum

## 4.1 Order — LOCKED

Order is determined once at encounter start and fixes side order for the entire battle.

1. Every participating heroine makes an Agility check.
2. Add all heroine successes.
3. Compare the party total against the highest Enemy Order value in the encounter.
4. The party wins on a tie or any higher result.
5. Otherwise, enemies win.

Ambushes and living traps do not bypass Order. Vines, tentacles, Mimics, and similar encounters receive higher authored Order values instead.

## 4.2 Full Momentum — LOCKED

When the winning Order result exceeds the losing result by at least three successes, the winner gains Momentum.

Momentum effect:

- the winning side begins round one normally;
- the losing side begins round one with zero Actions;
- the losing side cannot use Active Actions or reactions in round one;
- the losing side’s phase still occurs for phase-start effects and logging;
- all battlers refresh normally at Round Start 2.

Momentum applies universally to heroines, ordinary enemies, elites, and bosses.

The previous “one shared soft Momentum Action” rule is **DEPRECATED**.

## 4.3 Order logging — LOCKED

Examples:

```text
Enemies won the Order (6 vs 4). Enemies go first.
Party won the Order (5 vs 5). Party goes first.
Party won the Order (6 vs 3). Party goes first with Momentum.
Enemies won the Order (7 vs 4). Enemies go first with Momentum.
```

Expandable dice detail may show the individual heroine rolls.

---

# 5. Round and Phase Cadence

## 5.1 Round structure — LOCKED

```text
Encounter Setup
→ Order and Momentum
→ Round Start
→ first side phase
→ second side phase
→ end checks
→ next Round Start
```

The side that won Order always receives the first side phase.

## 5.2 Hero Phase — LOCKED

During the Hero Phase, the player may freely interleave individual Actions among all eligible heroines.

Example:

```text
Seraphine: Heal
Mira: Move
Mira: Attack
Lysandra: Move
Mira: Move away
Lysandra: Attack
Seraphine: Heal
End Hero Phase
```

There are no complete heroine activations. A heroine may spend one Action, yield control to another heroine, and act again later in the same Hero Phase.

Unspent Actions remain available for reactions during the Enemy Phase. At the next Round Start, all leftovers are discarded and current Actions reset to maximum.

## 5.3 Enemy Phase — LOCKED

Enemy resolution has two layers.

### Group rulebook

Before individual enemies act, the enemy group evaluates authored composition and battlefield rules to optimize activation order and roles.

Examples:

```text
If Grappler is in EnemyGroup...
If EnemyCount = 3...
If support enemy is alive...
If target at 0 HP is grapple-eligible...
```

### Individual rulebook

After activation order is chosen:

1. the first enemy checks its ordered rules from top to bottom;
2. the first legal/applicable rule executes;
3. the enemy reevaluates after every Action;
4. it continues until all Actions are spent, forfeited, or its special state ends the activation;
5. the next enemy begins.

Grappling enemies use the restricted Grapple activation rules instead of ordinary behavior.

## 5.4 Phase-start effect order — LOCKED

At the beginning of a side’s phase, before that side takes Active Actions, resolve:

1. healing and regeneration;
2. damage-over-time;
3. control effects;
4. Action gain and loss;
5. expiry.

Effects attached to a battler trigger once at the beginning of that battler’s side phase.

## 5.5 Durations and ticks — LOCKED

- A duration measured in rounds begins counting from the next Round Start after application.
- A periodic effect expires only after its specified number of actual ticks has resolved.
- Reaching a nominal round count does not delete a periodic effect before its final tick.
- “Until the end of the caster’s next phase” means the end of the next phase belonging to the caster’s side.

---

# 6. Action Selection and Commitment

## 6.1 Commitment point — LOCKED

An Action is committed only after all required decisions are confirmed.

Depending on the Action, confirmation may require:

- actor;
- action or ability;
- target;
- destination anchor;
- exact path;
- destination position;
- equipment or item choice;
- authored mode or target rule.

Before commitment:

- the on-screen Back command;
- `Esc`;
- gamepad Cancel

return to the previous selection step without spending Actions or MP.

After commitment, the route, destination, target, and other declared choices cannot be altered because of a roll or reaction result.

## 6.2 Cost timing — LOCKED principle

Action cost and MP cost are paid at commitment unless an ability explicitly says otherwise. Failure, Defense, zero successes, or later cancellation does not ordinarily refund the cost.

Exact spell interruption rules remain **OPEN**.

---

# 7. Battlefield Spatial Model

## 7.1 Mechanical layers — LOCKED

The battlefield uses three related concepts:

1. **BattleZone** — broad tactical region used for ranged distance, spell range, AOE scope, zone effects, and authored terrain relationships.
2. **Anchor** — visible selectable movement point and local engagement cluster.
3. **Position** — one occupancy point belonging to an anchor. Positions may be visually subtle or hidden until placement selection.

Pixels present the battlefield. Zones, anchors, positions, and authored connections determine legality.

## 7.2 Anchor capacity — LOCKED

- Standard anchor: **4 positions**.
- Restricted anchor: **2 positions**.
- Terrain may block or reduce positions.
- Each ordinary battler occupies one position.
- Grapple participants may be bundled into a single position and do not consume ordinary capacity individually.

## 7.3 Player-selected position — LOCKED

When moving, the player selects:

1. exact route;
2. destination anchor;
3. exact free destination position.

Every position in an anchor has identical outgoing anchor connections. Position choice does not change Adjacency, line of sight, or cover within that anchor, but gives the player formation and presentation control.

The final destination position is committed with the Move. Intermediate pass-through positions need only be legally traversable because their exits are identical.

## 7.3.1 Direct battlefield selection — LOCKED

Move and AOE targeting are selected on the illustrated battlefield, not from
flat route, Position, or BattleZone dropdown menus.

- Move highlights legal next Anchors and exact free Positions.
- An adjacent destination may be chosen with one Position click.
- For a two-step route, the player clicks the intermediate Engagement Area and then the
  exact destination Position.
- AOE highlights legal BattleZones and commits the clicked zone.
- `Esc`, right-click, or the active command's Cancel state exits before
  commitment without spending resources.

## 7.4 Engagement cluster and Adjacency — LOCKED

All occupants of the same anchor’s engagement cluster are Adjacent to one another.

- Same BattleZone does not automatically mean Adjacent.
- An engagement cluster may visually straddle a zone boundary when authored that way.
- Adjacency is determined by shared engagement-cluster membership, not pixel distance.
- Different anchors in the same BattleZone are Close unless a reach rule says otherwise.

## 7.5 Range ladder — LOCKED

| Relation | Digital meaning |
|---|---|
| Adjacent | Same engagement cluster |
| Close | Same BattleZone, different engagement cluster |
| Far | One BattleZone connection away |
| Very Far | Two BattleZone connections away |
| Beyond | Three or more zone connections away, or disconnected |

Adjacency overrides broader zone distance when battlers share a cluster.

Spell wording translates as follows:

- **Adjacent:** same engagement cluster;
- **within your zone:** any legal target in the same BattleZone;
- **within 1 zone:** same zone or one connected zone away;
- **within 2 zones:** up to two zone connections;
- line spells follow their authored valid line through anchors/zones.

## 7.6 Reach weapons — LOCKED

A spear or other explicitly tagged reach weapon may attack a target in a directly connected anchor, including when that connection crosses a BattleZone boundary.

Reach does not grant Move Reaction Attacks from the neighboring anchor. A Move Reaction still requires shared engagement-cluster Adjacency at the relevant movement step.

## 7.7 Move Action — LOCKED

One Move Action allows up to **two connected anchor steps**.

- Steps may remain inside one BattleZone or cross zone boundaries.
- Moving to a different anchor in the same BattleZone still costs a Move Action.
- Slow reduces Move to one step per Action.
- The player selects the exact path when multiple paths reach the same destination.
- The complete path and destination position are committed before movement begins.
- The player cannot redirect or stop voluntarily after seeing a Reaction Attack result.

Movement may stop early only when a rule makes the remaining route illegal, including becoming Restrained through Grapple rules or becoming Stunned.

Ordinary damage does not interrupt a committed Move.

## 7.8 Traversing occupied anchors — LOCKED

- A hostile or mixed anchor may be entered or traversed only if it has a free legal position.
- Passing through such an anchor may provoke a melee Reaction Attack.
- A completely full hostile or mixed anchor is impassable.
- A completely full allied anchor may be passed through as an exception.
- A battler may not end movement in a full allied anchor.
- When ending in an occupied but non-full anchor, the player may choose any free position.
- Terrain may make a route illegal even when nominal capacity exists.

## 7.9 Movement threat preview — LOCKED

Before Move confirmation, display:

- the exact legal path;
- destination anchor and position;
- steps that enter hostile engagement clusters;
- each enemy legally capable of a melee Move Reaction Attack.

This preview communicates legality, not enemy intention.

## 7.10 Move Reaction Attack — LOCKED

A committed Move creates one independent reaction opportunity for every
eligible opposing combatant encountered at a newly reached threatened Anchor.

At each path step:

1. determine which opposing melee weapon users share the mover’s engagement cluster;
2. offer each eligible combatant its own reaction or decline choice, one at a time;
3. reacting or declining consumes only that combatant’s opportunity;
4. each chosen melee Attack resolves before the next eligible combatant is offered;
5. movement remains paused until every eligible combatant at that step has reacted or declined;
6. if the mover survives and is not Stunned or Grapple-restrained, the committed route continues.

Selection:

- during Hero movement, enemy AI evaluates each eligible enemy according to its rulebook;
- during Enemy movement, the player is offered each eligible heroine sequentially;
- only melee weapon Attacks qualify;
- ranged weapons, damaging spells, and reach-only attacks from another anchor do not qualify;
- special abilities may create separate movement reactions such as Overwatch later.

## 7.11 Line of sight — LOCKED

Line of sight is determined by an anchor-to-anchor ray through the authored battlefield.

- Exact positions inside the same anchor share line-of-sight and cover results.
- Battlers do not block line of sight.
- Props and terrain may block the ray.
- Pixel placement supports the visual ray but does not independently override authored anchor results.

## 7.12 Cover and terrain — LOCKED baseline / OPEN expansion

Baseline cover:

- makes an ordinary ranged Attack illegal through the covered line;
- does not protect against AOE by default;
- does not provide a generic defense-dice bonus.

For the current implementation, terrain and props primarily provide:

- cover;
- movement restriction.

Later authored behaviors may include traps, Mimic transformation, destruction, state changes, or special interactions. The full terrain system remains **OPEN**.

---

# 8. Attacks, Targets, and AOE

## 8.1 Standard Attack — LOCKED

A standard Attack:

- costs one Action unless explicitly free;
- selects one legal target;
- rolls the relevant Attack pool;
- shows the committed result;
- opens one reaction window for the target when the target has available Actions and a legal option;
- applies remaining damage after Defense or Skip/Counterattack rules.

## 8.2 Multi-target skills — LOCKED authoring rule

Ordinary Attacks never become multi-target merely because several enemies are Adjacent.

A skill must explicitly define one of these targeting modes:

- player-selected targets;
- all legal targets;
- random legal targets;
- random targets including allies with authored probability;
- one BattleZone;
- specified BattleZones;
- all BattleZones except named exclusions;
- another authored shape or list.

## 8.3 AOE resolution — LOCKED digital adaptation

For a damaging AOE:

1. commit the ability and affected zone(s);
2. reveal affected zones only after commitment;
3. make one Attack roll;
4. apply the same incoming success total to every affected target;
5. each target resolves its own reaction and Defense independently;
6. resolve targets in stable party-strip or enemy-list order;
7. apply each target’s damage immediately before resolving the next target.

Ordinary cover does not block AOE unless the ability or terrain explicitly says otherwise.

This intentionally standardizes digital resolution even where individual tabletop spells might otherwise request separate checks.

## 8.4 Expert Armsmaster — LOCKED

Expert Armsmaster applies only when using:

- an explicitly tagged great/two-handed weapon, such as greatsword, giant sword, great axe, or lance; or
- a legal dual-wield configuration, such as two daggers or two short swords.

It does not apply to:

- one ordinary one-handed weapon;
- weapon and shield;
- weapon and empty hand;
- an invalid or broken dual-wield configuration.

When eligible:

- one Attack Action costs one Action;
- one target is selected;
- two complete Attack dice pools are rolled;
- each pool resolves explosions and Skill manipulation normally;
- successes are combined into one incoming Attack total;
- the target receives one reaction window;
- one Defense result reduces the combined total.

This is one Attack with two checks, not two attacks. “Per Attack” effects trigger once unless they explicitly refer to each Attack check.

---

# 9. Reaction System

## 9.1 General rule — LOCKED

A reaction normally costs one currently available Action.

When a battler has zero Actions:

- the reaction menu is omitted;
- resolution continues automatically;
- the combat log records:

```text
No Actions available. Reaction skipped.
```

One Active Action normally creates at most one direct opposing reaction
opportunity per eligible reactor. Move is the explicit multi-reactor case:
every eligible opposing combatant encountered at a newly reached threatened
Anchor receives one independent opportunity. Generated Attack events, such as
free Attacks, may create their own reaction windows according to their source
rules.

## 9.2 Attack reaction menu — LOCKED

After an Attack is committed and rolled, but before damage is applied, the target chooses:

```text
Attack | Dodge | Defend | Parry | Skip
```

The incoming successes/damage are shown at this point. This is committed-result information, not advance damage prediction.

### Skip

- spends no Action;
- applies the Attack without Defense;
- preserves Actions for later reaction windows.

### Attack

- the original Attack lands in full;
- after damage, if the defender survives and can act, spend one Action;
- make a legal Attack against the original attacker;
- the recipient may use the reaction set allowed by the generated Attack source;
- Parry and its free-Attack consequence remain possible when otherwise legal.

### Dodge

- spend one Action and roll Athletics with Agility;
- negate one Attack success per Defense success;
- apply all leftover damage and attack effects;
- if Dodge prevented at least one damage and the defender remains able to
  move, optionally take one connected Anchor step away from the attacker;
- the defensive step does not trigger Move Reactions;
- pressing Back/Esc declines the optional step and maintains position.

### Defend

- open the `Armor | Shield | Back` choice inside the same reaction window;
- spend one Action only when Armor or Shield is selected;
- use the established equipment Defense and damage-allocation rules;
- maintain the defender's current position.

### Parry

- spend one Action and roll the relevant Weapon Skill with the cumulative
  Parry penalty;
- negate one Attack success per Defense success;
- apply all leftover damage and effects;
- if at least one damage was prevented, generate one free Attack against the
  original attacker.

## 9.3 Reaction methods — LOCKED

The persistent Reaction Exchange shows the full player-facing set:

```text
Attack | Dodge | Defend | Parry | Skip
```

Illegal methods are disabled or hidden. `Defend` switches the same window to
`Armor | Shield | Back`; it does not open another modal. Each method may show
its exact currently calculated dice pool, including bonuses and penalties, but
not predicted successes.

No other heroine may intervene through the reaction window. Ally protection
must be an independently established Action, stance, or ability.

### Dodge

```text
Athletics with Agility
```

Dodge is unavailable while Grapple-restrained or when another effect explicitly prohibits it.

### Armor Defense

```text
Armor(type) with Agility
```

Unavailable with no usable armor. Broken armor cannot be used for Armor Defense, loses positive properties, and retains its penalties.

### Shield Defense

```text
Armor(Shield) with Might
```

Available only with a usable equipped shield. A Broken shield cannot be used for Shield Defense.

### Parry

```text
Relevant Weapon Skill Check −1d10
```

Parry:

- requires a suitable usable weapon;
- cannot defend against magic;
- cannot be rerolled with Luck;
- negates one Attack success per Defense success;
- generates one free Attack against the attacker if it prevents at least one damage.

Repeated Parries in the same free-Attack exchange take a cumulative penalty:

```text
First Parry:  −1d10
Second Parry: −2d10
Third Parry:  −3d10
...
```

## 9.4 Free Attacks — LOCKED

A free Attack is a regular Attack event that spends no Action.

It may:

- use the normal legal target and range rules;
- be Defended;
- be Counterattacked when the source permits a full reaction menu;
- trigger Parry;
- generate another free Attack;
- activate weapon properties and critical properties;
- damage equipment.

Free-Attack chains are intentionally legal and end naturally when:

- someone Skips;
- a Parry prevents no damage;
- no Action remains for Defense;
- the required pool becomes unusable;
- a battler is defeated or incapacitated;
- the Attack cannot legally be Parried;
- a source explicitly blocks further reactions.

**Current source policy — PROVISIONAL:** ordinary Attacks and Parry-generated
free Attacks open the full `Attack | Dodge | Defend | Parry | Skip` exchange.
An Attack-reaction generated Attack currently allows legal defensive methods
or Skip, preventing direct Attack-reaction recursion. All generated Attacks
use the same resolver and explicit generated-Attack queue. The one Reaction
Exchange window remains open and updates throughout the chain.

---

# 10. Weapons, Armor, Shields, and Durability

## 10.1 Adopted weapon properties — LOCKED RAV baseline

| Weapon | Property |
|---|---|
| Sword | Ignores 1 Dodge success |
| Axe | Ignores 1 Armor Defense success |
| Staff | If damage is dealt, target loses 1 currently available Action |
| Spear | May attack a directly connected anchor as reach |
| Dagger | Ignores 1 Parry success |
| Mace | Ignores 1 Shield Defense success |
| Unarmed | A natural critical may grant one free extra Attack once per trigger; requires Unarmed Skill 1+ |
| Bow | +1d10 at Very Far |
| Crossbow | +1d10 at Far |
| Sling | +1d10 at Close |

Exact preferred Attributes and final equipment lists remain **OPEN**.

## 10.2 Ranged weapons while engaged — LOCKED

When the attacker shares an engagement cluster with any hostile battler, a Bow, Crossbow, or Sling Attack suffers:

- `−2d10`;
- no Weapon Skill manipulation;
- no Specialty modification.

This applies even when firing at a different distant target.

## 10.3 Armor baseline — LOCKED RAV baseline

| Armor | Damage it may absorb | Dodge modifier |
|---|---:|---:|
| Cloth | 1 | +2d10 |
| Leather | 2 | +1d10 |
| Chain | 3 | −1d10 |
| Plate | 4 | −2d10 |

The next additional absorbed damage may break the armor. Broken armor loses positive bonuses and properties, but its penalties remain while equipped.

## 10.4 Shield baseline — LOCKED RAV baseline

| Shield | Property |
|---|---|
| Small | +1d10 Parry |
| Regular | May absorb 2 damage; −1d10 Dodge |
| Heavy | May absorb 3 damage; −2d10 Dodge |

## 10.5 Automatic damage allocation — LOCKED digital policy

After Defense, remaining damage is automatically redirected into eligible defensive gear according to the heroine’s configured policy:

```text
Shield First
Armor First
```

Allocation flow:

1. apply damage to the first eligible item up to its safe non-breaking limit;
2. stop before the next point would break it;
3. request confirmation to **Destroy** the item;
4. on Destroy, the item absorbs the breaking point and becomes Broken;
5. on Preserve, continue to the next eligible item or HP;
6. apply remaining damage to HP.

The same confirmation applies to armor and shields.

Broken equipment:

- remains equipped unless another rule removes it;
- loses positive bonuses and properties;
- retains penalties;
- becomes unusable when the item’s rules say so.

## 10.6 Weapon durability — LOCKED RAV baseline

When an Attack produced at least one success and the defender negates all weapon damage, the attacking weapon suffers one durability event.

A natural miss with zero Attack successes does not damage the weapon.

At five damage points, a weapon becomes Broken and unusable and loses positive properties.

For Expert Armsmaster, one combined Attack creates at most one durability event. Exact dual-wield allocation of that event remains **OPEN**.

---

# 11. Enemy Information, Forecast, and AI

## 11.1 Standard difficulty — LOCKED

Enemy decisions are hidden by default.

Always visible enemy information:

- HP;
- MP;
- current/max Actions;
- Weapon and condition;
- Armor and condition;
- current position/anchor;
- visible statuses and effects.

The battlefield itself telegraphs zones, engagement, cover, and legal movement. Enemy UI does not repeat unnecessary spatial data.

Every incoming-attack reaction or Defense prompt identifies the attacker,
attack source, and target before presenting the available response.

Standard does not reveal:

- selected future actions;
- targets or destinations;
- affected future AOE zones before commitment;
- damage prediction;
- dice pools;
- behavior hints;
- ability lists before use;
- AI priorities.

Players forecast enemies by learning their rulebooks across repeated encounters.

## 11.2 Easy difficulty — LOCKED Forecast mode

Easy enables Forecast support that may show selected or likely future:

- actions;
- targets;
- destinations;
- affected zones.

Forecast is an accessibility/difficulty aid. Standard remains the intended balance target.

## 11.3 Enemy knowledge — LOCKED

Enemy AI may use currently observable combat state:

- HP, MP, Resolve, Corruption, and Actions;
- Armor, Weapon, and their condition;
- position, engagement, and visible effects;
- abilities already witnessed in that enemy’s presence.

Enemy AI may not use:

- current player hover or menu selection;
- uncommitted intentions;
- future rolls;
- hidden inventory information;
- unseen abilities.

## 11.4 Deterministic rulebook AI — LOCKED

Each enemy uses ordered authored rules. The first legal/applicable rule executes.

The group rulebook may optimize activation order and assign roles before individual activations. Each individual then spends or forfeits all available Actions and reevaluates after every Action.

This system replaces score-only intent planners as the primary AI architecture.

---

# 12. Statuses and Periodic Effects

## 12.1 Periodic damage — LOCKED

Bleed, Poison, Burning, and similar effects normally deal damage at the beginning of the affected battler’s side phase, after healing/regeneration and before control effects.

## 12.2 Reapplication and stacking — LOCKED

Reapplying the same named status from the same source replaces the existing instance:

- use the newly applied damage value;
- reset its duration/tick count;
- discard the previous remaining duration.

The same named status from different sources creates separate instances and stacks. Each source tracks and expires independently.

## 12.3 Stunned — LOCKED

Stunned:

- immediately removes all currently available Actions;
- does not permanently change base maximum Actions;
- prevents Active Actions and reactions;
- permits passive and phase-start effects to resolve;
- stops a committed Move at the last reached anchor/position.

## 12.4 Slow — LOCKED

Slow:

- reduces maximum Actions by one;
- reduces a Move Action from two steps to one;
- persists until expired or dispelled.

## 12.5 Grapple replaces generic Restrained — LOCKED

The former generic multi-stage restraint ladder is retired. Adult restraint and loss-of-movement mechanics use the dedicated Grapple system below. Other non-adult control effects must define their own restrictions explicitly.

---

# 13. Grapple System

## 13.1 Role and track ownership — LOCKED

Grapple is the adult alternate combat route driven by Corruption and Resolve. It is not ordinary HP damage and is not a generic status effect.

Each grappled heroine owns a separate Grapple cluster. Every attached enemy owns a separate track against that heroine:

- one track is the **main track**;
- all others are **secondary tracks**;
- separate heroine clusters never merge, even when they occupy the same Anchor;
- an ordinary enemy may be attached to only one heroine;
- a boss may maintain tracks against several heroines only when its template explicitly permits it.

Boss templates may override ordinary Grapple rules only where the override is explicit.

## 13.2 Grapple initiation pool — LOCKED

A normal Grapple initiation costs one Action and requires legal melee or Reach distance. A ranged weapon pool does not create a ranged Grapple unless an explicit ability says so.

Build the attempt in this order:

1. select the enemy's first legal preferred weapon, falling through its authored list and then to Unarmed;
2. build that weapon's ordinary Attack pool;
3. apply ordinary relevant bonuses and penalties;
4. add `floor(Current Corruption / 10)d10`;
5. subtract `floor(Current Resolve / 10)d10`;
6. replace a result of zero or less with the minimum rolled pool of `1d10`;
7. add `+1 automatic success` separately.

```text
Rolled Grapple pool =
preferred legal weapon Attack pool
+ floor(Current Corruption / 10)d10
− floor(Current Resolve / 10)d10

Minimum rolled pool: 1d10
Flat modifier: +1 automatic success
```

Corruption and Resolve use complete tens: `0–9 = 0d10`, `10–19 = 1d10`, through `100 = 10d10`. Their values are snapshotted when the Grapple is committed; later changes during the same resolution do not rebuild the roll.

The automatic success:

- is not a die;
- cannot explode, be rerolled, or receive Skill manipulation;
- may be reduced by explicit future effects, including a planned `−1 automatic success` upgrade.

Natural dice, explosions, and preferred Weapon Skill manipulation otherwise resolve normally. Only weapon properties explicitly relevant to the Grapple pool apply. Damage, Bleed, Poison, armor damage, free Attacks, and other ordinary on-hit properties do not trigger unless tagged as Grapple-compatible.

## 13.3 Initiation defense and result — LOCKED

The heroine's initiation response is:

```text
Dodge | Skip
```

Armor Defense, Shield Defense, Parry, and Counterattack are not legal against initiation.

- Dodge costs one Action regardless of result.
- Each Dodge success cancels one Grapple success.
- Grapple succeeds only when at least one success remains.
- A tie after cancellation prevents the Grapple.
- Skip removes no successes.
- With the current `+1 automatic success`, Skip guarantees a legal Grapple; explicit automatic-success reduction may make Skip viable later.
- With zero Actions, no response menu appears and Skip is applied automatically.

A failed ordinary initiation spends only its one Action. The enemy retains remaining Actions, reevaluates its rulebook, and may retry unless authored limits prevent it.

A successful ordinary initiation spends its Action, forfeits all remaining Actions for that activation, and resolves Stage 1 once.

A permitted Grapple against a zero-HP heroine:

- makes no roll and opens no response;
- succeeds automatically;
- costs the normal initiation Action;
- forfeits all remaining Actions;
- applies Stage 1 normally.

## 13.4 First attachment and cluster occupancy — LOCKED

On a successful initial Grapple:

- the initiator becomes the main grappler;
- its track begins at Stage 1;
- Stage 1 Corruption and Resolve effects apply immediately;
- the initiator moves into the heroine's Position;
- its previous Position becomes free;
- the heroine and initiator form one bundled cluster occupying exactly one ordinary Position.

The cluster continues to occupy one Position regardless of the number of attached enemies.

## 13.5 Grapple Move Reactions — LOCKED

A Grapple-capable enemy receiving a Move Reaction opportunity may use its rulebook to choose:

- an ordinary melee Reaction Attack;
- a Grapple Reaction;
- waiting for a later eligible step;
- declining.

Each enemy may react at most once to the committed Move. When several enemies become eligible at the same step, resolve them in existing enemy/group activation order.

A Grapple Reaction:

- costs one currently available Action whether it succeeds or fails;
- uses the same pool, Dodge/Skip procedure, automatic success, and weapon-property restrictions as ordinary initiation;
- does not forfeit other Actions on success.

After a failed Grapple Reaction, the committed route continues and later eligible enemies may still react. Every separate Dodge costs the heroine another Action.

After a successful Grapple Reaction:

1. stop the heroine at the current Position;
2. bundle the reacting enemy with her;
3. start and resolve Stage 1;
4. cancel all remaining movement steps;
5. expire every unresolved reaction opportunity belonging to that Move.

The reacting enemy retains any remaining Actions. During its ordinary activation it may Progress or Hold; with zero Actions it produces no tick. A participation threshold opened by the new Stage 1 may be used only by a later activation or separate Move, not by an expired reaction window.

## 13.6 Additional attachment and participation limits — LOCKED

Maximum simultaneous grapplers are calculated independently for each heroine from her current Corruption when attachment would occur:

| Corruption | Maximum attached enemies |
|---:|---:|
| 0–29 | 1 |
| 30–59 | 2 |
| 60–89 | 3 |
| 90–99 | 4 |
| 100 | No numerical cap |

At 100 Corruption, enemies must still be alive, unattached, Grapple-capable, legally able to reach the cluster, and permitted by their rulebook. They do not teleport or attach automatically from elsewhere.

- Existing excess participants remain if Corruption later falls below a threshold.
- No new attachment is legal until the count falls below the current limit.
- Crossing a threshold opens the new slot immediately, including when initial Stage 1 changes Corruption during the same Enemy Phase.
- Attachment slots are never reserved.
- If a preferred cluster fills first, later enemies reevaluate.

An eligible enemy may enter and attach to a cluster even when the Anchor has no free ordinary Position, because it bundles into the occupied Grapple Position. If capacity is full, this occupancy exception does not apply.

Additional attachment:

- requires no Grapple roll and gives no Dodge response;
- succeeds automatically when the enemy's Move enters the eligible cluster;
- begins a separate secondary track at Stage 1;
- suppresses ordinary Stage 1 Corruption and Resolve effects;
- treats the Move Action that entered the cluster as the attachment cost;
- forfeits any Actions remaining after attachment.

An enemy may therefore use its final Move Action, including the second step, to enter and attach without paying another Action.

The planned Succubus heroine has an explicit priority override: eligible grapplers prefer her when she is a legal target. This does not bypass range, capacity, permissions, cooldowns, or other legality.

## 13.7 Cluster movement, separation, and detachment placement — LOCKED

An ordinary effect that forcibly moves any attached participant moves the heroine and every enemy attached to that heroine together. It cannot move only one participant unless it explicitly causes forced separation.

- The destination needs one legal Position for the bundled cluster.
- If none exists, the forced movement fails instead of splitting the cluster.
- Forced cluster movement causes no Move Reactions unless the ability explicitly says otherwise.

When a living enemy detaches through Climax, Struggle, an item, or forced separation:

1. the heroine retains the cluster Position;
2. place the enemy in the nearest free Position in the same Anchor;
3. otherwise use the nearest legal free Position in a directly connected Anchor;
4. break equal-distance ties by authored connection order.

If neither location exists, detachment still occurs. Place the enemy temporarily over capacity in the same Anchor. It remains Adjacent, its next legal movement must leave the over-capacity state, and no other battler may voluntarily enter that Anchor while over capacity.

A defeated grappler is removed through ordinary defeat handling and requires no detached Position.

## 13.8 Grappler activation, Progress, and Hold — LOCKED

Maintaining an existing track is passive and costs nothing. An attached enemy may only `Progress` or `Hold` unless its template explicitly grants another Grapple action.

Attached enemies:

- cannot Move, Attack, initiate another Grapple, switch heroines, or use ordinary abilities;
- cannot use Move Reactions, Counterattacks, or active Defense reactions;
- defend incoming attacks with zero active defensive successes;
- retain passive Armor and other passive mitigation.

If the enemy has at least one Action, Progress or Hold consumes **all currently available Actions** and ends its activation. Reduced Actions do not weaken the effect. With zero Actions it maintains the track but cannot Progress or Hold.

### Progress

- advance that enemy's track by one stage;
- if it is the main track, apply the newly reached stage's ordinary Corruption and Resolve effects;
- if it is secondary, suppress those ordinary effects;
- resolve authored final-stage or Climax effects when the track reaches Climax.

### Hold

- remain at the current stage;
- if it is the main track, repeat the current stage's ordinary Corruption and Resolve effects;
- if it is secondary, suppress those ordinary effects;
- increment the current-stage Hold counter only after the Hold successfully resolves.

Each stage defines a finite `maximum_holds`. Values may differ by stage; `0` makes Hold illegal. Once exhausted, Hold is illegal and the grappler must Progress at its next valid activation unless an explicit special action is legal.

Secondary tracks keep their own stage Hold counts. Promotion to main does not reset the current-stage Hold counter.

Stun or zero Actions:

- preserves the track;
- produces neither Progress nor an involuntary Hold;
- applies no resource effect;
- consumes no Hold allowance.

If Stun removes Actions and then expires later in the same phase-start sequence, those Actions are not restored unless another effect explicitly grants them.

## 13.9 Main track and succession — LOCKED

Only the main track applies ordinary stage Corruption and Resolve effects. Secondary Progress/Hold and initial secondary attachment suppress those effects, while independently authored Climax/final-stage effects still resolve when applicable.

When the main grappler Climaxes, is defeated, is shaken off, or is forcibly separated:

1. end that track;
2. choose the remaining track closest to Climax;
3. break ties in favor of the earliest attached enemy;
4. promote it immediately;
5. apply no resource effect merely because of promotion;
6. preserve its current stage and current-stage Hold count.

If the promoted enemy already activated this Enemy Phase, it does not activate again. If its activation has not occurred, it may later Progress or Hold normally.

## 13.10 Grappled heroine actions and defenses — LOCKED

The battle `CommandBar` is replaced by:

```text
Struggle | Wait | Submit
```

`Submit` is disabled until unlocked. A grappled heroine cannot voluntarily Move, Attack, cast abilities, or use other ordinary CommandBar actions unless an explicit ability overrides Grapple.

The separate six-slot Items panel remains usable.

Against attacks from outside her cluster, a grappled heroine may spend Actions on:

```text
Armor Defense | Shield Defense | Skip
```

Armor requires usable armor; Shield requires a usable shield. Dodge and Parry are unavailable because Grapple counts as restraint.

## 13.11 Struggle — LOCKED

Struggle:

- consumes all currently available Actions;
- remains available when Slow or another effect reduces that pool below three;
- is unavailable at zero Actions or while Stunned;
- lets the player choose Might, Agility, or Endurance;
- makes an opposed check against the selected grappler using the same Attribute;
- grants the enemy `+1d10` for every other attached grappler;
- gives ties to the enemy.

On success:

- with one grappler, reduce its track by one stage and release the heroine if reduced below Stage 1;
- with multiple grapplers, shake the selected enemy off completely;
- restore the Resolve value associated with the undone stage.

On failure, consume the Actions without changing the track or applying immediate Corruption/Resolve changes.

With multiple tracks, the player selects the exact grappler before rolling. The UI may show both current pools and the selected Attributes but never predicts the result.

## 13.12 Wait and Submit — LOCKED

Wait performs no resistance and does not advance a track by itself.

Submit:

- advances the main track by one stage immediately;
- applies the newly reached stage's effects;
- may trigger Climax;
- restores the upgrade-defined amount as a separate healing instance.

Submit and Climax healing are resolved separately. For each instance:

1. fill HP up to maximum;
2. convert unused healing to MP at `1:1`;
3. discard anything left after HP and MP are full.

Healing may raise a defeated heroine's stored HP but never Revives her. At full HP, all healing may restore MP. Submit healing resolves before Climax healing when both occur.

## 13.13 Items while grappled — LOCKED

The six-slot Items panel is always visible during:

- node-map exploration;
- non-battle room/node exploration;
- battle.

The `CommandBar` exists only in battle. During Grapple, items are selected directly from the Items panel rather than added to the restricted CommandBar.

Items retain their normal Action costs. If Actions remain, the heroine may use another legal item or choose Struggle, Wait, or Submit.

A grappled heroine may use any item whose normal target and range are legal, including:

- self-healing;
- healing an Adjacent ally;
- throwing an offensive item at an attached grappler;
- targeting another reachable enemy.

An item changes a track, stage, or attachment only through an explicit Grapple effect. Ordinary damage does not do so. Resolve changes are authored per item:

- a Knife escape may restore `1–2 Resolve`;
- a Calming Potion does not inherently restore Resolve;
- another escape item may reduce Resolve.

If an offensive item defeats an attached grappler, its track ends immediately, succession occurs, and the heroine may continue if Actions remain. Explicit Action-restoring items work up to the normal maximum. A zero-HP heroine cannot use items herself, although allies may target her with legal items.

Item use opens a reaction window only when the item performs an Attack or explicitly says it does.

## 13.14 Individual targeting, AOE, and effects — LOCKED

Every participant remains individually targetable. Damage is never automatically shared.

For range and Adjacency, every participant occupies the shared cluster Position. Anyone who can legally reach that Position can target any individual within it.

If an AOE includes the Grapple Position:

- it includes the heroine and every attached enemy as separate targets;
- use the existing single AOE roll;
- compare it with each target's legal defense separately;
- apply normal friendly-fire rules.

Ordinary damage, Stun, Knockdown, Disarm, armor destruction, and shield destruction do not inherently reduce a stage or break a track.

- Stun prevents Progress/Hold.
- Knockdown remains on the individual.
- Disarm changes equipment without changing Grapple strength.
- destroyed armor/shields change later defenses normally.
- a track ends only through grappler defeat, explicit Grapple break/separation, successful Struggle, Climax, or an authored exception.

Ordinary statuses remain on their battler after detachment. Only track-bound or `while_attached` effects expire with the track.

## 13.15 Enemy Grapple rulebooks — LOCKED

Enemy and group rulebooks use ordered conditional priorities. An unattached enemy reevaluates from the top after every ordinary Action.

A typical authored order may include:

1. continue own track;
2. attach to a preferred eligible cluster;
3. initiate Grapple against a preferred eligible heroine;
4. ordinary Attack;
5. Move toward preferred target;
6. Skip.

Authored rules decide between attachment and new initiation. A failed Grapple may be retried immediately if it remains the highest legal rule and no attempt limit applies. An enemy may Move toward a future Grapple target even when it cannot attempt Grapple during the current activation.

Zero-HP heroines are excluded by default. Explicit `can_target_defeated_with_grapple` permission is required. A heroine at participation capacity is not a legal Grapple/attachment target.

Progress and Hold use ordered conditional rules, but every stage has a finite Hold limit. The full-party-wipe forced-Progress rule overrides authored Hold preferences.

After a surviving enemy's track ends through Climax, Struggle, an item, or forced separation, its authored Grapple cooldown begins. Cooldown is counted in that enemy's own activations:

- `grapple_cooldown_activations = 2` blocks the next two activations;
- Grapple becomes legal again on the third;
- the enemy otherwise acts normally;
- it cannot initiate, attach, or use a Grapple Reaction during cooldown.

Templates may instead define one-use restrictions. Existing boss tracks are unaffected unless the boss template says otherwise.

## 13.16 Stage templates and Climax — LOCKED

### Standard enemy: 3 stages

| Stage | Corruption | Resolve |
|---|---:|---:|
| Stage 1 | +1 | −1 |
| Stage 2 | +2 | −2 |
| Stage 3 — Climax | +5 | −5 |

### Elite enemy: 4 stages

| Stage | Corruption | Resolve |
|---|---:|---:|
| Stage 1 | +3 | −2 |
| Stage 2 | +5 | −2 |
| Stage 3 | +2 | −2 |
| Stage 4 — Climax | +8 | −10 |

Boss enemies use five or more individually authored stages and may coordinate several heroine tracks only through explicit boss rules.

On Climax:

1. apply the final stage's permitted effects;
2. damage the grappling enemy by the upgrade-defined percentage of maximum HP;
3. resolve the independent Climax healing instance;
4. end that enemy's track;
5. start Grapple cooldown if it survives;
6. detach/place the enemy;
7. release the heroine if no tracks remain, otherwise perform succession;
8. run the outcome check.

| Refuge Grapple upgrade | Climax damage to enemy | Submit heal | Climax heal |
|---:|---:|---:|---:|
| 0 | 15% enemy max HP | Submit unavailable | 0 |
| 1 | 25% enemy max HP | 1 | 2 |
| 2 | 50% enemy max HP | 2 | 4 |

Upgrade level 1 unlocks Submit and improves Climax. Level 2 improves the same upgrade line. Specific enemies may explicitly override ordinary post-Climax behavior.

## 13.17 Zero HP, revival, and full wipe — LOCKED

Defeat does not break a heroine's existing tracks. Her stages, stored remaining Actions, and ordinary statuses remain. Grapplers continue resolving her tracks.

If an ally Revives her:

- keep every track and stage;
- apply the Revive effect's HP;
- restore her stored remaining Actions;
- allow Struggle, Wait, Submit, Items, and legal Armor/Shield defenses later in the same Hero Phase.

Poison, Bleed, Slow, Stun, and other statuses function normally during Grapple. A skipped activation never creates a Grapple tick by itself.

Once every heroine is at zero HP:

- no new track may begin;
- unattached enemies take no further meaningful actions;
- existing grapplers must Progress and may not Hold;
- forced Progress does not override Stun or zero Actions;
- rounds continue until controlled grapplers can act and the final track Climaxes;
- defeat resolves immediately afterward.

Outcome priority after each complete resolution:

1. all heroines at zero HP and no tracks: Defeat;
2. all heroines at zero HP with tracks: deferred Defeat sequence;
3. all enemies defeated while at least one heroine remains active: Victory;
4. all enemies and all heroines defeated simultaneously: Defeat.

## 13.18 Resolve and Corruption — LOCKED principle

Resolve affects the initial Grapple pool but not Struggle. At zero Resolve, Struggle remains available and Submit is not forced. Enemy rulebooks may prefer Grapple more strongly, and the heroine may be more susceptible to mind control.

The exact low-Resolve mind-control bonus remains **OPEN**.

## 13.19 Grapple UI, logging, save state, and validation — LOCKED

### Battlefield UI

Do not create a heroine-side Grapple panel. Each attached enemy sprite shows only its own Grapple progress bar above the sprite; no other track text is displayed there.

During the heroine's activation:

- the `CommandBar` shows only `Struggle | Wait | Submit`;
- the six-slot Items panel remains independently usable;
- unavailable commands/items remain visible but disabled with a short reason.

Struggle track selection identifies the selected grappler and may show both chosen Attributes and current rolled pools, including additional-grappler dice. It never predicts the result.

### Difficulty information

- Standard hides the attached enemy's next Progress/Hold choice and remaining Grapple cooldown.
- Easy may show Grapple cooldown as a visible effect above the enemy sprite.
- Current resolved effects remain visible through ordinary status/effect feedback.

### Combat log

The log is initially minimal, in the style of Baldur's Gate 3, with additional mechanical detail on mouse hover. Grapple events retain deterministic internal ordering:

1. selected Grapple action or initiation;
2. Action expenditure;
3. opposed rolls and cancellation;
4. stage/track change;
5. Corruption and Resolve changes or secondary suppression;
6. damage/healing and HP-to-MP overflow;
7. detachment, succession, cooldown, and outcome check.

Secondary Progress, Hold, and attachment explicitly record suppression of ordinary stage Corruption/Resolve effects. Independent final-stage effects are logged when they apply.

### Runtime persistence

Mid-combat saving/restoration preserves:

- heroine and grappler IDs;
- main/secondary status and succession order;
- current stage;
- current-stage Hold count;
- attachment and cluster Position;
- stored heroine Actions and defeated state;
- enemy Grapple cooldown;
- template-specific overrides and boss state.

### Development validation

Reject Grapple content with missing stages, no valid Progress path, unlimited Hold behavior, invalid succession references, undefined deterministic tie-breaks, or other impossible/incomplete definitions.

---
# 14. Zero HP, Revival, and Combat Defeat

## 14.1 Heroine at zero HP — LOCKED

When a heroine reaches zero HP:

- she is defeated immediately;
- store the number of Actions she had just before defeat for possible revival;
- set current Actions to zero;
- remove Active Actions and reactions;
- keep her visibly present on the battlefield;
- ordinary damaging attacks may no longer target her;
- a Grapple may target her only when the enemy rulebook explicitly allows it.

A permitted Grapple against a zero-HP heroine succeeds automatically.

A zero-HP grappled heroine:

- remains attached;
- is inactive;
- cannot Struggle, Wait, Submit, defend, or react;
- continues gaining Corruption and losing Resolve;
- remains until allies remove grapplers or all tracks reach Climax.

## 14.2 Revival — LOCKED

Only an explicitly tagged Revive effect can restore a defeated heroine during combat.

On revival:

- restore the effect-defined HP;
- restore the stored number of Actions that remained before defeat;
- if grappled, keep every track and stage;
- restore access to `Struggle | Wait | Submit`, the Items panel, and legal Armor/Shield defenses when still grappled.

Ordinary healing cannot revive.

## 14.3 Enemy at zero HP — LOCKED

When an enemy reaches zero HP:

- it is defeated immediately;
- committed unresolved Actions are cancelled;
- its Grapple track breaks immediately;
- it cannot receive ordinary healing;
- only an explicitly tagged enemy Revive may restore it.

## 14.4 Victory and defeat priority — LOCKED

- The party may win with one or two heroines at zero HP.
- If all heroines are at zero HP and no active Grapple tracks remain, defeat occurs immediately.
- If all heroines are at zero HP and tracks remain, enemies create no new tracks and complete only existing tracks.
- Defeat occurs immediately after the final active track reaches Climax; the rest of the Enemy Phase is skipped.
- If the final enemy and final active heroine reach zero HP in the same resolution, defeat takes priority.

## 14.5 Post-encounter state — LOCKED

Winning an encounter restores nothing automatically. Surviving heroines retain their exact:

- HP;
- MP;
- Resolve;
- Corruption;
- equipment condition.

A heroine who remains at zero HP after victory stays defeated and cannot participate in later encounters during that run unless an explicit Revive restores her. Victory rewards use shared party/roster resources; a defeated heroine receives no separate personal reward.

## 14.6 Full-wipe consequence — LOCKED combat handoff

Every heroine who participated in a fully failed run loses 15 Resolve.

On return to the Bloom Refuge, HP and MP restore to full automatically. Resolve and Corruption persist and can be modified only by explicit Refuge services or other effects. These economy details belong to the wider project reference, not this combat ruleset.

---

# 15. Combat UI and Information

## 15.1 Always-visible heroine information — LOCKED

- HP;
- MP;
- Resolve;
- Corruption;
- current/max Actions;
- visible statuses;
- optionally compact current Weapon and Armor icons/condition.

## 15.2 Always-visible enemy information — LOCKED

- HP;
- MP;
- current/max Actions;
- Weapon and condition;
- Armor and condition;
- visible statuses.

Zones and engagement are shown on the battlefield rather than duplicated in enemy panels.

## 15.3 Persistent Items panel and battle CommandBar — LOCKED

The six-slot Items panel remains visible on the node map, inside non-battle nodes/rooms, and during battle.

The `CommandBar` exists only during battle. Grapple replaces its ordinary actions with `Struggle | Wait | Submit`; items remain independently usable from the Items panel.

Unavailable commands and items stay visible but disabled with a short reason.

## 15.4 Contextual overlays — LOCKED

- legal anchors and positions;
- exact path;
- hostile engagement steps;
- potential Move Reaction attackers;
- target legality;
- line of sight and cover denial;
- exact current dice pools for chosen actions and legal defenses;
- committed AOE zones;
- detailed roll breakdown.

## 15.5 Combat log — LOCKED style

Concise default examples:

```text
Enemy used Attack on Mira within Central Nave. Damage: 4.
Mira used Dodge. Negated: 2.
Mira took 2 damage.
```

```text
No Actions available. Reaction skipped.
```

```text
Party won the Order (6 vs 3). Party goes first with Momentum.
```

The default display remains minimal. Additional dice, modifier, cancellation, stage, resource, and overflow details appear on mouse hover.

---

# 16. Suggested Runtime and Data Model

## 16.1 Core definition Resources — PROVISIONAL

```text
BattlerDefinition
AbilityDefinition
WeaponDefinition
ArmorDefinition
ShieldDefinition
StatusDefinition
BattlefieldDefinition
BattleZoneDefinition
AnchorDefinition
EncounterDefinition
EnemyRulebookDefinition
EnemyGroupRulebookDefinition
GrappleTemplateDefinition
GrappleStageDefinition
```

Useful tags include:

```text
great_weapon
two_handed
dual_wield_compatible
melee_weapon
ranged_weapon
reach
magic
parryable
aoe
revive
grapple_attack
forced_separation
```

## 16.2 Runtime state — PROVISIONAL

```text
BattleState
BattlerState
BattleZoneState
AnchorState
PositionState
PropState
ActionRequest
ActionResult
ReactionContext
DefenseChoice
DiceRollResult
StatusInstance
GrappleTrackState
EnemyRuleEvaluation
```

Important `BattlerState` fields:

```text
base_actions
max_actions
current_actions
pre_defeat_actions
hp
mp
resolve
corruption
battle_zone_id
anchor_id
position_id
is_defeated
active_grapple_track_ids
grapple_cluster_position_id
grapple_succession_order
grapple_cooldown_activations
```

Each `GrappleTrackState` also preserves heroine/grappler IDs, main/secondary state, stage, current-stage Hold count, and template/boss overrides.

## 16.3 Action pipeline — LOCKED

```text
selection
→ complete ActionRequest
→ validation
→ commitment and cost payment
→ reaction windows / nested generated attacks
→ rules resolution
→ ActionResult
→ presentation
→ end-state checks
→ safe next selection state
```

UI never mutates combat state directly. Rules never depend on animation completion.

## 16.4 State-machine needs — PROVISIONAL

The implementation must support nested but bounded resolution states:

```text
SETUP
ORDER
ROUND_START
PHASE_START_EFFECTS
HERO_SELECTION
ENEMY_GROUP_ORDER
ENEMY_ACTION
SELECT_ACTION
SELECT_TARGET
SELECT_PATH
SELECT_POSITION
COMMIT_ACTION
MOVE_STEP
REACTION_WINDOW
DEFENSE_SELECTION
RESOLVE_ATTACK
FREE_ATTACK
GRAPPLE_SELECTION
PRESENT_RESULT
CHECK_END
END_PHASE
VICTORY
DEFEAT
```

Generated attacks should be represented by an explicit resolution stack or queue rather than recursive UI calls.

---

# 17. Implementation Priority

Recommended combat implementation sequence. Items 1–12 are implemented and
user-verified; the focused Direct Battlefield Interaction correction gate is
pending:

1. deterministic d10 resolver and Skill manipulation;
2. battler state with max/current Actions;
3. BattleZones, anchors, positions, and authored connections;
4. two-step Move with exact path/position selection;
5. standard Attack and post-roll reaction window;
6. Dodge, Armor, Shield, Parry, Counterattack, and Skip;
7. free-Attack resolution stack;
8. Order, full Momentum, side phases, and heroine Action interleaving;
9. deterministic enemy group/individual rulebooks;
10. cover denial and anchor-based line of sight;
11. equipment durability and automatic Shield First/Armor First allocation;
12. periodic statuses, Stunned, and Slow;
13. Grapple tracks, stage templates, multi-grappler succession, and Climax;
14. zero-HP, Revival, and defeat edge cases;
15. Grapple Move Reactions, cluster movement, detachment placement, Hold limits, and cooldowns;
16. persistent Items panel, sprite progress bars, minimal hover-detail log, save state, and content validation;
17. boss-specific multi-track Grapple behavior.

The first chapel dev battle does not need Grapple content, but the architecture must avoid assumptions that would make later Grapple integration impossible.

---

# 18. Explicitly Deprecated Combat Rules

Do not implement:

- complete heroine activations;
- one shared soft Momentum Action;
- exact enemy intent on Standard difficulty;
- score-only intent planning as the primary AI model;
- universal reactive movement;
- ranged or spell Move reactions;
- shared multi-battler occupancy in one exact Position outside Grapple bundling;
- zone-only same-zone Adjacency;
- authored-zone-only line of sight without the anchor ray;
- generic cover dice bonuses as the baseline;
- the old restraint ladder `Snared → Restrained → Bound → Held → Roped → Wrapped`;
- old fixed Grapple percentages and formulas;
- one shared Grapple track for multiple enemies;
- automatic Grapple release at zero HP;
- ordinary healing as revival;
- boss immunity to Momentum;
- generic multi-target basic Attacks.

---

# 19. Remaining Open Combat Questions

## Attack, spells, and Skills

- final weapon-to-Attribute assignments and whether some weapons allow player choice;
- manual versus automatic Skill manipulation after the prototype;
- exact damaging-spell Defense permissions;
- non-damaging hostile-spell resistance defaults;
- spell interruption after commitment;
- full AOE ability catalogue;
- dual-wield durability allocation under Expert Armsmaster;
- exact free-Attack source tags and reaction restrictions.

## Equipment and terrain

- repair rules and costs outside combat;
- final item condition UI;
- complete terrain/prop authoring model;
- destructible terrain;
- Mimic/trap transitions;
- large-battler capacity and positioning.

## Statuses and control

- exact status catalogue;
- authored status priority overrides;
- mind-control dice formula based on low Resolve;
- Silence, knockback, pull, and forced-separation definitions.

## Grapple presentation and bosses

- enemy-specific scene content and animation timing;
- individual boss stage templates and track-alignment rules;
- enemy-specific exceptions after Climax;
- exact per-enemy Grapple priorities, per-stage Hold limits, cooldown lengths, and zero-HP permissions;
- future Corruption 101–200 Grapple-only mode.

---

# 20. Combat Decision Snapshot

| Area | Current decision |
|---|---|
| Standard enemy intent | Hidden |
| Easy enemy intent | Forecast enabled |
| Hero cadence | Free interleaving of individual Actions |
| Enemy cadence | Group ordering, then full individual Action expenditure |
| Order | Once at encounter start; party wins ties |
| Momentum | Difference 3+; losing side has zero Actions in round one |
| Normal Move | Up to 2 anchor steps |
| Slow Move | 1 anchor step and max Actions −1 |
| Adjacency | Shared engagement cluster |
| Standard anchor capacity | 4 positions |
| Restricted capacity | 2 positions |
| Path selection | Player chooses exact path |
| Destination position | Player chooses exact free position |
| Full allied cluster | Pass-through permitted |
| Full hostile/mixed cluster | Impassable |
| Move reaction | Independent sequential opportunity for every eligible opposing combatant |
| Cover | Denies ordinary ranged Attack; does not normally stop AOE |
| Attack reaction | Persistent Attack / Dodge / Defend / Parry / Skip exchange |
| Defend submenu | Armor / Shield / Back |
| Free attacks | Regular Attack rules, no Action cost, may chain |
| Expert Armsmaster | Great/two-handed or legal dual-wield only; two pools, one target, one Defense |
| Damage allocation | Configurable Shield First / Armor First; confirm before breaking |
| Grapple initiation | Preferred weapon pool + COR dice − RES dice, minimum 1d10, +1 automatic success |
| Grapple Defense | Dodge or Skip only |
| Grapple tracks | Separate per enemy; one main track applies COR/RES |
| Grappler action | Progress or Hold spends all currently available Actions |
| Hold | Finite, separately authored limit for each stage |
| Grapple cooldown | Authored in the enemy's own activations after a surviving track ends |
| Items while grappled | Normal legal targets and costs through the persistent six-slot Items panel |
| Grapple UI | Progress bar above each attached enemy sprite; no heroine-side track panel |
| Grapple intent/cooldown | Hidden on Standard; Easy may show cooldown as a sprite effect |
| Standard Grapple | 3 stages |
| Elite Grapple | 4 stages |
| Boss Grapple | 5+ authored stages |
| Climax damage | 15% / 25% / 50% enemy max HP by upgrade level |
| Heroine at 0 HP | Defeated, inactive; explicit Revive only |
| Simultaneous final defeat | Defeat takes priority |
