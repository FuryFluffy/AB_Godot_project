class_name RoomLootProfileDefinition
extends Resource


@export var profile_id: StringName = &""
@export var sources: Array[RoomLootSourceDefinition] = []


func get_entry(
	entry_id: StringName,
	source_id: StringName = &""
) -> RoomItemPoolEntryDefinition:
	for source: RoomLootSourceDefinition in sources:
		if source == null or source.pool == null:
			continue
		if source_id != &"" and source.source_id != source_id:
			continue

		var entry: RoomItemPoolEntryDefinition = (
			source.pool.get_entry(entry_id)
		)

		if entry != null:
			return entry

	return null


func collect_validation_errors() -> Array[String]:
	var errors: Array[String] = []

	if profile_id == &"":
		errors.append(
			"A room loot profile requires a profile_id."
		)

	if sources.is_empty():
		errors.append(
			"Room loot profile '%s' has no sources."
			% profile_id
		)

	var seen_source_ids: Dictionary = {}
	for source_index: int in range(
		sources.size()
	):
		var source: RoomLootSourceDefinition = (
			sources[source_index]
		)

		var source_label: String = (
			"Room loot profile '%s' source %d"
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
						"Room loot profile '%s' "
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

	return errors


func validate_definition() -> String:
	var errors: Array[String] = (
		collect_validation_errors()
	)

	var lines := PackedStringArray()

	for error_message: String in errors:
		lines.append(error_message)

	return "\n".join(lines)
