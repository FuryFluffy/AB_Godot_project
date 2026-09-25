class_name DialogueResult
extends RefCounted


var dialogue_id: StringName
var selected_choice_id: StringName
var selected_item_id: StringName
var selected_target_id: StringName
var outcomes: Array[DialogueOutcomeDefinition] = []
var entered_node_ids: Array[StringName] = []
var automatic_transition_ids: Array[StringName] = []
var current_node_id: StringName
var completed: bool = false
var session_snapshot: Dictionary = {}
var error_message: String = ""


func append_outcomes(
	new_outcomes: Array[DialogueOutcomeDefinition]
) -> void:
	for outcome: DialogueOutcomeDefinition in new_outcomes:
		if outcome != null:
			outcomes.append(outcome)


func to_snapshot() -> Dictionary:
	var outcome_snapshots: Array[Dictionary] = []
	for outcome: DialogueOutcomeDefinition in outcomes:
		outcome_snapshots.append(outcome.to_snapshot())
	return {
		"dialogue_id": String(dialogue_id),
		"selected_choice_id": String(selected_choice_id),
		"selected_item_id": String(selected_item_id),
		"selected_target_id": String(selected_target_id),
		"outcomes": outcome_snapshots,
		"entered_node_ids": _strings(entered_node_ids),
		"automatic_transition_ids": _strings(
			automatic_transition_ids
		),
		"current_node_id": String(current_node_id),
		"completed": completed,
		"session_snapshot": session_snapshot.duplicate(true),
		"error_message": error_message,
	}


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
