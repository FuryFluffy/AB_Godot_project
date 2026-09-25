class_name RoomEventDefinition
extends Resource


enum TargetRule {
	NONE,
	SELECTED_HEROINE,
}


@export_group("Identity")
@export var event_id: StringName = &""
@export var display_name: String = ""

@export_group("Interaction")
@export var hover_prompt: String = (
	"Click to interact"
)

@export var target_rule: TargetRule = (
	TargetRule.NONE
)

@export_group("Resolution")
@export var resolve_once: bool = true
@export var remove_on_resolve: bool = true

@export var outcomes: Array[RoomEventOutcomeDefinition] = []


func collect_validation_errors() -> Array[String]:
	var errors: Array[String] = []

	if event_id == &"":
		errors.append(
			"A room event requires an event_id."
		)

	if display_name.is_empty():
		errors.append(
			(
				"Room event '%s' requires "
				+ "a display name."
			)
			% event_id
		)

	if hover_prompt.is_empty():
		errors.append(
			(
				"Room event '%s' requires "
				+ "a hover prompt."
			)
			% event_id
		)

	if not resolve_once:
		errors.append(
			(
				"Room event '%s' is repeatable, "
				+ "but repeatable room events "
				+ "are not implemented yet."
			)
			% event_id
		)

	if outcomes.is_empty():
		errors.append(
			(
				"Room event '%s' has no outcomes."
			)
			% event_id
		)

	var seen_outcome_ids: Dictionary = {}
	var requires_target: bool = false

	for outcome_index: int in range(
		outcomes.size()
	):
		var outcome: RoomEventOutcomeDefinition = (
			outcomes[outcome_index]
		)

		var outcome_label: String = (
			"Room event '%s' outcome %d"
			% [
				event_id,
				outcome_index,
			]
		)

		if outcome == null:
			errors.append(
				"%s is null."
				% outcome_label
			)
			continue

		errors.append_array(
			outcome.collect_validation_errors(
				outcome_label
			)
		)

		if outcome.requires_heroine_target():
			requires_target = true

		if outcome.outcome_id == &"":
			continue

		if seen_outcome_ids.has(
			outcome.outcome_id
		):
			errors.append(
				(
					"Room event '%s' duplicates "
					+ "outcome_id '%s'."
				)
				% [
					event_id,
					outcome.outcome_id,
				]
			)
		else:
			seen_outcome_ids[
				outcome.outcome_id
			] = true

	if (
		requires_target
		and target_rule
		!= TargetRule.SELECTED_HEROINE
	):
		errors.append(
			(
				"Room event '%s' contains heroine "
				+ "effects but does not require "
				+ "a selected heroine."
			)
			% event_id
		)

	return errors


func validate_definition() -> String:
	var errors: Array[String] = (
		collect_validation_errors()
	)

	var lines := PackedStringArray()

	for error_message: String in errors:
		lines.append(
			error_message
		)

	return "\n".join(lines)
