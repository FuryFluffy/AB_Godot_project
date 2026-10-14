# Consolidated UI, map and rooms — Stage 00 audit

Date: 2026-10-09. Stage 00 is complete as an audit; user verification is pending. **Stage 01 has not started.** No gameplay, UI, scene, Resource, asset, save schema, migration or economy change was made.

This report is paired with `COMPLETE_UI_MAP_ROOMS_STAGE_LEDGER.md` and `COMPLETE_UI_MAP_ROOMS_STAGE_00_BASELINE_2026-10-09.md`. The ledger is the single review sequence for both portions of the supplied package.

## Authority, inputs and local state

The user explicitly delegated the task to `/home/fluffy56/Downloads/CODEX_AB_COMPLETE_UI_MAP_AND_ROOMS_STAGED_PROMPT.md`. Its current authorization is Stage 00 only, followed by a review pause. The archive's specifications and assets supply requirements and references; historical implementation claims, mockup numbers, browser checks and generated preview maps are not evidence of this checkout's runtime behavior. The later “Resume from where you left” continues this audit, not Stage 01.

Safely extracted 125 archive entries, checking containment and rejecting symlinks, into:

`/tmp/ab_complete_ui_handoff_2026-10-09/AB_Complete_UI_Map_and_Rooms_v1`

The 124 entries listed in the root SHA-256 manifest all match. The original ZIP remains in Downloads; the temporary extraction can be recreated from it. No archive content was copied over project files. The package's Refuge background matches the repository background exactly: SHA-256 `2ecc1b1705148364aa2789734bbd0922a4329a2d70300db3054412d9a53f82f1`.

Read the full root 00–05 documents; Refuge design index, specifications 01–14, verification checklist and open mappings; node-map/special-room specification; map manifest, presentation/particle notes and hotspot anchors; Refuge placement/hotspot JSON. Inspected the actual Refuge hotspot composition, approved combat dock and composed map reference. These images establish presentation intent only. Detailed per-stage art inspection and Godot alignment remain part of implementation acceptance.

Local branch: `codex/private-review-preparation`, HEAD `f3a573c` (`Record fresh-checkout verification and finalize review publishing workflow`). The relevant recent checkpoints include September review/workbench evidence, September Layer 1 novel/Jailer changes, static-PNG presentation, Refuge services/ownership, reward routing, active-run safe points, generator activation and the reverse Layer 2 route. The historical GitHub commit in the package was not checked out or used to reset anything.

Pre-existing local changes, preserved:

- Modified `project.godot`: enables Content Workbench.
- Modified `tools/run_regression_suite.py`: includes its test.
- Untracked `addons/`, `docs/CONTENT_AUTHORING_AUDIT.md`, `docs/CONTENT_AUTHORING_GUIDE.md`, `docs/CONTENT_WORKBENCH_VERIFICATION.md`, `tests/test_content_workbench.gd` and its UID.

These match the documented September 29 Content Workbench handoff. Stage 00 does not overlap them. A future renderer change would touch the already modified project configuration and must preserve that plugin setting; any change to the cumulative runner must preserve its added test.

## Baseline evidence and limits

| Check | Actual result |
| --- | --- |
| Engine | `/home/fluffy56/.local/bin/godot4`, `4.7.2.stable.official.ed1daf0bf` |
| Structural validation | Exit 1, 24 pre-existing diagnostic lines |
| Official cumulative runner | Exit 1 at structural prerequisite; no Godot scripts executed by that invocation |
| Direct isolated execution of the runner's current test list | **48/48 scripts passed**, all exit 0; every log contains its success summary |
| Python runner unit tests | **4/4 passed**, exit 0 |
| Headless application startup, five frames | Exit 0, existing ObjectDB/resource cleanup diagnostics |
| Graph/Elite/renderer audit probe, outside project | Exit 0; results below and in baseline evidence |
| Graphical application startup | Exit 1: X11 unavailable and Wayland connection unavailable |
| Package integrity | 124/124 manifest hashes match |
| Manual graphical gameplay / controller / particle QA | **Not performed**; no working native display in this execution session |

