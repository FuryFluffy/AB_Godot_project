# Complete UI / Map / Rooms — Stage 21 review

Stage 21 adds field Alchemy/Workshop rooms, current-run production ownership, once-per-room Material supplies and permanent recipe discovery support. The user authorized Stage 21 and explicitly approved provisional grants of 2 Red Wax + 2 Servant Cloth per Layer 1 station and 2 Chain Links + 2 Prison Iron per Layer 2 station. The earlier instruction to leave production recipes empty remains in force: shipped stations have no production recipes or recipe discoveries yet. Test-only recipes verify those interfaces and transactions; they are never shipped as playable recipes.

## Player behavior and content

New full Layer 1/2 maps activate independently optional Alchemy and Workshop reservations, each zero or one per layer. Four room definitions/scenes reuse the supplied, unchanged Distillation Chamber and Castle Maintenance Workshop backgrounds. The painted production table and door have fitted native interaction areas. Existing map generation seeds, topology, quotas and the inert forty-room registry are preserved; later layers remain inactive.

First entry atomically grants the approved Materials to the existing shared run pouch and learns any authored recipe discoveries. Materials have no Backpack capacity limit in this ownership model, so these grants are accepted in full; a failed grant/save leaves the entire grant pending behind Retry. It cannot be duplicated by reopening, revisiting or loading.

The station opens the existing Stage 06 Alchemy convergence or Crafting assembly/checklist layout in a modal with an explicit active-heroine Backpack destination selector. It displays every known recipe for that station type, including known recipes absent from the room's discovery list. Brew/Craft uses current-run Materials only and places ordinary outputs in the selected Backpack. Refuge continues to use banked Materials and Stash. A full Backpack, insufficient run Materials, wrong station, unknown recipe, inactive recipient or stale inventory request cannot consume inputs or create output. Existing stack splitting is retained. No station-use limit or extra production fee is added.

The modal blocks conflicting room, ordinary-Rest, Party and Backpack actions. Closing a preview consumes nothing. Successful production leaves the interface available for another craft. The rooms' authored content is complete on exit, independently of continued service availability: Solved stations remain usable on revisit.

## Implementation and files

Four scripts under `scripts/exploration/production/` provide the field provider, station Resource, hotspot intention and modal. The provider extends `RecipeProductionProvider` and delegates to existing RunInventoryState pouch/Backpack transactions. `RefugeRecipeDefinition.execute_production` remains the shared staged recipe transaction.

`RefugeRecipeCatalogDefinition.production_entries` and callback binding in `RefugeProductionView` let Refuge and field stations use the same filtering/layout code with explicit ownership providers. `starts_known` defaults true to preserve existing authored/default behavior; future discovery-only recipes set it false. No production recipe Resource is added.

EventRoomDefinition/InstanceState/Screen, LayerMapGenerator, MapNodeState, RunState and MainController connect authored rooms, first-entry preparation, saved grants and durable production. RefugeOwnershipState carries permanent discoveries through ownership copies, run departure, voluntary return and defeat. First Refuge establishment preserves discoveries on both the living and defeated routes. A tutorial defeat with discoveries saves a fresh retry checkpoint before publishing the restarted run; failed writes retain the defeat summary, and Continue resumes the same opening encounter seed with recipe knowledge intact.

Four room Resources/scenes, the event-room catalog and two supplied PNGs are added. Focused state/UI tests, native verification, a test-only recipe helper, two first-Refuge lifecycle tests and regression registration cover the new behavior. Stage 15/17 assertions now recognize the explicitly activated field rooms. The evidence file manifest and checksums identify the 46 source/content/test/UID files in the exact Stage 21 delta against the saved Stage 20 baseline. This review, the stage ledger and retained evidence complete the documentation changes. Earlier stages and unrelated Content Workbench changes are preserved.

## Persistence and compatibility

No save-version bump or destructive migration. Optional `discovered_recipe_ids` belongs to Refuge campaign ownership; `recipe_discoveries` in the active-run snapshot carries knowledge learned since departure, including before the first Refuge exists. Old snapshots default to existing departure knowledge or an empty library. Explicit malformed arrays, duplicate IDs, non-string IDs and unknown/non-production recipes reject before restore commits. Optional room-local `station_prepared` defaults absent/false; explicit values must be boolean.

Each entry/craft stages a complete RunState, validates current ownership and room outcome, and writes through the existing atomic CampaignSaveSlotStore before publishing live changes. Failed writes preserve inventory, knowledge and the prior document. Successful service resolution becomes the pre-node checkpoint for continuing that room. Ordinary mid-combat/mid-dialogue saves remain unsupported. Saved maps retain their existing content and are not regenerated to activate new rooms.

## Verification

The uninterrupted official regression suite passed **79/79 scripts, exit 0**, with no GDScript parse, compile or runtime diagnostics. Seven verification logs are retained alongside the six inspected screenshots.

- Focused state: **824 checks, zero failures**, including 200 generated layers, independent station presence, map round trips, field stacking/capacity, malformed recipe knowledge, legacy absence, return/defeat banking and a subsequent run retaining knowledge without restoring Materials.
- Final headless and native interfaces: **162 checks each, zero failures**. Covers all four room variants, all known/unknown recipe filtering, two-input recipes, exact stacked output, selected recipient, empty shipped catalogs, failed entry/craft writes, stale requests, Continue, Solved revisits and tutorial retry persistence.
- Existing Refuge production checks pass; both first-Refuge lifecycle tests pass with new recipe-preservation assertions.
- Python tooling: **13/13 passed**. Validator: **266 named GDScript classes**. Editor import has no GDScript parse/compile errors.

Native QA runs Godot 4.7.2 Compatibility on Intel Iris Xe. Production Main/map/room/save hosts are exercised at 1920×1080, 1600×900, 1280×720 and 1024×768 with real Travel, station, Close, Retry and Brew/Craft input. Prior route state and synthetic recipe registration are fixture-controlled; tutorial defeat outcomes are supplied to the production recovery handler. The field transaction and save store are production code. Native screenshots are manually inspected for room fitting, ingredient/output readability, destination labels, action visibility and the deliberately empty production state.

Existing ObjectDB/resource shutdown diagnostics and deliberate corrupt-save JSON diagnostics remain documented in retained logs. Initial UI verification caught and corrected dialog sizing and discovery loss during active-run restoration; successful final runs supersede those failed development runs. A native-run approval-review usage-limit failure was resolved by a normal approved retry after the user resumed.

Full manually played campaign and physical-gamepad acceptance remain pending. There is no unresolved design blocker for the authorized scope. Authored production recipes and discovery selections remain intentionally deferred, and the approved supply amounts are provisional balance.

## Reproducible review and handoff

Run `tools/verify_field_production.gd` with isolated Godot user/config/cache directories and `--field-captures=/tmp/field-captures` to reproduce empty and synthetic-recipe interfaces. The fixture searches seeds 1–29 for each station and primes only the preceding route. For normal play, start a new full Layer 1/2 run, find a station, verify its one-time pouch supplies and empty recipe list, leave and revisit; the materials must not be granted again.

Final full Stage 21 diff review, `git diff --check`, cumulative `git diff --stat`, baseline manifest comparison and all 46 source checksums pass. Six manually inspected native captures are retained in `evidence/complete_ui_stage21/`.

Work remains local and uncommitted. Suggested commit: `feat: complete stage 21 field production and permanent recipe discovery`.

Next milestone: Stage 22 — Intel purchases, permanent ownership and Submit unlock, awaiting instruction.
