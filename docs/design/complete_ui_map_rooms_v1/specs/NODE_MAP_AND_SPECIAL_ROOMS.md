# Node map, special rooms and Intel — consolidated gameplay specification

Use the unified execution plan in ../02_IMPLEMENTATION_STAGES.md. Art paths are relative to ../Node_Map_Art/. This specification supplies accepted gameplay rules and repository audit pointers; it is not a second task plan.

## 1. Repository findings and local audit

GitHub `FuryFluffy/AB_Godot_project` main was inspected on 8 October 2026 at commit `61a916795fc050a24a31808b76be205b44832481`. These findings are a navigation aid, not a claim about uncommitted laptop changes.

| Existing source | Finding / purpose |
| --- | --- |
| `scripts/map/run_state.gd`, `_make_enemy_composition` | ELITE handling exists. One branch returns `hollow_servant`, `knife_footman`, `prayer_rag_novice`; another returns `red_wax_acolyte`, `hollow_servant`. Reuse the existing trio and verify the local branch's formations. |
| `scripts/map/layer_map_generator.gd` | The inspected generator does not place ELITE nodes. The encounter definition existing alone does not make Elite rooms reachable. |
| `scripts/map/main_controller.gd` | Existing controller/UI entry point; includes an Elite description. Inspect current room/encounter transitions before wiring new types. |
| `scripts/map/map_node_state.gd`, `layer_map_graph.gd`, `layer_map_view.gd` | Existing node, graph and presentation infrastructure. Extend rather than replace it wholesale. |
| `scripts/map/run_inventory_state.gd`, `run_state.gd` | Inspect reward routing, source claims, deferred rewards and run persistence before changing collection lifetime. |
| `scripts/exploration/event_room_screen.gd` and exploration item resources | Reuse authored room hotspots, containers, hidden content and item routing. |
| `scripts/refuge/refuge_management_controller.gd`, recipe definitions/catalog | Reuse known recipe data and production transactions; field material ownership and output destination differ from Refuge. |
| `scripts/data/skill_entry.gd` | Awareness exists as `SkillEntry.Skill.AWARENESS`; tiers include UNTRAINED, NOVICE, EXPERT, MASTER, GRAND_MASTER. There is no need to invent a separate Perception stat. |
| `scripts/battle/rules/dice_resolver.gd`, `skill_rules.gd` | Existing attribute dice and skill/tier adjustments should resolve checks. Do not add an unrelated probability system. |
| `data/abilities/seraphine_light_arrow.tres`, `data/ability_effects/attack_light_arrow.tres` | Light Arrow gameplay resources exist. The actual current visual effect must be found on the laptop; the main inspection did not establish that implementation. |
| `tests/test_node_map.gd`, reward/refuge/recipe tests | Existing regression checks to inspect and extend where behavior changes. |

Confirm the current engine version and renderer from the project. Vic's target is Godot 4.7 / GL Compatibility, with 4.7.2 locally. Verify effects in that actual environment rather than introducing an untested renderer requirement.

