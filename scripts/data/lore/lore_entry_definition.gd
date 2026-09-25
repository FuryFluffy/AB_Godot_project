class_name LoreEntryDefinition
extends Resource

@export_group("Identity")
@export var lore_id: StringName = &""
@export var title: String = "Untitled Lore"

@export_group("Text")
@export_multiline var discovery_text: String = ""
@export_multiline var archive_text: String = ""


func validate_definition() -> String:
	if lore_id == &"":
		return "A LoreEntryDefinition has no lore_id"
		
	if title.is_empty():
		return "Lore entry '%s' has no title" % lore_id
		
	if discovery_text.is_empty():
		return "Lore entry '%s' has no discovery text" % lore_id
		
	return ""
