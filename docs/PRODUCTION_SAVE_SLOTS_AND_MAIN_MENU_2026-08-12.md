# Production Save Slots and Main Menu

**Date:** 2026-08-12  
**Godot target:** 4.7  
**Base:** Layer 2 first slice + curated SDXL background checkpoint

## Application entry

`project.godot` now opens `scenes/app/application_root.tscn`. The application
root owns the main menu, creates `scenes/main/main.tscn` only after a player
action, and provides a guarded return-to-menu action during gameplay.

The previous `AbyssalBloomMainController` no longer automatically loads a save
or starts Layer 1 from `_ready()`. It exposes explicit new-campaign and
load-slot entry methods so application boot, campaign selection, and gameplay
state have separate owners.

## Three production campaign slots

Campaign slots are stored beneath:

`user://saves/abyssal_bloom_slot_1.json` through slot 3.

Each slot retains its previous verified v3 envelope as `.bak`. Saving follows:

1. build the existing Refuge-boundary campaign snapshot;
2. wrap it in the canonical Save Envelope v3;
3. write a temporary envelope;
4. parse and structurally validate the temporary document;
5. rotate the current primary into backup;
6. atomically rename the verified temporary document into place.

If the new commit fails, the previous primary is restored. If a primary save
later becomes unreadable, the load screen exposes the previous verified backup
as **Recover** rather than silently discarding the slot.

The canonical top-level fields are:

- `save_version = 3`;
- the integer `slot_id`;
- `metadata` containing `campaign_seed`, `created_at_utc`, and
  `updated_at_utc` integer UTC timestamps;
- the existing serialized state under `campaign_snapshot`;
- an empty reserved `refuge_snapshot` Dictionary;
- `active_run_snapshot`, null at a Refuge/no-run boundary and a validated
  deterministic pre-node or post-node Dictionary during an active run.

Main-menu slot summaries derive campaign mode, safe location, Bloom, party IDs,
and completed-layer count from the validated envelope without instantiating a
gameplay scene. Reserved snapshots are not populated in this milestone.

Deleting a slot removes its primary, backup, and incomplete temporary file only
after explicit confirmation.

## Compatibility

`CampaignSaveStore` remains the authoritative campaign-snapshot serializer and
transactional state restorer. `CampaignSaveSlotStore` owns the single canonical
v3 envelope, slot validation, atomic writes, and backup recovery; no parallel
save store is introduced.

Versions 1 and 2 are unsupported development formats. They are reported as
incompatible, never loaded or imported, and are not silently overwritten or
deleted. The former `user://abyssal_bloom_campaign_v1.json` file is likewise
left in place and reported as incompatible when present. Milestone 1's fixed
legacy item-ID translation remains inside the campaign-load boundary, but is
reached only after a complete v3 envelope validates.

## Main menu

The main menu provides:

- **Continue** — newest slot with a validated active-run safe point;
- **New Campaign** — slot and positive seed selection with overwrite warning;
- **Load Campaign** — three detailed slot rows, backup recovery, and deletion;
- **Settings** — persistent master volume and desktop fullscreen;
- **Quit** — desktop only.

Web builds hide fullscreen and Quit controls that are not appropriate to the
embedded runtime.

## Current safe-save boundaries

The proven Bloom Refuge campaign boundary remains the target of Main Menu Load.
Active runs additionally write a pre-node boundary before content setup and a
post-node boundary after all outcomes and rewards commit. No mid-room,
mid-dialogue, or mid-battle state is serialized. Continue resumes the newest
validated active boundary; a pre-node boundary re-enters the node with its
stored deterministic content seed.

The slot envelope, backup rotation, menu selection, explicit session bootstrap,
and settings separation remain the single production persistence path.

## Regression coverage

`tests/test_production_save_slots.gd` covers:

- fixed three-slot validation;
- exact v3 envelope shape and reserved fields;
- production slot metadata and campaign round-trip;
- incompatible v1/v2 preservation;
- malformed-v3 transactional rejection;
- Stable-ID translation inside a valid v3 campaign snapshot;
- verified primary-to-backup rotation;
- recovery from a corrupted primary;
- removal of primary, backup, and temporary documents.
