# Position Contact Adjacency Milestone — 2026-08-04

## Outcome

Exact Positions can now carry sparse, authored cross-Anchor contact links.
This adds tactical boundary engagement without turning the illustrated
battlefield into a hidden square grid.

The normal spatial rule remains unchanged: every occupant of the same Anchor
is Adjacent to every other occupant. A `PositionContactDefinition` adds one
extra undirected adjacency pair between two exact Positions in different,
directly connected Anchors. Contact adjacency is not transitive and is never
derived from pixel distance.

## Opening Servant Corridor

The Foreground BattleZone authors two links directly on Position nodes:

- `ForegroundLeftPosition3` → `ForegroundCentrePosition2`
- `ForegroundCentrePosition3` → `ForegroundRightPosition1`

Each one-sided Inspector assignment compiles into one undirected runtime
contact. No reverse Position assignment is required. These are the visually
touching upper-right/upper-left boundary pairs.

## Rules integration

- Ordinary melee treats a contact-linked opponent as Adjacent.
- Grapple may begin across contact; success pulls the grappler into the
  heroine's exact Position through the existing bundle rule.
- Ranged engagement penalties detect hostile contact across Anchors.
- Move Reactions use exact reached Position adjacency.
- Repositioning inside one Anchor can provoke when the chosen Position enters
  a contact link.
- A two-step Move chooses the least-threatened free transient Position for its
  unselected intermediate Anchor, with stable Position-index tie-breaking.
- Enemy movement scores exact contact as Adjacent distance and considers
  same-Anchor reposition previews, so a rulebook can choose a boundary
  Position instead of treating all destination Positions as equivalent.
- A successful Dodge may choose a safe free Position in the defender's current
  Anchor or a connected Anchor, but never a Position that remains Adjacent to
  the attacker.

## Presentation

Contact links remain hidden during ordinary combat. Move and Dodge selection
show teal endpoint links. Exact Move destination reticles are gold when safe
and red when they create a reaction opportunity. Melee/ability/item targeting
shows a gold link only when the selected actor and a legal target are connected
through authored contact.

## Authoring constraints

- Select an `AuthoredPosition` and add one or more target nodes to its `Connected Positions` array.
- The root compiles node-local assignments into `PositionContactDefinition`
  runtime Resources; the root no longer exposes a contact Resource array.
- Every assignment is undirected; reverse assignments and duplicate pairs are deduplicated.
- Both endpoints must exist in directly connected Anchors.
- The Anchors may straddle a BattleZone boundary when both the Anchor connection and BattleZone connection are valid and two-way.
- One exact Position may own any number of cross-Anchor contacts.
- Duplicate and invalid links fail both editor authoring validation and runtime
  battlefield validation.

## Roadmap placement

After this corridor runtime test and its encounter-template registration, the
Layer 1 vertical slice should proceed. Before Layer 1 narrative rooms multiply,
add the reusable event-room system with hotspots/interactions and the dialogue
runner. Seeded full-map generation and encounter/enemy placement randomization
should then become the content-distribution layer used by those authored combat
and event templates.
