class_name RoomEventSourceDefinition
extends Resource


@export_group("Identity")
@export var source_id: StringName = &""

@export_group("Order")
@export_range(-1000, 1000, 1)
var priority: int = 0

@export_group("Pool")
@export var pool: RoomEventPoolDefinition

@export_group("Draw Rules")
@export_range(0, 16, 1)
var minimum_draws: int = 0

@export_range(0, 16, 1)
var maximum_draws: int = 1

@export_range(0.0, 1.0, 0.01)
var activation_chance: float = 1.0

@export var allow_duplicate_entries: bool = false


func collect_validation_errors(
	source_label: String
) -> Array[String]:
	var errors: Array[String] = []

	if source_id == &"":
		errors.append(
			"%s requires a source_id."
			% source_label
		)

	if pool == null:
		errors.append(
			"%s has no event pool."
			% source_label
		)
	else:
		errors.append_array(
			pool.collect_validation_errors(
				"%s pool '%s'"
				% [
					source_label,
					pool.pool_id,
				]
			)
		)

	if minimum_draws < 0:
		errors.append(
			"%s has a negative minimum draw count."
			% source_label
		)

	if maximum_draws < minimum_draws:
		errors.append(
			(
				"%s has maximum_draws below "
				+ "minimum_draws."
			)
			% source_label
		)

	if (
		activation_chance < 0.0
		or activation_chance > 1.0
	):
		errors.append(
			"%s has an invalid activation chance."
			% source_label
		)

	return errors