Snapshot source links: [Elite formations and run state](https://github.com/FuryFluffy/AB_Godot_project/blob/61a916795fc050a24a31808b76be205b44832481/scripts/map/run_state.gd), [map generator](https://github.com/FuryFluffy/AB_Godot_project/blob/61a916795fc050a24a31808b76be205b44832481/scripts/map/layer_map_generator.gd), [Awareness and tiers](https://github.com/FuryFluffy/AB_Godot_project/blob/61a916795fc050a24a31808b76be205b44832481/scripts/data/skill_entry.gd). These links pin the inspection; local changes may be newer.

Stage 00 must also locate the current preparation UI, Bloom wallet, permanent upgrades, campaign loss policy, Struggle/Submit logic, run material representation, current rest charges, within-layer automatic backtracking, boss-death persistence and the Layer 2 reverse route. Separate implemented behavior from older planning documents.

## 2. Map generation and knowledge

### Layout

- Each layer has **14–18 playable rooms**, including special rooms. They are not added beyond that budget.
- Main route: approximately **8–10 rooms**. Add **2–4 side branches**, usually **1–3 rooms** long, with **at least two genuine dead ends**.
- Preserve mandatory story/recruitment ordering and boss reachability. Existing story dependencies are constraints on generation, not content to discard.
- Preserve the Refuge-less Layer 2 direction **Jailer → Farthest Cell** and the authored Refuge origin sequence. New special rooms must not make that route impossible or force premature Refuge establishment.
- Special-room counts per layer: **Elite 1–2; Trap 1–2; Treasury 1–2; Rest 0–1; Alchemy 0–1; Workshop 0–1**. Alchemy and Workshop are independently optional.
- Keep layout generation reproducible for a run. Validate connectivity, required ordering, room budgets and mandatory reachability across representative seeds.
- Optional recovery/resources support a possible Refuge-less run through strategy and luck. Do not guarantee a Rest room, force a supply purchase, or add remote Stash access to ensure success.

### Discovery

All node positions are visible on the map. An unidentified room is a question-mark medallion. Connections begin hidden unless already discovered or revealed by purchased Intel.

Ordinary adjacency discovery happens after a **successful room exit**, not because a room became Cleared or Solved. Evaluate each exit separately. An available exit can reveal its accessible adjacent connection; a still-locked door does not reveal the route beyond it through that exit. An ordinary open passage does not require collecting all items or finding secrets first. Merely closing a menu must not count as taking an exit.

Without Scouting, newly reachable adjacent nodes remain `?` until entered. Scouting identifies adjacent room types through the eligible adjacency discovery. Global type-revealing Intel can identify remote nodes without discovering their routes. Never infer route visibility merely from knowing a room type.

Discovered knowledge persists for the run and across save/load. Hidden routes have no faint lines or placeholders. Unknown rooms must not leak names, types, item counts or secrets through tooltips, accessible labels, debug-derived player text or detail panels. Intel grants knowledge, not permission to traverse a lock.

### Separate progression state

| State | Meaning |
| --- | --- |
| Visited | The party entered the room. |
| Accessible exit | The current runtime conditions allow that particular exit. |
| Discovered connection | The player knows that connection exists. |
| Cleared encounter | The required combat/progression encounter was resolved. |
| Solved room | All authored content was resolved, including hidden content and secrets. |
| Used Rest | That room's one recovery use was confirmed and consumed. |

Do not collapse these states into one flag. A room can be Visited and leaveable while unsolved. Solved evaluates underlying authored content, not only currently revealed hotspots. Do not display undiscovered secret counts or locations to explain an unsolved state. Permanently resolved mutually exclusive authored outcomes count as resolved rather than making Solved impossible.

Within-layer backtracking should use the existing automatic travel through **visited rooms along known accessible passages**. Re-evaluate current locks. Do not replay cleared battles, first-visit grants or collected rewards along the route. Selecting an unvisited destination may enter it only through a valid reachable route. Preserve the working behavior rather than rebuilding it unnecessarily.

Floor Up/Down art is included for future cross-layer backtracking. Reserve its integration points, but keep those controls hidden or disabled until the later feature is implemented; do not ship a button that pretends to work.

Boss kills remain permanent between runs. A dead boss is distinct from normal per-run Solved state and is not respawned for another reward. Respect existing story/campaign consequences.

## 3. Combat-only rooms and Elites

Normal and Elite combat rooms contain **only combat**. Entry immediately starts the encounter. There are no exploration hotspots, hidden caches, extra room-loot searches or retreat commands in these node types.

The existing Layer 1 hard Elite formation is the three enemies **Hollow Servant + Knife Footman + Prayer-Rag Novice**. This is the user's remembered 3-on-3 formation when the party has three heroines; do not silently force a three-heroine party, because the game allows fewer. Reuse existing enemy resources and stats. Audit the alternate Red-Wax pair on the laptop, preserve intentional supported variants and document which formation is assigned. The trio must remain available as the established Layer 1 formation; do not claim it was newly invented.

Victory marks a combat-only node **resolved/Solved**, displays the victory summary with findings and loot, and then returns to the node map. Defeat displays its summary and returns to map presentation through the existing run/campaign defeat-resolution flow. Preserve defeat losses and run termination where applicable; returning to map must not allow an ended run to continue or create a free retry. There is intentionally **no retreat combat rule** to add.

Do not erase mandatory story/recruitment dialogue from authored sequences merely because an encounter exists there. Preserve such automatic preludes/aftermaths and their campaign dependencies while keeping Normal/Elite combat-only node interaction free of exploratory hotspots. An alarm encounter in a Trap room returns to that authored room's remaining content after victory, rather than declaring the whole Trap room Solved.

Combat summary loot uses the established reward/inventory flow and confirmed abandonment of surplus post-fight loot, as specified in ../Refuge_and_Run_UI/12_Loot_and_Full_Backpacks.md. Persistent ordinary room contents do not add a post-victory exploration scene to combat-only rooms. Audit the local contract and report actual conflicts; never reuse the fight-abandonment close-handler for room contents.

## 4. Treasury and ordinary item persistence

Treasuries are authored exploration rooms with meaningful seeded contents, containers, visible item placements and optional hidden/gated rewards. Use the two approved backgrounds where appropriate: Layer 1 Servants' Storehouse and Layer 2 Confiscated Belongings Store.

**Closing collection leaves all uncollected room contents available for a later visit.** This applies to Treasuries **and ordinary authored item hotspots**, including items in **chests, sachets and hidden caches**. Preserve already working ordinary-item behavior. A room must not lose its remaining contents because a reward window closed or a partial collection occurred.

Persist contents and per-item/source claims. Remove a visible collectible sprite only after its successful pickup transaction. Leaving a full Backpack, cancelling collection, taking one item from a multi-item container or saving/loading leaves the other items intact. Collected items and source grants cannot be duplicated by repeated opening, return visits or load.

Use stable run contents: leaving and revisiting must not reroll item identity, container contents, hidden rewards or traps. Keep authored hotspot anchoring and content separate from painted background scenery. Solved reflects all authored Treasury content, including hidden content, rather than merely opening a chest or dismissing a loot window.

## 5. Trap rooms and Awareness

Trap rooms are regular authored rooms with items, lore, hidden content and exits. Item hotspots can carry a trap-capable flag such as `is_trap`. At run initialization/first authoritative assignment, randomly select eligible trapped item hotspots and trap effects from configured pools. The same authored room can trap a different item and use a different effect on a later run.

Persist those assignments during the run. Do not reroll when entering again, inspecting an item, reopening a menu or loading a save. Some eligible items can remain safe. Avoid making the entire room one uniformly trapped interaction.

### Trigger and target

A trap triggers once when its item is successfully collected, or immediately on a failed Disarm check. Looking at an item, closing its interface, cancelling, choosing Ignore and a capacity-rejected pickup do not trigger it. Take the effect from the saved assignment, not a fresh roll.

HP, Resolve and Corruption penalties affect **only the currently chosen/interacting heroine**. They do not hit every party member. Alarm traps start a party encounter through existing combat infrastructure.

Example pool entries from the agreed discussion, to remain balance data:

| Effect | Consequence |
| --- | --- |
| Poison Fog | Chosen heroine loses 5 Resolve and 1 HP. |
| Alarm | Start a battle with 2 Hollow Servants. |
| Corruption | Chosen heroine gains 20 Corruption. |

Do not add an ongoing poison status duration or further mechanics merely because the example is named Poison Fog. Use existing resource bounds and loss rules.

### Detection

Any heroine in the **active party** can identify a trap; detection is not restricted to the heroine selected for collection. For each eligible observer, use the existing Awareness skill and skill-check system. A trap definition has a required-success threshold and a configurable automatic-detection tier. A sufficiently high tier identifies automatically; otherwise an Awareness check with sufficient successes identifies it. Do not pool several heroines' successes into one invented check.

Use the project's existing attribute/check pairing if defined. **Intellect + Awareness** is the agreed implementation direction if a new pairing is needed. Tier and success thresholds are authored/balance parameters. The discussion's “Mira has Awareness 4 Expert” is an example of detection behavior, **not permission to change Mira's starting character sheet** or to make Expert automatically identify every possible trap.

On room entry, a successful detector speaks through the existing dialogue window. Name the detecting heroine, hotspot place and item, for example: **“There is a trap here: bookshelf, red potion.”** Use authored display names. Do not reveal a trap that failed detection, and do not repeatedly reroll or repeat the announcement on ordinary revisit/load.

Persist per-observer check completion/outcome and room detection state. A later genuine party/progression change may be evaluated for a newly eligible observer if needed; menu reopening and selection changes alone must not create unlimited rerolls. Establish the precise trigger through the existing run lifecycle and record the implementation choice.

### Identified interaction

Interacting with an identified trapped item opens **Disarm / Collect / Ignore**.

- **Disarm:** the currently selected heroine makes the existing plain **Agility** check, or an already implemented appropriate disarm skill if the project defines one. Configure the threshold. Success makes the item safe and leaves it available to collect. Failure immediately triggers the assigned trap; a second free attempt is not granted.
- **Collect:** deliberately collect despite the identified trap. Run normal capacity validation first; a failed pickup must not inflict damage. A committed pickup triggers its saved effect once.
- **Ignore:** leave the item, trap and room use state unchanged.

The disarming heroine can differ from the heroine who identified the trap. Persist detected, disarmed, triggered and collected states independently. An alarm victory resolves that encounter only; remaining authored items/secrets still govern Trap-room Solved. Inspect the existing encounter/reward transaction to avoid double rewards or trap replay across combat transitions.

### Native visual effects

Follow `NATIVE_TRAP_PARTICLES.md` from ../Node_Map_Art/. Poison uses a brief local green cloud and Corruption a brief local violet cloud **above the trapped item**, using native Godot particles and the current laptop's **Light Arrow** presentation as the reference. There are no screen-wide cloud PNG overlays in the accepted art.

Capture the displayed item anchor before removing its sprite; let the room own transient effects so they can finish after collection. Keep effects aligned on resizing, clean them up on exit/encounter transition, and do not replay them on revisit/load. Detection alone shows dialogue/identification art, not damage particles. Particles present the committed trap result and must not independently apply gameplay consequences.

## 6. Rest rooms: exactly one assigned offer

Spawn **0–1 Rest room per layer**. When the room is spawned, randomly assign **one** of the six effects below. That single offer is fixed for the room and run. The player does **not** choose between six services or a multi-option subset. A later layer's Rest room independently rolls its own effect and **may repeat** an earlier one.

| Assigned offer | Recovery for each active party heroine |
| --- | --- |
| 1 | Restore 50% of maximum HP. |
| 2 | Restore 50% of maximum MP. |
| 3 | Restore 50% of maximum HP and 50% of maximum MP. |
| 4 | Restore 20 Resolve. |
| 5 | Reduce Corruption by 20. |
| 6 | Restore HP, MP and Resolve to their maxima; add 50 Corruption **to each** heroine. |

Resource changes are capped at valid maxima/minima. The percentage is an amount added based on the maximum resource, not “set the current value to 50%.” Use existing integer rounding conventions consistently; if none exists, document the chosen rounding rule.

There is **no currency or material cost**. Show the single offer and a **per-heroine before → after preview**, including the Corruption cost of offer 6, then **Confirm / Cancel**. Consume the room's use only on a successful Confirm transaction. Cancellation, leaving and revisiting keep unused recovery available. Persist the assigned effect and used flag across save/load. Consumed recovery cannot be repeated.

This is **one use per Rest room per run**, independent of the existing **two ordinary rest charges per run** from the Backpack/run UI. Do not spend a general rest charge, reset those charges or replace that earlier feature. Use the spent-Rest badge independently of the room's Solved state. Resolving all authored content does not consume an unused recovery offer.

## 7. Field Alchemy and Workshops

Spawn **0–1 Alchemy room** and **0–1 Workshop** independently per layer. Reuse the approved authored room backgrounds and the existing recipe/production interface where practical.

- Materials come exclusively from the **current run**. Refuge's banked Materials and Stash are unavailable during the run.
- Production results go into the **Backpack**. Do not deposit remotely into Stash.
- Offer every **known recipe appropriate to the station type**, using the permanent recipe library. A station is not restricted to a bespoke small production list. Authored selection applies to recipes found there, not to limiting the known recipes usable there.
- Recipes can be found in these rooms and are permanently added to the known-recipe library. This discovery survives defeat and the end of a run; do not treat knowledge as a losable Backpack recipe item unless an existing discovery interaction needs such an item before learning.
- Finding/first visiting the room also grants some current-run materials **once per room per run**. Use normal capacity/claim routing where relevant and retain any uncollected grant safely. Reopening/revisiting never duplicates it.
- Repeated production and later revisits are allowed while run materials and Backpack capacity permit. No extra per-station production charge, arbitrary craft count or room-consumed flag is added.
- Validate materials and output capacity before consuming inputs. Use an atomic transaction: capacity/material failure produces no item and consumes nothing. Account for existing stacking rules and output quantity.

Persist discovered recipes, first-visit grants, remaining authored items and run material consumption appropriately. Permanent recipe knowledge belongs to campaign state; currently available crafting materials belong to run state. Do not create a parallel conflicting material inventory if one already exists.

Alchemy/Workshop can become Solved after their authored rewards, discoveries and secrets are resolved while remaining **usable production services**. “Can still craft” does not keep a room unsolved forever.

## 8. Intel and Refuge preparation purchases

Use the established Refuge preparation flow and the same Bloom wallet as other approved preparation work. The options below are approved.

| Option | Benefit |
| --- | --- |
| Scouting | Identify adjacent room types through adjacency discovery. |
| Battle Sense | Identify all Normal and Elite Combat nodes in the layer. |
| Smell of a Coin | Identify a Treasury and reveal an actual route to it. Choose the target/path consistently for the run; do not draw an invented direct line. |
| Pathfinding | Show the layer's node connections. |
| Sanctuary Sense | Identify Rest nodes. |
| Danger Sense | Identify Trap-room nodes; it does not identify/disarm the particular trapped item. |
| Artisan’s Eye | Identify Alchemy and Workshop nodes. |
| Castle Memory | Reuse the last saved castle layout and its previously discovered map knowledge. |
| Conqueror’s Passage | Start an expedition from the boss room of an already defeated eligible layer boss. |

Knowledge never unlocks a door or makes a revealed path automatically traversable. Smell of a Coin may show a route containing a known blocked exit; preserve lock checks rather than secretly granting passage. Composition of several Intel options should be additive and should not erase discoveries.

### Purchase timing

**Clicking an affordable option in Refuge preparation buys it immediately.** Deduct Bloom once at that click and show the bought state. Cancelling preparation gives **no refund**; bought one-expedition options remain purchased for the pending run when preparation is reopened. Do not delay the purchase until Explore, or charge again on reopening/starting. Reject insufficient funds without changing either wallet or purchase state.

Consume one-expedition ownership when the corresponding expedition actually starts, not when preparation closes. Persist the pending-run purchases with the same lifecycle used by preparation. A defeat/end of the expedition ends its temporary benefits. Permanent benefits remain owned. An already owned permanent benefit should not require another one-expedition purchase.

### Permanent options and prices

Every approved one-expedition option has a permanent counterpart at **100 × its one-off price** for now. Example: one-run Scouting at 10 Bloom gives permanent Scouting at 1000 Bloom. These are price examples, not a finalized full price list.

Conqueror’s Passage is purchased for one expedition and its price scales with the selected layer: if Layer 1 is 100 Bloom, Layer 2 is 200, and so forth. Keep the base price configurable. For a permanent counterpart, use the same 100× rule for the corresponding layer entitlement; do not turn an inexpensive lower-layer unlock into every higher-layer shortcut. Preserve eligibility requirements and present the eligible layer before the purchase click commits its price. If a player switches preparation choices after already purchasing a shortcut, retain its paid entitlement for that pending run rather than refunding or charging the identical entitlement twice.

Add the separate **permanent upgrade that opens Submit during Struggle**. Reuse the existing Struggle system and its eligibility rules; do not make Submit an unconditional action outside it. Its exact price is still **TBD** and is not implied by the other examples.

All prices are authored/configurable. If temporary development prices are needed, mark them as provisional in data and implementation notes. Do not present them as final balance or silently overwrite unrelated existing prices.

### Castle Memory

Retain the reusable graph layout, node placements, room types and previously discovered node/route knowledge from the last castle layout. This is a preservation option, not blanket identification of every unknown room. Unknown rooms stay unknown where no other Intel reveals them.

On the new run, refresh enemies, remaining loot, resource grants, Rest assignments/uses and item trap assignments with fresh run encounter/content randomness. Do not restore prior Solved, collected, used or trap-triggered state. Keep permanently dead bosses dead. Previously known connections can be remembered while their current locks/accessibility are re-evaluated.

Separate layout identity/map knowledge from per-run encounter/content seed and progression. “Same layout” does not mean identical rewards or already collected items. Preserve the snapshot on run end according to the existing campaign lifecycle so a defeat does not unintentionally wipe the purchased memory benefit.

### Conqueror’s Passage

Eligible bosses have already been killed permanently. Starting from their room therefore does not respawn the boss or award its kill again. Respect existing story/Refuge access prerequisites and normal expedition starting resources. Skipped rooms do not become Visited/Solved and grant no free XP, loot, first-visit materials or recipe discovery.

Keep ordinary backtracking available through valid known passages after the shortcut start. Do not add cross-layer travel under the guise of this option; Floor Up/Down remains a later feature.

## 9. Art integration

Art paths below are relative to the extracted `Node_Map_Art/` folder. Read the delivered `manifest.json` rather than assuming every Intel option has a unique PNG path.

| Presentation | Asset / behavior |
| --- | --- |
| Map background | `map/background/occult_parchment_flat.png`; flat parchment, no panorama. |
| Room types | Eleven separate `map/nodes/node_*.png` textures, each already containing its gold medallion. Do not add an old frame over them. |
| Current location | `map/states/current_bloom.png`; draw behind the room medallion, initially about 1.55× its bounds. |
| Visited / Solved / Rest used | Independent generated badges, respectively lower-left / lower-right / upper-left as a starting proposal. |
| Known lock | `map/states/known_lock.png`; associate with the actual known locked exit/edge. The review sheet's corner example is not a rule that every exit is locked. |
| Selection / focus | Precise existing SVG/PNG borders; independent from Current location. |
| Intel | Manifest maps some benefits directly to their matching room emblems; labels, prices and ownership state are live UI. |
| Trap feedback | Identified eye, disarmed badge and alarm bell. Poison/Corruption are native local particles. |
| Floor controls | Existing art reserved for later cross-layer navigation. |

Preserve texture aspect ratios and live text. Start around **88 px node bounds at 1080p**, with zoom available; tune in the running game using the included 48/72/96 px readability preview. Fine engraving is not expected to remain fully visible at tiny sizes. Maintain readable focus/selection and meaningful tooltips for known content.

Draw changing connections, Treasury paths and discovery highlights in Godot behind nodes. The included `previews/map_composition.png` is a demonstration, not an authored map to reproduce or a background containing gameplay positions. Apply the actual generated graph.

The five room images are in `rooms/`. `hotspot_anchor_proposals.json` provides normalized centres for authoring, not validated hit boxes. Transform through the displayed image rectangle and check hit areas at different aspect ratios. Runtime item sprites, discovered recipes and material grants remain separate from the painted background.

Use `NATIVE_TRAP_PARTICLES.md` for Light Arrow-style effect integration, and `presentation_notes.json` for state positions. Keep particle effects out of modal panels and avoid covering other items. Existing ordinary Backpack/Refuge UI conventions continue to apply; do not fill the screen with another oversized permanent panel merely to expose these services.

## 10. Unified implementation order

The independent node-map Stage 00–11 order is superseded by ../02_IMPLEMENTATION_STAGES.md. Execute Stage 00 audit first, then one consolidated stage per reviewed cycle. Use the per-stage checks there; preserve all gameplay requirements in this specification.

## 11. Per-stage review format

For every implementation stage, report:

1. What changed and what the player now sees/does.
2. Which existing subsystem was reused and any save migration.
3. Tests/checks run and their actual results.
4. A short reproducible in-game review sequence, with a seed/fixture where useful.
5. Remaining uncertainties, balance placeholders or deviations requiring a decision.

Then stop for review. Keep each stage separately reviewable and follow the repository's commit/workflow rules. Correct a failed stage before advancing. Routine implementation choices within these rules do not need a new design debate; only surface an actual conflict or missing consequential rule.

## 12. Balance and authoring values intentionally left open

Exact option prices except the 100× relationship and Conqueror layer scaling; Submit unlock price; reward quantities/weights; eligible hotspot trap counts; trap success thresholds and automatic-detection tiers; station material/recipe discovery selections; final service/loot balance; final Boss icon. Use existing authored data/configuration and clearly marked provisional development values. These open balance fields do not change the accepted interaction, persistence, ownership or purchase rules above.

The historical word “subsets” in the Rest discussion has been clarified: **one effect per room**, not a subset the player chooses from. The earlier station suggestion of an authored crafting recipe list has also been clarified: **all known station-appropriate recipes**, plus authored recipe discoveries. The one-off prep payment is immediate, cancelled prep is not refunded, and item persistence includes ordinary hotspots and containers as well as Treasuries.
