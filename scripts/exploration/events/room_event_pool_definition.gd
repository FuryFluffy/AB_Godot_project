class_name RoomEventPoolDefinition
extends Resource


@export var pool_id: StringName = &""

@export var entries: Array[RoomEventPoolEntryDefinition] = []


func get_entry(
	entry_id: StringName
) -> RoomEventPoolEntryDefinition:
	for entry: RoomEventPoolEntryDefinition in entries:
		if (
			entry != null
			and entry.entry_id == entry_id
		):
			return entry

	return null


func collect_validation_errors(
	pool_label: String
) -> Array[String]:
	var errors: Array[String] = []

	if pool_id == &"":
		errors.append(
			"%s requires a pool_id."
			% pool_label
		)

	if entries.is_empty():
		errors.append(
			"%s contains no event entries."
			% pool_label
		)

	var seen_entry_ids: Dictionary = {}

	for entry_index: int in range(
		entries.size()
	):
		var entry: RoomEventPoolEntryDefinition = (
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
				"%s is null."
				% entry_label
			)
			continue

		errors.append_array(
			entry.collect_validation_errors(
				entry_label
			)
		)

		if entry.entry_id == &"":
			continue

		if seen_entry_ids.has(
			entry.entry_id
		):
			errors.append(
				(
					"%s duplicates entry_id '%s'."
				)
				% [
					pool_label,
					entry.entry_id,
				]
			)
		else:
			seen_entry_ids[
				entry.entry_id
			] = true

	return errors
