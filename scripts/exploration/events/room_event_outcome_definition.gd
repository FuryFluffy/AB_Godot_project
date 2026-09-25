class_name RoomEventOutcomeDefinition
extends Resource


@export var outcome_id: StringName = &""

@export_range(1, 100, 1)
var weight: int = 1

@export_multiline var message: String = ""

@export var effects: Array[RoomEventEffectDefinition] = []


func requires_heroine_target() -> bool:
	for effect: RoomEventEffectDefinition in effects:
		if (
			effect != null
			and effect.requires_heroine_target()
		):
			return true

	return false


func collect_validation_errors(
	outcome_label: String
) -> Array[String]:
	var errors: Array[String] = []

	if outcome_id == &"":
		errors.append(
			"%s has no outcome_id."
			% outcome_label
		)

	if weight <= 0:
		errors.append(
			"%s has an invalid weight."
			% outcome_label
		)

	if (
		message.is_empty()
		and effects.is_empty()
	):
		errors.append(
			(
				"%s has neither a message "
				+ "nor any effects."
			)
			% outcome_label
		)

	for effect_index: int in range(
		effects.size()
	):
		var effect: RoomEventEffectDefinition = (
			effects[effect_index]
		)

		var effect_label: String = (
			"%s effect %d"
			% [
				outcome_label,
				effect_index,
			]
		)

		if effect == null:
			errors.append(
				"%s is null."
				% effect_label
			)
			continue

		var effect_error: String = (
			effect.validate_definition(
				effect_label
			)
		)

		if not effect_error.is_empty():
			errors.append(
				effect_error
			)

	return errors
