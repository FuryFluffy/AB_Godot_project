class_name RoomItemPoolDefinition
extends Resource


@export var pool_id: StringName = &""
@export var entries: Array[RoomItemPoolEntryDefinition] = []


func get_entry(
	entry_id: StringName
) -> RoomItemPoolEntryDefinition:
	for entry: RoomItemPoolEntryDefinition in entries:
		if (
			entry != null
			and entry.entry_id == entry_id
		):
			return entry

	return null


func collect_validation_errors(
	pool_label: String = "Room item pool"
) -> Array[String]:
	var errors: Array[String] = []

	if pool_id == &"":
		errors.append(
			"%s requires a pool_id."
			% pool_label
		)

	if entries.is_empty():
		errors.append(
			"%s has no entries."
			% pool_label
		)

	var seen_ids: Dictionary = {}

	for entry_index: int in range(
		entries.size()
	):
		var entry: RoomItemPoolEntryDefinition = (
			entries[entry_index]
		)

		var entry_label: String = (
			"%s entry %d"
			% [
				pool_label,
				entry_index,
			]
		)

		if entry == null:
			errors.append(
				"%s is empty."
				% entry_label
			)
			continue

		var entry_error: String = (
			entry.validate_definition()
		)

		if not entry_error.is_empty():
			errors.append(entry_error)

		if entry.entry_id == &"":
			continue

		if seen_ids.has(entry.entry_id):
			errors.append(
				"Duplicate room item-pool entry: '%s'."
				% entry.entry_id
			)
		else:
			seen_ids[entry.entry_id] = true

	return errors


func validate_definition() -> String:
	var errors: Array[String] = (
		collect_validation_errors(
			"Room item pool '%s'"
			% pool_id
		)
	)

	var lines := PackedStringArray()

	for error_message: String in errors:
		lines.append(error_message)

	return "\n".join(lines)
