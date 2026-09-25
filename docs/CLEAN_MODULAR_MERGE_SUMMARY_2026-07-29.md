# Clean Modular Merge — Short Summary

## What changed

- Replaced the production combat host with an independent
  `CombatEncounter`.
- Removed the retired HUD, Inspect control, duplicate item bar, alternate
  reaction panels, old wrapper, presentation scripts, icons, and hidden
  developer controls from the live project.
- Kept the historical build in a separate ZIP, outside the Godot project.
- Connected the reusable HUD, persistent reaction exchange,
  ability/Struggle panels, log, item bar, command bar, heroine cards, enemy
  HUDs, and battler markers without adding a separate controls strip.
- Restored the Corrupted Butler sprite and made full character art the
  runtime selection area. Illegal overlapping heroine targets now pass input
  through to legal enemy targets.
- Restored the separately designed UI's exact scene layout and text-only
  buttons. The exact custom frame StyleBox is referenced directly by the
  native Godot controls.
- Fixed the node-map transition so encounter seeds are assigned through the
  production `CombatEncounter.base_seed` property.

## How it is separated

`CombatEngine` owns rules and state without UI types. `CombatPresenter`
translates between the engine and passive reusable views.
`EncounterCoordinator` only composes the production encounter and map
workflow. Enemy decisions, including Dodge destinations, are AI-owned.

## What is new

- Reaction exchange:
  `Attack | Dodge | Defend | Parry | Skip`.
- Defend submenu: `Armor | Shield | Back`.
- Dedicated Grapple mode and clear grapple progress below enemy HP/Actions.
- Bottom HUD with items between heroine cards and commands; both bars match
  the heroine cards' 229-pixel authored height.
- Enemy HP/Action HUDs, Butler art, full-sprite hit areas, and native system
  composition.

## What to check

Run the project in Godot 4.7 and follow
`MODULAR_COMBAT_TEST_CHECKLIST.md`. Prioritize:

1. Select a battle node and confirm it starts combat.
2. Butler art/HUD and targeting through overlapping Seraphine.
3. Item/command bar sizing, text-only buttons, and log layout.
4. all reaction choices, stale Skip cleanup, enemy-owned reactions, and
   chained Parry;
5. Grapple/Momentum with Struggle and Wait;
6. enemy movement, abilities/items, victory/defeat, and return to map.

The packaged static validator passes. Runtime tests require a Godot 4.7
executable.
