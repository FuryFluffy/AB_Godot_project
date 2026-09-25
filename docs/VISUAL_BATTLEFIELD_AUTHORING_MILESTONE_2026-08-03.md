# Visual Battlefield Authoring — Engagement Area Revision

## Outcome

Production battlefields remain visually editable Godot scenes and the sole
source of spatial data. BattleZones and Anchors are still separate mechanics,
but an authored Anchor is now presented as an editable polygonal **Engagement
Area**, never as an arbitrary circle.

The combat meaning is unchanged:

| Authored object | Combat meaning |
|---|---|
| BattleZone polygon | Broad range, AOE target, Zone effects |
| Engagement Area polygon | Adjacency cluster, movement step, Reach and Move Reactions |
| Position marker | Exact visual standing point and occupancy |

The internal class and serialized field names retain `Anchor` for compatibility.
User-facing guides and runtime presentation call the same object an Engagement
Area.

## Scene structure

```text
AuthoredBattlefield
├── BackgroundLayer
├── Zones
│   └── AuthoredBattleZone Polygon2D nodes
├── Anchors
│   └── AuthoredAnchor Polygon2D nodes (Engagement Areas)
│       └── AuthoredPosition Marker2D children
├── SpawnSlots
└── ForegroundProps
```

## Paint a BattleZone

1. Select or duplicate a `Polygon2D` child under `Zones`.
2. Use the polygon point-editing tool in the 2D toolbar.
3. Paint one broad tactical distance band, not furniture contours.
4. Set a stable `zone_id`, `display_name`, and two-way
   `connected_zone_ids`.

BattleZone polygons are the click shapes for AOE selection. A Zone may contain
one or several Engagement Areas.

## Paint an Engagement Area

1. Select or duplicate a `Polygon2D` under the internally named `Anchors`
   container.
2. Set `anchor_id`, `display_name`, `zone_id`, and two-way
   `connected_anchor_ids`.
3. Edit the polygon so it describes the usable local engagement floor.
4. Keep the polygon entirely within its owning BattleZone.
5. Choose capacity 2 or 4 and keep exactly that many Position children.
6. Place every Position inside both the Engagement Area and its BattleZone.

The polygon is now the movement hit area and player-facing subdivision. Its
size does not determine adjacency: all occupants of the same Engagement Area
are Adjacent regardless of visual spacing.

## Position validation

Validation now rejects a Position when it is outside either:

- its owning BattleZone; or
- its Engagement Area polygon.

This prevents the old silent failure mode where a Position could look outside
the authored floor while still belonging to the Anchor through scene hierarchy.

## Player-facing display

Ordinary combat shows no spatial geometry. Contextual overlays use one stable
colour language:

| Colour | Meaning |
|---|---|
| translucent white | broad BattleZone context or legal AOE Zone |
| teal | Engagement Area boundary or legal next movement step |
| gold | hovered/selected area, chosen route, exact final Position |
| red | threatened route or dangerous destination |
| active ability colour | hovered AOE preview only |

Movement reveals broad white Zones and their teal internal subdivisions. The
player chooses an Engagement Area first; only then are its free Position
reticles shown. AOE selection hides Engagement Area borders because the whole
BattleZone is the target.

The complete Zone/Area/Position/route diagram remains available only through
`BattlefieldOverlay.debug_geometry_visible` and is off by default.

## Ruined Chapel state

The chapel contains six BattleZones and eight Engagement Areas. Foreground
Nave is divided into Left, Centre, and Right polygonal areas. Gallery Approach
is the required route between Central Nave and Rear Gallery; the stale Right
Nave → Rear Gallery bypass has been removed.

## Reusable room templates

Background-only authoring scenes are available under:

`res://scenes/battle/battlefields/authoring_templates/`

They intentionally begin without Zones, Engagement Areas, Positions, or spawn
slots. Duplicate authored nodes from Ruined Chapel or Processing Chapel and
follow `REUSABLE_BATTLE_ROOM_AUTHORING_GUIDE_2026-08-03.md`.

## Deferred

- cover authoring;
- line-of-sight blockers;
- terrain rays;
- exploration hotspots and randomized room items;
- dialogue and narrative triggers.
