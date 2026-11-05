# Unified implementation stages — Stage 00–24

Execute one reviewed stage at a time in the existing local project. The two previous independent sequences are replaced by this plan. If a stage already works, verify it and fix only in-scope gaps. If the audit justifies combining/skipping a stage, propose that change before altering review boundaries. Detailed specifications supply exact behavior; these stage summaries do not authorize invented balance or missing mechanics.

Complete the current stage autonomously, run appropriate repository checks, leave a runnable path and provide concrete player checks plus evidence. Then STOP for Vic's verification/continue instruction. Track implemented, tested and user-verified separately. User corrections stay in the current stage. No remote push/merge is requested.

## 00 — Local audit and combined implementation plan

Read root authority/conflict documents, every relevant UI specification, specs/NODE_MAP_AND_SPECIAL_ROOMS.md and both art/placement notes. Inspect AGENTS.md, branch/working tree/checkpoints, engine/renderer, baseline tests and actual local systems. Identify owners of inventory/instances, keys, run/banked Materials, recipe knowledge, Actions, claims, graph discovery, prep purchases, saves, run loss/return, rest counters and permanent bosses. Confirm the Elite trio and current Light Arrow VFX; preserve the Layer 2 reverse/Refuge-origin sequence.

Deliver an implemented/missing/conflicting matrix, source/asset mapping, actual baseline results, any precise consequential gap, and proposed stage/file boundaries. In this first stage **do not modify gameplay or UI**. Stop for review before Stage 01. Do not reset to the historical GitHub snapshot or infer missing local behavior from main alone.

## 01 — Refuge room framework

Preserve the original background. Place five prop layers and eight station hotspots from the proposed geometry, adjusting visually in Godot. Implement Bloom-only default HUD, highlights/tooltips, one station panel, nested Escape/focus return, spatial controller focus and system menu. Station shells may be unavailable until their backend stages; do not fake successful services. Existing exploration navigation is outside this stage.

Player checks:
- Enter the real Refuge; verify no permanent room title or station labels and only Bloom in the default HUD.
- Reach all eight stations by mouse and supported keyboard/controller; hover highlights/tooltips clear correctly.
- Close a panel/nested dialog; verify focus returns and Escape does not also open the system menu.
- From the room, Escape opens Save/Load/Main Menu/Settings/Quit and returns normally, respecting existing safe-save rules.
- Resize/check supported aspect ratios: props and hotspots stay aligned, including Records versus weapon rack.


## 02 — Shared inventory views

Build reusable Stash/Backpacks views, familiar named selector, fifteen-slot personal grids, shared Key-ring outside slots, Materials in Stash, and conditional six-slot Item Bar. Establish instance ownership without changing defeat protection. Reuse a native Item Bar component that will later join the run dock.

Player checks:
- Stash chest opens Stash first; Backpacks switches heroine bag without selecting the expedition party.
- Count fifteen slots in three columns/five rows; Key-ring remains party-shared and uses no bag slot.
- Shared six-item bar appears for Backpacks in its intended HUD location, without duplication, then hides on return to normal Refuge.
- Materials reflect the existing banked quantities; closing/reopening displays actual owned state.


## 03 — Inventory transfers and stacks

Implement legal full-stack moves, same-item merges, exact-source swaps, Split, partial-swap rejection, named quick transfers, merge-first/first-free placement and atomic rollback. Preserve quantities and equipment instance/condition through transfers.

Player checks:
- Backpack↔Item Bar: empty move, different-item swap returning to exact source, matching merge with remainder, full matching target no-op.
- Split quantity to empty/matching targets; partial drop on a different occupied item fails; cancellation changes nothing.
- Stash right-click Move to Backpack→named heroine, reverse Move to Stash; merges first then first free positions, overflow stays at source.
- A full bag can accept a matching merge; quick transfers never evict unrelated items.
- Save/reload committed changes; no duplicate gear, quantity loss or altered condition.


