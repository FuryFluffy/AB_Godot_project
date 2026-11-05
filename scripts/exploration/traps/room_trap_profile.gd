class_name RoomTrapProfile
extends Resource

@export var profile_id: StringName
@export var minimum_traps: int = 0
@export var maximum_traps: int = 0
@export var definitions: Array[RoomTrapDefinition] = []

func validate_definition() -> String:
	if profile_id == &"" or minimum_traps < 1 or maximum_traps < minimum_traps:
		return "Trap profile requires an ID and authored positive counts."
	if definitions.is_empty():
		return "Trap profile requires an authored effect pool."
	var ids: Dictionary = {}
	for definition: RoomTrapDefinition in definitions:
		if definition == null:
			return "Trap profile has an empty definition."
		var error: String = definition.validate_definition()
		if not error.is_empty():
			return error
		if ids.has(definition.trap_id):
			return "Trap profile repeats an identity."
		ids[definition.trap_id] = true
	return ""
