# Item Sprite Art Reference

This directory preserves the review and regeneration material that accompanies
the runtime Stable-ID sprite library.

- `layer_01.png` through `layer_10.png` are contact sheets for visual review.
- `item_sprite_generation_plan.json` is the machine-readable record of every
  generate/reuse decision and prompt.
- `item_sprite_generation_plan.csv` is the same plan in a compact review form.

The runtime assets are in `res://assets/items/by_stable_id/`. The authoritative
runtime mapping and approved hashes are in
`res://data/items/item_sprite_manifest.json`.

This directory is excluded from Godot importing by `.gdignore`; its files are
production references, not gameplay resources. High-resolution masters remain
in the separately archived art-source package and are not duplicated here.
