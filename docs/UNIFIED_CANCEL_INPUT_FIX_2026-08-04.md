# Unified Cancel Input Fix — 2026-08-04

## Player-facing rule

Every cancellable, pre-commit combat interaction now accepts both:

- right mouse button;
- Escape.

Existing on-screen Cancel buttons and toggle-to-cancel command buttons remain
available.

## Covered interactions

- Use Item target selection;
- Attack target selection;
- single-target Ability selection;
- BattleZone AOE selection;
- Move route/destination selection;
- Dodge destination selection;
- Grapple-Dodge destination selection;
- Ability selection popup;
- Struggle selection popup.

All inputs route through `CombatEncounter._cancel_current_interaction()` so the
same state cleanup runs regardless of how cancellation was requested.

## Commitment boundary

Cancellation still applies only before commitment. It does not interrupt an
active Move, reaction exchange, attack resolution, or other committed action.
Cancelling a selection spends no Action, MP, or item quantity.

## Focused Web Editor check

For each available command, begin target/destination selection and cancel once
with right mouse button and once with Escape. Confirm that markers/overlays
clear, commands re-enable, and resources remain unchanged. For Dodge, either
input keeps the defender in the current Position and resumes resolution.
