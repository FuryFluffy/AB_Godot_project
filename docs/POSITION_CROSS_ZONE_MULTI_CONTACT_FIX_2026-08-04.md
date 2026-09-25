# Position Cross-Zone Multi-Contact Fix — 2026-08-04

## Correction

Position contacts may cross a BattleZone boundary. This is required for authored
engagement clusters that visually straddle zone borders. The previous validator
incorrectly rejected those links even when the parent Anchors and BattleZones
were directly connected.

A Position may also participate in any number of contacts. The runtime validator
now matches the node-local `Connected Positions` array and no longer imposes the
obsolete one-contact-per-endpoint rule.

## Valid contact

A contact is valid when:

- both endpoints are real `AuthoredPosition` nodes in this battlefield;
- the endpoints belong to different Anchors;
- the Anchors are directly connected in both directions;
- when the Anchors are in different BattleZones, those BattleZones are connected
  in both directions;
- both Position indices exist;
- the exact pair is not duplicated.

## Opening Servant Corridor

The sample scene now includes the full fourteen-link contact network authored in
the editor screenshot: two same-zone foreground links and twelve cross-zone
boundary links between Foreground, Runway, Chokepoint and Beyond.