The structural families match existing checkpoint reports: one missing explicit legacy-blanket flag, twenty room-identity diagnostics, two registry-order diagnostics, and one aggregate background-registration diagnostic. The actual aggregate lists **22 background filenames**; the older Workbench report's “21” should not be repeated. No validator/content repair is folded into this audit.

Passing direct scripts is evidence for existing behavior, not acceptance of the new design. Existing cleanup warnings remain, including leaked ObjectDB/resources and a shaped-text RID warning in the cancel-input test. Corruption-recovery tests intentionally exercise invalid JSON and print parse errors. Detailed results and reproduction commands are in the baseline document.

### Renderer discrepancy

`project.godot` declares `config/features = ["4.7", "GL Compatibility"]` but does not set `rendering/renderer/rendering_method`. A Godot probe reports both the effective setting and its override as **`forward_plus`**. The feature label alone is not a renderer selection. Headless execution cannot certify rendered Compatibility behavior, and the graphical launch failed before display initialization. Preserve this discrepancy for a reviewed configuration correction/real-laptop check; do not assert that particles already work in GL Compatibility.

Viewport is authored at 1920×1080, window override 1280×720, stretch mode `canvas_items`. No resolution or renderer setting was changed.

## Existing / missing / conflicting matrix and stage ownership

Status refers to the requested target, not to whether the current game is functional. All future stages still require their own implementation, tests and user review.

