class_name RoomLootSourceDefinition
extends Resource


enum SourceChannel {
	MAP_ITEM_CACHE,
	ENCOUNTER_COMPLETION,
	EVENT_ROOM_HOTSPOT,
	FIXED_STORY,
	ROOM_COMPLETION,
}


@export_group("Identity")
@export var source_id: StringName = &""
@export var source_channel: SourceChannel = SourceChannel.EVENT_ROOM_HOTSPOT
@export var eligible_layers: Array[int] = []
@export var once_only: bool = true

@export_group("Order")
@export_range(-1000, 1000, 1)
var priority: int = 0

@export_group("Pool")
@export var pool: RoomItemPoolDefinition
@export var fixed_entry_id: StringName = &""

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

	if source_channel not in [
		SourceChannel.MAP_ITEM_CACHE,
		SourceChannel.ENCOUNTER_COMPLETION,
		SourceChannel.EVENT_ROOM_HOTSPOT,
		SourceChannel.FIXED_STORY,
		SourceChannel.ROOM_COMPLETION,
	]:
		errors.append(
			"%s has an invalid source channel."
			% source_label
		)

	if eligible_layers.is_empty():
		errors.append(
			"%s has no eligible layers."
			% source_label
		)
	var seen_layers: Dictionary = {}
	for layer_number: int in eligible_layers:
		if layer_number <= 0 or layer_number > 10:
			errors.append(
				"%s has invalid eligible layer %d."
				% [source_label, layer_number]
			)
		elif seen_layers.has(layer_number):
			errors.append(
				"%s duplicates eligible layer %d."
				% [source_label, layer_number]
			)
		seen_layers[layer_number] = true

	if pool == null:
		errors.append(
			"%s has no item pool."
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
		if fixed_entry_id != &"" and pool.get_entry(fixed_entry_id) == null:
			errors.append(
				"%s fixed entry '%s' is absent from its pool."
				% [source_label, fixed_entry_id]
			)

	if minimum_draws < 0:
		errors.append(
			"%s has a negative minimum draw count."
			% source_label
		)

	if maximum_draws < minimum_draws:
		errors.append(
			(
				"%s has a maximum draw count "
				+ "below its minimum."
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


func validate_definition() -> String:
	var errors: Array[String] = collect_validation_errors(
		"Reward source '%s'" % source_id
	)
	var lines := PackedStringArray()
	for error_message: String in errors:
		lines.append(error_message)
	return "\n".join(lines)
