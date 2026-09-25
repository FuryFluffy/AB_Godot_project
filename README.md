# Abyssal Bloom — Modular Combat Build

This is the production Godot 4.7 project. Run `project.godot`; the main
scene is `res://scenes/app/application_root.tscn`. The application opens to
the production main menu, which creates or loads the gameplay session in
`res://scenes/main/main.tscn` only after the player chooses a campaign action.

For the current review checkpoint and private GitHub setup, see
[review status](docs/REVIEW_CHECKPOINT_2026-09-25.md) and
[private publishing guide](docs/PRIVATE_GITHUB_REVIEW_2026-09-25.md).
The proposed side-scrolling exploration overhaul is shelved.

The repository contains a complete 126-entry Stable-ID item sprite library at
`res://assets/items/by_stable_id/`, with its authoritative project manifest at
`res://data/items/item_sprite_manifest.json`. The 28 carried items plus four
executable Layer 1–2 Materials use those Stable IDs and canonical icons in the
Layer 1–2 catalog; the other 94 art records remain inert. The workbook-absent
Quiet Cell Blanket remains the catalog's thirty-third entry, explicitly
isolated as legacy/development content. See
`docs/ITEM_SPRITE_LIBRARY_INTEGRATION_2026-08-21.md` and
`docs/CANONICAL_ITEM_ID_MIGRATION_2026-08-25.md`.

All forty canonical Layer 1–2 rooms are registered in
`res://data/rooms/layer_1_2_room_catalog.tres`. The deterministic Layer map
generator selects 10–13 unique playable rooms per Layer, preserves the required
opening/event/boss anchors, and stores stable authored room IDs and content
seeds in active-run snapshots. All thirty-nine rooms with available art now
have an explicit exploration presentation; thirty-four use a shared
background-and-exit shell with no invented narrative or combat content. Intake
Corridor remains art-pending. See
`docs/LAYER_1_2_ROOM_REGISTRY_2026-08-21.md` and
`docs/LAYER_1_2_GENERATOR_ACTIVATION_2026-08-27.md`.

Milestone 15 Pilot A activates two ordinary Layer 1 entries with specialized
content. Dining Service Hall presents a room hotspot before a linked ordinary
battle; Bell-Pull Gallery presents one persistent entry observation and no
battle or reward. Other art-backed fillers remain presentation-only. See
`docs/MILESTONE_15_PILOT_A_DINING_HALL_AND_BELL_GALLERY_2026-08-31.md`.

Combat is composed by `CombatEncounter` from independent Godot systems:

- `CombatEngine` owns state, rules, dice, targeting, movement, AI,
  reactions, Grapple, abilities, items, statuses, and lifecycle.
- `CombatPresenter` is the only bridge between combat state and the view.
- `ReusableCombatHUD` emits player intentions and renders supplied state.
- `AuthoredBattlefield` scenes are the production source of truth for
  background art, painted BattleZone polygons, polygonal Engagement Areas
  (internally compatible Anchors), Positions, neutral spawns, routes, and
  depth presentation.
- `BattleMarkerFactory` creates views only for the active party and encounter.
- `BattleMarker` renders/selects those battlers and creates enemy HP/Action
  HUDs.
- `EncounterCoordinator` owns encounter sequencing and map integration.

The production combat view now resolves the curated static-PNG pose profiles
through linked stage data. Five reviewed active battle rooms use matching
restyled backgrounds; Ruined Chapel and Jailer include decorative
foreground-mask proof props. Unreviewed tactical variants keep their existing
authored backgrounds, and Chain Warden remains marker-only. See
`docs/STATIC_PNG_COMBAT_PRESENTATION_2026-08-30.md`.

The retired monolithic combat host and its UI are not included. A historical
checkpoint is distributed as a separate ZIP and is not part of this Godot
project.