| Stage | Existing foundation and actual owner | Target gap / planned boundary |
| --- | --- | --- |
| 01 Refuge room | `scenes/refuge/bloom_refuge_screen.tscn`, `scripts/refuge/bloom_refuge_screen.gd`; original room background; `scripts/app/application_root.gd`, menu/settings/save services | Current five-tab dashboard is permanent. Add five separate props/eight spatial hotspots, Bloom-only default, contextual shells, nested focus/Escape. Integrate system actions with existing safe points; no new mid-node saves. |
| 02 Shared inventory | `RefugeOwnershipState`, `RunInventoryState`, `RefugeSlotGrid`, six-slot combat inventory and existing item icons | Fifteen/three-column personal slots and six shared slots already exist. Bags currently accept ACTIVE items only; carried equipment/Mementos need a compatible slot representation. One reusable context-bound Backpack and Item Bar presentation is missing. |
| 03 Transfers | `RefugeManagementController._mutate`, ownership moves; `RunInventoryState._move_between_ordered_domains` | Current moves are by item ID/quantity, all-or-nothing capacity, with staged rollback. UI transfers one item. Add exact source/destination slots, partial acceptance, split, merge/full-target no-op, full swaps and rejection of partial different-item swaps. |
| 04 Loadouts | `PersonalEquipmentLoadoutState`, `EquipmentInstance`, `RunEquipmentState`; stash instance transfer and slot assignment | Registry instances preserve identity/condition, but equip/unequip changes assignments rather than exchanging exact bag locations. All named bag candidates and Nothing-to-Stash missing. Shield/Off Hand and Memento mapping needs review below. |
| 05 Workbench | `RefugeOwnershipState._apply_salvage`, `_apply_recipe`; controller repair/salvage; existing confirmation | Reuse actual cloth-armor repair (one Servant Cloth → +1 condition), equipped repair, and Common/Uncommon/Rare yields 1/2/3. Context panels and future carried-instance locations need wiring. Do not generalize the lone repair recipe into invented services. |
| 06 Alchemy/Crafting | `RefugeRecipeDefinition`, catalog and staged material debit/repair transaction | Only REPAIR_EQUIPMENT is executable; no brew/craft output recipes, station categories or permanent recipe library. Extend this authority with input/output providers; no parallel recipe engine. Real production requires authored recipe mappings. |
| 07 Refuge bed | Party snapshots; return recovery helpers; existing unavailable-service text | No executable paid Resolve restoration/Corruption cleansing or authored amounts/costs. Existing automatic HP/MP return recovery is not the bed service. Selector/shell can be built; paid actions must stay unavailable until defined. |
| 08 Expedition | Refuge selected-party order; `RunState.validate_next_layer_2_run`/`begin_next_layer_2_run`; progression snapshots; Bloom | All recruited heroines are required today. No pending Intel purchases/permanent entitlement store, no paid progression transaction, no durable accessed-floor history. Implement ordered 1–3 roster ownership safely; expose only real progression data and disabled unsupported Intel. |
| 09 Records | `save_test/persistence/knowledge_state.gd`, `scripts/dialogue/narrative_state.gd`, lore Resources/catalog, production dialogue runner | Lore IDs/text exist. No dedicated Bestiary disclosure model, historical-run archive, Gallery eligibility catalog or isolated replay mode found. Show truthful unavailable content; map authored entries before enabling replay. |
| 10 Run dock | `ReusableCombatHUD`, `CombatPresenter`, `EncounterCoordinator`; shared party/item/ability views; exploration HUD | Combat has actions/reactions/log and six items. Exploration Inventory/Party/Log are disabled placeholders; only Back works there. Unify dock/Ability context without granting new actions. Stage 14 Rest/Return and Stage 22 Submit remain gated until functional. |
| 11 Combat Backpack | Engine/BattlerState Action authority and validated item/equipment state | No approved bag mutation transaction tied to actor Action debit exists. Add one positive-operation debit with whole-operation rollback, actor-only ownership and grapple/shortcut guards. Item use costs stay separate. |
| 12 Loot | `RewardSourceResolver`, `RunState.reward_resolutions`, `EventRoomInstanceState.local_state.item_spawns`, world pickup handlers | Fixed deferred claims exist; generic adjacent loot/capacity UI, partial claims and fight abandonment do not. Active combat-usable rewards auto-route to Item Bar, not selected bag. Extend source transactions and preserve ordinary room remainders. |
| 13 Run Party | Ordered `party_snapshot`, active roster, party cards and standing profiles | No current-member inspection/reorder screen. Reorder presentation/state without rebuilding battlers, changing initiative, Actions or ownership. |
| 14 Ordinary Rest/Return | Existing Return lifecycle; explicit `has_established_refuge` | No ordinary Rest counter/service found. Its HP/MP amounts and recipients are undefined; two uses/+10 Corruption are settled. Return needs simple confirmation from new exploration dock. |
| 15 Graph/state | `MapNodeState`, `LayerMapGraph`, `LayerMapGenerator`, RunState travel/backtracking, room exit/lock handlers | Current 10–13 playable rooms/7 columns, converging routes, no generated Elites/special-room quotas. No persisted type/edge knowledge, Solved or used-Rest fields. Exit→edge bindings are absent. Extend state/generator/validator and preserve story gates. |
| 16 Map art | `LayerMapView` draws graph live with rectangular buttons | All edges are currently drawn; tooltips reveal names/IDs and selected details use actual type. Integrate flat parchment/emblems/badges, filtered knowledge, zoom/focus; keep cross-layer controls gated. |
| 17 Normal/Elite | Direct BATTLE/ELITE entry dispatch already exists; real Elite trio and alternate pair exist | Generator never selects ELITE. Wire both supported variants/formation capacity; retain mandatory story sequences and defeat lifecycle. Dining is a ROOM with an authored combat trigger: do not erase its existing exploration by blanket reclassification. |
| 18 Treasury | Authored room scenes/hotspots, seed mixer, reward catalog, source claims | Neither new Treasury is authored/executable. Use approved two backgrounds and Stage 12 remainders, explicit new registrations/activation, separate runtime items and hidden content. |
| 19 Trap | Awareness/tier Resources, DiceResolver/SkillRules, chosen-heroine room events, dialogue and encounter infrastructure | No item trap assignments/detection/disarm/once-only trigger state. No local Light Arrow particles found. Add saved trap state and presentation under existing room lifecycle; alarm must return to remaining room content. |
| 20 Rest rooms | Room local snapshots and existing bounded resource methods | No Rest node/service/saved offer/used flag. Implement exactly one seeded offer from six, party-wide preview and confirmed one-use transaction independent of Stage 14 and bed. |
| 21 Field stations | Material pouch consumption, source grants, existing production foundation to extend in 06 | No field production or permanent recipe discovery. Consume run pouch only, output to bag, first-visit grants once, repeat production independent of Solved. Needs authored output recipes/discovery mapping. |
| 22 Intel/Submit | Bloom in RunState, graph/lifecycle snapshot, Struggle UI gates | No purchasing/effects/entitlements. Buy immediately and atomically persist wallet+pending/permanent ownership. Submit button currently logs a locked message only; it needs real runtime behavior, not merely enabling the button. |
| 23 Memory/Passage | Deterministic layout/content seeds, boss-death IDs, graph snapshots, reciprocal travel | In-memory archived graphs are not a durable reusable-layout/knowledge snapshot. No purchase/start shortcut. Separate remembered layout from fresh content, retain unknowns and dead bosses; preserve prerequisites and reward-free skipped rooms. |
| 24 Acceptance | Existing 48 scripts, safe-point/defeat/route fixtures | Add behavioral coverage as each stage lands; perform actual graphical lifecycle checks and record normal-play versus fixture evidence. No campaign playthrough is claimed by Stage 00. |

