# Exploration Dialogue Foundation — 2026-08-10

## Scope

This checkpoint builds dialogue as a mode of exploration rather than a separate
screen. Event rooms now instantiate one shared `ExplorationHUD`, which owns the
party stat cards, six-slot Item Bar, command menu, hover presenter, and dialogue
panel. Existing Event-room interactions and outcomes remain owned by
`EventRoomScreen`.

Mira's recruitment content is intentionally not authored in this checkpoint.
The next content milestone will use this framework while preserving her locked
first line:

> You are either very brave or very lost. In this place, I suppose both count
> as qualifications.

## Authored dialogue data

Dialogue is a graph of stable Resource IDs:

- `DialogueDefinition`
- `DialogueNodeDefinition`
- `DialogueChoiceDefinition`
- `DialogueItemOptionDefinition`
- `DialogueConditionGroup`
- `DialogueConditionDefinition`
- `DialogueOutcomeDefinition`

Choices support a named responder and condition-failure presentation of either
hidden or visible-but-disabled. Conditions support `ALL`, `ANY`, and `NOT` over
current party, present actors, recruited heroines, heroine statistics, items,
Knowledge, scoped flags, earlier choices, and resolved interactions.

## Exploration modes and Item Bar policies

`ExplorationModeController` distinguishes free exploration, ordinary dialogue,
choice selection, and dialogue item selection. Room hotspots are disabled while
dialogue is active.

Each node selects one Item Bar policy:

- `DISABLED`
- `NORMAL_USE`
- `DIALOGUE_ITEMS`
- `REQUIRED_ITEM`

Dialogue item routes validate stable item and optional heroine IDs before their
outcomes are applied. Ineligible items are disabled and never consumed.

## State and outcomes

`DialogueRunner` produces `DialogueResult` snapshots. Results contain stable
choice, item, target, node, outcome, and session IDs. `NarrativeState` stores
recruitment, choice history, resolved interactions, dialogue sessions, pending
story requests, and flags separated into run, save, and persistent scopes.

Event-room-local inventory, heroine-stat, Bloom, and Knowledge effects are
applied before the room returns its outcome. Narrative results are then handed
to `RunState`; dialogue Resources never manipulate map scenes directly.
Recruitment always updates narrative recruitment state. Its `boolean_value`
controls whether the heroine also joins the current party immediately. Battle
and scene-request outcomes are emitted as stable request dictionaries for the
owning controller to route.

## Deterministic test conversation

`data/dialogue/dialogue_foundation_test.tres` covers:

- one unconditional Lysandra choice;
- one Mira-in-current-party choice shown disabled when Mira is absent;
- two branches rejoining at the same node;
- a required Warm Wine Flask answer;
- item consumption and a run-scoped flag;
- session and choice persistence.

The test is assigned to `EventRoomScreen` but disabled by default. For a visual
Web Editor check, enable `Developer Start Test Dialogue On Room Entry` on the
scene root, run the main scene, clear the solo opening, and enter an Event room.
Disable the property after testing so ordinary runs remain unchanged.
