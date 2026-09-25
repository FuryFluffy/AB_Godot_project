class_name RoomEventProfileDefinition
extends Resource


@export var profile_id: StringName = &""

@export var sources: Array[RoomEventSourceDefinition] = []


func get_entry(
	entry_id: StringName
) -> RoomEventPoolEntryDefinition:
	for source: RoomEventSourceDefinition in sources:
		if source == null or source.pool == null:
			continue

		var entry: RoomEventPoolEntryDefinition = (
			source.pool.get_entry(
				entry_id
			)
		)

		if entry != null:
			return entry

	return null


func collect_validation_errors() -> Array[String]:
	var errors: Array[String] = []

	if profile_id == &"":
		errors.append(
			"A room event profile requires a profile_id."
		)

	if sources.is_empty():
		errors.append(
			(
				"Room event profile '%s' "
				+ "contains no sources."
			)
			% profile_id
		)

	var seen_source_ids: Dictionary = {}
	var seen_entry_ids: Dictionary = {}

	for source_index: int in range(
		sources.size()
	):
		var source: RoomEventSourceDefinition = (
			sources[source_index]
		)

		var source_label: String = (
			"Room event profile '%s' source %d"
			% [
				profile_id,
				source_index,
			]
		)

		if source == null:
			errors.append(
				"%s is null."
				% source_label
			)
			continue

		errors.append_array(
			source.collect_validation_errors(
				source_label
			)
		)

		if source.source_id != &"":
			if seen_source_ids.has(
				source.source_id
			):
				errors.append(
					(
						"Room event profile '%s' "
						+ "duplicates source_id '%s'."
					)
					% [
						profile_id,
						source.source_id,
					]
				)
			else:
				seen_source_ids[
					source.source_id
				] = true

		if source.pool == null:
			continue

		for entry: RoomEventPoolEntryDefinition in (
			source.pool.entries
		):
			if entry == null or entry.entry_id == &"":
				continue

			if seen_entry_ids.has(
				entry.entry_id
			):
				errors.append(
					(
						"Room event profile '%s' "
						+ "contains entry_id '%s' "
						+ "in more than one source."
					)
					% [
						profile_id,
						entry.entry_id,
					]
				)
			else:
				seen_entry_ids[
					entry.entry_id
				] = true

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