## Consequential findings

### Inventory identity, party ownership and defeat protection

`RunInventoryState` has six Item Bar slots, fifteen slots per heroine, shared `key_chain`, `material_pouch`, and per-heroine Memento IDs. `RefugeOwnershipState` owns preparation bags/bar, Stash stacks and equipment instances, selected order, banked Materials and shared keys. `PersonalEquipmentLoadoutState.instances_by_id` is a separate equipment registry with `slot_instance_ids` assignments. An unequipped registered instance stays in that registry and consequently survives current defeat.

`EquipmentInstance` preserves instance ID, definition ID and condition; broken instances suppress positive authored effects and retain negative ones. Keep this model. A carried-instance representation must have one authoritative location, preserve the established protection of registered equipment, and never implicitly apply deferred equipped-only loss. Mementos currently use an ItemDefinition ID, not an EquipmentInstance with condition. Do not manufacture Memento condition or a new loss policy.

`RefugeOwnershipState._validate_selected_party` requires the selected set to equal all known heroines. Start clears every known heroine's deployed records; return iterates every known heroine expecting a run loadout. Supporting the approved subset of 1–3 heroines therefore requires all three boundaries to change together. Merely adding roster toggles would lose inactive heroines' persistent preparation/equipment or reject return. Extend before exposing selection in Stage 08, with inactive-heroine round trips tested.

Current slot enum is MAIN_HAND, OFF_HAND, ARMOR. Shields explicitly validate OFF_HAND only; Memento is separately stored. The package specifies four visible rows, while AGENTS lists an additional Shield slot. **Preserve current serialized slots for this UI pass and document Off Hand shield compatibility; a fifth independent Shield assignment would be a separate consequential rule/migration, not a cosmetic row.** Multi-slot displacement beyond existing single-slot rules must remain unsupported until resolved.

Voluntary return retains surviving Item Bar/bags, equipment and Mementos, banks unspent pouch Materials and restores HP/MP. Defeat clears Item Bar/bags and RUN_ONLY keys, retains registered equipment/condition and Mementos, banks surviving Materials, and preserves the safe Stash. Current canonical authored keys use RUN_ONLY. Existing tests cover return/defeat and one-way banking.

### Materials, recipes and wallet

Material rewards route into the current run's `material_pouch`, not directly into `banked_materials`. Return/defeat copies only the remaining pouch into the bank and empties the run pouch. `consume_material` already provides the correct spending domain for field production. Preserve that route and consume before return; do not maintain a second spendable balance. Bank withdrawal explicitly rejects.

