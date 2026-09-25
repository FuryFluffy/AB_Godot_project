# Loot Sources and Reward Routing

**Date:** 2026-08-28  
**Godot target:** 4.7.2  
**Milestone:** 9

## Production boundary

`RoomLootSourceDefinition` is the existing Event-room source Resource extended
with explicit channel, eligible Layers, once-only policy, and optional fixed
entry. Its item-pool entries already declare Stable-ID ItemDefinitions,
authored base weight, quantity, stack behavior through the item definition,
optional heroine ownership, and room presentation data. The production
`RewardSourceCatalogDefinition` validates unique IDs across active sources.

The executable source set is:

- `demo_map_item_cache` — map Item/cache channel; selectable Bandage Roll and
  Prisoner's Poultice entries for explicit Layer 1/2 Item nodes;
- `l02_kept_watch_chain_oil` — encounter-completion channel; fixed Chain Oil;
- `wine_cellar_specific` — Event-room hotspot; fixed Warm Wine Flask;
- `wine_cellar_optional_1`, `wine_cellar_optional_2`, and
  `wine_cellar_optional_3` — independent Wine Cellar hotspots, each with a
  deterministic 65% activation chance and one equal-weight Layer 1/global
  item draw;
- `butlers_office_specific` — Event-room hotspot; fixed Ledger Seal;
- `layer_1_common` — optional Event-room hotspot pool containing Servant's
  Tonic and Smelling Salts;
- `layer_1_rusty_key_01` — generated Event-room hotspot; fixed Rusty Key bound
  to the selected generated host node.
- `l01_wax_prep_red_wax_material` — room-completion Red Wax Material;
- `l01_linen_sorting_servant_cloth` — room-completion Servant Cloth Material;
- `l02_polished_gallery_chain_links` — room-completion Chain Links Material;
- `l02_punishment_room_prison_iron` — room-completion Prison Iron Material.

`m8_compat_bandage_cache` is catalogued only for loading an unresolved generic
Item node from a Milestone 8 snapshot. It preserves that node's former fixed
Bandage Roll outcome and is never assigned by current map generation.

Opening loadout, Bloom rewards, recruitment state, Blood Nun/Jailer state, and
Refuge formation remain their existing fixed non-item outcomes. There is no
production ADD_ITEM story outcome requiring conversion in the current authored
dialogue data.

## Eligibility and selection

`RewardSourceResolver` accepts only exact canonical ItemDefinitions and
requires `canonical_workbook_item = true`. Material entries additionally must
be executable `MaterialDefinition` Resources. It rejects the legacy Quiet Cell
Blanket, Story/Knowledge/unknown categories, fake Material-category items,
unowned or invalid-owner Mementos, wrong Layers, malformed quantities/weights,
and missing catalog resources. Manifest art-only rows have no ItemDefinition
and cannot enter a source.

Selection first validates and filters eligible entries, then sorts by
`entry_id`. Each entry keeps its authored base weight; when its item belongs to
the current map Layer, the effective weight is exactly `base_weight * 3`.
`StableSeedMixer` derives a dedicated `reward_source_selection` seed from the
run/generation seed, source ID, and stable node/draw binding. Battle seed
allocation is not read or advanced.

Fixed sources declare `fixed_entry_id`; they do not become random pools.
Independent sources may share a pool. Room assignments therefore resolve
presentation data through the stable `(source_id, entry_id)` pair; entry IDs
remain unique inside each pool, but need not be globally unique across a
multi-source room profile.

## Routing and one-time policy

Resolved records contain source/channel/binding IDs, entry and item Stable IDs,
quantity, optional owner, selection seed, base/effective weights, current
Layer, once-only policy, and claimed/deferred flags. Map/encounter records are
stored in `RunState.reward_resolutions`; Event-room and generated pickup records
live with the existing `item_spawns` room state. Normal debug output prints
resolution, deferral, and claim identity for QA.

All grants call `RunInventoryState.route_reward`, preserving canonical domain,
stack, slot order, and transactional capacity rules. A failed capacity check
does not mutate inventory or claim the source. The record becomes deferred and
is retried with the same item on explicit retry or when a cleared node is
revisited. Successful claims set both the resolution and map/room collection
state exactly once.

## Persistence and compatibility

Save Envelope remains version 3. Active-run `run_snapshot` adds the optional
plain Dictionary `reward_resolutions`; absence defaults to `{}` for Milestone 8
compatibility. Old fixed Chain Oil node fields map narrowly to its fixed source.
An old unresolved generic Item node maps narrowly to the compatibility-only
fixed Bandage source rather than rerolling from the new cache. Every new record
validates transactionally before RunState commit. Refuge return and defeat
continue to clear active-run reward state with the existing run boundary and
do not bypass Milestone 5 loss/banking rules.

## Deliberate deferrals

No art-only item, Memento reward without an owner, Equipment drop, new story
reward, or new inventory domain is activated here. The four later authored
Material grants reuse the existing Material Pouch and Refuge banking boundary.
