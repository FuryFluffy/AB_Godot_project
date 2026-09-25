class_name BattleMovementController
extends RefCounted


const NORMAL_MOVE_STEPS: int = 2


var battler_states: Dictionary = {}
var battlefield_state: BattlefieldState
var battle_flow_controller: BattleFlowController
var runtime: BattleRuntimeState
var last_error: String = ""


func initialize(
	new_battler_states: Dictionary,
	new_battlefield_state: BattlefieldState,
	new_battle_flow_controller: BattleFlowController,
	new_runtime: BattleRuntimeState
) -> void:
	battler_states = new_battler_states
	battlefield_state = new_battlefield_state
	battle_flow_controller = new_battle_flow_controller
	runtime = new_runtime


func begin_move_selection(
	mover_id: StringName,
	maximum_steps: int = NORMAL_MOVE_STEPS
) -> Array[MovementPreview]:
	var mover: BattlerState = _get_battler_state(mover_id)
	if mover != null:
		maximum_steps = mini(
			maximum_steps,
			mover.get_move_step_limit()
		)

	var previews: Array[MovementPreview] = get_move_previews(
		mover_id,
		maximum_steps
	)
	if previews.is_empty():
		return previews

	runtime.begin_move_targeting(mover_id)
	return previews


func get_move_previews(
	mover_id: StringName,
	maximum_steps: int = NORMAL_MOVE_STEPS
) -> Array[MovementPreview]:
	last_error = ""
	var previews: Array[MovementPreview] = []
	var mover: BattlerState = _get_battler_state(mover_id)
	if mover != null:
		maximum_steps = mini(
			maximum_steps,
			mover.get_move_step_limit()
		)

	var actor_error: String = _validate_mover(mover)
	if not actor_error.is_empty():
		last_error = actor_error
		return previews

	var position_state: BattlerPositionState = (
		battlefield_state.get_battler_position(mover_id)
	)
	if position_state == null:
		last_error = "%s has no battlefield Position." % (
			mover.definition.display_name
		)
		return previews

	_add_reposition_preview(
		mover,
		position_state,
		previews
	)

	var initial_path: Array[StringName] = [
		position_state.anchor_id,
	]
	_collect_paths(
		mover,
		initial_path,
		maxi(maximum_steps, 0),
		previews
	)

	if previews.is_empty():
		last_error = "%s has no legal Move routes." % (
			mover.definition.display_name
		)
		return previews

	return previews


func commit_move(
	preview: MovementPreview,
	destination_position_index: int
) -> String:
	if preview == null or not preview.is_valid:
		return "The selected Move preview is invalid."
	if runtime == null or not runtime.is_selecting_move:
		return "No Move selection is active."
	if runtime.pending_mover_id != preview.mover_id:
		return "The selected Move belongs to another combatant."

	var mover: BattlerState = _get_battler_state(
		preview.mover_id
	)
	var actor_error: String = _validate_mover(mover)
	if not actor_error.is_empty():
		return actor_error

	var current_position: BattlerPositionState = (
		battlefield_state.get_battler_position(
			preview.mover_id
		)
	)
	if (
		current_position == null
		or preview.anchor_path.is_empty()
		or preview.anchor_path[0] != current_position.anchor_id
	):
		return "The mover's starting Anchor changed."

	var route_error: String = _validate_committed_route(
		mover,
		preview
	)
	if not route_error.is_empty():
		return route_error

	if not preview.available_destination_positions.has(
		destination_position_index
	):
		return "The selected destination Position was not previewed."

	var current_occupant: StringName = (
		battlefield_state.get_battler_at(
			preview.destination_anchor_id,
			destination_position_index
		)
	)
	if (
		current_occupant != &""
		and current_occupant != preview.mover_id
	):
		return "The selected destination Position is now occupied."

	if not mover.spend_actions(1):
		return "%s could not spend the Move Action." % (
			mover.definition.display_name
		)

	var placement_error: String = battlefield_state.place_battler(
		preview.mover_id,
		preview.destination_anchor_id,
		destination_position_index
	)
	if not placement_error.is_empty():
		mover.set_current_actions(
			mover.current_actions + 1
		)
		return placement_error

	runtime.cancel_move_targeting()
	return ""