`data/refuge/refuge_recipe_catalog.tres` contains only `refuge_repair_cloth_armor`: consume one `mat_l01_servant_cloth`, restore one condition to compatible armor. `RefugeRecipeDefinition.Action` currently contains only REPAIR_EQUIPMENT. There are no production recipes or known-recipe ownership fields to reuse as if already implemented. Extend the existing definition/catalog/transaction with station kind, output and campaign knowledge only when authored data is available. No invented potion recipes or salvage mappings are required to finish this audit.

`RunState.bloom` is the wallet, included in campaign/run snapshots. Existing start sets it to zero, matching the older locked rule that unspent Bloom is discarded on departure; no spending backend is active. Preserve that rule unless explicitly superseded. Intel must debit before that boundary, survive preparation cancellation/save/load and consume the temporary entitlement at successful start, without a second debit. Purchases need a wider transaction than `RefugeManagementController._mutate` currently provides: that method stages Refuge ownership only, not Bloom or campaign entitlements.

### Three distinct recovery contexts

No ordinary two-use Rest counter or canonical ordinary-Rest HP/MP recovery function was found in runtime/state/resources/tests. The Wine Cellar offer restores active-party HP/MP, adds 10 Resolve and 10 Corruption and consumes its guaranteed bottle; it is a one-off authored narrative interaction and must not become the ordinary Rest rule. Automatic Refuge arrival HP/MP recovery is also separate.

Stage 07 needs actual selected-heroine Resolve/Corruption amounts and costs. Stage 14 needs HP/MP amounts plus the HP/MP and +10 Corruption recipient scope. Stage 20 is fully specified at the interaction/effect level: one saved offer from six, party-wide capped effects, free one-time confirmation, independent use flag. These gaps do not block the Stage 01 room/shell work.

### Room contents, fight rewards and safe points

Ordinary pickup assignments retain `collected`, and reward-backed assignments retain `claimed`/`deferred` and their resolution seed. Capacity is checked before a sprite is removed. Existing room outcomes persist the local state, and fixed deferred node rewards retry without rerolling. This is useful foundation, but collection is whole-quantity automatic routing and there is no chest/sachet multi-item remainder UI.

The package's statement that confirmed fight abandonment is already established is **not true of this checkout**. Encounter rewards use the same fixed deferred node-record path and can retry on revisit. No “Leave these items behind?” handler was found. Stage 12 must explicitly introduce the approved fight-only close/abandon operation; ordinary item/container closure stays non-destructive. This is an authorized behavior change under the new specification, not grounds to reinstate the older blanket loss draft.

Room exit currently emits `clear_node = true`; Back emits false. `RunState.apply_event_room_outcome` preserves room state, then clears or retreats as directed. This conflates exit with Cleared, not full authored Solved. Cleared event-room revisits are not generally reopened by `travel_to`, which only retries deferred node rewards. Stages 12/15 must ensure actual persistent-room re-entry as well as stored data.

Production save envelope remains **v3**, via `CampaignSaveSlotStore` validation, verified temporary writes, primary/backup recovery and Main Menu Continue/Load. Pre-node snapshots resume an interrupted node with the same selected seed; post-node snapshots capture resolved outcomes. Refuge Load restores the Refuge boundary and clears the active run. Room pickup persistence must use existing committed exit/resolution boundaries; closing a child panel is neither a room exit nor permission for a new mid-dialogue/combat save. Tests must distinguish reloading a completed room safe point from intentionally restarting an interrupted node.

The new Refuge system-menu requirement supersedes the absence of old permanent Refuge save buttons, but does not relax safe-save rules. Proposed Stage 01 mapping: Save uses the existing Refuge boundary writer only when legal; Load enters the existing slot-load path with its current active-run-abandon behavior; Settings/Main Menu/Quit reuse application services. Nested controls must consume Escape before application-root return confirmation.

Future compatibility work belongs to the stage introducing the state: carried slot payloads in 02–04; accessed floors/roster records in 08; remaining claims in 12; ordinary Rest count in 14; graph knowledge/Solved in 15; trap/Rest-room/field state in 19–21; pending/permanent purchases in 22; durable layout memory in 23. Extend existing campaign, Refuge, run and room snapshots rather than adding save files. Append serialized enum values and update range validators (MapNodeState currently rejects values above BOSS); never reorder existing values. Define safe absent-field defaults and reject malformed explicit fields before committing. Existing v3 migrations for legacy item IDs, prepared Item Bar, authored room identity/content seeds and fixed reward records must remain. No blanket save-version bump or abandonment of old saves is authorized here.

