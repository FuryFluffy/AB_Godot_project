class_name DialogueSessionState
extends RefCounted


var dialogue_id: StringName
var current_node_id: StringName
var visited_node_ids: Array[StringName] = []
var selected_choice_ids: Array[StringName] = []
var applied_entry_outcome_node_ids: Array[StringName] = []
var triggered_automatic_transition_ids: Array[StringName] = []
var completed: bool = false


func to_snapshot() -> Dictionary:
	return {
		"dialogue_id": String(dialogue_id),
		"current_node_id": String(current_node_id),
		"visited_node_ids": _strings(visited_node_ids),
		"selected_choice_ids": _strings(selected_choice_ids),
		"applied_entry_outcome_node_ids": _strings(
			applied_entry_outcome_node_ids
		),
		"triggered_automatic_transition_ids": _strings(
			triggered_automatic_transition_ids
		),
		"completed": completed,
	}


static func from_snapshot(snapshot: Dictionary) -> DialogueSessionState:
	var state := DialogueSessionState.new()
	var validation_error: String = validate_snapshot(snapshot)
	if not validation_error.is_empty():
		return state
	state.dialogue_id = StringName(snapshot.get("dialogue_id", ""))
	state.current_node_id = StringName(snapshot.get("current_node_id", ""))
	state.visited_node_ids = _names(
		snapshot.get("visited_node_ids", []) as Array
	)
	state.selected_choice_ids = _names(
		snapshot.get("selected_choice_ids", []) as Array
	)
	state.applied_entry_outcome_node_ids = _names(
		snapshot.get("applied_entry_outcome_node_ids", []) as Array
	)
	state.triggered_automatic_transition_ids = _names(
		snapshot.get("triggered_automatic_transition_ids", []) as Array
	)
	state.completed = bool(snapshot.get("completed", false))
	return state


static func validate_snapshot(
	snapshot: Dictionary,
	expected_dialogue_id: StringName = &""
) -> String:
	var stored_dialogue_id := StringName(snapshot.get("dialogue_id", ""))
	if stored_dialogue_id == &"":
		return "Dialogue session snapshot has no dialogue_id."
	if expected_dialogue_id != &"" and stored_dialogue_id != expected_dialogue_id:
		return "Dialogue session snapshot has the wrong dialogue_id."
	var current_node_value: Variant = snapshot.get("current_node_id", "")
	if not (current_node_value is String or current_node_value is StringName):
		return "Dialogue session snapshot has an invalid current_node_id."
	if not (snapshot.get("completed", false) is bool):
		return "Dialogue session snapshot has an invalid completed flag."
	for field_name: String in [
		"visited_node_ids",
		"selected_choice_ids",
		"applied_entry_outcome_node_ids",
		"triggered_automatic_transition_ids",
	]:
		var values: Variant = snapshot.get(field_name, [])
		if not (values is Array):
			return "Dialogue session snapshot has invalid %s." % field_name
		for value: Variant in values as Array:
			if not (value is String or value is StringName):
				return "Dialogue session snapshot has an invalid %s entry." % field_name
	if bool(snapshot.get("completed", false)):
		if StringName(snapshot.get("current_node_id", "")) != &"":
			return "Completed dialogue session snapshot retains a current node."
	elif StringName(snapshot.get("current_node_id", "")) == &"":
		return "Active dialogue session snapshot has no current node."
	return ""


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(value))
	return result
