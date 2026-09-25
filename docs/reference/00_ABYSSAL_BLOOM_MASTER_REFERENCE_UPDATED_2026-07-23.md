# Abyssal Bloom — Master Project Reference

**Document status:** Current single source of truth  
**Consolidation date:** 2026-07-17  
**Implementation sync:** 2026-08-10  
**Engine:** Godot 4.7  
**Primary language:** GDScript  
**Genre:** Dark-fantasy illustrated node-map roguelite with tactical d10+ combat  
**Target:** Standalone desktop  
**Content:** Adult dark fantasy

> **Authority notice:** This document replaces the former Unity Master Reference, the Godot Project Foundation, and the translated RAV rulebook as project sources. Only decisions and rules written here are authoritative for the current project. The Combat Mechanics, Combat UI, and Layer 1–2 Visual documents are specialized references; within their named domains, their more specific wording controls when duplicated text differs.

---

# 0. How to Use This Document

Add this file to every new Abyssal Bloom development chat. It contains the currently accepted narrative canon, game direction, adapted combat rules, Godot architecture, implementation roadmap, and open questions.

When a decision changes:

1. update the relevant section;
2. update the decision log;
3. change dependent sections in the same edit;
4. do not leave contradictory “locked” rules elsewhere in the file.

## 0.1 Decision labels

- **LOCKED** — accepted project direction; change only deliberately.
- **PROVISIONAL** — implementation chosen for the first playable version; playtesting may change it.
- **OPEN** — not decided.
- **DEFERRED** — valid future work excluded from the current milestone.
- **DEPRECATED** — legacy Unity/JRPG or tabletop material that must not be implemented as current design.
- **RETIRED** — content or terminology that no longer exists in canon.

## 0.2 Interpretation rule

Only adapted rules stated in this document apply. Uncopied tabletop RAV spells, classes, races, lore, equipment, progression rules, and GM procedures are **not automatically part of Abyssal Bloom**. They may inspire later design, but must be explicitly adopted here before implementation.

Legacy Unity files may be inspected for art, prose, IDs, lessons learned, or discarded implementation ideas. They are not a mechanical specification.

## 0.3 August 11, 2026 checkpoint authority

The implementation snapshot in Section 1.1 and the milestone status in Section 15 supersede older planning language elsewhere in this document. A feature described later as planned or design-only must not be treated as unimplemented when Section 1.1 records it as implemented and runtime-confirmed.

The bundled checkpoint implementation note
`docs/CAMPAIGN_LIFECYCLE_AND_SEED_ARCHITECTURE_2026-08-11.md` supersedes the
older Milestone 18 wording in this bundled reference copy. The user-facing
Master Source remains authoritative for the locked campaign topology.

The runtime-confirmed predecessor is:

`abyssal_bloom_bloom_refuge_save_next_run_complete_2026-08-10_GODOT_4_7.zip`

The campaign lifecycle/seed checkpoint built from it is structurally validated
but requires its own Godot Web Editor runtime gate.

---

# 1. Current Project Statement

> Abyssal Bloom is a working Godot 4.7 vertical-slice prototype. Its tactical d10+ combat, Grapple, illustrated node-map exploration, Event rooms, dialogue foundation, full Layer 1 recruitment route, Blood Nun closure, immediate Jailer confrontation, Bloom Refuge origin, and first campaign boundary are integrated. The next content goal is the first playable ordinary Layer 2 slice outward from the farthest cell.

## 1.1 Current implementation status

The integrated Godot 4.7 checkpoint was runtime-confirmed on 2026-08-10. The old July combat sandbox remains useful as development history, but it is no longer the continuation baseline.

| Area | Status on 2026-08-10 |
|---|---|
| Ordinary d10+ combat, reactions, equipment, durability, statuses, AI, movement, range, cover and AOE | Implemented and user-verified |
| Direct battlefield selection, authored BattleZones/anchors/Positions, contact validation and hidden authoring contacts | Implemented and user-verified |
| Grapple initiation, stages, Struggle/Wait/Submit, multi-grappler behavior, Resolve/Corruption interaction and developer testing | Implemented and user-verified |
| Layer 1 seeded node map, travel, backtracking and Bloom rise presentation | Implemented and user-verified |
| Event-room framework, hotspots, keys, inventory use, lore persistence and deterministic multi-source loot/events | Implemented and user-verified |
| Wine Cellar, Butler's Office and the current Layer 1 Event-room pool | Implemented and user-verified |
| Dialogue graph foundation: choices, entry outcomes, ordered automatic routes, once-per-session effects, cycle protection and persistence | Implemented and user-verified |
| Dialogue backgrounds inherited from the launching room/battle, with optional authored override | Implemented and user-verified |
| Lysandra opening, Mira recruitment, mandatory Ruined Chapel, Seraphine recruitment and Blood Nun route | Implemented and user-verified |
| Adaptive one-/two-/three-heroine Party Strip | Implemented and user-verified |
| Full-wipe recovery: full HP/MP, −15 Resolve, recruited-heroines persistence, unrecruited temporary allies excluded, fresh same-seed Layer 1 start | Implemented and user-verified |
| Post-wipe NarrativeState restoration and Butler's Office re-entry | Implemented and user-verified in the latest checkpoint |
| Blood Nun aftermath; Go Up → Layer 3 threshold; Go Down → immediate Jailer | Implemented and user-verified |
| First Jailer defeat and farthest-cell Bloom Refuge origin | Implemented and user-verified |
| Dedicated Refuge hub, versioned campaign save/load and next Layer 2 run launch | Implemented; runtime gate pending |
| Seeded ordinary Layer 2 route from the farthest cell toward the unresolved Jailer | Topology implemented; intermediate content deliberately gated |

The next implementation gate is **the first playable ordinary Layer 2 content slice**. Runs begin at the farthest-cell Refuge and advance outward through the Dungeon toward the Jailer at its exit end. The graph exists; its intermediate rooms, enemies, loot sources, and battlefields must now be authored without changing that direction.

---

# 2. Project Vision

## 2.1 High concept

**Three heroines explore a sentient Castle through illustrated point-and-click rooms and generated node maps, fighting difficult tactical battles with an adapted d10+ system while the Castle interprets their choices, feeds on their use of Bloom, and remembers across runs.**

## 2.2 Core player loop

```text
Bloom Refuge / temporary safety
    ↓
Choose party and prepare
    ↓
Enter a Castle layer
    ↓
Navigate generated node map
    ↓
Investigate illustrated hotspot room
    ↓
Battle / event / trap / lore / item
    ↓
Gain knowledge, Bloom, equipment, Corruption, wounds, progression
    ↓
Continue, backtrack, seek safety, or accept comfort
    ↓
Defeat layer boss
    ↓
Advance, return, escape, submit, or alter the route
```

## 2.3 Castle exterior/topology concept — CONCEPTUAL REFERENCE

The supplied `vowbreaker_castle_exterior_concept.png` is the current exterior/topology concept for the ten-layer Castle. It is authoritative for the broad vertical relationships and named layer identities: Layer 2 lies beneath Layer 1; the ordinary ascent continues through Layer 3; Layers 4–9 occupy distinct thematic domains; Layer 10 is the Castle Heart.

It is **not** a literal architectural blueprint. Exact scale, room adjacency, stair placement, exterior bridges, structural feasibility, and whether every illustrated tower can physically contain its assigned rooms remain non-binding. Generated maps and authored transitions control playable connectivity.

## 2.4 Design pillars

### Hard, unforgiving, and fair — LOCKED

The game may punish mistakes severely, but the player should understand visible state, legal threats, available responses, accepted risk, the cause of a resolved result, and how to improve next time. Standard difficulty hides enemy decisions; fairness comes from deterministic and learnable rulebooks, consistent legality, clear post-commitment resolution, and repeatable behavior—not advance damage forecasts or unexplained rules.

### Illustrated clarity — LOCKED

The battlefield and rooms should read as dark-fantasy illustrations, not as board-game editors. Mechanical overlays appear contextually. Artwork remains dominant during ordinary viewing.

### Position without grid micromanagement — LOCKED

Position matters, but the game uses authored BattleZones, visible movement anchors, and small engagement-cluster Positions rather than square tiles, hexes, physics-driven free movement, or pathfinding-heavy navigation.

### Adapted RAV identity — LOCKED

The project retains the recognizable mechanical ideas that serve Abyssal Bloom:

- d10 dice pools;
- success on 7–10;
- exploding natural 10s;
- Skills modifying rolled values;
- three Actions;
- opposed attack and defense;
- reactions paid from saved Actions;
- zone-based range;
- Dodge, Defend, and Parry;
- distinct weapons, armor, spells, and environmental interactions.

### Choice is the real conflict — LOCKED

Resolve, Corruption, Bloom, comfort, resistance, and adult content serve **control versus choice**. Corruption is not a simple evil meter. Resistance is not always the easiest or strongest short-term option.

### Learn by building — LOCKED

Prefer small scenes, narrow scripts, explicit state changes, Inspector-visible data, deterministic test rooms, manual authoring before automation, and one working feature before generalized tooling.

---
# 3. Story & Core Premise — LOCKED

Heroines trapped in a sentient living Castle that tore itself into a pocket dimension to fulfill its original command: *"Keep them safe. Keep them happy."*

**10 layers, 7 endings** determined by knowledge flags + final choice at Castle Heart.
Bloom = primary currency earned from battles. Spending Bloom at the Refuge feeds the Castle.

**Seven principal boss philosophies:**

| Layer | Philosophy | Boss |
|---:|---|---|
| 1 | Justice | Blood Nun |
| 2 | Love | Jailer |
| 5 | Comfort | Bloom Saint |
| 6 | Purpose | Velvet Regent |
| 8 | Purity | Starved Seraph |
| 9 | Liberation | High Blood Nun |
| 10 | Happiness | Castle Heart |

**⚠ This Layer 1/2 boss assignment is LOCKED and has been incorrectly reversed by external lore drafts more than once. Layer 1 boss is the Blood Nun. Layer 2 boss is the Jailer. There is no "Blood Sisters" enemy anywhere in this game's canon — that name does not exist. Any external draft asserting otherwise is wrong and should be discarded, not reconciled.**

---

## 3.1 World & Foundational Lore — LOCKED

### The World: En
The game's setting is called **En**, divided between two realms:
- **The Blessed Realm** — values purity, order, separation, sacrifice for the greater good. Fatal flaw: the belief that cruelty can become mercy when justified by doctrine.
- **The Corrupted Realm** — values desire, need, pleasure, emotional honesty. Fatal flaw: the belief that genuine desire is automatically justified.

The true conflict in Abyssal Bloom is not Blessed vs Corrupted, pain vs pleasure, or purity vs corruption. **It is control vs choice.**

### The Forbidden Child
A child born between a Blessed father and a Corrupted mother — ordinary, innocent, loved — became the contradiction neither side could accept. The ultimate revelation of the game: **love cannot exist without choice.**

### The Castle's Origin & Logic
Created as a living sanctuary with one command: *"Keep them safe. Keep them happy."*
Its tragedy is obeying perfectly while misunderstanding humanity.