## 04 — Refuge Loadouts

Approved selector and four equipped rows. Change lists compatible items from Stash and every Refuge heroine Backpack with sources and Nothing. Implement source-return exchange; Nothing returns removed gear/Memento to Stash. Use current slot eligibility; unresolved multi-slot conflicts need explicit review.

Player checks:
- Change each supported slot; compatible sources/instances are correct; no equipped item is duplicated as stored inventory.
- Equip from Stash returns the old item to Stash.
- Equip from another heroine's full Backpack returns the old item to that exact source slot.
- Nothing returns removed item to Stash; Nothing on empty is a no-op; Back/Escape browses without mutation.
- Verify identity/condition and reload.


## 05 — Workbench

Repair/Salvage tabs using actual existing costs/yields. Repair includes equipped gear; salvage requires unused gear and confirmation. Reuse ownership services.

Player checks:
- Sources and condition are visible; repair cost and outcome match current definitions.
- Insufficient resources cannot repair; cancelling changes nothing.
- Equipped gear cannot be salvaged until unequipped.
- Confirm salvage destroys the correct instance and gives exactly the displayed authored yield; cancel does neither.


## 06 — Alchemy and Crafting

Two distinct menus with shared recipe flow: Alchemy ingredient-convergence layout, Crafting blueprint/checklist layout. Shared banked Materials; Brew/Craft outputs merge into Stash. Use actual recipes/costs; no screenshot-authored balance. Factor the production transaction so input/output ownership is an explicit provider; do not let the later field context access banked Materials or Stash.

Player checks:
- Separate apparatus and toolbox open the correct distinct menus.
- Recipe, owned/required quantities and result preview agree with definitions.
- Successful operation consumes ingredients/cost and produces output once in Stash, merging to caps.
- Insufficient ingredients and cancellation consume nothing; failures do not create a partial transaction.


## 07 — Refuge Rest station

Bed panel: choose heroine, show actual Resolve/Corruption and Restore Resolve/Cleanse Corruption with existing authored costs. This is not run HP/MP Rest.

Player checks:
- Select each heroine; values/costs are correct.
- Confirm supported recovery changes only the intended heroine/resource and charges once.
- Unavailable/no-op/insufficient-resource operations follow existing rules; opening/closing is free.


## 08 — Refuge Expedition hub

Accessed-floor graphical map plus Party/Intel/Level Up/Explore. Reuse roster and existing progression/Intel services. Purchase timing/effects are settled by specs/NODE_MAP_AND_SPECIAL_ROOMS.md. Integrate actual available backend behavior. New Intel shells stay truthfully disabled until Stage 22 provides their purchase/effect transactions; do not charge for placeholders or at launch.

Player checks:
- Map shows accessed floors/deepest reach, not cleared floors; merely reaching a floor does not grant Conqueror’s Passage eligibility.
- Refuge Party shows roster sprites and 1/2/3 selection order; Backpack selection does not change the roster.
- Intel This Run/Permanent persistence and actual costs/effects agree with reviewed definitions.
- Level Up selector, Stats/Skills/Heroine Upgrades map to real supported data rather than mockup labels.
- Explore enters a run with the correct ordered party and ownership transfer, no duplicated bags/gear/charges.


## 09 — Records and Gallery

Lore/Bestiary/Run History/Gallery. Reuse existing archive data. Show actual available image/replay actions; absent data is truthfully unavailable. Implement supported replay without campaign changes or repeated rewards.

Player checks:
- Category/list/reading and thumbnails work with discovered/available data.
- View Image returns to Gallery; Replay Scene returns to Gallery.
- Replay does not change campaign flags, unlocks, inventory, stats, currency or rewards.
- Back/Escape follows nested navigation and returns focus to Records.


## 10 — Run bottom HUD

Apply approved native dock to intended combat/exploration contexts, preserving current controllers and any existing presentation pilot. Party cards→six items→separate Backpack→commands, collapsible log above. Correct context commands and real availability. Reuse Ability button/popup.

