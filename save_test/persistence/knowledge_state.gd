class_name KnowledgeState
extends RefCounted

const SAVE_PATH: String = "user://abyssal_bloom_knowledge_v1.json"


var discovered_entries: Dictionary = {}


func load_from_disk() -> String:
	discovered_entries.clear()

	if not FileAccess.file_exists(SAVE_PATH):
		return ""

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		return "Could not open knowledge save file."

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)

	if not (parsed is Dictionary):
		return "Knowledge save file is invalid."

	var data := parsed as Dictionary
	var stored_entries: Variant = data.get(
		"discovered_entries",
		[]
	)

	if not (stored_entries is Array):
		return "Knowledge save file has invalid entry data."

	for entry_value: Variant in stored_entries:
		var entry_id: String = String(entry_value)

		if not entry_id.is_empty():
			discovered_entries[entry_id] = true

	return ""


func save_to_disk() -> String:
	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return "Could not write the knowledge save file."

	var data: Dictionary = {
		"discovered_entries": discovered_entries.keys()
	}

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return ""


func to_snapshot() -> Dictionary:
	return {
		"discovered_entries": discovered_entries.keys()
	}


func restore_from_snapshot(snapshot: Dictionary) -> String:
	var stored_entries: Variant = snapshot.get("discovered_entries", [])
	if not (stored_entries is Array):
		return "Knowledge snapshot has invalid entry data."
	var restored: Dictionary = {}
	for entry_value: Variant in stored_entries:
		var entry_id: String = String(entry_value)
		if not entry_id.is_empty():
			restored[entry_id] = true
	discovered_entries = restored
	return ""


func has_entry(
	lore_id: StringName
) -> bool:
	return bool(
		discovered_entries.get(
			String(lore_id),
			false
		)
	)


func discover_entry(
	lore_id: StringName
) -> String:
	if lore_id == &"":
		return "Lore discovery requires a stable lore_id."

	if has_entry(lore_id):
		return ""

	discovered_entries[String(lore_id)] = true
	return save_to_disk()


func forget_all() -> String:
	discovered_entries.clear()
	return save_to_disk()
