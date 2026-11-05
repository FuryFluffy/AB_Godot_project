class_name IntelCatalogDefinition
extends Resource

@export var options: Array[IntelOptionDefinition] = []

func get_option(id: StringName) -> IntelOptionDefinition:
	for option: IntelOptionDefinition in options:
		if option.option_id == id:
			return option
	return null

func validate_ids(raw: Variant, permanent: bool = false) -> String:
	if not raw is Array:
		return "Intel ownership must be an array."
	var seen: Dictionary = {}
	for value: Variant in raw:
		if not (value is String or value is StringName):
			return "Intel ownership contains an invalid ID."
		var option: IntelOptionDefinition = get_option(StringName(value))
		if option == null or not option.available or option.effect == IntelOptionDefinition.Effect.CONQUEROR_PASSAGE or (option.permanent_only and not permanent) or seen.has(String(value)):
			return "Intel ownership contains an unavailable or duplicate option."
		seen[String(value)] = true
	return ""
