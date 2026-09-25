# Static-PNG Combat Presentation and Linked Stages

Milestone 14 connects the committed Milestone 13 battler profiles to the
existing production `CombatEncounter`. Combat rules remain owned by
`CombatEngine`, `BattlefieldState`, and each `AuthoredBattlefield`; this layer
only selects artwork, poses, transforms, and draw order.

## Active bindings

| Encounter | Exploration identity | Trigger | Stage | Return |
| --- | --- | --- | --- | --- |
| Lysandra opening | `opening_servant_corridor` | route | `opening_servant_corridor_stage` | Layer 1 map |
| Corrupted Butler | `lower_kitchen` | route | `selected_layer_1_battle_stage` | Mira aftermath |
| Seraphine recruitment | `ruined_chapel` | dialogue result | `ruined_chapel_stage` | Seraphine aftermath |
| Blood Nun | `blood_nun_processing_chapel` | route | `blood_nun_processing_chapel_stage` | Blood Nun aftermath |
| Jailer | `jailers_containment_hall` | route | `jailer_containment_landing_stage` | Jailer victory/Refuge aftermath |
| Kept Watch | `chain_maintenance_room` | route | `layer_2_chain_maintenance_stage` | Layer 2 map |
| Dining Service Hall | `dining_service_hall` | interaction: `dining_service_hall_battle_route` | `dining_service_hall_stage` | Layer 1 map |

The reviewed room assets replace the backgrounds for Opening, Ruined Chapel,
Blood Nun, Jailer, and Dining Service Hall. Lower Kitchen and Chain Maintenance
preserve the exact approved background authored into their dedicated battlefield
scenes.
Opening Servant Corridor now uses a centered threshold-to-far-door battlefield
graph that follows the reviewed straight-on room perspective. Party anchors in
the threshold and lower hall request the rear-facing heroine poses. Its four
depth zones and seven engagement areas are mutually separate around the
existing Positions, retaining the original nine-contact graph. Dining's entry
floor and side lanes likewise face the party into the depth of the room.
Ruined Chapel now follows its reviewed straight nave: six mutually separate
depth/aisle zones contain eight mutually separate engagement areas around the
pew foreground mask. It retains all existing IDs, spawn assignments, anchor
connections, and the intentionally empty Position-contact set.
Blood Nun Processing Chapel uses three separated depth zones and five separated
engagement areas that follow the reviewed altar-centred room perspective. The
existing threshold/floor/dais IDs, spawn assignments, and empty Position-contact
set remain unchanged.
Jailer's Containment Hall likewise uses three separated depth zones and five
separated engagement areas, widened around the symmetrical gate-room floor and
kept clear of the centre line. It preserves the boss gate spawn, anchor graph,
empty Position-contact set, and existing decorative iron divider.
Lower Kitchen follows the same readable-floor contract: six mutually separate
zones contain eight mutually separate engagement areas, with gaps around the
worktops, foreground props, and right service doorway. Its twelve explicit
Position contacts preserve the connected combat graph without stacking
selectable polygons.

## Renderer and layer order

`BattleMarkerFactory` keeps the legacy view available, then lets
`BattleMarker` resolve the stable battler/render-instance key through
`BattlerVisualProfileCatalog`. The marker uses the profile floor-contact pivot,
state correction, authored anchor scale, and the authoritative Position. Facing
uses the nearest living opponent in screen space: an opponent deeper in the
room selects `back`, an opponent nearer the camera selects `front`, equal depth
retains the current orientation, and stable battler ID resolves distance ties.
The authored anchor orientation remains the fallback when no opponent exists.
Defeated battlers preserve their final facing.

