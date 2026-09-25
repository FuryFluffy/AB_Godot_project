# Campaign Lifecycle and Seed Architecture — 2026-08-11

## Checkpoint boundary

This checkpoint formalizes campaign state before ordinary Layer 2 content is
authored. It extends the runtime-confirmed Blood Nun → Jailer → Bloom Refuge
build without changing combat balance or activating the locked Dungeon rooms.

## Campaign modes

- `TUTORIAL_PRE_REFUGE`: one randomly generated Layer 1 is reused after every
  wipe until Blood Nun completion.
- `REFUGELESS_ASCENT`: Layer 1 is complete and no Refuge has ever existed.
  Both Go Up and Go Down enter this mode.
- `REFUGE_RUN`: the Bloom Refuge exists; departures create normal generated
  run seed manifests.
- `CAMPAIGN_COMPLETE`: reserved for the future ending transaction.

## Independent seed scopes

`CampaignLifecycleState` owns:

- campaign seed;
- fixed tutorial Layer 1 seed;
- Refuge-less world seed and deterministic Layer 1–10 seed manifest;
- active Refuge-run seed and deterministic Layer 1–10 seed manifest;
- a persistent combat sequence index.

Map composition remains derived from the current graph seed. Combat dice are
derived from the campaign seed plus the ever-advancing combat sequence, so a
tutorial retry reproduces the map but not the previous battle rolls.

## Boss and Refuge rules

- Blood Nun completion permanently records `layer_1_blood_nun`.
- Jailer victory is an authored success transaction, not an unexpected edge.
- Jailer victory records `layer_2_jailer_first_containment` and leaves the
  campaign in `REFUGELESS_ASCENT`.
- The first full-party defeat anywhere in `REFUGELESS_ASCENT` establishes the
  Refuge exactly once and switches to `REFUGE_RUN`.
- A Layer 3/upper-route wipe uses a dedicated Refuge-origin dialogue that does
  not claim the Jailer carried the party.
- Existing boss defeats survive Refuge establishment and later saves.
- Later generated Layer 1/2 graphs replace defeated bosses with cleared,
  traversable transition nodes.

## Save compatibility

This checkpoint originally introduced campaign format 2. Save Envelope v3 now
stores its lifecycle-bearing campaign state under `campaign_snapshot` and is
the only supported production format. Format 1 and 2 development files are
reported as incompatible and preserved without migration.

## Deferred content

- actual Layer 3 rooms and encounters;
- ordinary Layer 2 rooms and enemies;
- full multi-layer map presentation;
- non-Refuge player-facing save controls;
- Jailer balance;
- ending resolution.

The lifecycle APIs already accept future Refuge-less defeats from any layer,
so those content passes should not need another campaign-state rewrite.
