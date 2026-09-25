# Active-Run Safe Points and Main Menu Continue

## Persistence boundary

Save Envelope v3 remains the only production format. Its
`active_run_snapshot` is either null or contains:

- `safe_point_kind`: `pre_node` or `post_node`;
- `campaign_seed` and stable `layer_id`;
- `map_snapshot`: plain graph/progression data and current, selected, pending,
  and origin node IDs;
- `run_snapshot`: party state, Run Inventory, equipment instances/condition,
  progression, Bloom, encounter/layer progress, Event-room state, generated
  pickups, deterministic reward-resolution records, NarrativeState,
  CampaignLifecycleState, KnowledgeState, and the validated Refuge ownership
  departure boundary;
- `selected_node_id` and `selected_node_seed`, non-null only at a pre-node
  boundary.

Every nested value is ordinary serializable Variant data. Nodes, Resources,
scenes, controls, RNG objects, animation state, active combat/dialogue state,
and logs are never retained.

## Safe-point timing

Legal uncleared-node travel allocates the existing deterministic content seed,
writes the pre-node snapshot, and only then starts battle, dialogue, or room
setup. A failed write rolls travel and the combat-sequence allocation back and
does not enter content.

After the complete node outcome, rewards, ownership changes, and map flags are
committed, a post-node snapshot is written. A failed post write leaves the
resolved in-memory node ineligible for replay and blocks further map travel.
The previous atomic save remains available for recovery.

Reward selection uses a stream separate from battle-seed allocation. A source
record is keyed by source ID plus generated node/encounter binding. If its
destination is full, the fixed result is retained as deferred, the item remains
unclaimed, and a revisit retries the same Stable ID and quantity rather than
rerolling. The post-node snapshot carries that deferred record.

An interruption during node content reloads the pre-node state and re-enters
through the normal pipeline with the exact saved seed. A post-node resume has
no pending node and cannot replay first-clear rewards.

## Continue, Load, and Refuge

Main Menu Continue selects the most recently updated slot whose primary, or
valid recovery backup, contains a validated active-run snapshot. Existing v3
files with null active state remain valid but do not enable Continue.

Main Menu Load continues to restore only the established Bloom Refuge campaign
boundary. Loading that boundary intentionally abandons and clears any active
run in the slot. Arrival at Refuge, voluntary return, and defeat save the full
Refuge boundary with `active_run_snapshot = null` through the existing atomic
writer. Production Refuge Save/Load buttons are removed; departure and return
persistence is automatic.

## Compatibility

The outer save version remains integer 3. Pre-v3 files remain incompatible and
preserved. Atomic temporary writes, verified primary/backup rotation,
corruption recovery, slot discovery, and canonical Stable-ID campaign-load
migration remain in the existing stores.

Milestone 8 active-run snapshots without `reward_resolutions` remain valid and
default to an empty record set. The former fixed Chain Oil first-clear fields
are narrowly recognized as the corresponding fixed reward source. Malformed
new reward records reject before any restored RunState is committed.
An unresolved Milestone 8 generic Item node retains its former fixed Bandage
outcome through a compatibility-only source and cannot reroll into the new
Layer-weighted cache during migration.
