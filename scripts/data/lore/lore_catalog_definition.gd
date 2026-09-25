class_name LoreCatalogDefinition
extends Resource

@export var entries: Array[LoreEntryDefinition] = []


func get_entry(
	lore_id: StringName
) -> LoreEntryDefinition:
	for entry: LoreEntryDefinition in entries:
		if entry != null and entry.lore_id == lore_id:
			return entry
			
	return null
	
func validate_definition() -> String:
	var seen_ids: Dictionary = {}
	
	for entry: LoreEntryDefinition in entries:
		if entry == null:
			return "Lore catalog contains null entry"
			
		var entry_error: String = entry.validate_definition()
		
		if not entry_error.is_empty():
			return entry_error
			
		if seen_ids.has(entry.lore_id):
			return "Duplicate ;pre entry ID: '%s'" % entry.lore_id
			
		seen_ids[entry.lore_id] = true
		
	return ""
			
		
