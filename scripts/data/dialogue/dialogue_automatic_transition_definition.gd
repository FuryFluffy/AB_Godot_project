@tool
class_name DialogueAutomaticTransitionDefinition
extends Resource


@export var transition_id: StringName
@export var conditions: DialogueConditionGroup
@export var next_node_id: StringName
@export var outcomes: Array[DialogueOutcomeDefinition] = []


func is_available(context: DialogueContext) -> bool:
	return conditions == null or conditions.evaluate(context)


func validate_definition() -> String:
	if transition_id == &"":
		return "A dialogue automatic transition has no transition_id."
	if conditions != null:
		var condition_error: String = conditions.validate_definition()
		if not condition_error.is_empty():
			return condition_error
	for outcome: DialogueOutcomeDefinition in outcomes:
		if outcome == null:
			return (
				"Dialogue automatic transition '%s' contains a null outcome."
				% transition_id
			)
		var outcome_error: String = outcome.validate_definition()
		if not outcome_error.is_empty():
			return outcome_error
	return ""