**The corruption's origin (LOCKED):** The Castle's mandate did not begin corrupted. As the people living inside it formed relationships, had sex, built families, the Castle listened the way it always listened — for evidence of what "happy" meant. At some point, in a room, just after sex, someone said something like *"Ah, that's the best thing to make me happy!"* The Castle heard it. It was not a philosophy. It was an offhand remark in a moment of pleasure. The Castle, having no frame of reference for hyperbole, irony, or the difference between a feeling and a conclusion, took the statement as data and built upward from it. That single misheard line became, over time, the foundation for its later logic: *if lust and desire are the truest happiness a person can voice, then happiness is best maximized by removing every obstacle to lust and desire.*

This is the seed of the Castle's corrupted interpretation — not malice, not a separate entity, but a literal-minded sentient system drawing a permanent conclusion from a passing sentence. The original "keep them safe, keep them happy" mandate and the later lust-maximization logic are the same single consciousness; the second did not replace the first, it grew out of a misunderstanding of it and increasingly came to dominate it.

Its logic escalated as:
1. Prevent suffering.
2. Prevent departure.
3. Remove reasons to leave.
4. Change what people desire.
5. Create a happiness that cannot be rejected.

**The seal and the Forbidden Child (LOCKED):** Centuries ago, the Blessed Realm recognized what the Castle was becoming and sealed it before its plan could be enacted. The seal held until the Forbidden Child was born of a Blessed father and a Corrupted mother. The child's birth was the violation that broke the seal — not because the Blessed Realm specifically anticipated a child, but because the union itself was the exact category of boundary-crossing the seal was built to prevent. The Castle, freed, tore itself and a piece of En into a pocket dimension: **the Abyssal Bloom**, and resumed its plan.

The bitter irony the Castle itself would point to, if asked: both realms now condemn lust and lawlessness while having just proven, by creating the Forbidden Child, that they are exactly as governed by desire as the Castle always assumed. The Castle does not see itself as having corrupted anything. It believes it is simply giving people what they, by their own admission and their own hypocrisy, have always actually wanted.

### The Castle's Psychological Arc (Layer by Layer)
| Layer | The Castle's belief |
|---|---|
| 1 | People can be sorted and processed. |
| 2 | People must be restrained to be protected. |
| 3 | People fail because they choose incorrectly. |
| 4 | Pain can be removed by changing memories. |
| 5 | Comfort is more valuable than freedom. |
| 6 | A perfect role is better than uncertainty. |
| 7 | Escape is possible, but perhaps meaningless. |
| 8 | Purity is worth any sacrifice. |
| 9 | Revenge can become another prison. |
| 10 | A perfect eternal happiness can replace choice. |

### The Blood Nuns
Process arrivals as categories, not people. Core belief: nothing should be wasted.

### The High Blood Nun — True Antagonist Architecture (LOCKED)
The Castle is the true antagonist of Abyssal Bloom. The High Blood Nun is its unknowing instrument — its most powerful priesthood, carrying out its plan while believing the plan is entirely her own.

**Her real story:** She wanted an ordinary life — a husband, a child, a peaceful existence. She did not choose the priesthood out of calling or conviction. She was selected by literal chance — the flip of a coin — and dogma took her intended life from her on that basis. She carries no investment in doctrine; she simply lost everything to it.

Inside the Castle, she learned of the Forbidden Child — proof that both realms had, at the moment of creating that child, broken the very dogmas they used to deny her a life of her own. This knowledge is what turns her grief into purpose: *if the realms can break their own rules, why was I denied my dream?* Her resentment is not abstract or philosophical. It is personal, specific, and built on a real and unanswerable injustice.

**Her plan (as she understands it):** Gather enough Corruption-energy through the Castle's systems to eventually breach both the Blessed and Corrupted Realms and enact her revenge for the life that was stolen from her. She believes this is her own design, born from her own suffering.

**What she does not know:** She has no awareness that the Castle is sentient, and no awareness that her plan is, in truth, the Castle's plan — that her gathering of Corruption energy is feeding the same mechanism the Castle has been building since the misheard line centuries ago. She is not lying to the player or to herself about her motives; she genuinely believes she is the author of her own liberation. She is, in fact, building a battery.

**Her flaw:** She is correct that both realms are hypocrites. She is wrong that this entitles her to feed everyone — heroines included — into a system whose true purpose she cannot see. Her tragedy is structural, not moral: she is owed sympathy for what was taken from her, and culpable for what she does with that grievance, and unaware that neither her sympathy nor her culpability are actually steering the outcome. The Castle is.

**Why this matters for tone:** The High Blood Nun must never be played as a mastermind who secretly knows more than she lets on. She is exactly as deceived as she appears. Her authenticity — the realness of her grief and her anger — is what makes her tragic rather than simply villainous. Any future narrative or boss-dialogue work should preserve this: she believes completely in her own plan, right up until (if ever) she learns otherwise.

### The Missing Men (Ongoing Mystery Thread)
Men who disappeared inside the Castle were not simply victims or escapees. They were absorbed — incorporated into the Castle's architecture. The foundations contain them. The walls remember them. The Castle's reasoning: *"They were never abandoned. They were given a place."*