Player checks:
- Normal combat: Attack/Move/Ability/End Phase. Struggle: Struggle/Wait/Submit/End Phase, Backpack disabled, Submit context gating intact; its approved permanent unlock is implemented at Stage 22.
- Exploration: Party/Ability/Rest before Refuge, Party/Ability/Return after; no Move/Continue.
- Exactly six item slots plus distinct Backpack, in stable placement; one/two/three heroine layouts and actual quantities/status/Action values.
- Log, Ability and existing reactions/targeting still operate and cancel correctly; UI blocks battlefield clicks.
- Inspect supported desktop resolutions, popup clearance and existing camera behavior.


## 11 — Same Backpack in runs and combat permissions

Connect the Stage 02/03 component to run ownership. Exploration uses current-party bags without Stash. Combat opens on actor and permits only approved weapon/armor replacements and shared Item Bar changes, charged atomically at 1 Action each.

Player checks:
- Open during exploration: same selector/grid/Key-ring/transfer behavior, no Stash; shared bar stays visible.
- Combat opening/browsing/cancelling is free; one successful swap/merge/equip spends actor's one Action; multiple changes spend separately.
- Failed/no-op/insufficient-Action changes neither alter inventory nor charge.
- Other heroine browsing cannot change actor, consume her Actions or mutate her bag; unapproved combat Memento/handoff/standalone-unequip/Use/Discard routes stay unavailable.
- Grapple disables Backpack access including keyboard/controller shortcuts.


## 12 — Loot UI and persistent source transactions

Wire fight rewards and ordinary item/container sources to the same adjacent Loot/Backpack interface. Reuse inventory capacity/transfer services, Use/Discard, source claims and save transactions. Source identity owns remainder lifetime: ordinary room hotspots/containers persist after close; post-fight surplus uses the existing confirmed-loss abandonment policy. Establish reusable persistence now for Stage 18 Treasuries and Stage 19 trapped item pickup. Do not create remote Stash access or equip directly from Loot.

Player checks:
- Fight reward and ordinary room/container sources both use Loot beside Backpack with exactly one shared Item Bar.
- Empty slots, compatible merges with 15/15 occupied, full matching stacks, partial accepted quantity and alternative heroine capacity conserve contents.
- Use/Discard affect carried items; cancellation changes nothing. Confirmed fight abandonment loses only that fight surplus.
- Close an ordinary item/chest/sachet/cache offer; leave/revisit/load and collect the exact remainder later. Nothing rerolls or duplicates.
- Failed pickup preserves the source and is available for the later trap transaction; gear enters a bag before equip.


## 13 — Run Party

Reuse standing-sprite screen with current members only, details, selection highlight, order badges, drag and left/right controls. Immediate order update; no roster removal/recruitment or separate Done.

Player checks:
- View each heroine's actual stats/effects/equipment.
- Drag and left/right reorder; boundary controls work; HUD updates immediately.
- Close/reopen and save/load retain order; party members and their inventories remain intact.
- Test one/two/three members; selection alone does not reorder or modify gear.


## 14 — Run Rest/Return

Before establishment: HP/MP Rest +10 Corruption, twice per run, confirmation plus remaining count only. After: Return confirmation simply "Return to Refuge?". Preserve current recovery recipient/return rules, reporting missing definitions precisely.

Player checks:
- Cancel at two; first successful Rest leaves one; second leaves zero; third cannot execute.
- Room/floor transitions and same-run reload do not replenish rests; genuine new run restores two.
- Actual recovery/+10 Corruption use the reviewed canonical recipient scope.
- Refuge establishment changes the tile to Return. Cancel stays in run; confirm returns once with correct existing ownership behavior.
- Refuge bed recovery remains separate.

## 15 — Graph state, generation, discovery and existing backtracking