func begin_committed_move(
	preview: MovementPreview,
	destination_position_index: int
) -> CommittedMoveState:
	var move_state: CommittedMoveState = CommittedMoveState.new()

	if preview == null or not preview.is_valid:
		return move_state.fail(
			"The selected Move preview is invalid."
		)
	if runtime == null or not runtime.is_selecting_move:
		return move_state.fail("No Move selection is active.")
	if runtime.pending_mover_id != preview.mover_id:
		return move_state.fail(
			"The selected Move belongs to another combatant."
		)
	if runtime.has_active_move():
		return move_state.fail(
			"Another committed Move is already active."
		)

	var mover: BattlerState = _get_battler_state(
		preview.mover_id
	)
	var actor_error: String = _validate_mover(mover)
	if not actor_error.is_empty():
		return move_state.fail(actor_error)

	var current_position: BattlerPositionState = (
		battlefield_state.get_battler_position(
			preview.mover_id
		)
	)
	if (
		current_position == null
		or preview.anchor_path.is_empty()
		or preview.anchor_path[0] != current_position.anchor_id
	):
		return move_state.fail(
			"The mover's starting Anchor changed."
		)

	var route_error: String = _validate_committed_route(
		mover,
		preview
	)
	if not route_error.is_empty():
		return move_state.fail(route_error)

	if not preview.available_destination_positions.has(
		destination_position_index
	):
		return move_state.fail(
			"The selected destination Position was not previewed."
		)

	var current_occupant: StringName = (
		battlefield_state.get_battler_at(
			preview.destination_anchor_id,
			destination_position_index
		)
	)
	if (
		current_occupant != &""
		and current_occupant != preview.mover_id
	):
		return move_state.fail(
			"The selected destination Position is now occupied."
		)

	if not mover.spend_actions(1):
		return move_state.fail(
			"%s could not spend the Move Action."
			% mover.definition.display_name
		)

	move_state.is_valid = true
	move_state.mover_id = preview.mover_id
	move_state.anchor_path = preview.anchor_path.duplicate()
	move_state.destination_anchor_id = (
		preview.destination_anchor_id
	)
	move_state.destination_position_index = (
		destination_position_index
	)
	move_state.action_was_spent = true

	runtime.store_active_move(move_state)
	return move_state


func advance_active_move_step() -> String:
	if runtime == null or runtime.active_move == null:
		return "No committed Move is active."

	var move_state: CommittedMoveState = runtime.active_move
	if not move_state.is_valid:
		return move_state.error_message
	if move_state.is_complete:
		return "The committed Move is already complete."

	var mover: BattlerState = _get_battler_state(
		move_state.mover_id
	)
	if mover == null or mover.definition == null:
		return _stop_active_move(
			"The mover no longer exists."
		)
	if mover.is_defeated:
		return _stop_active_move(
			"%s was defeated and the committed Move stopped."
			% mover.definition.display_name
		)
	if mover.is_stunned():
		return _stop_active_move(
			"%s is Stunned and the committed Move stopped."
			% mover.definition.display_name
		)

	if not move_state.has_next_step():
		var reposition_error: String = (
			battlefield_state.place_battler(
				move_state.mover_id,
				move_state.destination_anchor_id,
				move_state.destination_position_index
			)
		)
		if not reposition_error.is_empty():
			return _stop_active_move(reposition_error)

		move_state.reaction_anchor_path_index = (
			move_state.current_path_index
		)
		move_state.is_complete = true
		return ""

	var next_anchor_id: StringName = (
		move_state.get_next_anchor_id()
	)
	var is_final_step: bool = (
		move_state.is_next_step_final()
	)
	var step_position_index: int = -1

	if is_final_step:
		step_position_index = (
			move_state.destination_position_index
		)
	else:
		step_position_index = _choose_transit_position(
			mover,
			next_anchor_id
		)

	# A full allied Anchor may be crossed without assigning a temporary
	# Position. Hostile/mixed full Anchors were rejected during preview.
	if step_position_index >= 0:
		var placement_error: String = (
			battlefield_state.place_battler(
				move_state.mover_id,
				next_anchor_id,
				step_position_index
			)
		)
		if not placement_error.is_empty():
			return _stop_active_move(placement_error)

	move_state.current_path_index += 1
	move_state.reaction_anchor_path_index = (
		move_state.current_path_index
	)
	if is_final_step:
		move_state.is_complete = true

	return ""


