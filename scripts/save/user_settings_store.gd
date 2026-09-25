class_name UserSettingsStore
extends RefCounted


const SETTINGS_PATH: String = "user://abyssal_bloom_settings.json"
const SETTINGS_VERSION: int = 1


static func default_settings() -> Dictionary:
	return {
		"settings_version": SETTINGS_VERSION,
		"master_volume": 0.8,
		"fullscreen": false,
	}


static func load_settings() -> Dictionary:
	var settings: Dictionary = default_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return settings
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return settings
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return settings
	var document := parsed as Dictionary
	if int(document.get("settings_version", -1)) != SETTINGS_VERSION:
		return settings
	settings["master_volume"] = clampf(
		float(document.get("master_volume", 0.8)),
		0.0,
		1.0
	)
	settings["fullscreen"] = bool(document.get("fullscreen", false))
	return settings


static func save_settings(settings: Dictionary) -> String:
	var sanitized: Dictionary = default_settings()
	sanitized["master_volume"] = clampf(
		float(settings.get("master_volume", 0.8)),
		0.0,
		1.0
	)
	sanitized["fullscreen"] = bool(settings.get("fullscreen", false))
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return "Could not save settings."
	file.store_string(JSON.stringify(sanitized, "\t"))
	file.close()
	apply_settings(sanitized)
	return ""


static func apply_settings(settings: Dictionary) -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var volume: float = clampf(
			float(settings.get("master_volume", 0.8)),
			0.0,
			1.0
		)
		AudioServer.set_bus_mute(master_bus, volume <= 0.001)
		if volume > 0.001:
			AudioServer.set_bus_volume_db(master_bus, linear_to_db(volume))
	if not OS.has_feature("web"):
		var desired_mode: int = (
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if bool(settings.get("fullscreen", false))
			else DisplayServer.WINDOW_MODE_WINDOWED
		)
		if DisplayServer.window_get_mode() != desired_mode:
			DisplayServer.window_set_mode(desired_mode)
