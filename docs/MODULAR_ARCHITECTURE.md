# Modular Combat Architecture

## Production composition

`res://scenes/battle/combat_encounter.tscn` is the sole production combat
composition. It owns:

- a `CombatEngine` scene;
- a `CombatPresenter` scene;
- a `ReusableCombatHUD` scene;
- generic input/visual overlays;
- a battlefield host and a dynamic battler-marker host;
- battler and presentation catalogs.

It does not contain a concrete battlefield background, concrete initial
placements, or pre-created markers. `EncounterDefinition` selects an
`EncounterTemplateDefinition`; the template selects an `AuthoredBattlefield`
scene, group rulebook, and neutral spawn-slot order.

The map creates and addresses `CombatEncounter` directly and assigns each
encounter seed through `CombatEncounter.base_seed`. No alternate combat
host or retired UI tree is instantiated.

## System boundaries

### CombatEngine

`CombatEngine` constructs and initializes independent rule objects. These
objects do not reference UI scenes:

- deterministic dice;
- battler/runtime state;
- action and attack resolution;
- spatial movement and targeting;
- enemy rulebooks and AI;
- ordinary reaction exchange and Dodge step;
- Grapple;
- abilities and area effects;
- six-slot items;
- statuses;
- victory/defeat lifecycle.

The engine accepts data resources and returns state/results. It can be
instanced without the production HUD or map.

### CombatPresenter

`CombatPresenter` binds engine state to the view. It forwards UI intentions
as signals and sends display updates to `ReusableCombatHUD` and
`BattleMarker`. It contains no combat calculations.

### ReusableCombatHUD

The HUD is passive:

- heroine cards, item slots, command buttons, log, ability/Struggle panels,
  and the persistent reaction exchange are reusable scenes;
- commands are signals such as `attack_requested`,
  `item_requested(slot_index)`, and `reaction_selected(reaction)`;
- state arrives through explicit display methods;
- the ordinary reaction choices are
  `Attack | Dodge | Defend | Parry | Skip`;
- Defend uses the `Armor | Shield | Back` subview;
- Grapple and threatened-movement choices use explicit modes of the same
  persistent exchange.

### EncounterCoordinator

`EncounterCoordinator` is the workflow composition root. It initializes the
engine, connects presenter intentions, sequences enemy turns, and reports
the encounter outcome to the map. It does not construct a second HUD.

### AuthoredBattlefield and encounter templates

Each battlefield scene is a content scene with one placement-free
`BattlefieldDefinition`, neutral `SpawnSlotDefinition` resources, background
art, and future visual authoring layers. The scene validates encounter
assignments and creates an immutable runtime snapshot containing only the
active battlers' concrete placements.

The production source definition therefore never names Lysandra, Mira,
Seraphine, or an enemy. The encounter owns that assignment. The older
`ruined_chapel_spatial_test.tres` remains a deterministic mechanics fixture
and is not loaded by the production host.

`BattleMarkerFactory` similarly creates only the active party/enemy views.
Adding a battler extends catalogs; it does not add a fixed node or export to
`combat_encounter.tscn`.

## Native Godot implementation

- Layout is authored with `CanvasLayer`, `Control`, and `Container` nodes.
- The reusable UI's authored 229-pixel bottom-row height is shared by the
  heroine cards, Item Bar, and Command Bar.
- Bottom-row components use native container size flags; manual runtime
  offsets do not own their layout.
- Shared visuals reference the separately designed UI's exact external
  `hud_frame_style.tres` resource directly.
- Reusable UI buttons remain text-only.
- Scenes are connected by signals and exported `NodePath` references.
- Gameplay definitions remain `.tres` resources.
- Authored battlefield scenes remain the production composition source;
  concrete placements exist only in a per-session runtime snapshot.
- Generated `.godot` state and imported-cache output are not shipped.

## Removal boundary

The production tree contains no Inspect panel, alternate reaction windows,
duplicate item bar, developer-only combat wrapper, or previous combat HUD.
The historical checkpoint is a separate downloadable archive, so Godot
does not scan or import it.

## Current implementation override

Where older design notes describe a three-choice reaction prompt, this
implementation takes precedence:

`Attack | Dodge | Defend | Parry | Skip`

Parry grants a free counterattack only when it prevents at least one
incoming success. Enemy-owned reactions and movement destinations are
resolved by enemy logic rather than player input.