func get_active_move_reactor_ids() -> Array[StringName]:
	var reactor_ids: Array[StringName] = []
	if (
		runtime == null
		or runtime.active_move == null
		or runtime.active_move.reaction_anchor_path_index
		!= runtime.active_move.current_path_index
	):
		return reactor_ids

	var move_state: CommittedMoveState = runtime.active_move
	var mover: BattlerState = _get_battler_state(
		move_state.mover_id
	)
	if mover == null or mover.definition == null:
		return reactor_ids

	var mover_position := battlefield_state.get_battler_position(
		move_state.mover_id
	)
	if mover_position == null:
		return reactor_ids
	for occupant_id: StringName in (
		battlefield_state.get_adjacent_battler_ids_to_position(
			mover_position.anchor_id,
			mover_position.position_index,
			move_state.mover_id
		)
	):
		var occupant: BattlerState = _get_battler_state(
			occupant_id
		)
		if (
			_are_opponents(mover, occupant)
			and _can_make_move_reaction(occupant)
			and not move_state.reaction_processed_ids.has(
				occupant_id
			)
		):
			reactor_ids.append(occupant_id)

	reactor_ids.sort()
	return reactor_ids


func mark_active_move_reaction_used(
	reactor_id: StringName
) -> String:
	if runtime == null or runtime.active_move == null:
		return "No committed Move is active."
	if not get_active_move_reactor_ids().has(reactor_id):
		return "The selected combatant cannot make this Move Reaction."

	runtime.active_move.reaction_opportunity_used = true
	runtime.active_move.reaction_attacker_id = reactor_id
	runtime.active_move.reaction_attacker_ids.append(reactor_id)
	runtime.active_move.reaction_processed_ids.append(reactor_id)
	return ""


func mark_active_move_reaction_declined(
	reactor_id: StringName
) -> String:
	if runtime == null or runtime.active_move == null:
		return "No committed Move is active."
	if not get_active_move_reactor_ids().has(reactor_id):
		return "The selected combatant cannot decline this Move Reaction."

	runtime.active_move.reaction_processed_ids.append(reactor_id)
	return ""


func finish_active_move() -> CommittedMoveState:
	if runtime == null:
		return null

	var completed_move: CommittedMoveState = runtime.active_move
	if completed_move == null or not completed_move.is_complete:
		return null

	runtime.clear_active_move()
	return completed_move


func interrupt_active_move(
	reason: String
) -> String:
	if runtime == null or runtime.active_move == null:
		return "No committed Move is active."

	var move_state: CommittedMoveState = runtime.active_move
	move_state.stopped_early = true
	move_state.stop_reason = reason
	move_state.is_complete = true
	# A successful interrupt expires every later reaction window.
	move_state.reaction_anchor_path_index = -1
	return ""


func cancel_move_selection() -> void:
	if runtime != null:
		runtime.cancel_move_targeting()


func _collect_paths(
	mover: BattlerState,
	current_path: Array[StringName],
	maximum_steps: int,
	previews: Array[MovementPreview]
) -> void:
	var steps_used: int = current_path.size() - 1
	if steps_used >= maximum_steps:
		return

	var current_anchor: AnchorDefinition = (
		battlefield_state.definition.get_anchor(
			current_path[current_path.size() - 1]
		)
	)
	if current_anchor == null:
		return

	for neighbor_id: StringName in (
		current_anchor.connected_anchor_ids
	):
		if current_path.has(neighbor_id):
			continue
		if not _can_traverse_anchor(mover, neighbor_id):
			continue

		var next_path: Array[StringName] = (
			current_path.duplicate()
		)
		next_path.append(neighbor_id)

		var preview: MovementPreview = _build_preview(
			mover,
			next_path
		)
		if preview.is_valid:
			previews.append(preview)

		_collect_paths(
			mover,
			next_path,
			maximum_steps,
			previews
		)


func _add_reposition_preview(
	mover: BattlerState,
	position_state: BattlerPositionState,
	previews: Array[MovementPreview]
) -> void:
	if battlefield_state.is_battler_over_capacity(
		mover.definition.battler_id
	):
		return
	var free_positions: Array[int] = (
		battlefield_state.get_free_position_indices(
			position_state.anchor_id,
			mover.definition.battler_id
		)
	)
	free_positions.erase(position_state.position_index)
	if free_positions.is_empty():
		return

	var preview: MovementPreview = MovementPreview.new()
	preview.is_valid = true
	preview.mover_id = mover.definition.battler_id
	preview.anchor_path = [position_state.anchor_id]
	preview.destination_anchor_id = position_state.anchor_id
	preview.available_destination_positions = free_positions
	var has_threatened_destination: bool = false
	for destination_position_index: int in free_positions:
		preview.threat_battler_ids_by_destination_position[
			destination_position_index
		] = []
		var threats := _get_reactors_threatening_position(
			mover,
			position_state.anchor_id,
			destination_position_index
		)
		if threats.is_empty():
			continue
		has_threatened_destination = true
		_add_preview_threats(
			preview,
			destination_position_index,
			threats
		)
	if has_threatened_destination:
		preview.hostile_step_anchor_ids.append(position_state.anchor_id)
	previews.append(preview)