### Graph, Elite and permanent story state

The existing generator uses the catalog as a selection source; newer registered exploration shells and the Dining/Bell pilot are already active. The AGENTS description of the forty rooms as wholly inert is historically stale relative to this implemented/checkpointed state. Preserve actual activation; do not deactivate newer rooms or activate unfinished content just because it is registered. Layers 3–10 remain outside this milestone's activation scope.

The audit probe generated both layers for seeds 1, 111, 222, 333, 8128 and 27072026. All twelve pass the **old** generator's validator. They have 10–12 playable rooms in that sample, no ELITE nodes and zero non-start/non-boss degree-one dead ends. The current declared budget is 10–13; all nodes must have a forward path to the boss, which prevents true side dead ends. Stage 15 must change the topology contract and its tests, not simply increase node count.

There are no persistent edge/type knowledge sets. `LayerMapView` draws every outgoing connection; even Unknown buttons receive actual display-name/Stable-ID tooltips, and the selected detail pane uses real names/types. Both rendering and details must query the new knowledge policy. Backtracking already performs BFS through visited/cleared rooms, but does not check every intermediate edge's runtime lock. Keep the algorithm and add known-edge/per-exit accessibility predicates; add explicit room-exit bindings because current RoomExitHotspot has no destination edge ID.

The existing Elite composition is confirmed by executing `_make_enemy_composition`: even selector gives Red-Wax Acolyte + Hollow Servant; odd gives Hollow Servant + Knife Footman + Prayer-Rag Novice. The generator never selects ELITE, so the existing branch in generated-node tests is not proof of playable Elite coverage. Stage 17 must exercise actual encounter construction/spawn capacity for both formations and smaller parties.

`CampaignLifecycleState.defeated_boss_ids` is saved. Blood Nun/Jailer outcomes mark permanent deaths; generated dead bosses clear encounter IDs and mark rewards claimed. Preserve the required opening, Mira and Seraphine recruitment and Blood Nun/Jailer aftermaths. Jailer victory creates the full Layer 2 graph at the cleared boss end, then reciprocal travel leads to Farthest Cell; reaching it alive uses voluntary transfer. Jailer/refugeless defeat takes the authored Refuge-origin route with defeat loss. `test_l1_l2_demo_flow`, Jailer origin, campaign lifecycle and safe-point tests all passed directly. This is automated fixture evidence, not a newly played campaign.

Stage 15 must retain the small story entry/holding graphs as special transitions; do not force the 14–18 playable-room budget onto the two-node Jailer-entry graph, Refuge holding state or gated Layer 3 threshold. Apply the budget to full playable layers and preserve the transition into them.

### Light Arrow, traps and Submit

Light Arrow exists in `data/abilities/seraphine_light_arrow.tres` and `data/ability_effects/attack_light_arrow.tres`; Seraphine's sheet uses it. Whole-repository source/scene searches for Light Arrow, particle node classes, projectile and VFX references found no dedicated native particle/projectile implementation. Current battle presentation uses `BattleMarker` static pose fades, coordinator visual-event forwarding and encounter-root cleanup. Those lifecycle conventions are reusable, but **the requested Light Arrow particle reference cannot be confirmed in this checkout**. Resolve the intended local reference before Stage 19 visual matching; do not claim an existing particle system was reused.

Awareness and UNTRAINED/NOVICE/EXPERT/MASTER/GRAND_MASTER tiers exist in `SkillEntry`; `DiceResolver.roll_check`/`roll_attribute` and `SkillRules` are available. No new Perception stat or Mira stat change is needed. Saved item trap assignments, observer outcomes, detection announcements, disarm/trigger/collection flags and alarm continuation are new work. Keep consequences in state transactions and particle nodes beneath the room's transient presentation owner.

