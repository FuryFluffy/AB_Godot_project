@tool
class_name DialogueChoiceDefinition
extends Resource


enum FailedConditionPresentation {
	HIDE,
	DISABLE,
}


@export var choice_id: StringName
@export_multiline var text: String
@export var responder_id: StringName
@export var conditions: DialogueConditionGroup
@export var failed_condition_presentation: FailedConditionPresentation = (
	FailedConditionPresentation.HIDE
)
@export var unavailable_reason: String = "Requirements not met."
@export var next_node_id: StringName
@export var outcomes: Array[DialogueOutcomeDefinition] = []


func is_available(context: DialogueContext) -> bool:
	return conditions == null or conditions.evaluate(context)


func validate_definition() -> String:
	if choice_id == &"":
		return "A dialogue choice has no choice_id."
	if text.strip_edges().is_empty():
		return "Dialogue choice '%s' has no text." % choice_id
	if conditions != null:
		var condition_error: String = conditions.validate_definition()
		if not condition_error.is_empty():
			return condition_error
	for outcome: DialogueOutcomeDefinition in outcomes:
		if outcome == null:
			return "Dialogue choice '%s' contains a null outcome." % choice_id
		var outcome_error: String = outcome.validate_definition()
		if not outcome_error.is_empty():
			return outcome_error
	return ""