func _build_preview(
	mover: BattlerState,
	path: Array[StringName]
) -> MovementPreview:
	var preview: MovementPreview = MovementPreview.new()
	preview.mover_id = mover.definition.battler_id
	preview.anchor_path = path.duplicate()
	preview.destination_anchor_id = path[path.size() - 1]
	if battlefield_state.is_anchor_over_capacity(
		preview.destination_anchor_id
	):
		preview.error_message = (
			"The destination Anchor is over capacity."
		)
		return preview
	preview.available_destination_positions = (
		battlefield_state.get_free_position_indices(
			preview.destination_anchor_id,
			mover.definition.battler_id
		)
	)

	if preview.available_destination_positions.is_empty():
		preview.error_message = (
			"The destination Anchor has no free Position."
		)
		return preview

	for destination_position_index: int in (
		preview.available_destination_positions
	):
		preview.threat_battler_ids_by_destination_position[
			destination_position_index
		] = []

	for step_index: int in range(1, path.size()):
		var step_anchor_id: StringName = path[step_index]
		var is_final_step := step_index == path.size() - 1
		var step_has_threat := false
		if is_final_step:
			for destination_position_index: int in (
				preview.available_destination_positions
			):
				var threats := _get_reactors_threatening_position(
					mover,
					step_anchor_id,
					destination_position_index
				)
				if not threats.is_empty():
					step_has_threat = true
				_add_preview_threats(
					preview,
					destination_position_index,
					threats
				)
		else:
			var transit_position_index := _choose_transit_position(
				mover,
				step_anchor_id
			)
			if transit_position_index >= 0:
				var transit_threats := _get_reactors_threatening_position(
					mover,
					step_anchor_id,
					transit_position_index
				)
				if not transit_threats.is_empty():
					step_has_threat = true
				for destination_position_index: int in (
					preview.available_destination_positions
				):
					_add_preview_threats(
						preview,
						destination_position_index,
						transit_threats
					)

		if step_has_threat:
			preview.hostile_step_anchor_ids.append(step_anchor_id)

	preview.is_valid = true
	return preview


func _add_preview_threats(
	preview: MovementPreview,
	destination_position_index: int,
	threats: Array[StringName]
) -> void:
	var stored: Array = preview.threat_battler_ids_by_destination_position.get(
		destination_position_index,
		[]
	)
	for threat_id: StringName in threats:
		if not stored.has(threat_id):
			stored.append(threat_id)
		if not preview.threat_battler_ids.has(threat_id):
			preview.threat_battler_ids.append(threat_id)
	preview.threat_battler_ids_by_destination_position[
		destination_position_index
	] = stored
	preview.threat_battler_ids.sort()


func _get_reactors_threatening_position(
	mover: BattlerState,
	anchor_id: StringName,
	position_index: int
) -> Array[StringName]:
	var reactor_ids: Array[StringName] = []
	if mover == null or mover.definition == null:
		return reactor_ids
	for occupant_id: StringName in (
		battlefield_state.get_adjacent_battler_ids_to_position(
			anchor_id,
			position_index,
			mover.definition.battler_id
		)
	):
		var occupant := _get_battler_state(occupant_id)
		if (
			_are_opponents(mover, occupant)
			and _can_make_move_reaction(occupant)
		):
			reactor_ids.append(occupant_id)
	reactor_ids.sort()
	return reactor_ids


func _choose_transit_position(
	mover: BattlerState,
	anchor_id: StringName
) -> int:
	if mover == null or mover.definition == null:
		return -1
	var free_positions := battlefield_state.get_free_position_indices(
		anchor_id,
		mover.definition.battler_id
	)
	if free_positions.is_empty():
		return -1
	var best_position: int = free_positions[0]
	var best_threat_count := _get_reactors_threatening_position(
		mover,
		anchor_id,
		best_position
	).size()
	for position_index: int in free_positions:
		var threat_count := _get_reactors_threatening_position(
			mover,
			anchor_id,
			position_index
		).size()
		if (
			threat_count < best_threat_count
			or (
				threat_count == best_threat_count
				and position_index < best_position
			)
		):
			best_position = position_index
			best_threat_count = threat_count
	return best_position


