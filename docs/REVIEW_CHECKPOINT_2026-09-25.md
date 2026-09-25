# Current game review checkpoint — 2026-09-25

This checkpoint records the current production game for private source review.
The proposed side-scrolling exploration overhaul is **shelved**. Continue with
the existing illustrated rooms, hotspots, authored combat fields, node map,
DialogueGraph, Refuge and Save Envelope v3.

## Work preserved

The development branch was `milestone/15-l1-l2-demo-integration`, at
`0e2d862` before this preparation. There were 118 modified tracked files and
two new Lower Kitchen resources. All of that work is included in this
checkpoint, including Godot's resource serialization changes.

- Dining Service Hall is the user-authored depth/layout reference. Authoring
  supports optional per-Position sprite previews, scale overrides from 0.1 to
  3.0, and visual-order overrides; unmodified Positions inherit their Anchor.
- Lower Kitchen has a dedicated battlefield and encounter template for the
  Corrupted Butler/Mira recruitment. Existing active-run snapshots with the
  older template still resolve that encounter through its stable identity.
- Opening Servant Corridor, Lower Kitchen, Ruined Chapel, Blood Nun Processing
  Chapel and Jailer Containment have received floor geometry and sprite-scale
  corrections. Earlier work rendered these with movement overlays and preview
  sprites. Final interactive acceptance is still required.
- Selection temporarily fades battler art to make floor targets easier to
  see. Existing movement uses step poses and fades between Positions; facing
  follows the closest living opponent.
- Grapple resting poses survive transient reactions, and holder artwork is
  drawn behind the subject. Participants retain their separate sprites until
  combined authored art is available; the presentation does not replace the
  combat rules.
- The Wine Cellar full-restoration offer revives defeated active heroines,
  restores HP/MP and clears exploration Actions so the party cards do not
  acquire combat action displays.
- The existing novel integration preserves independent event discovery,
  visit-order callbacks, the Wine offer, Seraphine-gated Confessional,
  permanent Ledger knowledge and Torn Cuff ownership. See
  `LAYER_1_NOVEL_INTEGRATION_AND_JAILER_CALIBRATION_2026-09-02.md` for the
  approved effects and Jailer tuning.
- Existing sprite, portrait, enemy HUD, material-pickup and Refuge presentation
  fixes remain part of the current game. This preparation changes no gameplay
  code, scenes, resources, IDs or save formats.

## Remaining work

1. Play the five corrected encounters and verify floor contact, consistent
   scale, separated movement targets, route selection, obstacle ordering and
   Grapple presentation. Check defeated Mira receiving the Wine offer and
   verify that she revives with no exploration Actions display.
2. Author the remaining strong combat candidates with supplied restyled art:
   Laundry Boiler Room, Sorting Vestibule, Jailer's Gate Hall, Communal Prison
   Hall and Drainage Passage. Registration or an exploration shell does not
   mean that combat content is finished or activated.
3. Chain Maintenance retains its existing production battlefield. Matching art
   for it, Intake Corridor and Cell Block Crossroads is absent from the
   approved restyled Rooms folder; no replacement was invented.
4. Repair the pre-existing structural validator discrepancies separately:
   explicit legacy-blanket flag, parsed room identities/order and background
   registration. Packaging preserves these files and reports the failures.
5. Continue Jailer balance playtesting, complete the approved Layer 1–2 item
   and content work, and perform demo polish after battlefield acceptance.

## Verification provenance

The earlier battlefield pass reported 47/47 directly executed isolated Godot
scripts and 4/4 Python runner tests. The official cumulative runner stops at
its structural-validation prerequisite. Do not interpret the direct script
result as a clean structural-validation result.

Fresh-checkout verification and the publishing procedure are recorded in
`PRIVATE_GITHUB_REVIEW_2026-09-25.md`. Visual work from an earlier pass is not
represented as a newly performed manual playthrough.
