# Dialogue and Cutscene Production Authoring

Milestone 12 binds the existing `DialogueDefinition` graph format to production
events through `production_dialogue_catalog.tres`. A production graph declares
one stable `dialogue_id`, one `(trigger_kind, trigger_id)` pair, and one
completion condition. The completion must be authored by a graph choice or
outcome. Controllers resolve graphs through the catalog; executable event rooms
reference their entry graph from `EventRoomDefinition.entry_dialogue`.

The production catalog contains these bindings:

| Dialogue ID | Trigger |
| --- | --- |
| `layer_1_mira_recruitment_aftermath` | encounter aftermath: `layer_1_corrupted_butler_opening` |
| `layer_1_seraphine_recruitment_prelude` | encounter prelude: `layer_1_seraphine_ruined_chapel` |
| `layer_1_seraphine_recruitment_aftermath` | encounter aftermath: `layer_1_seraphine_ruined_chapel` |
| `layer_1_blood_nun_aftermath` | encounter aftermath: `layer_1_blood_nun` |
| `layer_2_refuge_origin` | Refuge-less defeat: `layer_2_jailer_first_containment` |
| `layer_2_refuge_origin_from_upper_route` | Refuge-less defeat: `refugeless_ascent_non_jailer` |
| `layer_2_jailer_victory_aftermath` | encounter victory: `layer_2_jailer_first_containment` |
| `layer_2_farthest_cell_refuge_establishment` | map arrival: `l2_refuge_farthest_cell` |
| `layer_1_wine_cellar_observation` | event-room entry: `wine_cellar_warm_bottles` |
| `layer_1_butlers_office_observation` | event-room entry: `butlers_office` |
| `layer_1_bell_pull_gallery_observation` | event-room entry: `bell_pull_gallery` |
| `layer_1_servant_ledger_observation` | event-room entry: `servant_ledger_alcove` |
| `layer_1_ruined_confessional` | event-room entry: `ruined_confessional` |
| `layer_1_coat_torn_cuff` | event-room entry: `coat_beside_service_door` |

Room and encounter backgrounds remain inherited by default. Only the authored
Refuge/Farthest Cell sequences use their existing explicit background override.
Dialogue completion is stored in the existing narrative state. Active-run safe
points therefore replay the unresolved pre-node boundary and retain completed
post-node state without introducing mid-dialogue serialization or rewards.

The opening beat is intentionally deferred. The current master reference locks
Lysandra's opening as silent isolation followed immediately by solo Hollow
Servant combat, so no speculative preamble or internal monologue is bound. Go Up
also remains mechanically deferred, and ordinary Layer 2 rooms remain generic.

Malformed sessions and unknown production graph references are rejected before
NarrativeState commits any staged values. Save Envelope version 3 and all
campaign, Refuge, inventory, combat, reward, and map formats remain unchanged.
The Bell-Pull Gallery entry uses the existing resolved-interaction outcome and
NarrativeState persistence. It grants no item, reward, status, key, battle, or
campaign branch.

The Layer 1 novel pass adds four narrowly scoped outcome kinds through the same
transactional result boundary: active-party stat changes, full active-party
HP/MP restoration, consumption of an authored uncollected room item, and
capacity-free campaign Story-item ownership. The Wine Cellar offer is once per
run. Accepting consumes its guaranteed room bottle—not a carried flask—then
fully restores the party and adds 10 Resolve and 10 Corruption; refusing leaves
the room bottle collectible. The Confessional remains dormant until Seraphine
is present, and only a completed holy interaction records its campaign callback
flag. The Ledger remains optional. Taking the Torn Cuff leaves the coat as
scenery and records `l01_torn_cuff` once in `NarrativeState.campaign_item_ids`.

The Mira recruitment aftermath uses the current curated Lysandra and Mira
sprites. Mira's dialogue portrait is a non-owning crop of that same curated
Mira source texture, so the scene no longer falls back to the retired temporary
heroine artwork.

Validate development worktrees with:

```bash
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 tools/run_regression_suite.py
```
