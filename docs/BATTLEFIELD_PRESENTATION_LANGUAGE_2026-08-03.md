# Clean Player-Facing Battlefield Language

## Principle

The player never sees the complete combat model at once. The same floor is
revealed in layers only when the active rule needs it.

## Normal combat

No Zone fill, Engagement Area border, route, Position marker, identifier, or
debug label is visible.

## Move

1. All broad BattleZones receive a very faint translucent-white wash and thin
   white border.
2. Their internal Engagement Area polygons appear as restrained teal borders.
3. The current/chosen area is gold.
4. Legal next areas are teal; areas entered under threat are red.
5. Selecting an area advances the one- or two-step route.
6. Exact free Positions appear only inside the currently selected destination
   area as small corner reticles.

This visually expresses the model as:

`[Zone] — [Zone split into Engagement Areas] — [Zone]`

without showing circles or implying that a whole Zone is reachable when only
one internal area is connected.

## AOE

- Legal target BattleZones use the neutral white wash.
- Engagement Area subdivisions are hidden.
- Hovering a Zone previews the active ability colour with a gold outline.
- Clicking the polygon confirms that entire Zone.

## Dodge step

Only the relevant white BattleZone, its teal Engagement Area, and legal exact
Position reticles appear.

## Adjacency and Reach inspection

When a later inspection interaction needs these rules, emphasize only the
current Engagement Area and directly connected areas. Do not restore the full
developer graph.

## Colour ownership

Purple remains primarily associated with Corruption/Grapple. It appears on the
floor only when a purple-coded ability is being previewed, not as the universal
Zone colour.