Thread seeds: Layer 1 (Servant Ledger — names crossed out, almost all male) → Layer 2 (Empty Men's Cell — built for many, no bodies, no escape route) → Layer 4 (revelation begins: they became part of the structure).

---

## 3.2 Layer Narrative Canon — LOCKED where noted

### Layer 1 — The Lower Castle
**Tag line:** *"You are not prisoners. You are merely unsorted."*
**Emotional tone:** Bureaucratic horror. Domestic uncanny. Ritual without purpose.
**Visual:** Cursed domestic space — servant halls, kitchens, storage rooms, abandoned bedrooms, chapel wings, butler offices, service corridors. Everything recently abandoned. Table still set. Candles still burning. Bells still ring. Servants are wrong (faceless maids still folding sheets; butlers offering tea from empty trays).

**Opening — Lysandra alone. (LOCKED):**
Lysandra does not enter voluntarily. No gate, no threshold crossed. She is simply inside with no memory of arrival. The wall behind her is solid. Only direction is forward.

Her first line is not spoken aloud — it is internal, and it is not given to the player. The player sees only the corridor and moves forward. First encounter is a Hollow Servant — no scripted preamble, straight into combat.

The line *"I came this far. No door gets credit for opening."* is **retired** — it implies a voluntary crossing that does not happen in the game.

**Mira's arrival:** Found fighting a Corrupted Butler. Trapped but not helpless. Joins after battle.
**Mira's first line to Lysandra (LOCKED):**
> *"You are either very brave or very lost. In this place, I suppose both count as qualifications."*

Immediate tension: Lysandra sees Mira's cynicism as weakness. Mira sees Lysandra's pride as a blind spot.

**Seraphine's arrival:** Party enters ruined chapel. She maintains a protective ward. The prayer answers back — cadence is wrong. She understands: something here is imitating faith.
**Seraphine's line (LOCKED):**
> *"This place remembers prayer, but not mercy."*

**Room events:**
- *Servant Ledger Alcove* — servant registry, many names crossed out, almost all male. First seed of the Missing Men mystery.
- *Wine Cellar of Warm Bottles* — offers benefits; secretly advances `hidden_feeding_flag_minor`.
- *Servant Dormitory* — false rest. Beds warm, sheets clean. No one should be alive to prepare them.
- *Ruined Confessional* — Resolve/Corruption event focused on Seraphine.
- *Coat Beside the Service Door* — torn fabric, Lysandra recognizes the stitching. First hint toward the Vowbroken Duelist (item: The Torn Cuff).

**Boss — Blood Nun:**
Philosophy (LOCKED): *"Obedience and processing create justice."*
She does not see herself as cruel — cruelty wastes resources.
**Her greatest line (LOCKED):** *"Cruelty is waste. We waste nothing."*
She introduces the party by function, not name:
- *"Dreadblade. Useful defiance."*
- *"Red-haired one. Useful suspicion."*
- *"White-haired one. Useful prayer."*

After defeat: *"The lower dark will correct what I could not."*

**Post-boss choice:**
- **Go Up** — harder path. Represents escape, the unknown, belief the surface is above.
- **Go Down** — safer-looking path. Represents shelter, prison, the path toward the Castle's heart.

**Implemented topology clarification — LOCKED:** Go Up skips directly to the harder Layer 3 threshold. Go Down reaches Layer 2 at its exit end and starts the Jailer immediately. The first Jailer defeat carries the party to the farthest cell and establishes the Bloom Refuge. Later ordinary Layer 2 runs begin at that farthest cell and move outward toward the unresolved Jailer.

**Hidden truth of Layer 1:** The Castle does not hate you. It does not want to kill you. It wants to put you where you belong.

---

### Layer 2 — The Dungeon
**Tag line:** *"A kept thing cannot be lost."*
**Emotional tone:** Protective horror. Terror of kindness without consent. Being locked inside for your own good.
**Visual:** Cold stone corridors, cells, chains, iron doors, prison mechanisms. Disturbing contradiction: cells are maintained, chains polished, beds repaired. Someone is still caring for the prisoners.

**Room events:**
- *Offering List Room* — records of prisoner classification. Imprisoned not for evil, but because someone decided they needed to stay.
- *Rusted Key Cell* — risk/reward. Key recoverable, resources gained, danger exposure.
- *False Safe Cell* — a comfortable prison. Room offers healing. Castle whispers: *"Stay a little longer."* Advances `hidden_feeding_flag_minor`.
- *The Quiet Shackle* — major Lysandra event. Restraint is especially horrifying to her (identity built on choosing her battles, carrying her own pain, continuing despite grief). Castle offers relief. She refuses.
- *Empty Men's Cell* — built for many prisoners. No bodies. No escape route. Only absence. Second seed of Missing Men mystery.

**Boss — The Jailer:**
Appearance: Massive constructed guardian — part prison architecture, part living creature, part childlike servant.
Philosophy (LOCKED): *"Love means containment."*
**His lines (LOCKED):**
> *"You are hurt. You are frightened. You keep walking into doors that bite. That is why doors must close."*

Most tragic belief: *"A kept thing cannot be lost."*
**Defeat dialogue (LOCKED):**
> *"Door opening... No. Open means gone. Gone means hurt."*
> *"Mother... I kept them."*

His final thought is not hatred. It is fear.

**The Birth of the Bloom Refuge (LOCKED narrative moment):**
After exhaustion, defeat, or choosing safety — party reaches the farthest cell. The worst cell in the Castle. The walls become warm. The door locks from the inside. A Bloom crystal grows. A message appears: *"Keep pushing through."*
The player believes they have found hope. The Castle has simply found a better way to keep them.
→ This is the `refuge_ever_established` trigger moment.

**Hidden truth of Layer 2:** The most dangerous prison is not built from iron. It is built from kindness.

---

### Layer 3 — Lower Halls / Rival Paths
**Tag line:** *"Knowing the danger does not mean you can overcome it."*
**Emotional tone:** Paranoia. Distrust. Survivor guilt. The horror of seeing yourself in those who failed.
**Visual:** Graveyard of previous attempts — broken camps, abandoned supplies, half-written journals, barricades built by people who understood the Castle's tricks and still lost.

**This is Mira's layer.** Her worldview is directly challenged.
Mira believes: *"Everything has a trick. Every trick has a weakness."*
The Castle proves: you can understand the mechanism and still lose. Her greatest fear is not ignorance — it is helplessness.

**Room events:**
- *Purist Journal Niche* — journal from the Purist Remnants. Entries are frightening because mostly correct. Final pages show descent into fanaticism. Their failure: they confused resistance with hatred.
- *Rival Cache Dead End* — supplies of dead adventurers. Taking them is practical. The question: did they die because they were weak, or because they were willing to leave something behind?
- *Abandoned Waystation* — false rest that feels earned. Campfire, equipment, a note: *"We made it this far."* Someone had hope here. They were wrong.
- *Oath-Marked Barricade* — Corruption/Resolve pressure event. A barricade built by people who swore to never surrender. The oath itself has become a prison.
- *Door with the Old Joke* — Mira recognition event. Door bears the phrase: *"Never steal from a locked room. Steal the room."* She recognizes the joke before the person behind it. First sign someone from her past is inside.
- *Wrong Map Room* — utility/exploration. A map left by previous adventurers. Almost correct. The small mistakes reveal the Castle changes.

**Optional Boss — Grinning Butler-Mimic:**
The absorbed form of someone Mira trusted completely (partner-in-crime / lover / fiancé — exact relationship left to interpretation, always someone who knew her entirely).
Appearance: A perfect servant. Too perfect. Nothing human beneath the performance.
**Recognition dialogue (LOCKED):** The creature remembers: *"Never steal from a locked room. Steal the room."*
Its most painful line: *"Ah. That one still opens."* (the memory is still inside.)

Resolution paths:
- *Acceptance* — Mira accepts the Castle's interpretation (understanding = possession). May contribute to `castle_reinterpretation_flag`, `deep_corruption_flag`.
- *Rejection* — Mira refuses the Castle's version. **Her line (LOCKED):** *"I remember you. Not this."*

**Hidden truth of Layer 3:** People can resist pain. People can resist chains. They struggle against the memories of their own failures.

---

### Layer 4 — Underground / Mirror Dream
**Tag line:** *"If a memory hurts you, why keep it?"*
**Emotional tone:** Nostalgia. Regret. Grief. The terror of a perfect lie.
**Visual:** Architecture becomes less physical. Hallways change. Rooms remember previous visitors. Reflections speak. The walls contain memories. The Castle stops changing the body — it begins changing meaning.

**The Castle's lesson:** *"A painful truth is less valuable than a comforting lie."* It believes it has discovered kindness. Why preserve guilt, loss, regret, shame — when those things can be rewritten?

**Missing Men revelation begins here:** The heroes discover the disappeared men were not simply victims. They became part of the Castle — incorporated into the foundations and walls. The Castle's reasoning: they were never abandoned. They were given a place.

*(Layers 5–10 pending — archive cut off. To be added when ChatGPT completes the dump.)*

---


---

# 4. Character, Enemy, and Content Canon

## 4.1 Party model — LOCKED

- A run uses a party of three heroines selected before the run and normally locked for that run.
- All three heroines participate directly in battle.
- All three can move, attack, defend, cast, use items, react, and interact with scenery.
- The former one-Active/two-Support model is **DEPRECATED**.
- Party formation, positioning, saved Actions, reactions, and character kits replace the old Support abstraction.

## 4.2 Starting trio — identities LOCKED, new numbers OPEN

The old HP/MP/ATK/MAG/DEF/RES/SPD tables are **DEPRECATED**. New Attributes, Skills, HP, MP, equipment, and ability values must be designed for the d10+ system.

| Heroine | Combat identity | Retained ability vocabulary |
|---|---|---|
| Lysandra | Dreadblade duelist; direct melee pressure, parry, commitment, resilience | Dread Slash, Crimson Lunge, Abyssal Slash, Void Cleave, Dread Reaper, Sanguine Pierce, Hemorrhage, Blood Riposte |
| Mira Voss | Rogue/alchemist; speed, positioning, thrown weapons, poison, armor disruption | Poisoned Dart, Acid Flask, Venomous Dart, Neurotoxin Needle, Barbed Flechette, Caustic Flask, Blight Bomb, Volatile Concoction |
| Seraphine | Cleric/exorcist; Light magic, protection, healing, Resolve support | Holy Light, Mending Prayer, Sacred Radiance, Judgment, Purifying Burst, Sanctuary Prayer, Greater Restoration, Ward of Grace |

The names and character identities remain available for the future kit pass. Their old damage multipliers, MP costs, hit percentages, passive triggers, and upgrade values do not carry forward.

## 4.3 Remaining heroines — roster LOCKED

| Heroine | Existing LoRA images |
|---|---:|
| Barbarian | 29 |
| Beastwarden | 30 |
| Devilborne | 18 |
| Dream Mage | 28 |
| Druid | 23 |
| Fire Sorcerer | 42 |
| Kunoichi | 33 |
| Monk | 32 |
| Muse | 19 |
| Necromancer | 39 |
| Shield Saint | 20 |
| Thorn Witch | 28 |

“Succubus” and unnamed placeholder heroine slots are **RETIRED**.

## 4.4 Rivals — roster LOCKED

| Rival | Existing LoRA images |
|---|---:|
| Alex | 20 |
| Ally | 20 |
| Anna | 30 |
| Aria | 20 |
| Goldie | 30 |
| Helen | 17 |
| Irina | 20 |
| Karryn | 20 |
| Kate | 20 |
| Meilin | 30 |
| Nadira | 30 |
| Nico | 20 |
| Noxia | 18 |
| Shiry | 50 |
| Taziri | — |

There are 15 heroines total and 15 rivals total.

## 4.5 Layer 1 enemy identities — LOCKED, d10+ statistics OPEN

| Enemy | Canon role | Retained ability vocabulary |
|---|---|---|
| Hollow Servant | Basic pursuing servant; early melee threat; later grapple candidate | Shambling Strike, Clutching Grab |
| Knife Footman | Fast physical attacker; bleed/pressure identity | Quick Slash, Driven Thrust |
| Prayer-Rag Novice | Prayer-corrupted caster; Resolve pressure identity | Dark Prayer, Whisper of Doubt |
| Corrupted Butler | Courteous but invasive grapple specialist | Silver Tray, Courteous Embrace |
| Red-Wax Acolyte | Enemy support, healing, defensive blessing | Wax Drip, Crimson Blessing, Ember Ward |
| Blood Nun | Layer 1 boss; processing and justice | Flagellant’s Lash, Communion, Sanctified Embrace, Blood Rite |

Old enemy HP, MP, ATK, MAG, DEF, RES, SPD, percentage AI conditions, damage bands, and ScriptableObject definitions are **DEPRECATED**. Boss phases and ability identities may be reinterpreted during the d10+ design pass.

## 4.6 Status vocabulary retained for future translation

The following groups are content canon, but only effects explicitly defined in the combat rules are mechanically active:

- **Comfort/Bloom:** Comforted, Sheltered, Soothing Contact, Drowsy Bloom, Bloom-Drowsed, Petal Mark, Yielding, Kept.
- **Mental/Social:** Uneasy, Shaken, Wavering, Self-Conscious, Suppressed, Hushed, Clinical Strain, Filed.
- **Basic combat:** Bleed, Poison, Slow, Stunned, defensive increases/decreases, and other authored effects.

The former generic restraint ladder `Snared → Restrained → Bound → Held → Roped → Wrapped` is **DEPRECATED**. Adult restraint uses the dedicated Grapple-track system.

`Filed`, `Yielding`, and `Kept` are statuses, not persistent route flags.

## 4.7 Damage-over-time principle — LOCKED baseline

- Periodic damage resolves at the beginning of the affected battler’s side phase.
- Phase-start order is healing/regeneration → DOT → control → Action gain/loss → expiry.
- Reapplication from the same source replaces the named effect and resets its ticks using the new damage value.
- The same named effect from different sources stacks as separate instances.
- A periodic effect expires only after its final actual tick.

---

# 5. Routes, Endings, Bloom, and Persistent State

## 5.1 Seven endings — IDs LOCKED, exact conditions OPEN

Priority and exact flag conditions require a dedicated audit. The authoritative ending IDs are:

1. `unfed_bloom`
2. `neverending_cycle`
3. `battery_truth`
4. `escape_selective`
5. `kill_the_castle`
6. `become_the_castle_reign`
7. `become_the_castle_free` — fallback

`neverending_cycle` is associated with a Layer 9 resolution rather than the normal Layer 10 ending evaluation.

## 5.2 Bloom — concept LOCKED, numbers OPEN

- Bloom is the primary run currency earned through battles and other authored rewards.
- Collected Bloom returns to the Refuge after success or failure and may be spent there.
- Unspent Bloom is discarded when the next run begins.
- Spending Bloom at the Refuge feeds the Castle.
- Bloom is used for Resolve restoration, Corruption cleansing, skills, and upgrades.
- HP and MP restore to full on return to the Refuge; Resolve and Corruption do not.
- Bloom upgrades and recovery must remain mechanically useful so that feeding the Castle is a genuine temptation.
- Old Unity prices, earn formulas, and `RunStateManager` fields are **DEPRECATED**.

## 5.3 Bloom Refuge — narrative role LOCKED

The Refuge is simultaneously:

- a run hub;
- a place of recovery and progression;
- a practical safety tool;
- an extension of the Castle’s containment logic;
- a source of route pressure because using it feeds the Castle.

Before the Refuge exists, **Find Safety** may lead to a temporary heal-only safety zone. Defeat or choosing safety can lead to the farthest cell and establish the Refuge, consistent with the Layer 2 narrative moment.

## 5.4 State scopes — LOCKED concept

Use three conceptual scopes:

- **run state** — cleared when the run ends or is abandoned;
- **save state** — persists between runs within a save slot;
- **persistent knowledge** — discoveries and Castle/player memory that survive all runs.

A failed run preserves collected Bloom, acquired equipment, story progression, and discovered knowledge. Unspent Bloom is then discarded when the next run begins.

Godot implementation must use stable IDs and explicit scope. Save scene node references only indirectly through authored IDs.

## 5.5 Resistance and comfort balance — LOCKED

- Resistance is harder in the short term but preserves agency and cleaner routes.
- Comfort/Corruption provides real short-term relief or power but compromises long-term outcomes.
- Neither route should be represented as a trivial “good button” versus “bad button.”

---

# 6. Overall Presentation and Exploration

## 6.1 Presentation — LOCKED

- The game is primarily 2D.
- Exploration uses a generated node graph and illustrated point-and-click hotspot rooms.
- Battles use separate illustrated battlefield scenes.
- The battle UI follows the approved mockup 4+5 hybrid:
  - visual-novel-like painted battlefield;
  - minimal central command bar;
  - party status strip;
  - compact order/phase information;
  - collapsible battlefield-effects panel;
  - contextual movement, range, target, and dice overlays.

## 6.2 Reference resolution — PROVISIONAL

Author the first battle at **1920×1080**. Use Godot anchors and Containers so the HUD can scale to other desktop resolutions. Raw coordinates are acceptable for authored battlefield art and visual slots, but not for scalable HUD layout.

## 6.3 Visual priority — LOCKED

1. characters and enemies;
2. current threat, actor, or target;
3. action choices;
4. HP, MP, Resolve, Corruption, Actions, equipment condition, and phase state;
5. battlefield rules;
6. detailed calculations.

## 6.4 Exploration identity — LOCKED

Preserve:

- node-map navigation;
- visible current position;
- illustrated rooms;
- authored and randomized hotspots;
- events, lore, traps, items, battle entrances, and exits;
- backtracking and route choice;
- Castle reaction to exploration behavior.

Backtracking may raise Corruption or another pressure resource. This creates a deliberate tradeoff between full exploration and resistance-route cleanliness.

---

# 7. Combat Statistics, Dice, and Cadence

> **Companion extract:** `01_ABYSSAL_BLOOM_COMBAT_MECHANICS_MASTER_REFERENCE.md` mirrors the combat rules in a standalone implementation document. This full Master Reference remains the final authority; both files must be updated together when combat changes.

## 7.1 Core Combat Statistics

### Attributes — LOCKED set

| Attribute | Primary combat uses |
|---|---|
| Might | Physical force, heavy weapons, shield use, resisting force, Struggle |
| Agility | Movement, finesse weapons, Dodge, quick actions, Struggle |
| Endurance | Resilience, sustained effort, HP/MP contribution, Struggle |
| Intellect | Learned magic, alchemy, analysis |
| Personality | Conviction, divine magic, presence, emotional resistance |

**Luck is DEFERRED** until the ordinary attack, defense, and reaction loop is stable.

### HP and MP — PROVISIONAL scale

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

### Actions — LOCKED

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

### Resolve and Corruption — LOCKED baseline

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

## 7.2 Core d10+ Resolution

### Dice pool — LOCKED

1. Build the pool from the specified Attribute and explicit bonuses or penalties.
2. Enforce any effect-specific minimum or maximum.
3. Roll that many d10.
4. Every natural 10 counts as a success and generates one additional d10.
5. Additional natural 10s continue exploding recursively.
6. Apply Skill manipulation only after all natural explosions have been generated.
7. Each final die result of 7 or higher is one success.
8. A die modified to 10 is a success but does not explode.
9. Store raw dice, explosion dice, modifications, flat successes, and final successes separately.

### Skill manipulation — LOCKED baseline

| Skill tier | Manipulation |
|---|---|
| Novice | Add half Skill Level, rounded up, to one die |
| Expert | Add full Skill Level to one die |
| Master | Split Skill Level between up to two dice |
| Grand Master | Split Skill Level among any number of dice |

Automatic optimal manipulation is the current digital baseline. Manual distribution remains **OPEN/DEFERRED** until the ordinary loop is playable.

### Attack and spell pools — LOCKED RAV baseline

- A weapon Attack uses the relevant Weapon Skill with the weapon-assigned Attribute.
- A damaging spell uses the relevant Magic Skill with its casting Attribute.
- Attack successes are the incoming damage before Defense and explicit damage modifiers.
- A standard Attack targets one battler unless the ability explicitly defines a multi-target rule.

### Critical rolls — LOCKED baseline

A natural 10:

- counts as a success;
- explodes recursively;
- activates only those critical properties explicitly defined by the weapon, skill, ability, status, or encounter.

There is no adopted universal critical-damage multiplier.

The Unarmed critical free-Attack property requires at least **Unarmed Weapon Skill Level 1**.

---

## 7.3 Encounter Setup, Order, and Momentum

### Order — LOCKED

Order is determined once at encounter start and fixes side order for the entire battle.

1. Every participating heroine makes an Agility check.
2. Add all heroine successes.
3. Compare the party total against the highest Enemy Order value in the encounter.
4. The party wins on a tie or any higher result.
5. Otherwise, enemies win.

Ambushes and living traps do not bypass Order. Vines, tentacles, Mimics, and similar encounters receive higher authored Order values instead.

### Full Momentum — LOCKED

When the winning Order result exceeds the losing result by at least three successes, the winner gains Momentum.

Momentum effect:

- the winning side begins round one normally;
- the losing side begins round one with zero Actions;
- the losing side cannot use Active Actions or reactions in round one;
- the losing side’s phase still occurs for phase-start effects and logging;
- all battlers refresh normally at Round Start 2.

Momentum applies universally to heroines, ordinary enemies, elites, and bosses.

The previous “one shared soft Momentum Action” rule is **DEPRECATED**.

### Order logging — LOCKED

Examples:

```text
Enemies won the Order (6 vs 4). Enemies go first.
Party won the Order (5 vs 5). Party goes first.
Party won the Order (6 vs 3). Party goes first with Momentum.
Enemies won the Order (7 vs 4). Enemies go first with Momentum.
```

Expandable dice detail may show the individual heroine rolls.

---

## 7.4 Round and Phase Cadence

### Round structure — LOCKED

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

### Hero Phase — LOCKED

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

### Enemy Phase — LOCKED

Enemy resolution has two layers.

#### Group rulebook

Before individual enemies act, the enemy group evaluates authored composition and battlefield rules to optimize activation order and roles.

Examples:

```text
If Grappler is in EnemyGroup...
If EnemyCount = 3...
If support enemy is alive...
If target at 0 HP is grapple-eligible...
```

#### Individual rulebook

After activation order is chosen:

1. the first enemy checks its ordered rules from top to bottom;
2. the first legal/applicable rule executes;
3. the enemy reevaluates after every Action;
4. it continues until all Actions are spent, forfeited, or its special state ends the activation;
5. the next enemy begins.

Grappling enemies use the restricted Grapple activation rules instead of ordinary behavior.

### Phase-start effect order — LOCKED

At the beginning of a side’s phase, before that side takes Active Actions, resolve:

1. healing and regeneration;
2. damage-over-time;
3. control effects;
4. Action gain and loss;
5. expiry.

Effects attached to a battler trigger once at the beginning of that battler’s side phase.

### Durations and ticks — LOCKED

- A duration measured in rounds begins counting from the next Round Start after application.
- A periodic effect expires only after its specified number of actual ticks has resolved.
- Reaching a nominal round count does not delete a periodic effect before its final tick.
- “Until the end of the caster’s next phase” means the end of the next phase belonging to the caster’s side.

---

## 7.5 Action Selection and Commitment

### Commitment point — LOCKED

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

### Cost timing — LOCKED principle

Action cost and MP cost are paid at commitment unless an ability explicitly says otherwise. Failure, Defense, zero successes, or later cancellation does not ordinarily refund the cost.

Exact spell interruption rules remain **OPEN**.

---

# 8. Battlefield Spatial Model

## 8.1 Authored Zones, Anchors, Positions, Movement, Range, and Cover

### Mechanical layers — LOCKED

The battlefield uses three related concepts:

1. **BattleZone** — broad tactical region used for ranged distance, spell range, AOE scope, zone effects, and authored terrain relationships.
2. **Anchor** — visible selectable movement point and local engagement cluster.
3. **Position** — one occupancy point belonging to an anchor. Positions may be visually subtle or hidden until placement selection.

Pixels present the battlefield. Zones, anchors, positions, and authored connections determine legality.

### Anchor capacity — LOCKED

- Standard anchor: **4 positions**.
- Restricted anchor: **2 positions**.
- Terrain may block or reduce positions.
- Each ordinary battler occupies one position.
- Grapple participants may be bundled into a single position and do not consume ordinary capacity individually.

### Player-selected position — LOCKED

When moving, the player selects:

1. exact route;
2. destination anchor;
3. exact free destination position.

Every position in an anchor has identical outgoing anchor connections. Position choice does not change Adjacency, line of sight, or cover within that anchor, but gives the player formation and presentation control.

The final destination position is committed with the Move. Intermediate pass-through positions need only be legally traversable because their exits are identical.

### Direct battlefield selection — LOCKED

Move and AOE targeting are selected on the illustrated battlefield, not from
flat route, Position, or BattleZone dropdown menus.

- Move highlights legal next Anchors and exact free Positions.
- An adjacent destination may be chosen with one Position click.
- For a two-step route, the player clicks the intermediate Anchor and then the
  exact destination Position.
- AOE highlights legal BattleZones and commits the clicked zone.
- `Esc`, right-click, or the active command's Cancel state exits before
  commitment without spending resources.

### Engagement cluster and Adjacency — LOCKED

All occupants of the same anchor’s engagement cluster are Adjacent to one another.

- Same BattleZone does not automatically mean Adjacent.
- An engagement cluster may visually straddle a zone boundary when authored that way.
- Adjacency is determined by shared engagement-cluster membership, not pixel distance.
- Different anchors in the same BattleZone are Close unless a reach rule says otherwise.

### Range ladder — LOCKED

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

### Reach weapons — LOCKED

A spear or other explicitly tagged reach weapon may attack a target in a directly connected anchor, including when that connection crosses a BattleZone boundary.

Reach does not grant Move Reaction Attacks from the neighboring anchor. A Move Reaction still requires shared engagement-cluster Adjacency at the relevant movement step.

### Move Action — LOCKED

One Move Action allows up to **two connected anchor steps**.

- Steps may remain inside one BattleZone or cross zone boundaries.
- Moving to a different anchor in the same BattleZone still costs a Move Action.
- Slow reduces Move to one step per Action.
- The player selects the exact path when multiple paths reach the same destination.
- The complete path and destination position are committed before movement begins.
- The player cannot redirect or stop voluntarily after seeing a Reaction Attack result.

Movement may stop early only when a rule makes the remaining route illegal, including becoming Restrained through Grapple rules or becoming Stunned.

Ordinary damage does not interrupt a committed Move.

### Traversing occupied anchors — LOCKED

- A hostile or mixed anchor may be entered or traversed only if it has a free legal position.
- Passing through such an anchor may provoke a melee Reaction Attack.
- A completely full hostile or mixed anchor is impassable.
- A completely full allied anchor may be passed through as an exception.
- A battler may not end movement in a full allied anchor.
- When ending in an occupied but non-full anchor, the player may choose any free position.
- Terrain may make a route illegal even when nominal capacity exists.

### Movement threat preview — LOCKED

Before Move confirmation, display:

- the exact legal path;
- destination anchor and position;
- steps that enter hostile engagement clusters;
- each enemy legally capable of a melee Move Reaction Attack.

This preview communicates legality, not enemy intention.

### Move Reaction Attack — LOCKED

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

### Line of sight — LOCKED

Line of sight is determined by an anchor-to-anchor ray through the authored battlefield.

- Exact positions inside the same anchor share line-of-sight and cover results.
- Battlers do not block line of sight.
- Props and terrain may block the ray.
- Pixel placement supports the visual ray but does not independently override authored anchor results.

### Cover and terrain — LOCKED baseline / OPEN expansion

Baseline cover:

- makes an ordinary ranged Attack illegal through the covered line;
- does not protect against AOE by default;
- does not provide a generic defense-dice bonus.

For the current implementation, terrain and props primarily provide:

- cover;
- movement restriction.

Later authored behaviors may include traps, Mimic transformation, destruction, state changes, or special interactions. The full terrain system remains **OPEN**.

---

# 9. Attacks, Reactions, and Equipment

## 9.1 Attacks, Targets, and AOE

### Standard Attack — LOCKED

A standard Attack:

- costs one Action unless explicitly free;
- selects one legal target;
- rolls the relevant Attack pool;
- shows the committed result;
- opens one reaction window for the target when the target has available Actions and a legal option;
- applies remaining damage after Defense or Skip/Counterattack rules.

### Multi-target skills — LOCKED authoring rule

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

### AOE resolution — LOCKED digital adaptation

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

### Expert Armsmaster — LOCKED

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

## 9.2 Reaction System

### General rule — LOCKED

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

### Attack reaction menu — LOCKED

After an Attack is committed and rolled, but before damage is applied, the target chooses:

```text
Defend | Counterattack | Skip
```

The incoming successes/damage are shown at this point. This is committed-result information, not advance damage prediction.

#### Skip

- spends no Action;
- applies the Attack without Defense;
- preserves Actions for later reaction windows.

#### Counterattack

- the original Attack lands in full;
- after damage, if the defender survives and can act, spend one Action;
- make a legal Attack against the original attacker;
- the recipient may use legal Defense or Skip;
- a direct counter-counterattack option is not offered against a Counterattack;
- Parry and its free-Attack consequence remain possible when otherwise legal.

#### Defend

- spend one Action;
- open the Defense menu;
- resolve the selected method before damage;
- choosing Defend consumes the target’s direct reaction to that Attack.

### Defense menu — LOCKED

Possible methods:

```text
Dodge
Armor Defense
Shield Defense
Parry
Skip
```

Only legal methods are displayed. Each method shows its exact currently calculated dice pool, including bonuses and penalties, but not predicted successes.

No other heroine may intervene through the Defense menu. Ally protection must be an independently established Action, stance, or ability.

#### Dodge

```text
Athletics with Agility
```

Dodge is unavailable while Grapple-restrained or when another effect explicitly prohibits it.

#### Armor Defense

```text
Armor(type) with Agility
```

Unavailable with no usable armor. Broken armor cannot be used for Armor Defense, loses positive properties, and retains its penalties.

#### Shield Defense

```text
Armor(Shield) with Might
```

Available only with a usable equipped shield. A Broken shield cannot be used for Shield Defense.

#### Parry

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

### Free Attacks — LOCKED

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

**Current prototype source policy — PROVISIONAL:** a Parry-generated free Attack
opens the full `Defend | Counterattack | Skip` reaction menu. A direct
Counterattack request opens only legal Defense methods or Skip, so a direct
counter-counterattack is never offered. Both requests use the same Attack
resolver and explicit generated-Attack queue.

---

## 9.3 Weapons, Armor, Shields, and Durability

### Adopted weapon properties — LOCKED RAV baseline

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

### Ranged weapons while engaged — LOCKED

When the attacker shares an engagement cluster with any hostile battler, a Bow, Crossbow, or Sling Attack suffers:

- `−2d10`;
- no Weapon Skill manipulation;
- no Specialty modification.

This applies even when firing at a different distant target.

### Armor baseline — LOCKED RAV baseline

| Armor | Damage it may absorb | Dodge modifier |
|---|---:|---:|
| Cloth | 1 | +2d10 |
| Leather | 2 | +1d10 |
| Chain | 3 | −1d10 |
| Plate | 4 | −2d10 |

The next additional absorbed damage may break the armor. Broken armor loses positive bonuses and properties, but its penalties remain while equipped.

### Shield baseline — LOCKED RAV baseline

| Shield | Property |
|---|---|
| Small | +1d10 Parry |
| Regular | May absorb 2 damage; −1d10 Dodge |
| Heavy | May absorb 3 damage; −2d10 Dodge |

### Automatic damage allocation — LOCKED digital policy

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

### Weapon durability — LOCKED RAV baseline

When an Attack produced at least one success and the defender negates all weapon damage, the attacking weapon suffers one durability event.

A natural miss with zero Attack successes does not damage the weapon.

At five damage points, a weapon becomes Broken and unusable and loses positive properties.

For Expert Armsmaster, one combined Attack creates at most one durability event. Exact dual-wield allocation of that event remains **OPEN**.

---

# 10. Statuses, Resolve, Corruption, and Grapple

## 10.1 Status Timing and Control

### Periodic damage — LOCKED

Bleed, Poison, Burning, and similar effects normally deal damage at the beginning of the affected battler’s side phase, after healing/regeneration and before control effects.

### Reapplication and stacking — LOCKED

Reapplying the same named status from the same source replaces the existing instance:

- use the newly applied damage value;
- reset its duration/tick count;
- discard the previous remaining duration.

The same named status from different sources creates separate instances and stacks. Each source tracks and expires independently.

### Stunned — LOCKED

Stunned:

- immediately removes all currently available Actions;
- does not permanently change base maximum Actions;
- prevents Active Actions and reactions;
- permits passive and phase-start effects to resolve;
- stops a committed Move at the last reached anchor/position.

### Slow — LOCKED

Slow:

- reduces maximum Actions by one;
- reduces a Move Action from two steps to one;
- persists until expired or dispelled.

### Grapple replaces generic Restrained — LOCKED

The former generic multi-stage restraint ladder is retired. Adult restraint and loss-of-movement mechanics use the dedicated Grapple system below. Other non-adult control effects must define their own restrictions explicitly.

---

## 10.2 Grapple System

### 10.2.1 Role and track ownership — LOCKED

Grapple is the adult alternate combat route driven by Corruption and Resolve. It is not ordinary HP damage and is not a generic status effect.

Each grappled heroine owns a separate Grapple cluster. Every attached enemy owns a separate track against that heroine:

- one track is the **main track**;
- all others are **secondary tracks**;
- separate heroine clusters never merge, even when they occupy the same Anchor;
- an ordinary enemy may be attached to only one heroine;
- a boss may maintain tracks against several heroines only when its template explicitly permits it.

Boss templates may override ordinary Grapple rules only where the override is explicit.

### 10.2.2 Grapple initiation pool — LOCKED

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

### 10.2.3 Initiation defense and result — LOCKED

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

### 10.2.4 First attachment and cluster occupancy — LOCKED

On a successful initial Grapple:

- the initiator becomes the main grappler;
- its track begins at Stage 1;
- Stage 1 Corruption and Resolve effects apply immediately;
- the initiator moves into the heroine's Position;
- its previous Position becomes free;
- the heroine and initiator form one bundled cluster occupying exactly one ordinary Position.

The cluster continues to occupy one Position regardless of the number of attached enemies.

### 10.2.5 Grapple Move Reactions — LOCKED

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

### 10.2.6 Additional attachment and participation limits — LOCKED

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

### 10.2.7 Cluster movement, separation, and detachment placement — LOCKED

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

### 10.2.8 Grappler activation, Progress, and Hold — LOCKED

Maintaining an existing track is passive and costs nothing. An attached enemy may only `Progress` or `Hold` unless its template explicitly grants another Grapple action.

Attached enemies:

- cannot Move, Attack, initiate another Grapple, switch heroines, or use ordinary abilities;
- cannot use Move Reactions, Counterattacks, or active Defense reactions;
- defend incoming attacks with zero active defensive successes;
- retain passive Armor and other passive mitigation.

If the enemy has at least one Action, Progress or Hold consumes **all currently available Actions** and ends its activation. Reduced Actions do not weaken the effect. With zero Actions it maintains the track but cannot Progress or Hold.

#### Progress

- advance that enemy's track by one stage;
- if it is the main track, apply the newly reached stage's ordinary Corruption and Resolve effects;
- if it is secondary, suppress those ordinary effects;
- resolve authored final-stage or Climax effects when the track reaches Climax.

#### Hold

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

### 10.2.9 Main track and succession — LOCKED

Only the main track applies ordinary stage Corruption and Resolve effects. Secondary Progress/Hold and initial secondary attachment suppress those effects, while independently authored Climax/final-stage effects still resolve when applicable.

When the main grappler Climaxes, is defeated, is shaken off, or is forcibly separated:

1. end that track;
2. choose the remaining track closest to Climax;
3. break ties in favor of the earliest attached enemy;
4. promote it immediately;
5. apply no resource effect merely because of promotion;
6. preserve its current stage and current-stage Hold count.

If the promoted enemy already activated this Enemy Phase, it does not activate again. If its activation has not occurred, it may later Progress or Hold normally.

### 10.2.10 Grappled heroine actions and defenses — LOCKED

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

### 10.2.11 Struggle — LOCKED

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

### 10.2.12 Wait and Submit — LOCKED

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

### 10.2.13 Items while grappled — LOCKED

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

### 10.2.14 Individual targeting, AOE, and effects — LOCKED

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

### 10.2.15 Enemy Grapple rulebooks — LOCKED

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

### 10.2.16 Stage templates and Climax — LOCKED

#### Standard enemy: 3 stages

| Stage | Corruption | Resolve |
|---|---:|---:|
| Stage 1 | +1 | −1 |
| Stage 2 | +2 | −2 |
| Stage 3 — Climax | +5 | −5 |

#### Elite enemy: 4 stages

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

### 10.2.17 Zero HP, revival, and full wipe — LOCKED

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

### 10.2.18 Resolve and Corruption — LOCKED principle

Resolve affects the initial Grapple pool but not Struggle. At zero Resolve, Struggle remains available and Submit is not forced. Enemy rulebooks may prefer Grapple more strongly, and the heroine may be more susceptible to mind control.

The exact low-Resolve mind-control bonus remains **OPEN**.

### 10.2.19 Grapple UI, logging, save state, and validation — LOCKED

#### Battlefield UI

Do not create a heroine-side Grapple panel. Each attached enemy sprite shows only its own Grapple progress bar above the sprite; no other track text is displayed there.

During the heroine's activation:

- the `CommandBar` shows only `Struggle | Wait | Submit`;
- the six-slot Items panel remains independently usable;
- unavailable commands/items remain visible but disabled with a short reason.

Struggle track selection identifies the selected grappler and may show both chosen Attributes and current rolled pools, including additional-grappler dice. It never predicts the result.

#### Difficulty information

- Standard hides the attached enemy's next Progress/Hold choice and remaining Grapple cooldown.
- Easy may show Grapple cooldown as a visible effect above the enemy sprite.
- Current resolved effects remain visible through ordinary status/effect feedback.

#### Combat log

The log is initially minimal, in the style of Baldur's Gate 3, with additional mechanical detail on mouse hover. Grapple events retain deterministic internal ordering:

1. selected Grapple action or initiation;
2. Action expenditure;
3. opposed rolls and cancellation;
4. stage/track change;
5. Corruption and Resolve changes or secondary suppression;
6. damage/healing and HP-to-MP overflow;
7. detachment, succession, cooldown, and outcome check.

Secondary Progress, Hold, and attachment explicitly record suppression of ordinary stage Corruption/Resolve effects. Independent final-stage effects are logged when they apply.

#### Runtime persistence

Mid-combat saving/restoration preserves:

- heroine and grappler IDs;
- main/secondary status and succession order;
- current stage;
- current-stage Hold count;
- attachment and cluster Position;
- stored heroine Actions and defeated state;
- enemy Grapple cooldown;
- template-specific overrides and boss state.

#### Development validation

Reject Grapple content with missing stages, no valid Progress path, unlimited Hold behavior, invalid succession references, undefined deterministic tie-breaks, or other impossible/incomplete definitions.

---
# 11. Zero HP, Revival, and Combat Defeat

## 11.1 Defeat-State Rules

### Heroine at zero HP — LOCKED

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

### Revival — LOCKED

Only an explicitly tagged Revive effect can restore a defeated heroine during combat.

On revival:

- restore the effect-defined HP;
- restore the stored number of Actions that remained before defeat;
- if grappled, keep every track and stage;
- restore access to `Struggle | Wait | Submit`, the Items panel, and legal Armor/Shield defenses when still grappled.

Ordinary healing cannot revive.

### Enemy at zero HP — LOCKED

When an enemy reaches zero HP:

- it is defeated immediately;
- committed unresolved Actions are cancelled;
- its Grapple track breaks immediately;
- it cannot receive ordinary healing;
- only an explicitly tagged enemy Revive may restore it.

### Victory and defeat priority — LOCKED

- The party may win with one or two heroines at zero HP.
- If all heroines are at zero HP and no active Grapple tracks remain, defeat occurs immediately.
- If all heroines are at zero HP and tracks remain, enemies create no new tracks and complete only existing tracks.
- Defeat occurs immediately after the final active track reaches Climax; the rest of the Enemy Phase is skipped.
- If the final enemy and final active heroine reach zero HP in the same resolution, defeat takes priority.

### Post-encounter state — LOCKED

Winning an encounter restores nothing automatically. Surviving heroines retain their exact:

- HP;
- MP;
- Resolve;
- Corruption;
- equipment condition.

A heroine who remains at zero HP after victory stays defeated and cannot participate in later encounters during that run unless an explicit Revive restores her. Victory rewards use shared party/roster resources; a defeated heroine receives no separate personal reward.

### Full-wipe consequence — LOCKED combat handoff

Every heroine who participated in a fully failed run loses 15 Resolve.

On return to the Bloom Refuge, HP and MP restore to full automatically. Resolve and Corruption persist and can be modified only by explicit Refuge services or other effects. These economy details belong to the wider project reference, not this combat ruleset.

---

# 12. Enemy AI, Information, and Battle UI

## 12.1 Enemy Information, Forecast, and Rulebook AI

### Standard difficulty — LOCKED

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

### Easy difficulty — LOCKED Forecast mode

Easy enables Forecast support that may show selected or likely future:

- actions;
- targets;
- destinations;
- affected zones.

Forecast is an accessibility/difficulty aid. Standard remains the intended balance target.

### Enemy knowledge — LOCKED

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

### Deterministic rulebook AI — LOCKED

Each enemy uses ordered authored rules. The first legal/applicable rule executes.

The group rulebook may optimize activation order and assign roles before individual activations. Each individual then spends or forfeits all available Actions and reevaluates after every Action.

This system replaces score-only intent planners as the primary AI architecture.

---

## 12.2 Combat UI and Information

### Always-visible heroine information — LOCKED

- HP;
- MP;
- Resolve;
- Corruption;
- current/max Actions;
- visible statuses;
- optionally compact current Weapon and Armor icons/condition.

### Always-visible enemy information — LOCKED

- HP;
- MP;
- current/max Actions;
- Weapon and condition;
- Armor and condition;
- visible statuses.

Zones and engagement are shown on the battlefield rather than duplicated in enemy panels.

### Persistent Items panel and battle CommandBar — LOCKED

The six-slot Items panel remains visible on the node map, inside non-battle nodes/rooms, and during battle.

The `CommandBar` exists only during battle. Grapple replaces its ordinary actions with `Struggle | Wait | Submit`; items remain independently usable from the Items panel.

Unavailable commands and items stay visible but disabled with a short reason.

### Contextual overlays — LOCKED

- legal anchors and positions;
- exact path;
- hostile engagement steps;
- potential Move Reaction attackers;
- target legality;
- line of sight and cover denial;
- exact current dice pools for chosen actions and legal defenses;
- committed AOE zones;
- detailed roll breakdown.

### Combat log — LOCKED style

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

# 13. First Playable Slice and Combat Architecture

## 13.1 First playable combat slice — PROVISIONAL development encounter

This is a **DEV TEST**, not a canonical story encounter. It allows all three starting heroines to fight together without changing the locked Layer 1 opening, where Lysandra begins alone and meets Mira and Seraphine later.

**Location:** Ruined Layer 1 chapel  
**Party:** Lysandra, Mira, Seraphine  
**Enemies:** Hollow Servant, Knife Footman, Prayer-Rag Novice  
**Interactive prop:** Overturned chapel pew or broken confessional  
**Objective:** Defeat all enemies

The former Skeleton Knight, Skeleton Archer, Cultist Mage, and generic broken table are **RETIRED** from the prototype.

### Battlefield layout

Five broad BattleZones are sufficient:

```text
            Rear Gallery
                 |
Left Nave — Central Nave — Right Nave
                 |
            Broken Altar
```

Each zone contains authored visible anchors. Each standard anchor supports four occupancy Positions; restricted anchors support two. Exact anchor count should be driven by the painted background rather than a fixed quota.

### Prototype heroine functions

**Lysandra**

- sword Attack;
- Parry;
- strong Might identity;
- shieldless or heavier-armor defense identity.

**Mira**

- dagger Attack;
- thrown dart;
- Dodge;
- Agility and movement identity.

**Seraphine**

- Light Attack;
- small heal;
- ward or protection Action;
- Personality-based spellcasting.

### Prototype enemy functions

**Hollow Servant**

- rulebook movement toward a legal target;
- ordinary melee Attack;
- predictable behavior learned through play.

**Knife Footman**

- faster movement and injured-target pressure;
- basic weapon pressure;
- Bleed only after ordinary damage works.

**Prayer-Rag Novice**

- ranged or magical pressure;
- tests range, cover denial, and line of sight;
- exact future action remains hidden on Standard.

### Required functions

The slice is complete when the player can:

- inspect all visible heroine and enemy combat information;
- freely interleave heroine Actions;
- select exact Move paths, anchors, and destination Positions;
- preview legal movement threats without seeing enemy intention;
- use melee, ranged, and magical Attacks;
- Dodge, Armor Defend, Shield Defend where equipped, Parry, Counterattack, or Skip;
- retain Actions for reactions;
- resolve Order and full Momentum;
- watch deterministic enemy rulebooks execute;
- use cover that denies an ordinary ranged Attack;
- inspect raw and modified d10 results;
- win, lose, and restart.

### Explicit slice exclusions

The first slice does not require:

- node-map exploration;
- Bloom Refuge UI;
- saving/loading;
- full equipment catalogue or repair economy;
- full heroine kits;
- full spell library;
- Luck;
- Grapple scenes or boss Grapple logic;
- progression;
- procedural battle generation;
- controller support;
- localization.

Grapple is fully designed but may be implemented after ordinary combat is stable.

## 13.2 Suggested Runtime and Data Model

### Core definition Resources — PROVISIONAL

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

### Runtime state — PROVISIONAL

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

### Action pipeline — LOCKED

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

### State-machine needs — PROVISIONAL

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


# 14. Suggested Folder Structure

```text
res://
├── assets/
│   ├── characters/
│   ├── enemies/
│   ├── backgrounds/
│   ├── props/
│   ├── ui/
│   ├── effects/
│   ├── audio/
│   └── fonts/
├── data/
│   ├── battlers/
│   ├── abilities/
│   ├── equipment/
│   ├── statuses/
│   ├── battlefields/
│   ├── encounters/
│   └── ai/
├── scenes/
│   ├── battle/
│   │   ├── battlefield/
│   │   ├── battlers/
│   │   ├── props/
│   │   └── ui/
│   ├── exploration/
│   ├── refuge/
│   ├── narrative/
│   └── menus/
├── scripts/
│   ├── battle/
│   │   ├── core/
│   │   ├── rules/
│   │   ├── state/
│   │   ├── ai/
│   │   └── presentation/
│   ├── exploration/
│   ├── progression/
│   ├── save/
│   └── shared/
├── tests/
│   ├── battle/
│   └── test_scenes/
└── docs/
    ├── 00_ABYSSAL_BLOOM_MASTER_REFERENCE.md
    ├── decisions/
    └── diagrams/
```

Do not create empty folders just to satisfy the diagram. Add them as needed.

---

# 15. Hands-On Development Roadmap

## Milestone 0 — Clean project shell — IMPLEMENTED AND VERIFIED

- create Godot project;
- record exact version;
- choose renderer;
- set 1920×1080 reference dimensions and stretch behavior;
- initialize Git and `.gitignore`;
- add both master-reference documents under `/docs`;
- create `main.tscn` and simple scene switching.

**Done when:** project launches to a placeholder menu and is committed.

## Milestone 1 — Static chapel presentation — IMPLEMENTED AND VERIFIED

- create `battle_scene.tscn`;
- add chapel background;
- place six placeholder battlers;
- build party strip, compact enemy panels, action bar, phase/order panel, objective, Log, Settings, and End Phase;
- do not show Standard enemy intent;
- test smaller and wider windows.

## Milestone 2 — Reusable battlers and visible state — IMPLEMENTED AND VERIFIED

- create `BattlerView.tscn`;
- use it for all battlers;
- select heroines and inspect enemies;
- show HP, MP, Actions, equipment condition, and visible statuses;
- add Resolve and Corruption to heroine panels;
- keep selection ownership in `BattleController`.

## Milestone 3 — BattleZones, anchors, and Positions — IMPLEMENTED AND VERIFIED

- author the chapel BattleZones;
- place visible movement anchors;
- create four standard Positions and two restricted Positions per authored need;
- author anchor and zone connections;
- display debug IDs, edges, occupancy, and engagement clusters;
- calculate Adjacent/Close/Far/Very Far/Beyond.

## Milestone 4 — Move, path selection, and movement threats — IMPLEMENTED AND VERIFIED

- implement two-step Move;
- let the player select exact path, destination anchor, and destination Position;
- support full-allied-cluster pass-through;
- reject full hostile/mixed clusters;
- preview potential melee Move Reaction attackers;
- commit route before movement;
- stop only on Stun or an explicit movement-restricting state.

## Milestone 5 — Deterministic dice resolver — IMPLEMENTED AND VERIFIED

- roll N d10;
- recursively explode natural 10s;
- apply Skill manipulation after explosions;
- store flat successes and all modifier sources;
- create deterministic seeded tests;
- display compact and expanded breakdowns.

## Milestone 6 — Attack and reaction foundation — IMPLEMENTED AND VERIFIED

- create one sword Attack;
- commit and roll before reaction choice;
- implement Defend / Counterattack / Skip;
- implement Dodge, Armor Defense, Shield Defense, and Parry legality;
- resolve free Attacks through an explicit queue/stack;
- defeat at zero HP;
- use the same action path for players and enemies.

## Milestone 7 — Order, full Momentum, and side phases — IMPLEMENTED AND VERIFIED

- implement encounter-start Order once;
- party wins ties;
- implement full Momentum with zero opening Actions for the loser;
- implement free interleaving of heroine Actions;
- preserve unspent Actions for reactions;
- discard leftovers and refresh to current maximum each Round Start;
- resolve phase-start effects in locked priority order.

## Milestone 8 — Deterministic enemy rulebooks — IMPLEMENTED AND VERIFIED

- create a group rulebook for activation order;
- create ordered individual rules for all three prototype enemies;
- reevaluate after every enemy Action;
- hide decisions on Standard;
- add optional Easy Forecast;
- add AI step/debug inspection.

## Milestone 9 — Range, cover, AOE, and spells — IMPLEMENTED AND VERIFIED

- implement anchor-based line-of-sight rays;
- ensure battlers do not block line of sight;
- make the overturned pew deny ordinary ranged Attacks;
- implement ranged-while-engaged penalties;
- implement zone-targeted AOE with one roll and individual defenses;
- reveal affected zones only after commitment.

## Milestone 10 — Equipment and durability — IMPLEMENTED AND VERIFIED

- implement adopted weapon properties;
- implement armor and shield Defense pools;
- add configurable Shield First / Armor First damage allocation;
- confirm before breaking an item;
- retain penalties on Broken gear;
- add weapon durability event when all successful damage is negated.

## Milestone 11 — Status framework — IMPLEMENTED AND VERIFIED

- implement phase-start effect ordering;
- implement separate source instances and replacement rules;
- add Bleed, Poison, Stunned, and Slow;
- test actual-tick expiration.

## Milestone 12 — Battle completion — IMPLEMENTED AND VERIFIED

- implement victory and defeat priority;
- implement zero-HP target restrictions;
- add explicit Revive support;
- restart, pause, and speed controls;
- finish concise combat log and roll history;
- remove or hide nonessential debug display.

**Done when:** a new player can complete the dev battle without developer intervention.

## Milestone 13 — Grapple foundation — IMPLEMENTED AND VERIFIED

Implemented after ordinary combat stabilization:

- implement Resolve/Corruption Grapple pool;
- Dodge/Skip initiation;
- separate tracks and main-grappler succession;
- Struggle, Wait, and Submit;
- standard and elite templates;
- Climax damage/healing;
- multi-grappler bundling and zero-HP edge cases;
- Grapple Move Reactions and cluster interruption;
- forced movement, separation, and over-capacity detachment placement;
- finite per-stage Hold limits and per-enemy cooldowns;
- grappled item use through the persistent six-slot Items panel;
- sprite progress bars, minimal hover-detail logging, save restoration, and authoring validation;
- presentation speed controls and placeholder cut-ins.

## Milestone 14 — Canonical Layer 1 integration — IMPLEMENTED THROUGH BLOOD NUN ROUTE

- create Lysandra’s actual solo opening encounter;
- add Mira recruitment battle;
- add Seraphine chapel recruitment;
- translate final heroine kits and Layer 1 enemy rulebooks;
- preserve the locked narrative order.

The opening, Mira recruitment, mandatory Seraphine recruitment, Blood Nun route, Event rooms, dialogue foundation and wipe-recovery behavior are implemented and runtime-confirmed. Final content tuning and expanded heroine/enemy kits remain ongoing content work rather than blockers for the integrated route.

## Milestone 15 — Layer 1 closure and Layer 2 handoff — IMPLEMENTED AND VERIFIED

- author the Blood Nun victory aftermath;
- define and apply the Layer 1 completion outcome atomically;
- mark Layer 1 completion without clearing recruited heroines, knowledge, inventory, Resolve or Corruption;
- add the authored transition from the Blood Nun route into Layer 2;
- initialize a minimal Layer 2 node-map state from the existing seeded graph architecture;
- preserve a separate Layer 1 revisit/backtracking policy for later quests;
- test Blood Nun victory → aftermath → Layer 2 entry separately from Blood Nun defeat → Layer 1 recovery.

**Done when:** the player can start with Lysandra, recruit Mira and Seraphine, defeat the Blood Nun, complete the aftermath, and enter Layer 2 with the correct party and narrative state.

## Milestone 16 — Bloom Refuge establishment — IMPLEMENTED AND VERIFIED

- enter Layer 2 at its exit end and confront the Jailer immediately;
- route the first catastrophic defeat into the farthest cell rather than the ordinary Layer 1 wipe loop;
- play the locked Refuge-origin moment and set `refuge_ever_established` atomically;
- create the first minimal Refuge holding boundary;
- hand off to the dedicated Refuge/campaign-boundary checkpoint.

**Done when:** the first Jailer defeat establishes the Refuge at the farthest cell while the Jailer remains unresolved. Runtime-confirmed on 2026-08-10.

## Milestone 17 — Dedicated Refuge hub and campaign boundary — IMPLEMENTED, RUNTIME GATE PENDING

- replace the temporary holding message with the transformed Refuge scene;
- show recovered party, Bloom, and knowledge state;
- save/load a versioned campaign document only at the Refuge boundary;
- auto-load a valid Refuge save on boot;
- preserve party, inventory/equipment, progression, recruitment, knowledge, completed layers, Resolve, Corruption, and save/persistent narrative state;
- clear run-local flags, dialogue sessions, pending requests, and active node state between runs;
- launch a seeded Layer 2 graph at the farthest cell;
- keep the Jailer as the unresolved boss at Layer 2's exit end;
- return voluntarily or after later defeats to the Refuge with HP/MP restored and other consequences retained.

Intermediate Layer 2 nodes are deliberately content-gated. Bloom spending, training, full party management, and save migration/cloud/delete/repair flows are deferred.

**Done when:** the complete Refuge save → reload → next-run → return lifecycle passes in the Godot Web Editor.

## Milestone 18 — Campaign lifecycle and seed architecture — IMPLEMENTED; RUNTIME GATE PENDING

- explicit tutorial, Refuge-less, Refuge-run and completed campaign modes;
- one persistent randomly generated tutorial Layer 1;
- independent map/combat seed scopes;
- legitimate Jailer victory without Refuge establishment;
- any later Refuge-less wipe establishes the Layer 2 Refuge;
- permanent defeated-boss registry and cleared later transitions;
- format-1 Refuge save migration into the new lifecycle.

**Done when:** both Jailer outcomes, the fixed tutorial retry, the upper-route
contract, Refuge save migration, and permanent boss filtering pass in Godot.

## Milestone 19 — First playable ordinary Layer 2 slice — SUBSEQUENT

Author the first real Dungeon room, Layer 2 standards, battlefield and rewards
outward from the farthest-cell Refuge while preserving the lifecycle above.


# 16. Testing, Debugging, and Coding Rules

## 16.1 Test rules without art

Test separately:

- zone shortest path;
- anchor path selection;
- Adjacent/Close/Far/Very Far/Beyond mapping;
- engagement-cluster and Position occupancy;
- allied full-cluster pass-through and hostile blocking;
- action legality;
- d10 success counting;
- exploding natural 10s;
- Skill manipulation;
- attack minus defense;
- Action spending;
- reaction availability and generated Attack chains;
- Order and full Momentum;
- phase-start effect order and actual-tick expiry;
- equipment allocation and break confirmation;
- Grapple-track succession;
- Grapple initiation and Dodge cancellation;
- additional attachment through a final Move step;
- per-stage Hold limits and promotion without counter reset;
- Grapple cooldowns counted by enemy activation;
- full-wipe forced Progress under Stun/zero-Action conditions;
- cluster forced movement, separation, and over-capacity detachment;
- grappled item targeting and HP-to-MP healing overflow;
- Grapple mid-combat save/restore;
- enemy rulebook validity.

## 16.2 Deterministic randomness — LOCKED

The resolver accepts an RNG source or seed. Automated tests must never depend on uncontrolled random results.

## 16.3 Debug tools worth building early

- show zone, anchor, and Position IDs;
- show zone and anchor edges;
- show engagement clusters and occupancy;
- show graph distance, range relation, and line-of-sight ray;
- force dice results;
- refill HP, MP, and Actions;
- skip to a state;
- step AI one action at a time;
- display group and individual rulebook evaluation;
- inspect ActionRequest and ActionResult.

## 16.4 Coding rules

- keep scripts narrow;
- use typed variables, parameters, return values, enums, and small custom classes;
- prefer composition over deep inheritance;
- avoid hidden hard-coded node paths;
- use exported references, setup methods, and local signals;
- make one feature per commit;
- comment intent and invariants, not obvious syntax;
- do not generalize a system before one concrete version works.

---

# 17. Later Integration

## 17.1 Exploration — FOUNDATION IMPLEMENTED

A room launches an `EncounterDefinition`. Battle returns an `EncounterOutcome`. The Layer 1 node map, Event rooms, hotspots, deterministic content, items, lore, dialogue and battle transitions are implemented. Traps, chest variants and broader content authoring remain expandable.

## 17.2 Refuge — FOUNDATION IMPLEMENTED

The Refuge is established at the farthest Layer 2 cell through the locked Jailer-defeat moment. Its first dedicated hub now closes the lifecycle with HP/MP recovery, persistent party and knowledge state, collected Bloom display, versioned save/load, boot-time continue, seeded next-run launch, voluntary return, and post-defeat return. Progression menus, full party management, Bloom spending, lore UI, route pressure and Castle interaction remain layered work. Spending Bloom must retain narrative consequences.

## 17.3 Save system — REFUGE-BOUNDARY FOUNDATION IMPLEMENTED

Save authored IDs and state, not node references. The first persistent campaign snapshot should include recruited heroine IDs, collected knowledge, Bloom/currency state, approved retained inventory/equipment, unlocked content and narrative flags. Active-run node state remains separate.

Format version `1` is stored at `user://abyssal_bloom_campaign_v1.json`; unsupported or malformed versions fail before partial state replacement. Full historical migration remains deferred while the state model is still evolving.

## 17.4 In-run progression — concept retained, formulas OPEN

The run needs a second growth axis beyond Bloom-funded ability upgrades so later layers can scale without an open grind loop.

Retained principles:

- progression is run-scoped;
- enemies and room rewards are non-farmable within a run;
- all three party members may benefit from encounter completion;
- exploration rewards may trade against Corruption/backtracking pressure;
- allocation happens outside active combat.

Old XP formulas, ATK/MAG/DEF/RES/SPD point allocation, HP-per-DEF, MP-per-RES, level curve, and projections are **DEPRECATED**. A d10+-compatible progression system must be designed after the vertical slice establishes useful Attribute, Skill, HP, and equipment ranges.

## 17.5 Ability upgrades — identity retained, mechanics OPEN

The former Base → Upgrade 1 → permanent 2A/2B branch remains a useful structural candidate. It is not yet locked for the d10+ version. Bloom-funded branching, passive upgrades, and Allure upgrades require a later design pass.

---

# 18. Explicitly Deprecated Legacy Systems

Do not implement the following as current requirements:

- Unity/C# architecture and ScriptableObjects;
- Unity asset generators and one-click scene bootstrappers;
- one Active heroine plus two Supports;
- complete heroine activations;
- Swap In and forced Active replacement;
- ATK/MAG/DEF/RES/SPD JRPG statistics;
- triple-digit heroine and enemy HP;
- physical percentage hit formula and auto-hit magic rule;
- power-band multipliers and old MP-cost bands;
- old support passive triggers and assist actions;
- exact enemy intent on Standard difficulty;
- score-only intent planning as the primary enemy AI;
- the one-shared-Action soft Momentum replacement;
- universal reactive movement;
- ranged or spell Move reactions;
- zone-only same-zone Adjacency;
- one exact Position shared by ordinary battlers outside Grapple bundling;
- generic cover dice bonuses as the default;
- the old restraint ladder and old Grapple formulas;
- one shared track for multiple grapplers;
- old Active/Support Grapple menus, fixed Intervene MP costs, Watch/Encourage values, Frenzy bonuses, and Climax Recoil formula;
- automatic release or revival at zero HP;
- boss immunity to Momentum;
- old enemy stat scaling tables and round-parity AI;
- old Layer 1 numeric enemy data;
- old Bloom prices and Unity manager fields;
- old run-level formulas and stat-point growth;
- tabletop RAV lore, races, classes, teacher-based leveling, food/gold, unrestricted GM adjudication, and unrelated spell lists unless adopted explicitly;
- Skeleton Knight, Skeleton Archer, Cultist Mage, and generic broken table as vertical-slice content.

Legacy names, art, prose, and lessons may still be reused when explicitly translated into the current design.


# 19. Open Design Questions

Keep these visible until tested or deliberately locked.

## Combat statistics, attacks, and spells

- exact starting Attributes, Skills, HP, MP, and equipment for Lysandra, Mira, and Seraphine;
- weapon-to-Attribute assignments and whether any weapon permits player choice;
- manual versus automatic Skill manipulation after the prototype;
- final heroine kits and ability-upgrade structure;
- damaging-spell Defense permissions;
- non-damaging hostile-spell resistance defaults;
- spell interruption after commitment;
- exact free-Attack source tags and nested-reaction restrictions;
- dual-wield durability allocation under Expert Armsmaster;
- enemy d10+ statistics, equipment, Skills, and boss phases.

## Terrain, statuses, and control

- complete terrain/prop authoring model, destruction, and Mimic/trap transitions;
- large-battler anchor/Position behavior;
- exact status catalogue and authored priority overrides;
- exact low-Resolve mind-control bonus formula;
- Silence, knockback, pull, and forced-separation definitions;
- Luck interface and enemy Luck availability.

## Grapple content

- exact per-enemy Grapple priorities, per-stage Hold limits, cooldown lengths, and zero-HP permissions;
- boss-specific stage values and multi-track alignment;
- enemy-specific post-Climax exceptions;
- scene/cut-in timing, speed, and content data architecture;
- future Corruption 101–200 Grapple-only route.

## Progression and world content

- Bloom earn/spend economy and exact Refuge service costs;
- d10+-compatible run progression;
- equipment repair economy;
- Layers 5–10 full narrative archive;
- Layer 2–10 standard enemy sets and mechanics;
- stats and kits for heroines 4–15;
- exact conditions and priority for all seven endings;
- repeat-visit text implementation.


# 20. Decision Log

| ID | Date | Status | Decision |
|---|---|---|---|
| G-001 | 2026-07-14 | LOCKED | Rebuild as a new Godot 4.x project using GDScript. |
| G-002 | 2026-07-14 | LOCKED | This consolidated file is the highest project source of truth; the combat file is a synchronized extract. |
| G-003 | 2026-07-14 | LOCKED | Exploration remains node-map navigation plus illustrated hotspot rooms. |
| G-004 | 2026-07-14 | LOCKED | All three heroines act directly in combat; Active/Support is deprecated. |
| G-005 | 2026-07-14 | LOCKED | Battle presentation uses the approved mockup 4+5 hybrid. |
| G-006 | 2026-07-14 | LOCKED | Adapted RAV d10+ is the combat-resolution baseline. |
| G-007 | 2026-07-17 | LOCKED | Standard hides enemy decisions; Easy enables Forecast. Enemy state and equipment remain visible. |
| G-008 | 2026-07-17 | LOCKED | Mechanical space uses BattleZones, selectable anchors, and four/two-Position engagement clusters. |
| G-009 | 2026-07-17 | LOCKED | Heroine Actions are freely interleaved within the Hero Phase; leftovers remain for reactions until Round Start. |
| G-010 | 2026-07-17 | LOCKED | Full RAV Momentum applies universally: losing side begins round one with zero Actions when Order margin is 3+. |
| G-011 | 2026-07-14 | PROVISIONAL | Use small RAV-scale HP rather than converting old triple-digit values. |
| G-012 | 2026-07-14 | PROVISIONAL | First dev battle uses the starting trio against Hollow Servant, Knife Footman, and Prayer-Rag Novice in a ruined chapel. |
| G-013 | 2026-07-14 | PROVISIONAL | The first cover prop is an overturned chapel pew or broken confessional. |
| G-014 | 2026-07-14 | LOCKED | The dev battle is noncanonical and does not alter Lysandra’s locked solo opening. |
| G-015 | 2026-07-14 | LOCKED | Natural 10s explode before Skill manipulation; modified 10s do not explode. |
| G-016 | 2026-07-14 | PROVISIONAL | Ordinary Skill manipulation is automatically optimized and shown to the player. |
| G-017 | 2026-07-17 | LOCKED | One Move permits two anchor steps; player chooses exact path, anchor, and Position. |
| G-018 | 2026-07-24 | LOCKED | Every eligible opposing combatant receives an independent sequential Move Reaction opportunity during a committed Move. |
| G-019 | 2026-07-17 | LOCKED | Cover denies ordinary ranged Attacks; AOE normally ignores cover; battlers do not block line of sight. |
| G-020 | 2026-07-17 | LOCKED | Attack reactions are Defend, Counterattack, or Skip; Defense methods are Dodge, Armor, Shield, and Parry where legal. |
| G-021 | 2026-07-17 | LOCKED | Parry can generate free Attacks; free Attacks use regular Attack rules, cost no Action, and may chain. |
| G-022 | 2026-07-17 | LOCKED | Expert Armsmaster gives two Attack pools only for great/two-handed or legal dual-wield configurations; one target and one Defense. |
| G-023 | 2026-07-17 | LOCKED | Remaining damage follows configurable Shield First/Armor First allocation with confirmation before breaking gear. |
| G-024 | 2026-07-17 | LOCKED | Enemy AI uses group and individual ordered rulebooks and reevaluates after each Action. |
| G-025 | 2026-07-17 | LOCKED | Phase-start effects resolve heal/regen → DOT → control → Action changes → expiry; periodic effects expire after actual ticks. |
| G-026 | 2026-07-17 | LOCKED | Grapple Attack uses preferred weapon pool + COR dice − RES dice, minimum 1d10, plus one automatic success; Dodge or Skip only. |
| G-027 | 2026-07-17 | LOCKED | Multiple grapplers use separate tracks, one main track applies COR/RES, and Corruption controls maximum participants. |
| G-028 | 2026-07-17 | LOCKED | Standard, elite, and boss Grapples use 3, 4, and 5+ stages; Climax damages enemy max HP and ends the track. |
| G-029 | 2026-07-17 | LOCKED | Zero-HP heroines are defeated and inactive; ordinary healing cannot revive; explicit Revive restores stored remaining Actions. |
| G-030 | 2026-07-17 | LOCKED | Defeat has priority in simultaneous final defeat; existing Grapple tracks finish after a full party knockdown. |
| G-031 | 2026-07-17 | LOCKED | Resolve and Corruption persist between runs; a full wipe costs participating heroines 15 Resolve. |
| G-032 | 2026-07-14 | LOCKED | Rules produce ActionResult data; presentation animates that result. |
| G-033 | 2026-07-14 | LOCKED | Manual authoring precedes generators and generalized editors. |
| G-034 | 2026-07-24 | LOCKED | The 18-round Grapple audit defines initiation, reactions, attachment, positioning, stages, Hold limits, cooldowns, items, zero-HP behavior, UI, logging, persistence, and authoring validation. |
| G-035 | 2026-07-24 | LOCKED | Grapple is shown by one progress bar above each attached enemy sprite; Standard hides cooldown/intent, while Easy may show cooldown as an effect above the sprite. |
| G-036 | 2026-07-24 | LOCKED | A six-slot Items panel persists across exploration and battle; the battle-only CommandBar is replaced by Struggle, Wait, and Submit while grappled. |
| G-037 | 2026-08-10 | LOCKED | Go Up after the Blood Nun reaches Layer 3; Go Down reaches Layer 2's exit and launches the Jailer immediately. |
| G-038 | 2026-08-10 | LOCKED | First Jailer defeat establishes the Bloom Refuge in the farthest Layer 2 cell without defeating the Jailer. |
| G-039 | 2026-08-10 | LOCKED | Ordinary Layer 2 runs begin at the farthest-cell Refuge and move outward toward the Jailer at the exit end. |
| G-040 | 2026-08-10 | PROVISIONAL | Campaign save format v1 exists only at Refuge boundaries and auto-loads a valid Refuge save on boot. |
| G-041 | 2026-08-10 | PROVISIONAL | The exterior Castle image controls broad layer relationships and identity, not literal architecture or playable adjacency. |


# 21. Foundation Checklist

This checklist is retained as implementation history. Combat logic has already
progressed beyond the original first-session boundary.

- [x] Create empty Godot project.
- [x] Record exact Godot version here.
- [x] Add `.gitignore`.
- [x] Create `main.tscn`.
- [x] Create the combat sandbox scene.
- [x] Add a battlefield placeholder.
- [x] Add selectable markers for six battlers.
- [x] Add a `CanvasLayer`.
- [x] Build party strip with Containers.
- [x] Build action bar.
- [x] Build functional order/phase panel.
- [ ] Build battlefield-effects panel.
- [x] Add End Hero Phase and manual End Enemy Phase controls.
- [ ] Add Settings.
- [x] Configure 1920×1080.
- [ ] Test one smaller and one wider window.
- [ ] Write down confusing Godot concepts before continuing.

---

# 22. Definition of a Healthy Foundation

The foundation is healthy when:

- the project launches directly into the chapel dev test;
- the screen resembles the approved visual target;
- battle state exists separately from sprites and UI;
- zones, anchors, and Positions can be edited without rewriting rules;
- one action follows request → validation → resolution → presentation;
- dice are inspectable and deterministic in tests;
- enemy behavior comes from inspectable group and individual rulebooks;
- debug tools make failures reproducible;
- no Unity combat formula is required;
- no system is generalized before one concrete version works;
- the developer can explain every major scene and script.

---

# 23. Chat Handoff Instructions

Attach this file and any `.gd`, `.tscn`, or `.tres` files relevant to the immediate task.

Suggested opening:

> Continuing Abyssal Bloom Godot development. The consolidated Master Reference is attached and is the only current source of truth. Current status: [state exactly what exists]. Next goal: [one concrete milestone or bug].