The combat UI remains connected to live state through reusable Godot
`Control`/`Container` scenes, but now uses the compact edge layout: three
vertical heroine cards at bottom-left, a small two-row Command grid at
bottom-right, a short Log drawer directly above it, and six icon-ready item
slots on the right edge. Enemies show only HP and Action pips above their
sprites. The imported `hud_frame_style.tres` is retained, and the node map
launches production `CombatEncounter` instances directly. See
`docs/COMPACT_EDGE_COMBAT_HUD_CHECKPOINT_2026-08-04.md`.

See `docs/MODULAR_ARCHITECTURE.md` for system boundaries and
`docs/MODULAR_COMBAT_TEST_CHECKLIST.md` for runtime verification.

The ability layer now uses composed, Inspector-editable effect Resources
instead of the prototype `EffectType` enum. The current heroine kits are
preserved, and Dispel Magic, Slow, Regeneration and Cure are available in the
retained spell catalogue for progression integration. See
`docs/ABILITY_EFFECT_RESOURCE_MIGRATION_2026-07-30.md`.

The weapon layer now uses shared Sword, Dagger and Staff family Resources,
three Inspector-editable ranks per family, runtime-equipped ranks, and
additive unique-effect Resources on individual weapons. Future
Refuge-taught techniques can require a weapon family and minimum rank. See
`docs/WEAPON_FAMILY_RANK_RESOURCE_MIGRATION_2026-07-30.md`.

The first persistent Refuge weapon-art slice is now playable: Forced Blade,
Knife Dance, and Jaw Break cost 1 Action + 2 MP, inherit the equipped weapon,
and are unlocked through per-heroine progression snapshots. Temporary
developer grants are enabled for runtime testing. See
`docs/WEAPON_TECHNIQUES_AND_PROGRESSION_2026-08-03.md`.
Knife Dance attacks up to two different legal targets and remains usable as a
single strike when only one legal target remains.

The opening campaign now has explicit tutorial, Refuge-less, Refuge-run, and
completed modes. One randomly generated tutorial Layer 1 remains fixed through
pre-Blood-Nun wipes, while an independent combat sequence keeps retry dice from
repeating. Blood Nun victory opens two real Refuge-less contracts: **Go Up** to
the harder Layer 3 threshold or **Go Down** to the immediate Jailer encounter.
The Jailer is genuinely winnable; victory preserves no-Refuge eligibility and
permanently records the boss defeat. A victorious party enters the deterministic
Layer 2 graph at its cleared Jailer end and travels backward toward the Farthest
Cell; reaching it alive establishes the Refuge. A Refuge-less full-party defeat
still uses the authored defeat origin and normal loss policy. Either boundary
establishes the Refuge once and clears active-run Continue state. See
`docs/CAMPAIGN_LIFECYCLE_AND_SEED_ARCHITECTURE_2026-08-11.md` and
`docs/L1_JAILER_REVERSE_L2_DEMO_FLOW_2026-08-27.md`.

The farthest cell becomes a dedicated Bloom Refuge hub using the authored
transformed-room artwork. Its five-tab management surface exposes Party &
Loadouts, personal preparation and the six-slot pre-run Item Bar, Stash,
Materials and authored services, Key Chain, and Launch/Return rules while
preserving the automatic `user://` campaign boundary. It launches seeded
ordinary Layer 2 routes from the farthest cell toward the Jailer transition.
Defeated bosses are persisted by stable encounter ID and
appear as cleared passages in later generated layers. The first ordinary
Dungeon segment is now playable: **Farthest Cell Passage — Kept Watch** uses
the Chain Maintenance Room battlefield, introduces Chain Thrall and
Iron-Masked Guard, and grants 4 Bloom plus one Chain Oil on first victory.
The remaining selected Layer 2 rooms form a traversable deterministic route,
while incomplete room-specific content remains inactive. See
`docs/BLOOM_REFUGE_HUB_AND_CAMPAIGN_BOUNDARY_2026-08-10.md` and
`docs/LAYER_2_FIRST_SLICE_AND_SDXL_BACKGROUND_INTEGRATION_2026-08-12.md`.

