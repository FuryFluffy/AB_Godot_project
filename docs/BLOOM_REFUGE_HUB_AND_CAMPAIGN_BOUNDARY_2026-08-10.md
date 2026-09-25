# Abyssal Bloom — Bloom Refuge Hub and Campaign Boundary

## Scope

This checkpoint replaces the temporary post-origin holding message with the
first dedicated Bloom Refuge hub. It closes the first complete lifecycle:

`Layer 1 → Blood Nun → Go Down → Jailer defeat → Refuge → save/load → next Layer 2 run → Refuge`

Bloom spending, training menus, full party management, polished inventory,
and playable Layer 2 room/encounter content remain separate milestones.

## Final Layer 2 presentation art

The player-facing temporary SVG backdrops have been replaced:

- `jailer_boss_room.png` — the immediate Jailer battlefield;
- `farthest_cell_pre_refuge.png` — the intentional origin-dialogue cutaway;
- `bloom_refuge_transformed.png` — the dedicated Refuge hub.

The origin dialogue uses an explicit backdrop override because the Jailer has
carried the defeated party away from the active battlefield. Ordinary story
dialogue continues to inherit the scene that launched it.

## Refuge hub

The hub exposes only the lifecycle information needed for this checkpoint:

- recovered Lysandra, Mira, and Seraphine state;
- HP, MP, Resolve, and Corruption summaries;
- collected Bloom and discovered-knowledge counts;
- **Save Campaign** and **Load Campaign**;
- an editable seed and **Begin Layer 2 Run**;
- a non-destructive Layer 1 replay button that retains the Refuge save;
- the locked warning that unspent Bloom is discarded on departure.

The first Refuge origin, voluntary return, and post-Refuge defeat all restore
HP/MP while preserving Resolve, Corruption, inventory, equipment condition,
progression, recruitment, knowledge, and longer-lived narrative flags.

## Campaign save boundary

The following describes this historical checkpoint's original format-1
boundary. Production persistence now uses Save Envelope v3 under
`user://saves`; pre-v3 development files remain on disk but are incompatible.

The first versioned campaign document is stored at:

`user://abyssal_bloom_campaign_v1.json`

It contains only approved campaign-boundary state: the three-member party,
six-slot inventory, heroine progression, collected Bloom, completed layer IDs,
save/persistent narrative state, and discovered knowledge. Run-local flags,
dialogue sessions, active node state, and pending story requests are cleared.

At this checkpoint the save format had explicit version `1`. The current v3
store retains the same transactional failure rule: invalid data cannot
partially replace the in-memory run. Active-run autosaves remain deferred.

## Next Layer 2 run

Ordinary Layer 2 runs now begin at `l2_refuge_farthest_cell` and move outward
toward the unresolved Jailer at the Dungeon exit. The seeded seven-column map
is generated and visible, including its branch topology and final boss node.

Intermediate Layer 2 nodes remain deliberately travel-gated in this
checkpoint. This proves the direction and persistence lifecycle without
inventing rooms, enemy data, or battlefields before the dedicated Layer 2
content pass. **Return to Refuge** remains available from the map.

Beginning a run clears run-scoped narrative state and discards unspent Bloom,
while retaining campaign/persistent state. Returning to the Refuge archives
the active Layer 2 graph for later expansion and heals only HP/MP.
Departure writes the same zero-Bloom Refuge return point before showing the
Layer 2 map, so reloading during a run cannot restore discarded currency or
active node progress. The complete next-run graph and narrative transition are
validated before that durable departure boundary is replaced; an invalid
launch therefore leaves both the in-memory Refuge and its save untouched.

## Castle topology concept

`docs/reference/vowbreaker_castle_exterior_concept.png` is packaged as the
current broad Castle exterior/topology concept. It governs layer identity and
the vertical relationship between Layer 2, Layer 1, Layer 3, and the later
domains. It is not a literal floor plan; generated graphs and authored
transitions remain the playable connectivity source of truth.

## Regression coverage

`tests/test_bloom_refuge_hub.gd` covers:

- JSON serialization and restoration of the campaign boundary;
- String/StringName normalization after JSON parsing;
- party, inventory, progression, Bloom, knowledge, completion, and narrative
  restoration;
- the farthest-cell → Jailer seeded Layer 2 topology;
- unspent Bloom discard on next-run launch;
- invalid next-run rejection without mutating the Refuge boundary;
- voluntary return recovery;
- post-Refuge defeat recovery with Resolve/Corruption consequences retained.
