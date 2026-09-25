@tool
class_name DialogueItemOptionDefinition
extends Resource


@export var item_id: StringName
@export var target_heroine_id: StringName
@export var next_node_id: StringName
@export var outcomes: Array[DialogueOutcomeDefinition] = []


func validate_definition() -> String:
	if item_id == &"":
		return "Dialogue item option has no item_id."
	for outcome: DialogueOutcomeDefinition in outcomes:
		if outcome == null:
			return "Dialogue item option contains a null outcome."
		var error: String = outcome.validate_definition()
		if not error.is_empty():
			return error
	return ""
