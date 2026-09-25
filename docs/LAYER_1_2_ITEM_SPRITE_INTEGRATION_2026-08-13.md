# Layer 1–2 Item Sprite Integration — 2026-08-13

## Scope

This checkpoint locks and integrates the supplied `AB_Item_Complete_Pack.zip` artwork into the current Godot 4.7 project. It changes presentation only: item identities, balance, effects, pickups, save data, and campaign mechanics are unchanged.

The supplied 1024×1024 images remain the authoritative source masters in the original pack. Runtime copies are alpha-trimmed, proportionally resized, padded, and centered on transparent 512×512 canvases. This keeps the in-project assets consistent without permanently resizing the masters. The reusable door states use transparent 1024×1536 canvases so they remain compatible with the authored Wine Cellar placement.

## Locked item mapping

| Layer 1 item ID | Runtime sprite |
|---|---|
| `bandage_roll` | `assets/items/layer_1/bandage_roll.png` |
| `chapel_rosary` | `assets/items/layer_1/chapel_rosary.png` |
| `courtesy_collar` | `assets/items/layer_1/courtesy_collar.png` |
| `hollow_livery_pin` | `assets/items/layer_1/hollow_livery_pin.png` |
| `kitchen_knife` | `assets/items/layer_1/kitchen_knife.png` |
| `ledger_seal` | `assets/items/layer_1/ledger_seal.png` |
| `polished_serving_tray` | `assets/items/layer_1/polished_serving_tray.png` |
| `red_wax_ampoule` | `assets/items/layer_1/red_wax_ampoule.png` |
| `repair_thread_and_wax` | `assets/items/layer_1/repair_thread_and_wax.png` |
| `servants_tonic` | `assets/items/layer_1/servants_tonic.png` |
| `smelling_salts` | `assets/items/layer_1/smelling_salts.png` |
| `torn_cuff` | `assets/items/layer_1/torn_cuff.png` |
| `warm_wine_flask` | `assets/items/layer_1/warm_wine_flask.png` |
| `wax_sealed_needle` | `assets/items/layer_1/wax_sealed_needle.png` |

| Layer 2 item ID | Runtime sprite |
|---|---|
| `bitter_wakefulness_tonic` | `assets/items/layer_2/bitter_wakefulness_tonic.png` |
| `chain_oil` | `assets/items/layer_2/chain_oil.png` |
| `filed_iron_shard` | `assets/items/layer_2/filed_iron_shard.png` |
| `guiltless_key` | `assets/items/layer_2/guiltless_key.png` |
| `iron_wedge` | `assets/items/layer_2/iron_wedge.png` |
| `jailers_maintenance_kit` | `assets/items/layer_2/jailers_maintenance_kit.png` |
| `jailers_tag` | `assets/items/layer_2/jailers_tag.png` |
| `lime_dust_pouch` | `assets/items/layer_2/lime_dust_pouch.png` |
| `mercy_chain` | `assets/items/layer_2/mercy_chain.png` |
| `prisoners_poultice` | `assets/items/layer_2/prisoners_poultice.png` |
| `quiet_cell_blanket` | `assets/items/layer_2/quiet_cell_blanket.png` |
| `quiet_shackle` | `assets/items/layer_2/quiet_shackle.png` |
| `rusted_nail_bundle` | `assets/items/layer_2/rusted_nail_bundle.png` |
| `shackle_key` | `assets/items/layer_2/shackle_key.png` |

The universal `rusty_key` pickup is locked to `assets/items/keys/rusty_key.png`.

## Authored-room integration

- Warm Wine Flask, Rusty Key, and Red Wax Ampoule room/event visuals now reuse their canonical item sprites.
- Butler's Records, Tarnished Service Bell, and Bone Dice Cup use the supplied interaction-prop sprites under `assets/exploration/shared/props/`.
- The Wine Cellar closed/open door states use the supplied reusable pair under `assets/exploration/shared/doors/`.
- Butler's Records received a local scale correction for the new trimmed 512×512 asset. Existing hotspot geometry and interaction logic are unchanged.

Godot will generate `.import` metadata for the new PNG files when the project is first opened.
