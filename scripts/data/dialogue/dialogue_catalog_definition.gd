@tool
class_name DialogueCatalogDefinition
extends Resource


@export var dialogues: Array[DialogueDefinition] = []


func get_dialogue(dialogue_id: StringName) -> DialogueDefinition:
	for dialogue: DialogueDefinition in dialogues:
		if dialogue != null and dialogue.dialogue_id == dialogue_id:
			return dialogue
	return null


func get_triggered_dialogue(
	trigger_kind: StringName,
	trigger_id: StringName
) -> DialogueDefinition:
	for dialogue: DialogueDefinition in dialogues:
		if dialogue != null and dialogue.matches_trigger(trigger_kind, trigger_id):
			return dialogue
	return null


func validate_definition() -> String:
	if dialogues.is_empty():
		return "The production dialogue catalog is empty."
	var dialogue_ids: Dictionary = {}
	var trigger_keys: Dictionary = {}
	for dialogue: DialogueDefinition in dialogues:
		if dialogue == null:
			return "The production dialogue catalog contains an empty graph."
		var dialogue_error: String = dialogue.validate_definition()
		if not dialogue_error.is_empty():
			return dialogue_error
		if (
			dialogue.trigger_kind == &""
			or dialogue.trigger_id == &""
			or dialogue.completion_kind == &""
			or dialogue.completion_id == &""
		):
			return "Production dialogue '%s' has no complete binding." % dialogue.dialogue_id
		if dialogue.trigger_kind == &"development":
			return "Development dialogue cannot enter the production catalog."
		if dialogue_ids.has(dialogue.dialogue_id):
			return "The production dialogue catalog repeats '%s'." % dialogue.dialogue_id
		dialogue_ids[dialogue.dialogue_id] = true
		var trigger_key: String = "%s|%s" % [
			String(dialogue.trigger_kind),
			String(dialogue.trigger_id),
		]
		if trigger_keys.has(trigger_key):
			return "The production dialogue catalog repeats trigger '%s'." % trigger_key
		trigger_keys[trigger_key] = true
	return ""
