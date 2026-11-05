# Scope, authority and ownership

Use this single combined plan for the running `FuryFluffy/AB_Godot_project` on the TUXEDO laptop. Inspect current AGENTS.md, branch/working tree/checkpoints, engine and renderer first. Do not reset newer work to historical main, discard unrelated changes, push or merge. One primary chat owns the stage ledger and shared inventory/crafting/preparation/map integration.

## Authority

Current explicit user corrections are highest. In this package, root combined rules and `specs/NODE_MAP_AND_SPECIAL_ROOMS.md` govern settled gameplay changes; detailed `Refuge_and_Run_UI/` documents govern approved presentation, inventory/control permissions and retained rules. `02_IMPLEMENTATION_STAGES.md` alone governs execution order and review pauses. Mockups govern visual arrangement, not stats, prices, recipe costs, canonical heroine art or a new economy. Current code supplies compatible existing implementations/data; report a real conflict rather than overriding a settled rule with older code silently.

The former UI source copies are corrected throughout for loot and Intel timing. Detailed undecided presentation/data fields remain marked open; do not infer that every older proposal was approved. Native controls/themes and existing ownership, progression, combat, skills, recipe and save engines should be reused. Shared Backpack and Ability interfaces are single components with context permissions.

## Included scope

Refuge authored-room framework; Stash/Backpacks, transfers/stacks/splits; Loadouts; Repair/Salvage; distinct Refuge Alchemy/Crafting; Refuge bed; Expedition Party/Intel/Level Up/Explore; Records/Gallery; run dock/Ability/Backpack permissions; loot/capacity; run Party; ordinary Rest/Return; generated node graph/discovery/backtracking; revised map presentation; Normal/Elite combat-only rooms; persistent Treasuries/ordinary item sources; Trap detection/disarm/local particles; single-offer Rest rooms; run-only field production/permanent recipes; immediate preparation Intel/permanent upgrades/Submit; Castle Memory; eligible defeated-boss Passage.

## Keep these boundaries distinct

| Context | Ownership / rule |
| --- | --- |
| Refuge production | Banked Materials → Stash; existing known recipes/authored costs. |
| Field production | Materials collected during this run only → Backpack; all known station-appropriate recipes, repeated production and visits. |
| Ordinary room/Treasury/container collection | Remaining contents persist on close, revisit and save/load until collected. |
| Post-fight collection | Established summary/offer and confirmed abandonment of surplus; no post-victory exploration container scene. |
| Refuge bed | Choose heroine; Restore Resolve/Cleanse Corruption with existing authored amounts/costs. |
| Ordinary pre-Refuge HUD Rest | HP/MP recovery for +10 Corruption, two confirmed successful uses per run; minimal confirmation/count, existing recipient/amount rules. |
| Rest room | 0–1 per layer; one random fixed offer from six; party-wide bounded changes, detailed preview, no costs, one confirmed use per room. |
| Trap detection | Any active party heroine may identify with Awareness/tier. |
| Trap HP/Resolve/Corruption effect | Only the chosen interacting heroine; an alarm starts party combat. |
| Preparation purchase | Paid once on affordable click; cancelled prep gives no refund and retains pending-run ownership. |
| Actual expedition start | Consumes temporary entitlements without another charge; permanently owned benefits persist. |

Current defeat protection of all registered equipment, banking/key scopes and return/loss semantics remain preserved except expressly specified field/source boundaries. Do not implement the deferred equipped-only defeat-protection idea. Audit immediate versus deferred Materials banking and ensure field spending/return cannot double-credit or spend a separate copy of the same resources.

Append serialized enums or use established save migrations; never reorder serialized room/skill values casually. One item instance has one owner/location, and quantities, condition, Actions, source claims and wallet mutations commit atomically. Unsupported stage shells must be disabled rather than charge for a fake success.

## Deferred / configurable

Companion interaction systems, cross-layer Floor Up/Down travel, equipped-only equipment/Memento defeat loss and unsupported inventory permissions remain deferred. Floor controls/art can be reserved but not advertised as working. Exact prices except the 100× and layer-scaling relationships, Submit unlock price, loot weights/quantities, trap thresholds/counts, discovery selections and final balance are authored/configurable; temporary values must be marked provisional. Preserve genuine remaining Party draft, Memento/multi-slot, ordinary Rest recipient and backend-content mapping questions for the local audit.