Submit is currently disabled in both HUD/controller and its callback only logs the locked message. The older combat reference §13.12/§13.16 defines main-track advancement and separate healing, coupled to a two-level Refuge Grapple upgrade. The new pack approves a separate permanent Submit unlock but does not explicitly grant the older bundled Climax upgrades. Stage 22 must map the unlock to a real engine action and resolve that coupling before charging; a price alone is insufficient. Do not invent effects or silently grant unrelated upgrades.

## Asset mapping for later stages

| Stage | Supplied assets | Existing target / constraint |
| --- | --- | --- |
| 01 | Refuge `reference/07_Bloom_Refuge_Transformed.png`; `sprites/{alchemy_apparatus,crafting_toolbox,expedition_map,repair_toolkit,weapon_stand}.png`; placement/hotspot JSON | Reuse existing identical background under `assets/backgrounds/layer_2/sdxl_curated/`. One 1344×768 room transform for art/polygons. Bed/chest/books are background objects; no new prop needed. Eight explicit neighbor maps; tight Records/rack separation needs real QA. |
| 02–09 | `reference/approved_ui/01_loadouts.png` through `09_gallery.png` | Native controls bound to canonical runtime values/art. Equipment definitions currently lack icons; use real available metadata or truthful text, not fabricated art mappings. |
| 10–14 | Approved UI references `10_run_combat.png` through `15_loot_and_backpack.png` | Existing reusable combat/exploration components and real heroine profiles; separate Backpack after six items; no mockup stats. |
| 16 | `Node_Map_Art/map/background/occult_parchment_flat.png`, eleven node emblems, independent state badges, focus/selection controls | Extend LayerMapView live graph. Use manifest aliases for Intel/identified-trap art; no duplicate medallion frame. Current bloom behind icon; known locks on actual known edges. Composed preview is not a seed. Boss icon provisional. |
| 18 | `rooms/l1_treasury_servants_storehouse.png`, `l2_treasury_confiscated_belongings.png` | Author separate runtime item/container sprites and hidden source claims; normalized anchors are proposals. |
| 19–21 | Rest, Alchemy and Workshop room PNGs; trap alarm/disarmed markers; native particle guidance | No screen fog overlays. Capture item anchor before removing sprite. Rest offer/field service state remains separate from art/Solved. |

All map images retain their aspect ratio. Suggested 88-pixel medallions at 1080p, badge positions and room anchor centers are tuning proposals. Per-stage implementation must inspect the specific raw assets and verify readable native Godot output at 1920×1080, 1600×900 and 1280×720 plus supported input methods.

## Proposed implementation plan and review boundaries

Keep all 00–24 review pauses. No stages should be declared complete merely because a related backend exists. Proposed refinements, for review before their affected stages:

1. **Before Stage 01 visual acceptance:** resolve the renderer-setting discrepancy without losing the uncommitted Workbench plugin entry; obtain real graphical Godot evidence. Keep the 24 baseline structural issues as a separately reviewed repair, rather than mixing a validator rewrite into UI work.
2. **Stage 02 → 03 → 04:** settle carried instance/Memento representation and serializer validation in 02 before transfer/equip UIs depend on it. Implement atomic slot operations in 03, exact-source equipment exchange in 04. Migrate only with explicit compatibility defaults; preserve registered-equipment defeat protection. No stage merge proposed.
3. **Stage 06:** build the shared production transaction and explicit providers here; field binding stays in 21. If authored recipes are still missing, mark the production actions blocked/unavailable rather than invent recipes or claim full completion.
4. **Stage 08:** treat subset roster ownership/return as part of this stage, not just sprite selection. Track accessed floors separately from completed floors/bosses; a ten-layer seed manifest is not proof those floors were visited. Pending paid Intel remains gated until 22; Memory/Passage until 23.
5. **Stage 12 → 15:** implement source-specific remaining quantities/close policy and actual room re-entry needed for Stage 12's revisit checks in 12. Keep graph knowledge, distinct Solved and exit-driven discovery in 15. This is a small justified dependency adjustment; delaying every re-entry fix to 15 would make Stage 12 acceptance impossible.
6. **Stage 15:** add/register special-room types/state and generator constraints, but do not expose unfinished services. Gate new special-room activation until 18–21 provide working content; fixture-generated graphs can verify final quotas meanwhile. Report the transitional production distribution honestly rather than activating empty rooms to hit quotas. Final full-layer quotas must pass after activation/at 24.
7. **Stages 07/09/14/19/22:** resolve only the precise missing mappings below; continue independent work. Later shells may be visible but unavailable and must never charge.
8. **Stage 23:** persist a layout/knowledge projection at the lifecycle boundary, not a wholesale old RunState. Re-evaluate locks and refresh contents/Rest/traps; retain boss deaths and grant nothing for skipped rooms.

