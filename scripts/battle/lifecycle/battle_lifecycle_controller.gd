class_name BattleLifecycleController
extends RefCounted


var battler_states: Dictionary = {}
var stable_battler_order: Array[StringName] = []
var battle_state: BattleState
var runtime: BattleRuntimeState
var battlefield_state: BattlefieldState
var status_controller: StatusController
var grapple_controller: GrappleController

var last_processed_round: int = -1
var last_processed_phase_index: int = -2
var full_wipe_penalty_applied: bool = false


func initialize(
	new_battler_states: Dictionary,
	new_stable_battler_order: Array[StringName],
	new_battle_state: BattleState,
	new_runtime: BattleRuntimeState,
	new_battlefield_state: BattlefieldState,
	new_status_controller: StatusController,
	new_grapple_controller: GrappleController = null
) -> void:
	battler_states = new_battler_states
	stable_battler_order = new_stable_battler_order.duplicate()
	battle_state = new_battle_state
	runtime = new_runtime
	battlefield_state = new_battlefield_state
	status_controller = new_status_controller
	grapple_controller = new_grapple_controller
	full_wipe_penalty_applied = false


func process_current_phase_start() -> StatusPhaseReport:
	var empty_report: StatusPhaseReport = StatusPhaseReport.new()
	if battle_state == null or not battle_state.encounter_started:
		return empty_report
	if battle_state.phase == BattleState.Phase.COMPLETE:
		return empty_report
	if (
		last_processed_round == battle_state.round_number
		and last_processed_phase_index == battle_state.phase_index
	):
		return empty_report

	last_processed_round = battle_state.round_number
	last_processed_phase_index = battle_state.phase_index
	var report: StatusPhaseReport = status_controller.process_side_phase(
		battle_state.get_active_side()
	)
	evaluate_outcome()
	return report


func evaluate_outcome() -> BattleState.Outcome:
	if battle_state == null:
		return BattleState.Outcome.NONE
	if not battle_state.encounter_started:
		return BattleState.Outcome.NONE
	if battle_state.outcome != BattleState.Outcome.NONE:
		return battle_state.outcome

	var living_heroine_count: int = _count_living_faction(
		BattlerDefinition.Faction.HEROINE
	)
	var living_enemy_count: int = _count_living_faction(
		BattlerDefinition.Faction.ENEMY
	)

	if living_heroine_count <= 0:
		# Existing Grapple tracks complete after a full party knockdown.
		# Defeat remains pending while at least one controlled grappler is
		# still attached; no new track may be created during this state.
		if (
			grapple_controller == null
			or not grapple_controller.has_active_tracks()
		):
			_apply_full_wipe_resolve_penalty()
			battle_state.complete_battle(BattleState.Outcome.DEFEAT)
	elif living_enemy_count <= 0:
		battle_state.complete_battle(BattleState.Outcome.VICTORY)

	return battle_state.outcome


func is_full_party_defeated() -> bool:
	return (
		_count_living_faction(BattlerDefinition.Faction.HEROINE)
		<= 0
	)


func is_deferred_defeat_active() -> bool:
	return (
		battle_state != null
		and battle_state.encounter_started
		and battle_state.outcome == BattleState.Outcome.NONE
		and is_full_party_defeated()
		and grapple_controller != null
		and grapple_controller.has_active_tracks()
	)


func revive_battler(
	battler_id: StringName,
	restored_hp: int
) -> String:
	if battle_state != null and battle_state.phase == BattleState.Phase.COMPLETE:
		return "A completed battle must be restarted before Revival testing."

	var state: BattlerState = battler_states.get(
		battler_id
	) as BattlerState
	if state == null or state.definition == null:
		return "Revival target is invalid."
	if not state.is_defeated:
		return "%s is not defeated." % state.definition.display_name
	if not state.revive(restored_hp):
		return "%s could not be revived." % (
			state.definition.display_name
		)

	if state.is_stunned():
		state.set_current_actions(0)
	return ""


func restart_battle() -> String:
	var validation_error: String = validate_restart()
	if not validation_error.is_empty():
		return validation_error

	# Keep placement reset isolated from any shared Dictionary reference held by
	# presentation or combat controllers. The BattlerState objects themselves
	# remain shared; only the registry container is copied.
	var restart_battler_states: Dictionary = battler_states.duplicate()
	var restart_definition: BattlefieldDefinition = (
		battlefield_state.definition
	)

	for battler_id: StringName in stable_battler_order:
		var state: BattlerState = restart_battler_states.get(
			battler_id
		) as BattlerState
		if state != null:
			state.reset_to_definition()

	battle_state.reset()
	runtime.reset()
	last_processed_round = -1
	last_processed_phase_index = -2
	full_wipe_penalty_applied = false

	return battlefield_state.initialize(
		restart_definition,
		restart_battler_states
	)


func _apply_full_wipe_resolve_penalty() -> void:
	if full_wipe_penalty_applied:
		return
	full_wipe_penalty_applied = true

	for state_value: Variant in battler_states.values():
		var state: BattlerState = state_value as BattlerState
		if (
			state != null
			and state.definition != null
			and state.definition.faction
			== BattlerDefinition.Faction.HEROINE
		):
			state.change_resolve(-15)


func validate_restart() -> String:
	if battle_state == null or runtime == null:
		return "Battle lifecycle state is incomplete."
	if battlefield_state == null or battlefield_state.definition == null:
		return "BattlefieldState cannot reset its placements."

	for battler_id: StringName in stable_battler_order:
		var state: BattlerState = battler_states.get(
			battler_id
		) as BattlerState
		if state == null or state.definition == null:
			return "Restart registry is missing battler '%s'." % battler_id

	# Validate every authored placement before any live combat state is reset.
	# This prevents a failed restart from leaving HP/Actions reset while old
	# battlefield positions remain visible.
	var staged_battlefield: BattlefieldState = BattlefieldState.new()
	var staged_error: String = staged_battlefield.initialize(
		battlefield_state.definition,
		battler_states.duplicate()
	)
	if not staged_error.is_empty():
		return staged_error

	return ""


func _count_living_faction(
	faction: BattlerDefinition.Faction
) -> int:
	var living_count: int = 0
	for state_value: Variant in battler_states.values():
		var state: BattlerState = state_value as BattlerState
		if (
			state != null
			and state.definition != null
			and state.definition.faction == faction
			and not state.is_defeated
		):
			living_count += 1

	return living_count
