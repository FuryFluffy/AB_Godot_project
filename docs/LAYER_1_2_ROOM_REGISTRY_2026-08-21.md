# Layer 1–2 Room Registry — 2026-08-21

This checkpoint registered all forty canonical Layer 1–2 rooms as authoring
data. A later presentation pass now gives every room with available art a safe
exploration shell while keeping unauthored narrative and combat content
inactive.

## Registry contents

- `res://data/rooms/layer_1_2_room_catalog.tres` is the general registry.
- `res://data/rooms/layer_1/` contains the twenty canonical Layer 1 entries.
- `res://data/rooms/layer_2/` contains the twenty canonical Layer 2 entries.
- Every room has a stable `room_id`, display name, Layer, canonical order,
  concise source-derived authoring summary, visual variants and optional
  structural tags.
- Strong battle-background candidates are marked for authoring convenience;
  that marker does not schedule encounters or activate the room.

The registry contains 43 visual variants backed by all 42 curated backgrounds
currently delivered in the project. The extra variants represent distinct
states or uses of canonical rooms:

- Ruined Chapel: exploration and battle;
- Farthest Cell: pre-Refuge and transformed Refuge;
- Jailer's Containment Hall: containment-hall and boss-battle presentations.

The Intake Corridor is fully registered, but its single visual is marked
`art_pending`. The specialized visual specification expects
`10_Intake_Corridor.png`; that file is absent from the tested project and was
not found among the supplied Library files. No unrelated corridor image was
silently substituted.

## Exploration presentation coverage

Thirty-nine rooms now have an `EventRoomDefinition`. The five rooms with
specialized interaction content retain their dedicated scenes and definitions:

- Wine Cellar of Warm Bottles;
- Butler's Office;
- Wax Preparation Room;
- Dining Service Hall;
- Bell-Pull Gallery.

The other thirty-four use
`res://scenes/exploration/rooms/registered_room_shell.tscn`. Each embedded room
definition supplies its own registered background through
`presentation_texture`; the shared scene supplies only a normal map exit. It
adds no dialogue, lore, encounter, lock, pickup, or campaign outcome. Intake
Corridor remains the sole exception because its required art is missing.

The seven existing production battlefields are similarly linked from their
room entries:

- Opening Servant Corridor;
- Ruined Chapel;
- Blood Nun Processing Chapel;
- Lower Kitchen;
- Dining Service Hall;
- Chain Maintenance Room;
- Jailer's Containment Hall.

The Servant Dormitory and Service Stair Landing battlefield authoring templates
are linked separately and are not mislabeled as production-ready battlefields.

No existing resource path, encounter template, or specialized event-room
definition was replaced. `LayerMapGenerator` selects unique registry entries,
binds their stable IDs to generated nodes, and opens the explicit exploration
definition when one is authored. A presentation shell does not activate
dialogue, lore, encounters, or room-specific mechanics.

## Authoring an exploration room

1. Open its `LayerRoomDefinition` under `res://data/rooms/layer_1/` or
   `res://data/rooms/layer_2/` and review the registered visual and summary.
2. Start from the reusable registered-room shell for background-and-exit-only
   content. Create a dedicated scene under `res://scenes/exploration/rooms/`
   only when authored anchors or layout require it.
3. Add only the anchors the authored content needs: item, event, lock, exit and
   lore anchors remain independent scene components.
4. Create its `EventRoomDefinition` with the presentation scene and, when
   authored, its loot and event profiles.
5. Assign that definition to the general room entry's
   `exploration_definition` field.
6. Specialized production rooms may remain in the event-room catalog. The main
   controller also resolves the explicit definition linked by the general room
   registry, so presentation-only rooms do not require duplicate catalog rows.

## Authoring a battlefield

1. Use the room entry's primary/battle visual as the `BackgroundArt` texture.
2. Duplicate an appropriate authored battlefield/template; do not share
   mutable room-specific zones or spawn layouts between unrelated rooms.
3. Paint BattleZones, Anchors, Positions, contacts, routes and spawn slots in
   the Godot 2D editor against the 1920×1080 presentation coordinate space.
4. Run the existing battlefield authoring validation.
5. Assign the completed scene to the room entry's `production_battlefields`
   array and reference it from an encounter template when the encounter content
   is ready.

The runtime automatically cover-fits the delivered 1344×768 curated images to
the 1920×1080 presentation space. Do not destructively upscale or replace the
source textures merely to author positions.

## Generator activation

Layer 1 and ordinary Layer 2 generation now select IDs through this catalog.
Each generated layer has 10–13 playable nodes, a branch and convergence, one
entry, one boss-route exit, and deterministic per-node content seeds. Required
opening, event, recruitment, Refuge, first-slice, pre-boss, and boss roles are
reserved before safe filler rooms are selected. The generator rejects an
invalid or insufficient catalog instead of returning a partial graph or
duplicating a room.

`MapNodeState.authored_room_id` records registry identity independently of
`room_definition_id`. The latter is set only when an explicit exploration
definition exists; it still does not imply an encounter, reward, or narrative
event. Both authored identity and the derived content seed are included in
active-run snapshots and survive Continue.

## Validation

`res://tests/test_layer_room_registry.gd` validates the catalog in Godot,
`res://tests/test_registered_room_presentations.gd` exercises the reusable
shell and registered background binding, and
`res://tests/test_layer_generator_activation.gd` validates deterministic
selection, structural topology, required anchors, transactional failure, and
snapshot/Continue behavior. The dependency-free project validator checks the
same activation boundary alongside exact canonical ID/order coverage, every
delivered background reference, the single documented pending asset, and
authoring links.
