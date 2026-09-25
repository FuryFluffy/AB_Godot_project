class_name ItemCatalogDefinition
extends Resource


@export var items: Array[ItemDefinition] = []


func get_item(
	item_id: StringName
) -> ItemDefinition:
	for item: ItemDefinition in items:
		if item != null and item.item_id == item_id:
			return item
	return null


func get_items_for_layer(
	layer: int
) -> Array[ItemDefinition]:
	var matches: Array[ItemDefinition] = []
	for item: ItemDefinition in items:
		if item != null and item.layer == layer:
			matches.append(item)
	return matches


func validate_catalog() -> String:
	var seen_ids: Dictionary = {}
	for item: ItemDefinition in items:
		if item == null:
			return "The item catalog contains an empty entry."
		var definition_error: String = item.validate_definition()
		if not definition_error.is_empty():
			return definition_error
		if seen_ids.has(item.item_id):
			return "Duplicate item_id: %s." % item.item_id
		seen_ids[item.item_id] = true
	return ""