## Review items and blockers by stage

No unresolved gameplay choice prevents proceeding with the Stage 01 authored room and truthful shells after the user continues it. These are later-stage blockers or review choices, not a request to reapprove settled rules:

| Affected stage | Exact unresolved input / proposed handling |
| --- | --- |
| 02/04 | Carried Memento instance/slot semantics and separate Shield wording. Proposed: retain current Off Hand shield model and separate Memento ID, agree representation before extending serialized bag payloads; reject unsupported multi-slot displacement. |
| 06/21 | Authored Alchemy/Crafting outputs, ingredient quantities and permanent recipe discovery mapping are absent. No mockup economy. |
| 07 | Selected-heroine Resolve recovery and Corruption cleanse amounts, currency/material costs and eligibility are absent. |
| 08 | Paid Stats/Skills/Heroine Upgrade costs/prerequisites are absent; existing weapon ranks/unlocked abilities can be displayed truthfully. Draft/toggle semantics need an explicit proposal because current UI only reorders the full roster. |
| 09 | Bestiary fields/unlocks, run-history retention/fields, Gallery eligibility and replay-to-content bindings need authored mapping. Lore can proceed independently. |
| 14 | Ordinary Rest HP/MP recovery amounts and whether HP/MP/+10 Corruption affect selected heroine or party are not defined locally. Two successful uses and +10 are already settled. |
| 19 | Intended existing Light Arrow particle reference is missing from this checkout. Reuse verified lifecycle, obtain/reference the intended effect before claiming visual matching. |
| 22 | How the separate Submit entitlement maps to older Grapple upgrade healing/Climax coupling. Keep locked until executable; price remains configurable/TBD as authorized. |
| 23 | Current ordinary departure is Layer 2/Farthest Cell only. Generalize validation for approved eligible boss starts without bypassing story prerequisites; do not infer arbitrary floor selection or cross-layer travel. |

Provisional values remain prices (subject to 100× and Passage layer scaling), loot weights/quantities, trap counts/thresholds/automatic tiers, discoveries and final Boss art. The audit creates none of them.

## Player review and handoff

Normal entry remains `scenes/app/application_root.tscn` → Main Menu → New Campaign/Continue/Load. No new fixture entry or debug shortcut was added to production.

Stage 00 review checklist:

1. Review the matrix and the future-stage blockers; verify that these match the intended local branch.
2. On the laptop, confirm the actual renderer selection and existing Refuge/Main Menu behavior. Graphical launch here was unavailable, not visually passed.
3. Preserve the current real campaign path: opening → Mira/Seraphine → Blood Nun → Jailer; victory reverses Layer 2 toward Farthest Cell, defeat uses the Refuge-origin flow. These routes passed existing automated fixtures but were not manually replayed here.
4. Review the proposed Stage 12 re-entry and Stage 15 activation boundaries. Stage 01 work remains limited to room/hotspots/panels/system routing with unavailable later actions.
5. Give verification/continue instruction before Stage 01 begins.

Files added by Stage 00: this audit, the combined ledger and the baseline evidence document. No migration or compatibility change. No commit, push, merge, reset or publishing performed.

Suggested commit message: `docs: audit consolidated UI map and room stages`