Campaign persistence uses the canonical Save Envelope v3 across three
production slots under `user://saves`. Each validated Refuge-boundary envelope
is written through a temporary document, verified, and atomically committed
while retaining the previous valid v3 envelope as a recovery backup. Pre-v3
development saves are reported as incompatible and preserved rather than
loaded or migrated. The main menu exposes Continue, New Campaign, Load,
recovery, deletion, basic settings, and desktop Quit. Save Envelope v3 now
stores deterministic pre-node and post-node active-run safe points. Continue
selects the newest validated active run, while Load remains a Refuge-boundary
campaign operation. See
`docs/PRODUCTION_SAVE_SLOTS_AND_MAIN_MENU_2026-08-12.md`.

Runtime carried-item ownership now lives in `RunInventoryState`: a shared
six-slot combat Item Bar, fifteen-slot personal backpacks for the three demo
heroines, a shared Key Chain, a run-only Material Pouch, and one nullable
Memento slot per heroine. The generated Rusty Key and its authored lock use the
Key Chain. These domains now persist inside active-run safe points; no inventory
UI was added and the Save Envelope remains version 3. See
`docs/RUN_INVENTORY_STATE_DOMAINS_2026-08-26.md`.

Runtime equipment now uses authored definitions plus independent per-heroine
instances and condition. Each demo heroine has explicit Main Hand, Off Hand,
and Armor assignments; shields occupy Off Hand, while the existing Memento
slot remains owned by `RunInventoryState`. The established combat durability,
broken-effect, and unarmed-fallback behavior is preserved through shared
instance adapters. The 26 current non-example definitions are now registered
in one production Equipment catalog. Four definitions with direct Layer 1–2
Material mappings support deterministic Common/Uncommon/Rare salvage at the
Refuge; all other gear remains non-destructible. See
`docs/EQUIPMENT_INSTANCES_AND_PERSONAL_LOADOUTS_2026-08-26.md` and
`docs/AUTHORED_EQUIPMENT_MATERIALS_SALVAGE_RECIPES_2026-08-28.md`.

Bloom Refuge persistence now owns each heroine's ordered fifteen-slot
preparation inventory, equipment instances and assignments, one Memento,
selected-party order, the ordered six-slot pre-run Item Bar, the safe shared
Stash, the shared Key Chain between runs, and one-way banked Materials. Starting
a run moves selected prepared ownership
into runtime state. Voluntary return moves surviving backpack contents,
Item Bar, equipment, and Mementos back and banks Materials; defeat instead loses Item Bar
contents, backpacks, and ordinary run-only keys while preserving protected
ownership and broken condition. Save Envelope v3 remains version 3, and older
v3 saves without the explicit Refuge Item Bar import their migrated campaign
Item Bar safely. Banked Materials fund the one data-driven cloth-Armor repair
service, and explicitly available Refuge-owned equipment can be salvaged only
after confirmation. Materials still cannot be withdrawn into a later run. See
`docs/REFUGE_OWNERSHIP_AND_RUN_RESOLUTION_2026-08-26.md` and
`docs/REFUGE_SERVICES_AND_INVENTORY_UI_2026-08-29.md`.

Active-run persistence writes only stable safe points: once before node content
starts and once after its complete outcome is committed. Interrupted combat,
dialogue, or room interaction resumes the saved pre-node state with the exact
stored content seed; no partial encounter/UI state is serialized. Refuge
Save/Load controls are absent in production because Main Menu Continue and Load
own those actions. See
`docs/ACTIVE_RUN_SAFE_POINTS_AND_CONTINUE_2026-08-26.md`.