func _validate_mover(
	mover: BattlerState
) -> String:
	if mover == null or mover.definition == null:
		return "No valid mover is selected."
	if battlefield_state == null:
		return "BattlefieldState is missing."
	if battle_flow_controller == null:
		return "BattleFlowController is missing."
	if runtime == null:
		return "Battle runtime state is missing."

	var phase_error: String = (
		battle_flow_controller.validate_active_actor(mover)
	)
	if not phase_error.is_empty():
		return phase_error
	if mover.is_defeated:
		return "%s is defeated and cannot Move." % (
			mover.definition.display_name
		)
	if mover.is_stunned():
		return "%s is Stunned and cannot Move." % (
			mover.definition.display_name
		)
	if mover.is_attached_grappler():
		return "%s is attached and cannot Move." % (
			mover.definition.display_name
		)
	if mover.is_grappled():
		return "%s is grappled and cannot Move." % (
			mover.definition.display_name
		)
	if mover.current_actions <= 0:
		return "%s has no Actions remaining." % (
			mover.definition.display_name
		)

	return ""


func _validate_committed_route(
	mover: BattlerState,
	preview: MovementPreview
) -> String:
	var maximum_steps: int = mover.get_move_step_limit()
	if preview.anchor_path.size() > maximum_steps + 1:
		return "%s may Move only %d Anchor step this Action." % [
			mover.definition.display_name,
			maximum_steps,
		]

	for step_index: int in range(
		1,
		preview.anchor_path.size()
	):
		var previous_anchor: AnchorDefinition = (
			battlefield_state.definition.get_anchor(
				preview.anchor_path[step_index - 1]
			)
		)
		var step_anchor_id: StringName = (
			preview.anchor_path[step_index]
		)
		if (
			previous_anchor == null
			or not previous_anchor.connected_anchor_ids.has(
				step_anchor_id
			)
		):
			return "The committed Move path is no longer connected."
		if not _can_traverse_anchor(mover, step_anchor_id):
			return "The committed Move path is now blocked."

	var current_free_positions: Array[int] = (
		battlefield_state.get_free_position_indices(
			preview.destination_anchor_id,
			preview.mover_id
		)
	)
	if battlefield_state.is_anchor_over_capacity(
		preview.destination_anchor_id
	):
		return "The destination Anchor is over capacity."
	if current_free_positions.is_empty():
		return "The destination Anchor is now full."

	return ""


func _can_traverse_anchor(
	mover: BattlerState,
	anchor_id: StringName
) -> bool:
	var anchor: AnchorDefinition = (
		battlefield_state.definition.get_anchor(anchor_id)
	)
	if anchor == null:
		return false
	if battlefield_state.is_anchor_over_capacity(anchor_id):
		return false

	var occupants: Array[StringName] = (
		battlefield_state.get_occupants(
			anchor_id,
			mover.definition.battler_id
		)
	)
	if occupants.size() < anchor.capacity:
		return true

	for occupant_id: StringName in occupants:
		var occupant: BattlerState = _get_battler_state(
			occupant_id
		)
		if _are_opponents(mover, occupant):
			return false

	# A full allied cluster is the one capacity exception: it may be
	# crossed, but _build_preview will not allow it as the destination.
	return true


func _can_make_move_reaction(
	reactor: BattlerState
) -> bool:
	if (
		reactor == null
		or reactor.definition == null
		or reactor.is_defeated
		or reactor.is_stunned()
		or reactor.is_attached_grappler()
		or reactor.current_actions <= 0
	):
		return false

	var weapon: WeaponDefinition = (
		reactor.get_usable_main_hand_weapon()
	)
	return (
		weapon != null
		and weapon.attack_range
		== WeaponDefinition.AttackRange.MELEE
	)


func _are_opponents(
	first: BattlerState,
	second: BattlerState
) -> bool:
	if (
		first == null
		or second == null
		or first.definition == null
		or second.definition == null
	):
		return false

	return (
		(
			first.definition.faction
			== BattlerDefinition.Faction.HEROINE
			and second.definition.faction
			== BattlerDefinition.Faction.ENEMY
		)
		or (
			first.definition.faction
			== BattlerDefinition.Faction.ENEMY
			and second.definition.faction
			== BattlerDefinition.Faction.HEROINE
		)
	)


func _get_battler_state(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(
		battler_id
	) as BattlerState


func _stop_active_move(
	reason: String
) -> String:
	if runtime != null and runtime.active_move != null:
		runtime.active_move.stopped_early = true
		runtime.active_move.stop_reason = reason
		runtime.active_move.is_complete = true

	return reason