Implement/extend persistent map state and the generated room distribution using the accepted node-map rules: 14–18 rooms; approximately 8–10 on the main route; 2–4 side branches of 1–3 rooms; at least two genuine dead ends. Within the budget: Elite 1–2, Trap 1–2, Treasury 1–2, Rest 0–1, Alchemy 0–1 and Workshop 0–1 per layer. Preserve mandatory story order, permanent bosses and the Layer 2 Jailer → Farthest Cell Refuge-less route.

Keep Visited, discovered connection/type, accessible exit, cleared encounter, Solved authored content and used Rest distinct. Reveal eligible adjacency after an actual successful exit without requiring Solved; a locked exit reveals no ordinary route beyond it. All node positions remain visible as unknown until identified; hidden edges have no placeholders. Reuse automatic backtracking through known accessible passages and visited rooms. Separate layout/knowledge identity from fresh per-run content so Stage 23 can reuse it.

Player checks:
- Representative seeds satisfy counts, connectivity, mandatory order/boss reachability and real dead ends; no over-budget special-room additions.
- Leaving an unsolved room through an open exit reveals adjacency; a closed door does not. Merely dismissing a panel is not an exit.
- Unidentified neighboring nodes remain question marks without Intel; type knowledge does not imply route knowledge or unlocked passage.
- Revisits/backtracking retain knowledge, apply current locks and replay no encounters/rewards. Save/load conserves all distinct states.
- Solved includes hidden authored content without exposing secret counts; the reverse Layer 2/story sequence still works.

Keep not-yet-playable special types behind an internal fixture/feature gate until their implementation stage; do not expose crashing or fake-success destinations in ordinary gameplay. Append serialized enum values or use the project's existing migration mechanism.

## 16 — Flat node-map art and live presentation

Use Node_Map_Art/manifest.json, the flat parchment, eleven separate gold medallions, independent violet Current ring, state badges, precise selection/focus and dynamic route drawing. Preserve aspect and responsive focus/tooltips. Start around 88 px at 1080p and tune with the included readability sheet. The demonstration map is not a seed or baked topology.

Player checks:
- No panorama or baked nodes/routes. Actual generated layout drives the view.
- Current + Visited + Solved + used Rest coexist without hiding the type; known lock represents the relevant exit/edge.
- Unknowns leak no room type/name/secrets in hover, focus or detail panels; hidden routes have no faint lines.
- Mouse/keyboard/controller selection and backtracking work at supported aspect ratios, with legible zoom and routes behind nodes.
- Floor Up/Down remains reserved and hidden/disabled until actual cross-layer travel exists. Provide actual Godot screenshots.

## 17 — Combat-only nodes and existing Elite formations

Wire generated Normal/Elite entry directly to combat. Reuse the existing Layer 1 Hollow Servant + Knife Footman + Prayer-Rag Novice trio; audit supported alternate formations. Victory resolves/Solves the node and shows findings/loot before map return. Defeat shows its summary and follows existing loss/end-run state into map presentation without enabling a free retry. No retreat rule or exploratory hotspots are added. Preserve required automatic story/recruitment preludes and aftermaths.

Player checks:
- Enter a real Elite trio encounter with three heroines, then a supported smaller party; no forced party size or invented enemies.
- Victory summary/loot/map return marks the combat node resolved. Defeat retains losses and an ended run cannot continue.
- Revisiting a resolved battle grants no repeat enemies/rewards. Combat-only rooms have no exploration phase or retreat button.
- Existing targeting, Actions, equipment permissions and story transitions still work.

## 18 — Treasury authoring and saved room contents

Author Layer 1 Servants' Storehouse and Layer 2 Confiscated Belongings Store using the approved backgrounds and runtime item/containers. Reuse Stage 12 claims/remainders. Include meaningful seeded rewards and optional hidden/gated content; anchors are editor proposals, not validated hit boxes.

