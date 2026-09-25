class_name CommittedMoveState
extends RefCounted


var is_valid: bool = false
var error_message: String = ""

var mover_id: StringName = &""
var anchor_path: Array[StringName] = []
var destination_anchor_id: StringName = &""
var destination_position_index: int = -1

# Index inside anchor_path. Index 0 is the starting Anchor.
var current_path_index: int = 0

var action_was_spent: bool = false
var reaction_opportunity_used: bool = false
var reaction_attacker_id: StringName = &""
var reaction_attacker_ids: Array[StringName] = []
var reaction_processed_ids: Array[StringName] = []
# The path index whose newly reached Anchor is still offering reactions.
# -1 means every eligible combatant at that step has reacted or declined.
var reaction_anchor_path_index: int = -1

var is_complete: bool = false
var stopped_early: bool = false
var stop_reason: String = ""


func has_next_step() -> bool:
	return (
		is_valid
		and not is_complete
		and current_path_index + 1 < anchor_path.size()
	)


func get_current_anchor_id() -> StringName:
	if (
		current_path_index < 0
		or current_path_index >= anchor_path.size()
	):
		return &""

	return anchor_path[current_path_index]


func get_next_anchor_id() -> StringName:
	if not has_next_step():
		return &""

	return anchor_path[current_path_index + 1]


func is_next_step_final() -> bool:
	return (
		has_next_step()
		and current_path_index + 1
		== anchor_path.size() - 1
	)


func fail(message: String) -> CommittedMoveState:
	is_valid = false
	error_message = message
	return self