Production narrative graphs now use a validated dialogue catalog with explicit
trigger and completion bindings. The playable recruitment, Blood Nun, Jailer,
Farthest Cell/Refuge, Wine Cellar, and Butler's Office beats run through the
existing DialogueGraph and safe-point state. Bell-Pull Gallery adds a concise,
once-only room-entry observation through the same catalog; the canonically
silent solo opening remains direct combat. The Servant Ledger, holy-only Ruined
Confessional, and Coat/Torn Cuff clue are independently discoverable Layer 1
graphs with visit-order callbacks and campaign persistence. See
`docs/DIALOGUE_AND_CUTSCENE_PRODUCTION_AUTHORING_2026-08-30.md`.

Executable item rewards now originate from explicit source Resources. Map
caches, authored encounter completion, Event-room hotspots, and generated room
pickups share canonical-item validation, stable per-node selection seeds, the
current-layer ×3 weight rule, and `RunInventoryState` routing. Fixed Wine
Cellar, Butler's Office, Rusty Key, and Chain Oil rewards remain fixed. A full
destination stores one deferred resolution and retries that exact result; it
never silently claims or rerolls the item. See
`docs/LOOT_SOURCES_AND_REWARD_ROUTING_2026-08-28.md`.

The Wine Cellar now guarantees its offered Warm Wine Flask and rolls three
additional independent hotspots at 65% each. Accepting the room's restorative
offer consumes only the guaranteed uncollected room bottle; carried and
optional bottles are untouched. The same novel pass recalibrates the immediate
Jailer from its former five-action blocker to a hard two-action first-run boss.

Four exact first-clear room sources now make the authored Materials obtainable:
Wax Preparation grants Red Wax, Linen Sorting grants Servant Cloth, Polished
Shackle Gallery grants Chain Links, and Punishment Mechanism Room grants Prison
Iron. They route to the shared run Material Pouch and bank only through the
existing voluntary-return or defeat boundary.

The runtime art pool now includes the 21 curated SDXL Layer 1 winners and 21
curated SDXL Layer 2 winners. Current player-facing Layer 1/2 scenes reference
those winners, with aspect-preserving cover presentation against the authored
1920×1080 coordinate space. Backups and contact sheets remain external
production references rather than runtime assets.

Battle content is now composed from one generic combat host, authored
battlefield scenes, and encounter templates. Regular/elite encounters use the
Ruined Chapel proof scene; the Blood Nun boss uses the Processing Chapel proof
scene. See `docs/BATTLE_COMPOSITION_MILESTONE_2026-08-03.md`.

The future static-PNG battler renderer now has an inert typed visual-profile
catalog. It registers both orientations of the curated core pose sets for
thirteen battlers, keeps Chain Warden on an explicit marker-only fallback, and
derives presentation intents from authoritative battlefield placement without
altering the current marker renderer or combat rules. See
`docs/BATTLER_VISUAL_PROFILE_DATA_2026-08-30.md`.

Battlefield layout is edited directly in the Godot 2D viewport. Production
scenes convert their BattleZone and Engagement Area Polygon2D nodes, Position
markers, and spawn markers into the immutable `BattlefieldDefinition`; no Bake
button or synchronized production `.tres` is required. Ordinary combat hides
the geometry. Move, AOE, and Dodge reveal only the contextual white/teal/gold/
red layers required by that interaction. See
`docs/VISUAL_BATTLEFIELD_AUTHORING_MILESTONE_2026-08-03.md` and
`docs/BATTLEFIELD_PRESENTATION_LANGUAGE_2026-08-03.md`.

Sparse authored Position contacts can now make visually touching boundary
Positions Adjacent across two Anchors. Select a Position marker, expand its
**Connected Positions** array in the Inspector, and add any number of target
Position nodes. Every link is automatically undirected and compiled into
runtime contact data. Contacts may remain inside one BattleZone or cross a
valid connected BattleZone boundary, and one Position may participate in any
number of links. The Opening Servant Corridor is the first test battlefield;
melee, Grapple, Move Reactions, Dodge, ranged engagement and contextual
overlays share the same contact rule. See
`docs/POSITION_NODE_CONTACT_AUTHORING_2026-08-04.md` and
`docs/POSITION_CONTACT_ADJACENCY_MILESTONE_2026-08-04.md`.
