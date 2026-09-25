# Position Contact Player Overlay Cleanup — 2026-08-04

## Change

Authored Position-contact edges remain part of battlefield legality and remain visible in the Godot 2D editor through `AuthoredBattlefield.show_position_contacts`.

They are no longer drawn in player-facing runtime overlays:

- Move selection;
- Dodge Step selection;
- attack/ability/item target selection.

Players now see the BattleZone and Engagement Area geometry, legal destination Position reticles, route/threat feedback, and battler target markers without the underlying Position-contact graph.

## Runtime behavior

No movement, adjacency, range, Grapple, targeting, or validation logic changed. Only presentation changed.
