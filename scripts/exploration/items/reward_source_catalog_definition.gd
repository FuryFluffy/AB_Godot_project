class_name RewardSourceCatalogDefinition
extends Resource


@export var sources: Array[RoomLootSourceDefinition] = []


func get_source(source_id: StringName) -> RoomLootSourceDefinition:
	for source: RoomLootSourceDefinition in sources:
		if source != null and source.source_id == source_id:
			return source
	return null


func collect_validation_errors(
	item_catalog: ItemCatalogDefinition
) -> Array[String]:
	var errors: Array[String] = []
	var seen_source_ids: Dictionary = {}
	for source_index: int in range(sources.size()):
		var source: RoomLootSourceDefinition = sources[source_index]
		if source == null:
			errors.append("Reward source catalog entry %d is null." % source_index)
			continue
		if seen_source_ids.has(source.source_id):
			errors.append("Duplicate reward source_id: '%s'." % source.source_id)
		else:
			seen_source_ids[source.source_id] = true
		errors.append_array(
			RewardSourceResolver.collect_validation_errors(
				source,
				item_catalog
			)
		)
	return errors


func validate_catalog(item_catalog: ItemCatalogDefinition) -> String:
	var lines := PackedStringArray()
	for error_message: String in collect_validation_errors(item_catalog):
		lines.append(error_message)
	return "\n".join(lines)