Idle, move, attack/cast, defend, hurt, defeated, and Grapple events use static
fade swaps. Attack/cast now holds for 0.70 seconds and defend/hurt for 0.55
seconds. During an active Grapple, the subject persistently uses the Hurt pose,
the holder persistently uses the Attack pose, and the holder's art renders
behind the subject; separation returns both to Idle. Grapple progress events
may still use their 0.60–0.65-second transient poses before returning to those
role poses. Pose crossfades use 0.10 seconds in each direction. Committed
movement does not glide between authored Positions. Every
route step shows the move pose, fades out at the old Position, snaps invisibly,
re-resolves scale/depth/facing, fades in at the new Position, and returns to
idle before the next step. Movement legality and reactions remain authoritative
and unchanged. Chain Warden remains the explicit marker-only gap; Cell Slime
remains visually registered but inactive.

Spatial relayout preserves an active transient-pose timer. Position changes
re-resolve nearest-opponent facing immediately even during Attack, Hurt, or
Defend, and transient completion resolves it again while returning to idle.
Enemy HUDs show name, HP, and Actions only while the enemy is alive; defeated
art remains on the battlefield without a stale zero-HP overlay. Profile-art
HUD placement uses the sprite's top-left bounds so pose swaps and dodge movement
cannot displace the HUD by an extra half sprite. Combat and exploration party
portraits use per-heroine face-dominant crops of the current curated sources;
active Seraphine/Blood Nun/Refuge dialogue actors and portraits display those
same curated sources as combat profiles.

Stage composition is fixed at 1920×1080. Background art is at `-100`; rear,
mid, and foreground prop roots use `-20`, `5`, and `60`; active battlefield
markers retain authored orders `10`–`30`. Every active anchor now explicitly
declares background, midground, or foreground depth. Y ordering remains bounded
inside the authored marker band and never changes combat legality.

Contextual Move, BattleZone, and dodge selection geometry renders above the
battler marker band. While that geometry is active, all battler sprites fade to
46% opacity without fading enemy name/HP displays. Attack, item, and direct
ability targeting use the same non-destructive visibility layer: legal targets
remain at 72% opacity and non-targets fade to 46%. Ending or cancelling the
selection restores full sprite opacity; pose crossfades and defeated tinting
remain independent.

## Prop policy

The Ruined Chapel long pew and Jailer iron divider are foreground front-mask
proofs. Both are explicitly decorative: they add no route, capacity, cover,
line-of-sight, contact, or collision rule. A future prop may set `mechanical`
only with a non-empty `battlefield_rule_id` and the exact corresponding
`AuthoredBattlefield` rule plus focused legality tests.

The optional curtain/chain treatment is disabled by default. No cursor
parallax ships in this milestone.

## Trigger and lifecycle policy

`CombatStageBindingDefinition` records room, trigger, encounter, stage,
battlefield, completion, and return identities. `ExplorationStageTriggerState`
supports interaction, dialogue-result, route, and delayed-on-enter triggers.
Delayed triggers cancel before firing when the room resolves or exits, dialogue
opens, the mode changes, or restored state says the trigger already fired.
Trigger state is presentation orchestration only and is not a parallel save
store. Existing pre-node/post-node safe points and completed encounter state
remain authoritative for Continue and duplicate prevention.

Encounter retirement removes the combat root immediately; marker pose timers,
tweens, stage prop nodes, and deferred callbacks are owned beneath that root and
are stopped or released with it.

## Authoring recipe

1. Finish and validate the `AuthoredBattlefield` tactical composition first.
2. Add a unique `CombatStageDefinition` with the same `battlefield_id`.
3. Bind only a reviewed matching 1920×1080 room image, or explicitly preserve
   the authored background.
4. Add sparse prop definitions with normalized floor anchors and explicit depth.
5. Keep props decorative unless an exact battlefield rule and legality test
   already exist.
6. Add one binding with stable exploration-room, trigger, encounter, completion,
   and return identities.
7. Validate the catalog and exercise entry, actions, outcome, revisit, and
   Continue before activating the binding.

The remaining handoff rooms/props are candidate assets only. Registration does
not activate them.
