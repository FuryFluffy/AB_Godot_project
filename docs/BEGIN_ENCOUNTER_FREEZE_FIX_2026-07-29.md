# Begin Encounter freeze fix

The reusable UI itself was not changed.

The freeze was caused by combat round startup emitting several synchronous
`BattlerState.state_changed` notifications. Each notification made the
presenter rebuild the complete HUD and recalculate every item slot before the
`Begin` click could finish.

The corrected flow is:

1. `Begin` locks the command bar and defers encounter startup by one frame.
2. `BattleFlowController` resolves Order and creates round one independently.
3. `CombatPresenter` coalesces battler, battle, and inventory notifications.
4. The HUD refreshes once after the state transaction is complete.
5. Hero or enemy phase control continues through the existing battle systems.

Action pips are now reused instead of being destroyed and recreated on every
state notification. `BattlerState` also avoids emitting no-op Action changes.

Runtime check:

1. Travel to the Corrupted Butler node.
2. Press `BEGIN`.
3. Confirm the header changes from `ROUND 0 / ENCOUNTER SETUP` to round one.
4. If Heroes win Order, confirm heroine commands unlock.
5. If Enemies win Order, confirm the Butler begins its automatic phase.

`tests/test_encounter_startup.gd` covers the reusable Begin-button path.