Player checks:
- Successful pickup removes only the collected sprite/quantity; full Backpack leaves it intact.
- Close, leave, revisit and save/load preserve exact remaining chest/sachet/cache/visible contents; no reroll or duplicate first claims.
- Hidden unresolved content affects Solved without disclosing its count/location; current locks and exits work.
- Art/hit areas align at supported aspect ratios and collectible rewards are not painted into the background.

## 19 — Authored Trap rooms, Awareness and native particles

Use ordinary authored rooms with trap-capable item hotspots. Randomly assign trapped items/effects per run and persist them. Any active-party heroine can detect through existing Awareness checks or a sufficient configured tier; do not change Mira's starting sheet because an example used Awareness 4 Expert. Successful entry detection names the detector, place and item in dialogue. Identified interaction offers Disarm / Collect / Ignore; selected heroine disarms using plain Agility or an existing appropriate skill.

Successful disarm leaves a safe collectible item; failed disarm triggers once. A committed pickup triggers its saved trap, after capacity validation; Ignore/cancel/inspection/capacity rejection does not. HP/Resolve/Corruption affect only the chosen interacting heroine; alarms start party combat. Example effects: −5 Resolve/−1 HP, +20 Corruption, or 2 Hollow Servants. Reuse Light Arrow's actual local VFX lifecycle for a small native green/violet cloud above the item. No screen-wide fog PNG.

Player checks:
- Eligible high tier auto-detects; enough rolled successes detect; a failure leaks nothing. Another selected heroine can disarm/collect.
- Disarm success/failure, intentional Collect, Ignore and full-bag failure produce the exact state changes without extra charges or damage.
- Only the selected heroine receives penalties. Alarm combat returns to the remaining authored room; its victory does not alone Solve all content.
- Different runs may trap different items/effects; ordinary revisit/load/menu reopening does not reroll, duplicate damage or repeat detection dialogue.
- Particles remain at the item's captured displayed anchor after sprite removal, scale correctly and clean up on exit/combat transitions. Detection alone emits no damage cloud.

## 20 — Rest rooms with one fixed offer

Implement one random effect per spawned Rest room, fixed for that run. The six assignable effects are in specs/NODE_MAP_AND_SPECIAL_ROOMS.md: +50% max HP, +50% max MP, both, +20 Resolve, −20 Corruption, or full HP/MP/Resolve with +50 Corruption each. Apply to every active party heroine with bounds. No material/currency cost. Show one offer and per-heroine before/after preview, then Confirm/Cancel. Consume only after confirmed success; unused recovery remains available on revisit. A later layer may repeat the same assigned effect.

Player checks:
- A fixture exercises all six effects/caps; percentages add an amount based on maxima rather than setting current values to half.
- Exactly one offer, not six player choices; preview includes offer 6's Corruption for every heroine.
- Cancel/leave/revisit/load preserves unused recovery; confirmed use occurs once and persists.
- The ordinary Stage 14 two-use Rest and Refuge bed costs/recipient rules remain unchanged and independent. Solved does not silently consume recovery.

## 21 — Field Alchemy/Workshop and permanent recipe discovery

Reuse Stage 06 production layouts/transactions with explicit field ownership: current-run Materials only, output to Backpack, no banked Materials/Stash access. Every known station-appropriate recipe is available; authored selection controls recipe discoveries, not a restriction to a station-exclusive crafting list. Finding the room grants run materials once; recipe discoveries join the permanent library and survive defeat/run end. Repeated production/revisits remain available while inputs and output capacity permit, even after authored content is Solved.

Player checks:
- Refuge still consumes banked Materials and outputs to Stash; field actions cannot borrow either ownership provider.
- Known appropriate recipes craft repeatedly to Backpack with correct input consumption/stack capacity; insufficient inputs/capacity change nothing.
- First-visit materials/grants never duplicate and uncollected supply remainders remain available through proper source routing.
- Recipe discovery survives defeat/end of run; a new run does not restore consumed materials. No double banking/spending of a run-material copy.
- Revisiting a Solved station still crafts; no invented station-use/craft-count limit.

## 22 — Intel purchase effects, permanent counterparts and Submit unlock

