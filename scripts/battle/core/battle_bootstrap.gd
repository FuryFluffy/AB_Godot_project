class_name BattleBootstrap
extends RefCounted


func create_battler_states(
	definitions: Array[BattlerDefinition],
	heroine_progression_snapshots: Dictionary = {},
	run_equipment: RunEquipmentState = null
) -> Dictionary:
	var battler_states: Dictionary = {}

	for definition: BattlerDefinition in definitions:
		_register_battler_state(
			battler_states,
			definition,
			heroine_progression_snapshots,
			run_equipment
		)

	return battler_states


func _register_battler_state(
	battler_states: Dictionary,
	definition: BattlerDefinition,
	heroine_progression_snapshots: Dictionary = {},
	run_equipment: RunEquipmentState = null
) -> BattlerState:
	assert(
		definition != null,
		"Battle setup has an unassigned BattlerDefinition."
	)

	assert(
		definition.battler_id != &"",
		"%s has no battler_id."
		% definition.display_name
	)

	assert(
		not battler_states.has(definition.battler_id),
		"Duplicate battler_id: %s"
		% definition.battler_id
	)

	var progression: HeroineProgressionState
	if definition.faction == BattlerDefinition.Faction.HEROINE:
		var snapshot: Dictionary = heroine_progression_snapshots.get(
			definition.battler_id,
			heroine_progression_snapshots.get(
				String(definition.battler_id),
				{}
			)
		) as Dictionary
		progression = HeroineProgressionState.new(
			definition.battler_id,
			snapshot
		)
	var personal_loadout: PersonalEquipmentLoadoutState
	if run_equipment != null:
		personal_loadout = run_equipment.get_loadout(definition.battler_id)
	var state: BattlerState = BattlerState.new(
		definition,
		progression,
		personal_loadout
	)

	battler_states[definition.battler_id] = state
	return state
