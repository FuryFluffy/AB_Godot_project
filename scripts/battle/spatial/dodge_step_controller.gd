class_name DodgeStepController
extends RefCounted


var battler_states: Dictionary = {}
var battlefield_state: BattlefieldState


func initialize(
	new_battler_states: Dictionary,
	new_battlefield_state: BattlefieldState
) -> void:
	battler_states = new_battler_states
	battlefield_state = new_battlefield_state


func get_legal_destinations(
	defender_id: StringName,
	attacker_id: StringName
) -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []
	if battlefield_state == null or battlefield_state.definition == null:
		return destinations

	var defender_position: BattlerPositionState = (
		battlefield_state.get_battler_position(defender_id)
	)
	var attacker_position: BattlerPositionState = (
		battlefield_state.get_battler_position(attacker_id)
	)
	if defender_position == null:
		return destinations

	var origin: AnchorDefinition = battlefield_state.definition.get_anchor(
		defender_position.anchor_id
	)
	if origin == null:
		return destinations

	var candidate_anchor_ids: Array[StringName] = [origin.anchor_id]
	for connected_anchor_id: StringName in origin.connected_anchor_ids:
		candidate_anchor_ids.append(connected_anchor_id)
	for anchor_id: StringName in candidate_anchor_ids:
		for position_index: int in battlefield_state.get_free_position_indices(
			anchor_id,
			defender_id
		):
			if (
				anchor_id == defender_position.anchor_id
				and position_index == defender_position.position_index
			):
				continue
			if (
				attacker_position != null
				and battlefield_state.are_positions_adjacent(
					anchor_id,
					position_index,
					attacker_position.anchor_id,
					attacker_position.position_index
				)
			):
				continue
			destinations.append({
				"anchor_id": anchor_id,
				"position_index": position_index,
			})

	return destinations


func apply_step(
	defender_id: StringName,
	attacker_id: StringName,
	anchor_id: StringName,
	position_index: int
) -> String:
	for destination: Dictionary in get_legal_destinations(
		defender_id,
		attacker_id
	):
		if (
			destination.get("anchor_id", &"") == anchor_id
			and int(destination.get("position_index", -1))
			== position_index
		):
			return battlefield_state.place_battler(
				defender_id,
				anchor_id,
				position_index
			)
	return "That Position is not a legal defensive Dodge step."


func choose_ai_destination(
	defender_id: StringName,
	attacker_id: StringName
) -> Dictionary:
	var destinations: Array[Dictionary] = get_legal_destinations(
		defender_id,
		attacker_id
	)
	if destinations.is_empty():
		return {}

	var attacker_position: BattlerPositionState = (
		battlefield_state.get_battler_position(attacker_id)
	)
	var attacker_point := Vector2.ZERO
	if attacker_position != null:
		attacker_point = battlefield_state.get_world_position(attacker_id)

	var best: Dictionary = destinations[0]
	var best_distance: float = -1.0
	var best_key: String = ""
	for destination: Dictionary in destinations:
		var anchor_id := StringName(
			destination.get("anchor_id", &"")
		)
		var position_index := int(
			destination.get("position_index", -1)
		)
		var anchor := battlefield_state.definition.get_anchor(anchor_id)
		if anchor == null:
			continue
		var point := anchor.get_position_point(position_index)
		var distance := point.distance_squared_to(attacker_point)
		var stable_key := "%s:%04d" % [
			String(anchor_id),
			position_index,
		]
		if (
			distance > best_distance
			or (
				is_equal_approx(distance, best_distance)
				and (best_key.is_empty() or stable_key < best_key)
			)
		):
			best = destination
			best_distance = distance
			best_key = stable_key
	return best.duplicate(true)
