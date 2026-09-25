# Multiple Position Node Contacts Patch — 2026-08-04

## Changed authoring workflow

Cross-Anchor Position contacts remain authored directly on an
`AuthoredPosition`, but the former single **Connected Position** field has been
replaced with:

```text
Cross-Anchor Adjacency
└── Connected Positions
```

The array accepts any number of target `AuthoredPosition` nodes. Each one-sided
entry becomes one undirected runtime `PositionContactDefinition`.

## Runtime compatibility

`BattlefieldDefinition.position_contacts` remains unchanged. Movement,
Adjacency, targeting, Grapple, Dodge, ranged engagement, Move Reactions and
battlefield overlays continue consuming the same runtime contact data.

## Migrated sample

`opening_servant_corridor_battlefield.tscn` retains its existing contacts in
one-element arrays:

- `ForegroundLeftPosition3` → `ForegroundCentrePosition2`
- `ForegroundCentrePosition3` → `ForegroundRightPosition1`

## Validation

The battlefield validator still enforces:

- non-empty target entries;
- different endpoint Anchors;
- two-way direct Anchor connectivity;
- valid same-zone or cross-zone Anchor/BattleZone connectivity;
- valid Position indices.

The former rule limiting each Position to one cross-Anchor contact has been
removed. Duplicate entries and mirrored A→B / B→A declarations are
silently deduplicated.

## Relevant files

- `scripts/data/battlefield/authored_position.gd`
- `scripts/data/battlefield/authored_battlefield.gd`
- `scenes/battle/battlefields/opening_servant_corridor_battlefield.tscn`
- `tests/test_battlefield_authoring.gd`
- `docs/POSITION_NODE_CONTACT_AUTHORING_2026-08-04.md`