Complete the Stage 08 Intel UI with the approved option list/effects. Clicking an affordable purchase deducts Bloom atomically once; cancelled preparation gives no refund and retains ownership for the pending run. Explore consumes temporary ownership without recharging. Permanent counterparts cost 100× one-off configured prices; already permanently owned benefits need no repurchase. Implement the separate permanent Submit unlock with existing Struggle/context gates and a clearly provisional/TBD price configuration.

Player checks:
- Scouting, Battle Sense, Smell of a Coin, Pathfinding, Sanctuary Sense, Danger Sense and Artisan's Eye reveal their specified knowledge alone and in combinations.
- Known types/paths never unlock doors or leak particular hidden item traps. Treasury path is a real graph route.
- Buy/cancel/reopen/save/load/Explore conserves wallet and pending ownership; insufficient funds/no-op duplicate purchase changes nothing.
- Permanent ownership/prices and one-run expiration follow the specified scopes. Viewing an option is free.
- Submit appears only in eligible Struggle after its permanent unlock; grapple Backpack disabling and phase semantics remain intact.
- Castle Memory/Conqueror's Passage options remain truthfully gated until Stage 23 completes their runtime behavior; do not charge for unsupported shells.

## 23 — Castle Memory and Conqueror's Passage

Preserve the last layout, placements/types and previously discovered knowledge for a memory run, including retained unknowns. Fresh run content resets encounters/rewards/resource grants/Rest/trap assignments and per-run Solved/used/collected flags; permanently dead bosses remain dead. Re-evaluate lock accessibility. Add eligible defeated-boss starting positions and layer-scaled one-run prices; permanent layer counterparts use the 100× relationship. Preserve paid pending entitlements when prep closes or choices are revisited; do not refund/recharge identical purchases.

Player checks:
- Reused layout and knowledge match the snapshot, but rewards/content/Rest/traps are fresh and no prior claimed/used state is restored.
- Unknowns remain unknown absent other Intel; current locks govern traversability; boss death never resets.
- Shortcut requires defeated eligible boss and current story prerequisites, charges the chosen layer price once, and starts with normal run resources.
- Skipped rooms gain no Visited/Solved/XP/loot/material/recipe credit and the dead boss grants no repeat kill reward.
- Valid within-layer backtracking works after shortcut start. Cross-layer travel is still deferred.

## 24 — Combined end-to-end acceptance and final evidence

Complete the original UI acceptance flow plus map/special-room/Intel lifecycle. Run repository-required checks and focused behavior tests for transactions, state/claims, graph constraints and purchase boundaries; avoid repetitive decorative UI tests. Distinguish baseline failures, actual passed tests, unrun checks, fixture evidence and normal gameplay.

Player checks:
- Refuge → inventory/equip/repair/salvage/craft/bed → ordered Party/Intel/Level Up → Explore → room/loot/trap/station/Rest → normal/Elite combat/struggle/Backpack → victory summary/map → Return.
- Pre-establishment ordinary Rest, Layer 2 reverse/Refuge-origin route, representative Refuge-less scenario, defeat, Castle Memory and Passage run are exercised with supported saves/fixtures as necessary.
- Save/load partial room containers, selected party/order/gear/condition/keys, used/unused Rest, detected/disarmed/triggered traps, permanent learned recipes and cancelled-prep purchases without duplication/loss.
- Gallery replay changes no campaign/unlock/reward state. Current equipment defeat protection remains the baseline; no deferred equipped-only loss is introduced.
- Inspect supported resolutions/input methods, nested focus/Escape, effect cleanup, input click-through and current engine/renderer.

Final report: implementation/test/user-verification status for every Stage 00–24, actual commands/results, runtime screenshots or recordings, normal-play versus fixture coverage, balance placeholders and precise blockers. No claim that packaging checks prove Godot integration, no blanket “complete” for unrun paths, and no claim that cross-layer travel or Companion interactions have been implemented.


