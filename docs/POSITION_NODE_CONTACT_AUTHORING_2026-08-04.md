# Position-to-Position Contact Authoring — 2026-08-04

## Purpose

Cross-Anchor Position adjacency is authored directly on each `AuthoredPosition`
node. A Position may connect to any number of Positions in neighbouring
Anchors. The battlefield root compiles these local references into unique,
undirected `PositionContactDefinition` runtime data.

## Connect one Position to several Positions

1. Confirm the two parent Anchors are directly connected in both directions.
2. If the Anchors belong to different BattleZones, confirm those BattleZones are directly connected in both directions.
3. In the Scene tree, select the source Position marker.
4. In the Inspector, expand **Cross-Anchor Adjacency**.
5. Expand **Connected Positions**.
6. Increase the array size to the number of target Positions you need.
7. Assign one target Position node to each array element by dragging it from
   the Scene tree or using the node picker.
8. Save the scene. One gold line appears for every valid contact.
9. Select the battlefield root and press **Validate Battlefield**.

Each assignment works both ways. Do not repeat it on the target Position unless
that is more convenient; mirrored A→B and B→A entries are harmless and are
compiled only once.

## Example: one source with three contacts

Select the source Position and configure:

```text
Cross-Anchor Adjacency
└── Connected Positions (size 3)
    ├── 0: TargetPosition1
    ├── 1: TargetPosition2
    └── 2: TargetPosition3
```

The runtime receives three undirected contacts:

```text
SourcePosition ↔ TargetPosition1
SourcePosition ↔ TargetPosition2
SourcePosition ↔ TargetPosition3
```

## Existing Opening Servant Corridor examples

- `Anchors/ForegroundLeft/ForegroundLeftPosition3` connects to
  `Anchors/ForegroundCentre/ForegroundCentrePosition2`.
- `Anchors/ForegroundCentre/ForegroundCentrePosition3` connects to
  `Anchors/ForegroundRight/ForegroundRightPosition1`.

These remain single-contact examples, but either array may now contain more
entries.

## Constraints

- Every target must be an `AuthoredPosition`.
- Empty array entries fail validation.
- A Position cannot connect to itself.
- The two Positions must belong to different Anchors.
- Their Anchors must have a two-way direct Anchor connection.
- The Anchors may belong to the same or different BattleZones. Cross-zone contacts require a valid two-way BattleZone connection through their directly connected Anchors.
- Duplicate entries and mirrored declarations are deduplicated.
- There is no longer a one-contact-per-Position limit.

Remove an array entry to delete that contact.
