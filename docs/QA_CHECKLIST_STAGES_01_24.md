# Abyssal Bloom — Full QA checklist, Stages 01–24

Prepared 2026-11-05; finalized 2026-11-07 for branch [`codex/complete-ui-map-rooms-stages-01-24`](https://github.com/FuryFluffy/AB_Godot_project/tree/codex/complete-ui-map-rooms-stages-01-24). Gameplay publication: [`06e4b80`](https://github.com/FuryFluffy/AB_Godot_project/commit/06e4b802e8c2a331e72bf4cce3e0102f8921a27a); corresponding development commit: `a9a917db71854531d0943cbb32e080a333de9b18`. This checklist is a test plan, not a claim that the manual checks have passed.

## How to use this list

Start with the smoke route, then complete the stage checks and save/loss matrix. Record the exact tested commit, seed, save slot, device and resolution. Use an expendable test campaign; retain a copy of any valuable campaign before testing interruptions. Never inject failure/corrupt-save cases into a valuable save.

Use **Continue** to resume an active-run safe point. Main Menu **Load** restores the chosen campaign’s Refuge and follows its active-descent abandonment rule; it is not interchangeable with Continue. In active-run cases below, “reload” means restart then Continue, or the explicitly labelled fixture restore.

Every checkbox starts **Not run**. Tick it only when its complete expected result was observed. Record **Fail**, **Blocked** or **Deferred** beside any unticked case; attach the case ID to the issue/evidence. An automated fixture pass does not tick a normal-play or physical-controller case.

- **P — Player:** perform through the actual game, using naturally reached campaign checkpoints.
- **F — Fixture/engineering:** requires the supplied isolated test scripts, controlled resources, forced outcomes or a specific save condition. Record it separately from player evidence.
- **D — Deferred content:** verify the present unavailable state; a playable service cannot pass until approved content is authored.
- **P0:** release-critical ownership, progress, crashes, saves or purchases. **P1:** remaining behavior/input/layout. **P2:** visual polish and balance observations. All inventory/purchase/save/return/defeat checks are P0 unless explicitly described as presentation only.

Record each run:

| Field | Fill in |
| --- | --- |
| Tester / date | |
| Commit / branch / launch method | |
| OS / Godot version / renderer / GPU | |
| Resolution / window mode / UI scale | |
| Mouse-keyboard / physical controller model | |
| Campaign slot / seed / layer / node | |
| Party order / relevant gear condition / inventory / Bloom / Materials before | |
| Case IDs / Pass-Fail-Blocked-Deferred / evidence / issue link | |

For a failure, record the smallest reproduction, expected and actual result, before/after quantities, and whether it repeats after a restart. A screenshot is useful for layout; attach the error log and disposable save for state or persistence failures. Stop a branch of testing after a destructive-state failure so later failures are not mistaken for independent defects.

## Current scope and truthful unavailable states

| Area | Current expected behavior |
| --- | --- |
| Production Alchemy/Crafting recipes | Deliberately empty by user decision, both Refuge and field. Test-only recipes prove transactions; they are not playable content. |
| Refuge bed | Select heroine and inspect Resolve/Corruption; paid Restore/Cleanse actions remain unavailable until costs/effects/eligibility are authored. |
| Level Up | Supported data can be inspected; unauthored paid upgrades remain unavailable and cannot charge. |
| Records | Only discovered/available content appears. Missing Bestiary/history/Gallery content stays unavailable. Optional replay media uses a fixture for engineering QA. |
| Save/Load policy alignment | Main Menu Continue/Load is the target workflow. Current Refuge System also exposes Save/Load via existing writers; Stage 01 documented that implementation, but repository target wording excludes Refuge Save/Load controls. Record this as an open UI-policy alignment item, not as an absent or already-resolved feature. |
| Loadout compatibility | Current UI has Main Hand, Off Hand, Armor and one Memento. Existing shields use Off Hand; no player-available Off Hand candidate is currently authored. The audit explicitly retained these serialized slots. Do not mark a separate fifth Shield assignment as implemented; reconciling that older repository wording requires a separate design/migration decision. |
| Equipment on defeat | Preserve current registered-equipment and equipped-Memento protection, including registered unequipped equipment. Do not expect the deferred equipped-only loss policy. |
| Later content | Layers 3–10, cross-layer travel and Companion interactions are not activated. Floor controls must not pretend to travel between layers. |
| Balance | Treasury rewards, trap thresholds/effects, station grants and Intel prices are provisional. Functional correctness and balance approval are separate results. |

## Test campaign checkpoints

Create checkpoints by normal play where possible. Use a separate test campaign or an isolated fixture when a prerequisite cannot be reached; label that case F. Test scripts auto-run and exit: they do not provide a general interactive save editor.

| Label | Needed state | Used for |
| --- | --- | --- |
| A | Fresh story before Refuge; injured and optionally defeated active heroines; ordinary Rest unused | 10, 13–15, 24 |
| B | Reverse Layer 2 / Refuge-less progression and a first-Refuge origin route | 14–17, 21, 24 |
| C | Established Refuge with recruited roster, test funds, prepared bags, banked Materials and damaged authored armor | 01–09, 21–24 |
| D | Run with ordinary item/container remainder, scoped key and nonempty material pouch | 11–15, 18, 24 |
| E | Normal battle, supported Elite pair/trio, and a heroine with an Action; separate eligible Grapple | 10–12, 17, 22, 24 |
| F | Trap room before detection, after detection, after disarm and after trigger/alarm | 19, save matrix |
| G | Rest room with unused offer; separate used state; six-offer fixture | 20 |
| H | Alchemy/Workshop first entry and revisit; fixture-only known/unknown recipes and output-capacity cases | 06, 21 |
| I | Refuge with purchases pending; defeated Layer 1 and Layer 2 bosses; recorded map knowledge | 22–24 |
| J | Defeat/voluntary Return with known inventory, key, material and equipment totals | 14, 17, 21–24 |

The combined verifier uses generated Layer 2 seed **7** with fixture-controlled access to representative rooms. Treasury/trap UI fixtures use seed **333**. These seeds alone do not reproduce their primed story state, funds, party, accessibility or forced outcomes in normal play.

## First pass — critical smoke route

- [ ] **SM-01 P0/P:** Launch the published checkout in Godot 4.7 Compatibility; New Game reaches the actual opening without missing Resources, a blank host or a script error.
- [ ] **SM-02 P0/P:** Play opening/recruitment and a normal battle; finish its real outcome and reach the map with one reward and correct party state.
- [ ] **SM-03 P0/P:** Before Refuge, use ordinary Rest once, exit to a supported save point, restart and Continue; the use and recovery persist.
- [ ] **SM-04 P0/P:** Follow the supported Layer 1/Layer 2/Refuge-origin flow; Refuge establishes once and permanently defeated bosses remain dead.
- [ ] **SM-05 P0/P:** At Refuge, transfer an item, equip/repair gear and Apply an ordered party. Main Menu Load restores those exact choices and quantities.
- [ ] **SM-06 P0/P:** Buy affordable one-run Intel, close preparation and Load. Ownership remains paid; Explore consumes it once with the applied party.
- [ ] **SM-07 P0/P:** Partially collect a Treasury container, leave and revisit/Continue. Only the remainder is available.
- [ ] **SM-08 P0/P:** Complete a Trap and a Rest-room interaction. Confirm the selected-recipient versus whole-party rules, then save/reload their distinct state.
- [ ] **SM-09 P0/P:** Open ordinary combat Backpack; complete one legal change and observe one Action spent. During Grapple, Backpack remains blocked.
- [ ] **SM-10 P0/P:** Win a real Elite, resolve loot/summary, return to map and revisit; no repeat encounter or reward.
- [ ] **SM-11 P0/P:** Voluntarily Return, compare ownership totals, begin another expedition and suffer a real defeat. Verify the different carry/loss rules and no ended-run Continue.
- [ ] **SM-12 P0/P:** Use Memory and an eligible Passage; preserve layout knowledge, refresh content, start at the correct defeated boss, and grant no skipped-room rewards.

## Stage-by-stage checks

### 01 — Refuge room framework

- [ ] **01-01 P/P1:** Enter Refuge. Original background/props are aligned; only Bloom is permanent HUD information, without a permanent station-name overlay.
- [ ] **01-02 P/P1:** Reach all eight stations using mouse, keyboard and a physical controller in separate passes. Highlight/tooltip identifies the correct hotspot and clears on exit.
- [ ] **01-03 P/P1:** Open stations consecutively; one active station panel owns focus, with no duplicate panel or blocked invisible overlay.
- [ ] **01-04 P/P1:** Escape from a nested chooser/dialog, then station, then room. Each press closes one level and restores appropriate focus; it does not also open the system menu or activate the background.
- [ ] **01-05 P/P1:** Open Settings/Main Menu/Quit and cancel each; campaign stays intact. On an expendable test slot, verify the currently exposed Refuge System Save/Load uses the existing campaign boundary and explained active-run abandonment behavior. Record the target-policy mismatch above; passing the existing action does not certify Main Menu-only UI compliance.
- [ ] **01-06 P/P1:** Resize through the four display sizes below. Check Records versus the weapon rack and all prop hit areas; artwork and interaction remain aligned.

### 02 — Shared inventory views

- [ ] **02-01 P/P1:** Open the chest: Stash appears first. Switch to Backpacks and every recruited heroine; selector names, portraits and contents match their owner.
- [ ] **02-02 P/P0:** Changing the viewed Backpack does not change selected expedition party or order.
- [ ] **02-03 P/P1:** Count fifteen personal slots in a 3×5 grid and exactly six shared Item Bar slots. The bar appears once in its intended context and disappears when the service closes.
- [ ] **02-04 P/P0:** Keys appear only in the shared Key-ring, never occupying bag/bar slots; all heroines see the same key ownership.
- [ ] **02-05 P/P0:** Materials view shows banked quantities at Refuge. Close/reopen and Load; it agrees with actual ownership, not a stale preview.
- [ ] **02-06 P/P1:** Empty slots, full stacks, equipment names/conditions and canonical Memento artwork remain distinguishable at every supported size.

### 03 — Transfers and stacks

- [ ] **03-01 P/P0:** Move a whole stack between Backpack and Item Bar into an empty slot; source empties and destination gains exactly that quantity.
- [ ] **03-02 P/P0:** Swap different items between occupied slots; the displaced stack returns to the exact source slot without quantity or ownership changes.
- [ ] **03-03 P/P0:** Merge into a partially full matching stack; accepted quantity respects the cap and excess stays at source. A full matching stack is a free no-op.
- [ ] **03-04 P/P0:** Split into an empty/matching destination; cancel and try invalid quantities. Partial drops onto a different occupied item reject without mutation.
- [ ] **03-05 P/P0:** Quick-move Stash → named heroine and Backpack → Stash. Merge matching stacks first, then use free capacity; never evict an unrelated item.
- [ ] **03-06 P/P0:** With 15/15 occupied, accept a legal matching merge but reject excess. Use another heroine's capacity; neither bag changes beyond the accepted amount.
- [ ] **03-07 P+F/P0:** Reload committed moves; verify total quantities, instance IDs and condition. Stale requests, duplicate confirmation and injected failed writes change nothing.

### 04 — Refuge Loadouts

- [ ] **04-01 P/P1:** View each heroine's four current rows; source labels and available candidates match the catalog. Empty Off Hand offers Nothing without fabricated shield items.
- [ ] **04-02 P/P0:** Equip compatible gear from Stash; the old item goes to Stash and the new instance exists in only one location.
- [ ] **04-03 P+F/P0:** Equip from another heroine's full Backpack; return the old item to the exact vacated source slot without dropping or duplicating either instance.
- [ ] **04-04 P/P0:** Select Nothing: removed gear/Memento safely returns to Stash. Nothing on an empty slot is a no-op; browsing, Back and Escape do not equip.
- [ ] **04-05 P/P0:** Change Memento ownership; retain the existing one-equipped-owner-per-ID rule and no fabricated Memento condition.
- [ ] **04-06 P+F/P0:** Reload changes; identity/condition survives. Incompatible and unsupported multi-slot exchanges reject without partially displacing gear.

### 05 — Repair and Salvage

- [ ] **05-01 P/P1:** Open both tabs. Repair targets show correct source, current/max condition, next condition and Materials cost, including equipped armor.
- [ ] **05-02 P/P0:** Use authored cloth-armor repair: one Servant Cloth buys one condition point up to the authored maximum. Maxed/insufficient-material operations do not charge.
- [ ] **05-03 F/P0:** Repair a broken item; positive effects remain suppressed while broken, authored negative effects remain, and the repaired condition survives Load.
- [ ] **05-04 P+F/P0:** Equipped items cannot be salvaged. With an eligible unused fixture candidate, Cancel preserves it; Confirm removes precisely that instance/reference and banks the displayed salvage yield once.
- [ ] **05-05 F/P0:** Stale confirmation or failed save rolls back item location, condition and Material totals. Test source cases: equipped repair, Stash and Backpack.
- [ ] **05-06 D/P1:** If no player-available salvage candidate exists in production, show the empty/unavailable state. Do not invent a candidate merely to pass manual QA.

### 06 — Refuge Alchemy/Crafting

- [ ] **06-01 P+D/P1:** Apparatus opens Alchemy and toolbox opens Crafting, with their distinct ingredient-convergence and blueprint/checklist layouts.
- [ ] **06-02 P+D/P0:** Shipped catalogs remain empty; no enabled Brew/Craft action, fake result or charge appears. Opening/closing is free.
- [ ] **06-03 F/P0:** With a test-only recipe, preview agrees with Materials/output definitions. Produce once: banked inputs decrease exactly once and output merges into Stash to caps.
- [ ] **06-04 F/P0:** Insufficient ingredients, stale preview, cancellation and failed durable write leave inputs/output/ownership unchanged.
- [ ] **06-05 F/P0:** Repeated valid production and reload conserve quantities; no field Backpack or current-run Material account is used by the Refuge provider.

### 07 — Refuge bed

- [ ] **07-01 P/P1:** Select each heroine and inspect actual Resolve/Corruption; selection does not change expedition party or another heroine's values.
- [ ] **07-02 P+D/P0:** Restore Resolve/Cleanse Corruption remain truthfully unavailable; there is no authored price, hidden charge or fake success.
- [ ] **07-03 P/P0:** Opening, changing heroine and closing consumes nothing and applies no HP/MP recovery or ordinary-Rest use.
- [ ] **07-04 D/P0:** Keep paid recovery outcomes explicitly Deferred until recipient scope, amounts, cost and eligibility are approved; do not record a functional-service pass for a disabled button.

### 08 — Expedition, ordered Party and Level Up

- [ ] **08-01 P/P1:** Floor map reports accessed floors/deepest reach; merely reaching a floor does not imply clearing it or Passage eligibility.
- [ ] **08-02 P/P0:** Select/remove roster sprites in a new order. The draft displays 1/2/3; zero selected cannot Explore; no fourth heroine is added.
- [ ] **08-03 P/P0:** Return to hub and reopen Party: draft survives. Reset Draft restores the applied order. Explore requires the draft to be applied.
- [ ] **08-04 P/P0:** Apply one-, two- and three-heroine parties in separate runs. Explore transfers only active bags/gear; inactive preparation/equipment remains safe through Return and defeat.
- [ ] **08-05 P/P0:** Load after Apply: exact order/selection survives. Viewing bags or Level Up never changes the roster.
- [ ] **08-06 P+D/P1:** Level Up selector/Stats/Skills/Heroine Upgrades reflect supported data; unauthored upgrades stay unavailable and cannot charge. Test actual Intel behavior under 22–23.

### 09 — Records and Gallery

- [ ] **09-01 P/P1:** Browse all four categories. Only discovered/available entries appear; unavailable Bestiary/history/media content is not filled with invented data.
- [ ] **09-02 P/P1:** Read available lore, change entries and scroll long text; selection, thumbnail and reading pane stay in sync.
- [ ] **09-03 F/P1:** Open fixture image-only, replay-only and combined-media entries; show only supported actions. Back/Escape returns one level and restores selection/focus.
- [ ] **09-04 F/P0:** Finish and interrupt replay repeatedly. Campaign flags, recruitment, discoveries, inventory, stats, Bloom, rewards and disk save remain identical.
- [ ] **09-05 P+F/P1:** Close Records and reopen; no orphan replay/dialogue continues behind the room and no background click fires.

### 10 — Run/combat HUD

- [ ] **10-01 P/P1:** Inspect exploration, normal combat and Struggle with one/two/three heroines: party cards, six item slots, separate Backpack, commands and collapsible log remain readable and distinct.
- [ ] **10-02 P/P1:** Normal combat exposes Attack/Move/Ability/End Phase; Struggle exposes Struggle/Wait/eligible Submit/End Phase with correct disabled states.
- [ ] **10-03 P/P1:** Exploration uses Party/Ability/Rest before Refuge and Party/Ability/Return after. No combat Move/Continue or unsupported available action appears.
- [ ] **10-04 P/P0:** Current HP/MP/Resolve/Corruption/statuses/Actions and stack quantities track actual state after actions, healing, damage and defeat.
- [ ] **10-05 P/P1:** Open log/Ability, target/cancel, trigger existing reactions and change selection. Overlays block clicks into battlefield/hotspots; camera and pose changes remain correct.
- [ ] **10-06 P/P1:** At all four resolutions, inspect popups, portraits, command labels, targeting and bottom-dock clearance.

### 11 — Run Backpack and combat permissions

- [ ] **11-01 P/P0:** Exploration shows only current-party Backpacks, shared bar and Key-ring; there is no remote Stash or banked-Material access.
- [ ] **11-02 P/P0:** In combat, Backpack opens on the acting heroine. Opening, viewing, changing the viewed heroine and canceling spend no Actions.
- [ ] **11-03 P/P0:** Each allowed actor equipment replacement or shared-bar change costs exactly one Action after success; two successful changes cost two.
- [ ] **11-04 P/P0:** Full/no-op/invalid/stale changes and insufficient Actions spend nothing and do not change inventory or gear.
- [ ] **11-05 P/P0:** Browsing another heroine cannot mutate her bag, make her actor or charge her Actions. Unapproved Memento changes, handoff, standalone unequip, Use/Discard stay unavailable in combat.
- [ ] **11-06 P/P0:** While grappled, mouse, B/key binding and physical-controller shortcut cannot open Backpack. It becomes available again only when the actual context permits it.

### 12 — Loot, capacity and source lifetime

- [ ] **12-01 P/P1:** Ordinary item, multi-item container and fight reward open Loot beside Backpack with one shared Item Bar; no direct-from-Loot equip or Stash route exists.
- [ ] **12-02 P/P0:** Test free slot, matching merge in a 15/15 bag, full matching stacks, partial capacity and alternate heroine. Source loses only accepted quantity.
- [ ] **12-03 P/P0:** Failed pickup preserves item/quantity/source. A successfully exhausted visible pickup removes its runtime sprite; partial contents remain.
- [ ] **12-04 P/P0:** Close ordinary chest/sachet/cache loot, leave, revisit and Continue from a supported safe point; exact remainders remain and nothing rerolls.
- [ ] **12-05 P/P0:** Close fight loot: abandonment requires confirmation. Cancel retains the offer; Confirm loses only remaining fight surplus, never unrelated room contents or owned items.
- [ ] **12-06 P/P0:** In allowed exploration context, Use/Discard changes only the chosen carried item and follows confirmation/cancel rules; no unauthorized combat shortcut is exposed.
- [ ] **12-07 F/P0:** Duplicate/stale claim and failed transaction tests conserve source and destination totals; no successful-looking partial failure.

### 13 — Current-run Party

- [ ] **13-01 P/P1:** Open run Party: current active heroines, their real stats/gear and current order are shown; it is not the full Refuge recruitment selector.
- [ ] **13-02 P/P0:** Reorder active heroines within allowed controls; dock order updates immediately without changing ownership, actor identity or recruiting/removing heroines.
- [ ] **13-03 P/P0:** Close/reopen, enter/leave a node, then Continue at a supported safe point: order persists without swapping stats/bags between identities.
- [ ] **13-04 F/P0:** Older saves without explicit order still restore a valid deterministic order; malformed/duplicate/unknown IDs reject transactionally.

### 14 — Ordinary Rest and Return

- [ ] **14-01 P/P0:** Before Refuge, confirm ordinary Rest: every active heroine gains `ceil(max HP/2)` and `ceil(max MP/2)`, capped at maxima, plus 10 Corruption within bounds. Defeated active heroines revive.
- [ ] **14-02 P/P0:** Cancel the preview, open Backpack behind it, and attempt repeated input. Cancel consumes nothing; blocked background input cannot sneak through.
- [ ] **14-03 P/P0:** Two successful uses are allowed per run; third is unavailable. At supported exit/Continue, used count and stats persist together.
- [ ] **14-04 F/P0:** Mid-node interruption restores the supported pre-node state, including the old use count; it is not an ordinary mid-node save. Failed durable writes apply no partial result.
- [ ] **14-05 P/P0:** After Refuge establishment the tile becomes Return. Cancel stays in run; Confirm banks surviving Materials once, preserves surviving carried ownership, restores HP/MP and persists Resolve/Corruption.
- [ ] **14-06 P/P0:** Return, automatic Refuge recovery, paid Refuge bed and single-use room Rest remain separate; none silently spends another context's counter.

### 15 — Generated graph, discovery and backtracking

- [ ] **15-01 F/P0:** Representative seeds in both layers meet 14–18 playable rooms, approximately 8–10 main-route rooms, 2–4 branches of 1–3 rooms and at least two real dead ends. Current generator normally uses 14–16 rooms, nine on the main route and three branches. Small story/holding graphs are separate, intentional exceptions.
- [ ] **15-02 F/P0:** Per layer: Elite/Trap/Treasury each 1–2, Rest/Alchemy/Workshop each 0–1 within the same budget; connectivity, required story ordering, key reachability and boss reachability hold.
- [ ] **15-03 P/P0:** Leave an unsolved room by an open exit: eligible adjacency becomes known. Closing a panel is not an exit; a locked exit reveals no ordinary route past the door.
- [ ] **15-04 P/P1:** Visible unknown node positions remain question marks. Known type, route, accessibility, visit, encounter clear, Solved and Rest-used are distinct states.
- [ ] **15-05 P/P0:** Backtrack through known accessible visited passages; current locks still apply, encounters/rewards do not repeat, and room remainders remain.
- [ ] **15-06 P/P0:** Save/load graph knowledge and partial-room state. Hidden unresolved content prevents Solved without revealing secret counts or locations.
- [ ] **15-07 P+F/P0:** Preserve mandatory Layer 1 story and Jailer → reverse Layer 2 → Farthest Cell/Refuge-origin routes. Representative Refuge-less progression/defeat does not reset permanent bosses or establish Refuge twice.

### 16 — Flat map presentation/navigation

- [ ] **16-01 P/P1:** Actual generated nodes/routes appear over the flat parchment; no baked demo topology or panorama substitutes for runtime layout.
- [ ] **16-02 P/P1:** Current violet ring, type medallion, Visited/Solved/used-Rest badges and selection/focus coexist without hiding important state.
- [ ] **16-03 P/P0:** Unknown hover/focus/details disclose no room name/type/hidden reward; undiscovered hidden edges leave no faint line or placeholder.
- [ ] **16-04 P/P1:** Mouse selection, wheel zoom, middle-drag pan, fit/current-room controls, keyboard and physical-controller selection remain usable at all supported sizes; routes render behind nodes.
- [ ] **16-05 P/P0:** Known lock marker describes the relevant edge and never grants travel. Selection alone does not visit or resolve a node.
- [ ] **16-06 P+D/P1:** Floor Up/Down remain hidden/disabled for unsupported cross-layer travel; Layers 3–10 are not activated by their registry or artwork.

### 17 — Normal and Elite combat-only nodes

- [ ] **17-01 P/P0:** Enter generated Normal and Elite nodes in both layers: direct combat host, no exploratory pickup phase or retreat button. Authored story/recruitment preludes/aftermaths still run where required.
- [ ] **17-02 P+F/P0:** Exercise Layer 1 Hollow Servant + Knife Footman + Prayer-Rag Novice trio, supported pairs, and parties of one/two/three heroines. No forced party expansion or invented composition.
- [ ] **17-03 P/P0:** Begin/order, targeting, movement, abilities, reactions, Grapple and legal equipment changes work with all supported formations; obscured/transparent sprite areas do not steal targets.
- [ ] **17-04 P/P0:** Win naturally: resolve findings/loot before map return; node encounter clears/Solves and one reward is granted. Revisit yields no new enemy or reward.
- [ ] **17-05 P/P0:** Lose naturally: show defeat summary, apply correct losses/Refuge-origin behavior and end the expedition. No free retry or Continue into the ended encounter.
- [ ] **17-06 F/P0:** Forced outcome tests verify lifecycle plumbing only. Keep natural combat/balance acceptance separate from their results.

### 18 — Treasuries and hidden caches

- [ ] **18-01 P/P1:** Visit Layer 1 Servants' Storehouse and Layer 2 Confiscated Belongings Store; runtime pickups/container hotspots align with backgrounds at all sizes.
- [ ] **18-02 P/P0:** Fully and partially collect visible items and multi-item containers; remove only exhausted contents. Full capacity leaves the source intact.
- [ ] **18-03 P/P0:** Close chest/sachet loot, leave, revisit and restart/Continue at a safe point. Compare exact item IDs, quantities and earlier claims; no reroll or duplicate grant.
- [ ] **18-04 P/P0:** Inspect the cache location to reveal it; no initial tooltip/count/marker discloses the hidden reward. Reveal/claim state persists.
- [ ] **18-05 P/P0:** Unclaimed hidden content keeps the room unsolved; resolving visible contents alone does not reveal a secret count. Exits/locks work independently.
- [ ] **18-06 P/P2:** Record reward usefulness as provisional balance feedback, separately from deterministic persistence/capacity correctness.

### 19 — Traps, detection and native effects

- [ ] **19-01 P+F/P0:** Verify 1–2 trapped eligible hotspots with at least one safe item. Saved item/effect assignments stay fixed through reopen/revisit/Load; another run may differ.
- [ ] **19-02 F/P0:** Expert Awareness auto-detects under configured rules; otherwise Intellect/Awareness needs two successes. A failed observer leaks no trap. Do not change production heroine sheets to create this fixture.
- [ ] **19-03 P/P1:** Successful detection uses the existing dialogue and names actual detector, place and item; closing/revisiting does not repeat or reroll the announcement.
- [ ] **19-04 P/P0:** Identified item offers Disarm/Collect/Ignore. Choose a different active heroine; Ignore/Cancel/inspection changes nothing and blocks background shortcuts.
- [ ] **19-05 F/P0:** Plain Agility with two successes disarms and leaves a safe collectible; failure triggers the saved effect once, leaves uncollected loot, and grants no repeat free attempt.
- [ ] **19-06 P+F/P0:** Collect first validates capacity. Rejected/full pickup causes no damage; committed pickup triggers once on the chosen collector, not the whole party.
- [ ] **19-07 F/P0:** Check each provisional effect: −1 HP/−5 Resolve; +20 Corruption; or party alarm battle with two Hollow Servants. Apply bounds and no invented ongoing Poison status.
- [ ] **19-08 P+F/P0:** Alarm victory resumes remaining authored room contents; it alone does not Solve the room. Defeat follows normal loss/end-run behavior. Save failure/retry grants no double alarm or reward.
- [ ] **19-09 P/P1:** Green/violet cloud originates above the captured item anchor even after sprite removal; scale stays aligned, effects expire and clear on room/combat transition. Detection alone emits no damage cloud.
- [ ] **19-10 P+F/P0:** Independently reload detected, disarmed, triggered and collected states; no repeated damage or detection announcement.

### 20 — Single-offer Rest rooms

- [ ] **20-01 P/P0:** A spawned room offers one fixed effect, not a six-option menu. The offer stays the same across Cancel/leave/revisit/Continue until a fresh run.
- [ ] **20-02 F/P0:** Exercise all six effects using the table below, including odd maxima, near-cap resources and defeated active heroines; preview equals the actual capped result.
- [ ] **20-03 P/P0:** Preview lists every active heroine and all consequences, including +50 Corruption for full recovery. No Bloom/Material cost is applied.
- [ ] **20-04 P/P0:** Cancel/leave preserves unused recovery. Confirm spends it once; repeated click/revisit/reload cannot apply again. Solved does not automatically consume an unused offer.
- [ ] **20-05 F/P0:** Failed save rolls back resources/use flag; stale confirmation rejects. HP-restoring offers revive; MP-only/Resolve/Corruption-only effects do not revive.
- [ ] **20-06 P/P0:** Ordinary two-use Rest and Refuge bed remain unaffected; a later layer/run may legitimately have the same offer.

| Offer | Expected per active heroine |
| --- | --- |
| 1 | Add `ceil(max HP/2)`, capped at max HP |
| 2 | Add `ceil(max MP/2)`, capped at max MP |
| 3 | Both of the above |
| 4 | +20 Resolve, capped |
| 5 | −20 Corruption, floored at minimum |
| 6 | Full HP/MP/Resolve; +50 Corruption, capped |

### 21 — Field Alchemy/Workshop and recipes

- [ ] **21-01 P/P0:** First visit to each Layer 1 station grants 2 Red Wax +2 Servant Cloth; each Layer 2 station grants 2 Chain Links +2 Prison Iron to the current run. Revisit/Continue never grants again.
- [ ] **21-02 P+D/P0:** Empty shipped production recipes remain unavailable. The room/grant/exit works without inventing a craftable recipe or charging anything.
- [ ] **21-03 F/P0:** Test-only known station-appropriate recipes appear even when not discovered at that station; unknown recipes stay unavailable until discovered.
- [ ] **21-04 F/P0:** Repeated production consumes only run Materials and outputs to the selected active Backpack; no access to banked Materials or Stash. Test merges, partial/free capacity, and capacity rejection without loss.
- [ ] **21-05 F/P0:** Discovered recipes survive station exit, Return, defeat and first-Refuge origin; a fresh run has knowledge but not its old consumed/granted Material stock.
- [ ] **21-06 F/P0:** Solved station remains usable while ingredients/capacity permit. No invented per-station craft limit; failed grant/craft save and retries duplicate nothing.
- [ ] **21-07 P+F/P0:** Spend some run Materials, then Return/defeat. Bank only the remainder once; later Refuge crafting spends the bank and cannot withdraw it into a run.

### 22 — Intel and permanent Submit

- [ ] **22-01 P/P0:** Inspect each available option/cost without purchase; wallet remains unchanged. Buy affordable temporary Intel once, and reject insufficient funds without mutation.
- [ ] **22-02 P/P0:** Cancel preparation, reopen and Main Menu Load: paid pending ownership and deducted Bloom persist, with no refund or extra charge.
- [ ] **22-03 P+F/P0:** Explore consumes temporary entitlement once; failed departure/purchase save consumes nothing. Continue after departure restores the active benefit, not a new pending purchase. Unspent Bloom is discarded by the existing departure rule.
- [ ] **22-04 P/P0:** Temporary effect ends with that expedition; permanent counterpart survives Return/defeat and costs 100× its ordinary one-run price. Duplicate/permanently owned purchases cannot recharge.
- [ ] **22-05 P+F/P0:** Test each map effect alone, then combinations. Known routes/types neither open locks nor identify/disarm a particular trapped item; a revealed Treasury path is a real graph route.
- [ ] **22-06 P/P0:** Before Submit ownership, no paid-locked action is available. After purchase it appears only in eligible Hero-Phase Struggle with remaining Actions.
- [ ] **22-07 P+F/P0:** Submit spends all remaining Actions, advances the main Grapple track once and heals 1; approved Climax bundle deals 25% enemy max-HP damage and heals 2. Healing overflow goes to MP, does not revive a defeated heroine, and excess is discarded.
- [ ] **22-08 F/P0:** Verify enemy-driven Climax uses the upgrade, existing succession/cooldown/phase behavior remains, and Backpack stays disabled during Grapple.

| Option | Expected knowledge | Provisional price |
| --- | --- | --- |
| Scouting | Adjacent room types through eligible exits | 10 per run / 1,000 permanent |
| Battle Sense | All Normal and Elite Combat types | 10 / 1,000 |
| Smell of a Coin | One Treasury and a real route to it; locks still apply | 10 / 1,000 |
| Pathfinding | Layer connections, without opening blocked passages | 10 / 1,000 |
| Sanctuary Sense | Rest types | 10 / 1,000 |
| Danger Sense | Trap-room types, not item traps | 10 / 1,000 |
| Artisan's Eye | Alchemy and Workshop types | 10 / 1,000 |
| Submit | Permanent eligible Struggle action and approved level-1 bundle | 100 permanent only |

### 23 — Castle Memory and Conqueror's Passage

- [ ] **23-01 P/P0:** Purchase Memory with no recorded layout: UI truthfully says a new layout will generate. With saved memory, positions/types/connections and previously known routes/types match the previous layout.
- [ ] **23-02 P+F/P0:** Unknown rooms remain unknown absent other Intel. New run gets fresh content seeds, claims, encounters, station grants, Rest uses/offers and trap assignments; fresh randomness may legitimately produce some identical outcomes.
- [ ] **23-03 P/P0:** Permanent boss deaths remain; previously opened authored locks are re-evaluated for the fresh run, not inherited as unlocked.
- [ ] **23-04 P/P0:** Passage is offered only for an eligible permanently defeated boss with required Refuge/story state. Floor access alone or an unsupported layer is insufficient.
- [ ] **23-05 P/P0:** Verify Memory 10/run or 1,000 permanent; Passage Layer 1 100/run or 10,000 permanent, Layer 2 200/run or 20,000 permanent. Price/layer shown before purchase matches charge.
- [ ] **23-06 P/P0:** Buy both layers where eligible; select ordinary departure or another layer and close/Load. Unused paid ownership remains; only the selected temporary Passage is consumed at successful departure.
- [ ] **23-07 P/P0:** Shortcut starts at the correct dead boss with normal prepared party/inventory. Skipped rooms gain no visits/Solved/XP/loot/Materials/recipes and the dead boss pays no reward.
- [ ] **23-08 P/P0:** Backtrack through valid adjacent within-layer routes. No cross-layer travel is introduced; ordinary Layer 2 departure remains supported.
- [ ] **23-09 P+F/P0:** Continue after either layer's Passage preserves consumed ownership, generated key placement, graph and knowledge. Failed save, wrong price/layer, duplicates and stale selections never charge/consume partially.
- [ ] **23-10 P/P0:** Return/defeat updates latest remembered layout, retains unused Passage and permanent ownership; later Memory uses the latest valid full layer, not a transient story graph.

### 24 — Combined lifecycle acceptance

- [ ] **24-01 P/P0:** Complete one normal-play campaign through preparation → ordered party/Intel → Explore → room/loot/trap/station/Rest → Normal/Elite combat/Struggle/Backpack → summary/map → Return. Record unavailable recipe/paid-service cases as Deferred rather than pretending to craft/rest/upgrade.
- [ ] **24-02 P/P0:** Repeat with a different party size/order, leave one heroine inactive, then compare her preserved Refuge gear/preparation after Return and after defeat.
- [ ] **24-03 P/P0:** In the same campaign, Cancel paid preparation, Load, depart, claim a partial container, use room Rest, Continue, Return, use Memory, suffer defeat, and use a retained Passage. No cross-system duplication, lost knowledge or ownership swap.
- [ ] **24-04 P+F/P0:** Complete the save/loss matrix below, including unused/used Rest and all trap states. Supported safe points, rather than mid-combat/mid-dialogue snapshots, remain authoritative.
- [ ] **24-05 P/P1:** Complete the physical-controller and resolution matrix. Synthetic joypad events and screenshots are supporting evidence only.
- [ ] **24-06 F/P0:** Run the official suite and combined verifier in isolation; attach exact commands, exit status and logs. Do not mark manual battle balance or full campaign acceptance passed from forced outcomes.
- [ ] **24-07 P+F/P0:** Review stage results, provisional balance, deferred content and all open defects; obtain explicit player sign-off for release. No blank/Blocked/Deferred case becomes Pass automatically.

## Save, rollback and loss matrix

Use the before/after record for every row. For interrupted nodes, identify the actual last safe point: ordinary unresolved work can roll back to pre-node with the same content/encounter seed. Trap preparation, field production and room recovery have explicit durable transaction checkpoints exercised by their focused tests; do not generalize these into unrestricted mid-room saving.

| Done | ID / mode | Operation | Expected comparison |
| --- | --- | --- | --- |
| [ ] | SV-01 P | Main Menu Continue/Load after Refuge transfer/equip/repair/Apply | Exact party order, gear IDs/condition, bag/bar/Stash quantities, shared keys and banked Materials |
| [ ] | SV-02 P | Close ordinary partial container, exit room, restart/Continue | Same item identities and remaining quantities; prior claims not collectible again |
| [ ] | SV-03 P+F | Interrupt ordinary unresolved room/dialogue/combat | Supported pre-node state/seed restored; no mid-combat progress/reward assumed |
| [ ] | SV-04 P+F | Continue prepared detected/disarmed/triggered/alarm trap checkpoints | Independent state restored; no reroll, repeat damage or duplicate alarm reward |
| [ ] | SV-05 P | Unused Rest room exited/Solved, then Load; repeat after use | Same offer; unused remains available, used stays spent |
| [ ] | SV-06 P | Ordinary Rest followed by a completed node and Continue | Uses/recovery/Corruption persist together; at most two uses |
| [ ] | SV-07 F | Failed transfer/repair/salvage/craft/Rest/purchase/departure write | Whole live transaction rolls back and old durable document remains readable |
| [ ] | SV-08 P | Cancel preparation, Main Menu Load, successful Explore and Continue | Paid pending Intel retained until departure, then active only; no second charge or refund |
| [ ] | SV-09 P | Voluntary Return with carried loot, keys and unspent run Materials | Surviving carried ownership retained; bank remainder once under declared key scope; no later bank withdrawal |
| [ ] | SV-10 P | Defeat with consumables, registered gear, Memento, run key and Materials | Bags/bar consumables and ordinary run keys lost; registered gear/condition, protected Memento and safe Stash preserved; remaining Materials bank once |
| [ ] | SV-11 F | Authored persistent-key fixture on defeat | Declared persistent scope survives; no conversion into bag/bar item or fabricated production persistent key |
| [ ] | SV-12 P | Return/defeat while some heroines inactive | Inactive personal preparation/loadouts unchanged; no copies accidentally deployed or lost |
| [ ] | SV-13 P+F | Discovered recipe followed by first Refuge/Return/defeat/new run | Permanent knowledge survives; old Material supply and used source state do not reappear |
| [ ] | SV-14 P | Memory/Passage departure then Continue/Return/defeat | Layout knowledge and boss death persist; contents fresh per run; used versus unused temporary rights stay distinct |
| [ ] | SV-15 F | Older supported save missing optional order/Intel/memory fields | Defaults restore valid state without destructive migration; malformed explicit data rejects transactionally |
| [ ] | SV-16 F | Corrupt primary/truncated save and available backup | Existing atomic-store recovery/backup behavior works; no partially loaded campaign or overwrite of good state |
| [ ] | SV-17 P | Complete an outcome/claim, then repeated Confirm/Return/load/revisit | Exactly one reward/charge/bank operation; ended run cannot be resumed |
| [ ] | SV-18 F | Replay Gallery to completion/interruption repeatedly | Campaign, discoveries, rewards and save document unchanged |

## Resolution, input and presentation matrix

Primary verified environment: Godot **4.7.2**, **Compatibility**, Linux/Intel Iris Xe. Record another OS/renderer as a separate target; do not infer Windows, Forward+ or exported-build acceptance from this environment.

| Done | Render size | Mouse/keyboard | Physical controller | Required scenes |
| --- | --- | --- | --- | --- |
| [ ] | 1920×1080 | Not run | Not run | Refuge, inventory/chooser, Intel, map, Treasury/Trap/Rest/station, combat/Struggle, summary |
| [ ] | 1600×900 | Not run | Not run | Same |
| [ ] | 1280×720 | Not run | Not run | Same |
| [ ] | 1024×768 | Not run | Not run | Same, including letterboxing and tall panels |

- [ ] **UX-01 P/P1:** Traverse every interactive control with keyboard and controller; focus is visible, stays inside modal scope, reaches scrolled actions and returns to the originating control.
- [ ] **UX-02 P/P1:** Open selectors/context menus/quantity dialogs/confirmations, then Back/Escape repeatedly. One level closes per input; no double activation or background command.
- [ ] **UX-03 P/P1:** Switch mouse ↔ keyboard ↔ controller while a panel is open; no stuck hover, lost focus, repeated held-button purchase or incorrect actor selection.
- [ ] **UX-04 P/P1:** Test controller confirm/cancel/navigation/context action/map travel and actual battle targeting. Record device bindings; synthetic joypad tests do not replace this pass.
- [ ] **UX-05 P/P1:** Resize with a station, loot, Rest or trap modal open. Text, before/after values and Confirm/Cancel remain visible; scroll to off-screen actions before activating them.
- [ ] **UX-06 P/P1:** Inspect long names, maximum stacks, full bags and multiple statuses. No overlap, clipped critical cost, duplicate bar or obscured primary action.
- [ ] **UX-07 P/P1:** Click UI overlapping a hotspot/battler; only UI handles it. Drag/zoom map without accidentally traveling or selecting a hidden route.
- [ ] **UX-08 P/P1:** Enter/exit/interrupt room or combat effects and Gallery replay; no lingering particles, input blockers, dialogue or audio/presentation nodes remain.
- [ ] **UX-09 P/P2:** Compare backgrounds/props/medallions/portraits and static PNG poses with intended assets; record visual polish separately from mechanics.
- [ ] **UX-10 P/P1:** Test Refuge interface scale 1.0 and 1.3 plus the default after restarting; controls/text remain usable, props/hotspots stay aligned, and changing Main Menu settings does not erase the Refuge scale.

## Engineering runbook and supporting automation

Run from the tested project root. The official runner isolates each Godot process automatically. A standalone native verifier must also use temporary XDG directories; its script is fixture automation, not a normal-play campaign. On Windows use a separate test user-data environment appropriate to that platform; the shell example below is Linux-specific.

```bash
python3 tools/validate_project.py --allow-generated-cache
GODOT_BIN=/path/to/godot4 python3 tools/run_regression_suite.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools -p 'test_*.py'
```

Expected count for this published branch: **84 Godot scripts**. The development workspace has **85** because it retains an unrelated local Content Workbench test. Never remove a failing script to reach the expected count. When validating a downloadable package that must contain no `.godot/` cache, omit `--allow-generated-cache`.

Example isolated desktop journey, with captures retained separately:

```bash
qa_root=$(mktemp -d /tmp/ab-manual-qa.XXXXXX)
XDG_DATA_HOME="$qa_root/data" XDG_CONFIG_HOME="$qa_root/config" \
XDG_CACHE_HOME="$qa_root/cache" /path/to/godot4 --path . \
  --script res://tools/verify_combined_acceptance.gd -- \
  --acceptance-captures="$qa_root/captures"
```

Retain the generated directory/logs until the run has been reviewed. Do not substitute a player save directory. Existing fixture tools use production controllers but may seed story/ownership, inject outcomes, install process-local recipes or use synthetic input. Record those boundaries.

| Stage coverage | Focused tests / native tools (paths relative to project) |
| --- | --- |
| 01–02 | `tests/test_refuge_management_ui.gd`, `tests/test_shared_inventory_views.gd`; `tools/preview_refuge_room.gd` |
| 03–05 | `tests/test_inventory_transfers.gd`, `tests/test_refuge_loadouts.gd`, `tests/test_refuge_workbench.gd`; matching `tools/verify_inventory_transfers.gd`, `verify_refuge_loadouts.gd`, `verify_refuge_workbench.gd` |
| 06–09 | `tests/test_refuge_production.gd`, `test_refuge_rest.gd`, `test_refuge_expedition.gd`, `test_refuge_records.gd`; matching `tools/verify_refuge_*.gd` |
| 10–14 | `tests/test_run_hud.gd`, run Backpack/Loot/Party/Recovery state and UI tests; `tools/verify_run_hud.gd`, `verify_run_backpack.gd`, `verify_run_loot.gd`, `verify_run_party.gd`, `verify_run_recovery.gd` |
| 15–17 | Node-map/discovery/navigation, generated-combat, layer-generator activation, story transition/lifecycle tests; `tools/verify_map_discovery.gd`, `verify_map_navigation.gd`, `verify_generated_combat.gd` |
| 18–21 | Treasury, room-trap/interface/alarm, Rest-room and field-production tests; `tools/verify_treasuries.gd`, `verify_trap_interface.gd`, `verify_trap_rooms.gd`, `verify_rest_rooms.gd`, `verify_field_production.gd` |
| 22–23 | `tests/test_intel_purchases.gd`, `test_submit_upgrade.gd`, `test_intel_ui.gd`, `test_castle_memory_passage.gd`, `test_castle_memory_ui.gd`; `tools/verify_intel.gd`, `verify_castle_memory.gd` |
| 24 / save boundaries | `tests/test_combined_acceptance.gd`, `test_production_save_slots.gd`, `test_active_run_safe_points.gd`, `test_campaign_lifecycle.gd`, `test_l1_l2_demo_flow.gd`, `test_jailer_refuge_origin.gd`; `tools/verify_combined_acceptance.gd` |

Native capture flags vary by tool; use its existing `--...-captures=` argument in the script. Existing Stage 24 evidence contains 154 combined checks, 40 recovery checks, 25 trap-interface checks and 31 reviewed images. These results remain distinct from this checklist's unticked player/device cases. Historical ObjectDB/resource shutdown and intentional corrupt-save diagnostics are documented; any new runtime error still needs investigation.

## Completion and sign-off

- [ ] **QA-END-01:** All P0 failures resolved and rerun, or explicitly accepted with a named owner/reason; no unexplained quantity, equipment, key, seed, recipe, purchase or save discrepancy.
- [ ] **QA-END-02:** Every stage 01–24 has recorded implementation, automated/fixture evidence and player verification separately; Blocked/Deferred cases list the missing prerequisite.
- [ ] **QA-END-03:** Full normal-play route, alternate party/inactive ownership, defeat, Return, Memory/Passage and controller/resolution matrices have actual evidence.
- [ ] **QA-END-04:** Provisional balance is reviewed separately; missing recipes, paid bed, upgrades, archive content, independent Shield-slot decision, Refuge Save/Load policy alignment and deferred later systems are not silently claimed complete.
- [ ] **QA-END-05:** Final tested commit, suite counts/exit codes, screenshots, disposable saves and defect links are recorded; user explicitly signs off or names remaining blockers.

| Sign-off | Name / date / commit / decision / remaining exceptions |
| --- | --- |
| Engineering regression and persistence | |
| Normal-play campaign | |
| Mouse/keyboard and physical controller | |
| Visual/resolution review | |
| Balance/content acceptance | |
| User acceptance | |
