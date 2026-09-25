# Canonical Item Stable-ID Migration — 2026-08-25

Milestone 1 makes the August 18 workbook Stable IDs canonical for the 28 item
definitions whose existing artwork is identified by
`data/items/item_sprite_manifest.json`. It does not create definitions for the
other 98 manifest rows and does not change item effects, targeting, stack
limits, action costs, or combat behavior.

## Implemented identity mapping

| Previous ID | Canonical Stable ID |
| --- | --- |
| `bandage_roll` | `l01_bandage_roll` |
| `servants_tonic` | `l01_servants_tonic` |
| `repair_thread_and_wax` | `l01_repair_thread_wax` |
| `wax_sealed_needle` | `l01_wax_sealed_needle` |
| `warm_wine_flask` | `l01_warm_wine_flask` |
| `red_wax_ampoule` | `l01_red_wax_ampoule` |
| `kitchen_knife` | `l01_kitchen_knife` |
| `polished_serving_tray` | `l01_polished_serving_tray` |
| `smelling_salts` | `l01_smelling_salts` |
| `chapel_rosary` | `l01_chapel_rosary` |
| `hollow_livery_pin` | `l01_hollow_livery_pin` |
| `courtesy_collar` | `l01_courtesy_collar` |
| `ledger_seal` | `l01_ledger_seal` |
| `torn_cuff` | `l01_torn_cuff` |
| `rusty_key` | `shared_rusty_key` |
| `prisoners_poultice` | `l02_prisoners_poultice` |
| `rusted_nail_bundle` | `l02_rusted_nail_bundle` |
| `bitter_wakefulness_tonic` | `l02_bitter_wakefulness_tonic` |
| `chain_oil` | `l02_chain_oil` |
| `lime_dust_pouch` | `l02_lime_dust_pouch` |
| `iron_wedge` | `l02_iron_wedge` |
| `jailers_maintenance_kit` | `l02_jailers_maintenance_kit` |
| `filed_iron_shard` | `l02_filed_iron_shard` |
| `shackle_key` | `l02_shackle_key` |
| `mercy_chain` | `l02_mercy_chain` |
| `jailers_tag` | `l02_jailers_tag` |
| `quiet_shackle` | `l02_quiet_shackle` |
| `guiltless_key` | `l02_guiltless_key` |

## Metadata boundary

`ItemDefinition` remains the single gameplay definition model. It now records
the manifest-backed content category, rarity, origin Layer, canonical icon, and
whether the definition is a canonical workbook item. `item_type` remains only
for compatibility with the existing item-use code.

Milestone 1 inferred no salvage material, recipe, economy,
equipment-instance, inventory-domain, or activation data from the art
manifest/workbook handoff. Milestone 10 later activates only the four authored
Layer 1–2 Material rows and documents its direct salvage mappings separately.

Active Warm Wine and Rusty Key world pickups, plus the Red Wax Vial event
presentation, use the corresponding Stable-ID runtime textures.

## Compatibility and inactive content

Milestone 1 registered 28 implemented workbook items plus one explicitly
isolated legacy/development item. Milestone 10 adds the four executable Layer
1–2 Material definitions, so the current catalog contains 32 workbook-backed
entries plus the legacy blanket. The remaining 94 manifest rows provide
artwork only and remain non-executable.

Quiet Cell Blanket is absent from the workbook. Its definition remains at
`data/items/layer_2/quiet_cell_blanket.tres`, explicitly categorized as
legacy/development content and remains the only non-workbook catalog entry.
Its original ID and legacy icon are preserved; it has no invented Stable ID.

Save Envelope v3 is the only supported production save format. After a complete
v3 envelope validates, previous item IDs found inside its `campaign_snapshot`
are translated to Stable IDs at the campaign-load boundary before transactional
RunState restoration. Pre-v3 development files are incompatible and are not
loaded or migrated. New runtime state and newly written saves use canonical
IDs; the catalog provides no runtime aliases. Valid v3 snapshots containing
`quiet_cell_blanket` retain that ID and continue to resolve it through the
catalog.

## Validation

Run development-worktree validation and the isolated Godot suite with:

```bash
python3 tools/validate_project.py --allow-generated-cache
GODOT_BIN="$HOME/.local/bin/godot4" python3 tools/run_regression_suite.py
```
