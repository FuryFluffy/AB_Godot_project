@tool
class_name DialogueConditionGroup
extends Resource


enum Mode {
	ALL,
	ANY,
	NOT,
}


@export var mode: Mode = Mode.ALL
@export var conditions: Array[DialogueConditionDefinition] = []
@export var groups: Array[DialogueConditionGroup] = []


func evaluate(context: DialogueContext) -> bool:
	var values: Array[bool] = []

	for condition: DialogueConditionDefinition in conditions:
		if condition != null:
			values.append(condition.evaluate(context))

	for group: DialogueConditionGroup in groups:
		if group != null:
			values.append(group.evaluate(context))

	match mode:
		Mode.ALL:
			for value: bool in values:
				if not value:
					return false
			return true
		Mode.ANY:
			for value: bool in values:
				if value:
					return true
			return false
		Mode.NOT:
			return values.size() == 1 and not values[0]

	return false


func validate_definition() -> String:
	if mode == Mode.NOT and conditions.size() + groups.size() != 1:
		return "A NOT dialogue condition group must contain one entry."

	for condition: DialogueConditionDefinition in conditions:
		if condition == null:
			return "Dialogue condition group contains a null condition."
		var error: String = condition.validate_definition()
		if not error.is_empty():
			return error

	for group: DialogueConditionGroup in groups:
		if group == null:
			return "Dialogue condition group contains a null group."
		var error: String = group.validate_definition()
		if not error.is_empty():
			return error

	return ""
