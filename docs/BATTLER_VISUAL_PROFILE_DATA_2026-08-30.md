# Battler Visual Profile Data — 2026-08-30

Milestone 13 adds an inert, typed contract for the static-PNG battler renderer
planned for Milestone 14. It does not replace `BattleMarker`, attach sprites to
combat scenes, move battlers, or change combat/Grapple rules.

## Schema and ownership

`BattlerVisualProfileCatalog` resolves a stable `battler_id` to one
`BattlerVisualProfile`. A profile owns a stable `profile_id`, supported pose and
orientation keys, typed state pairs, floor-contact pivot, baseline scale,
per-state corrections, depth/z policy, deterministic fallbacks, optional
Grapple presentation metadata, and explicit development status. A state owns a
direct `Texture2D`; no filename or display-name guessing occurs at runtime.

The allowed core poses are `idle`, `move`, `attack`, `cast`, `defend`, `block`,
`hurt`, and `defeated`. Orientations are `front` and `back`. Resolution walks
the requested pose chain first and the requested orientation chain second, in
declared order, and rejects cycles. Render identity is
`<battler_id>::<render_instance_id>` and does not change when a pose changes.

`AuthoredBattlefield` remains authoritative for legal Positions and all combat
geometry. Anchors now expose only three future-presentation intents:
`visual_depth_band`, `visual_orientation`, and
`bounded_y_sort_within_band`. The resolver reads the authoritative placement;
it never defines routes, contacts, capacity, cover, or line of sight.

## Curated art coverage

The curated archives supplied under `assets/characters/` were inspected rather
than inferred. The 162 transparent runtime PNGs selected from them live under
`assets/characters/curated/<battler_id>/`. Thirteen inert profiles are
registered:

- heroines: Lysandra, Mira Voss, and Seraphine;
- Layer 1: Hollow Servant, Knife Footman, Prayer-Rag Novice, Corrupted Butler,
  Red-Wax Acolyte, and Blood Nun;
- Layer 2: Chain Thrall, Iron-Masked Guard, Cell Slime, and the Jailer.

Core attack, move, hurt, defeated, and authored defend pairs are registered for
both orientations. Idle is registered where supplied. Staff-cast pairs are
registered for Seraphine, Prayer-Rag Novice, Red-Wax Acolyte, and Blood Nun.
The selected PNGs are data only; the existing marker renderer remains active.

Chain Warden has no supplied archive and is the sole explicit marker-only
placeholder. Cell Slime has curated visual data but no production
`BattlerDefinition`; its profile is inert registration data and the catalog
reports that activation dependency. This follows the repository rule that
registration does not imply activation.

## Deterministic fallbacks

- `block` uses correctly oriented `defend` for every current profile.
- A missing `cast` uses correctly oriented `attack`.
- Mira's archive contains no idle pair, so `idle` uses correctly oriented
  `move`.
- A missing allowed profile returns marker-only presentation and a development
  diagnostic; an unknown battler returns an error without a texture or crash.

These choices affect only future presentation. They never change action,
movement, hit, defeat, or Grapple state. Grapple roles and overlay IDs have a
typed metadata resource, but no Grapple renderer or pose binding is activated
in this milestone.

## Adding art safely

1. Confirm the stable battler ID and inspect the actual transparent PNG.
2. Place the selected runtime asset under that battler's curated directory.
3. Add an explicit state/orientation pair to the profile; do not infer it from
   the filename at runtime.
4. Declare only intentional fallbacks, with the same orientation whenever
   possible. Never add a fallback cycle.
5. Calibrate pivot/scale/corrections in a later renderer QA pass without
   changing authored battlefield geometry.
6. Run structural validation, the focused visual-profile test, and the full
   isolated regression suite.

Room backgrounds, shared props, foreground masks, encounter-to-stage bindings,
crossfades, sprite movement, camera work, and Grapple overlays remain deferred
to their owning milestones.
