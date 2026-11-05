class_name EventRoomDefinition
extends Resource


@export_group("Identity")
@export var room_id: StringName = &""
@export var display_name: String = ""

@export_group("Presentation")
@export var presentation_scene: PackedScene
@export var presentation_texture: Texture2D
@export var fitted_source_size: Vector2 = Vector2.ZERO

@export_group("Loot")
@export var loot_profile: RoomLootProfileDefinition
@export var solve_when_loot_exhausted: bool = false
# For authored rooms whose only content-completion condition is their open exit.
@export var solve_on_exit: bool = false
@export var field_station: FieldStationDefinition
@export var trap_profile: RoomTrapProfile

@export_group("Events")
@export var event_profile: RoomEventProfileDefinition

@export_group("Dialogue")
@export var entry_dialogue: DialogueDefinition

# Temporary migration field. Clear this in every room
# after assigning loot_profile.
@export var item_pool: RoomItemPoolDefinition


func validate_definition() -> String:
	if trap_profile != null:
		var trap_error: String = trap_profile.validate_definition()
		if not trap_error.is_empty():
			return trap_error
		if loot_profile == null:
			return "Trap profile requires authored item contents."
	if fitted_source_size != Vector2.ZERO and (fitted_source_size.x <= 0.0 or fitted_source_size.y <= 0.0):
		return "Room presentation requires two positive source dimensions."
	if solve_when_loot_exhausted and loot_profile == null:
		return "Loot completion requires an authored loot profile."
	if room_id == &"":
		return "Event room requires a stable room_id."

	if display_name.is_empty():
		return (
			"Event room '%s' requires a display name."
			% room_id
		)

	if presentation_scene == null:
		return (
			"Event room '%s' requires a presentation scene."
			% room_id
		)

	if (
		loot_profile != null
		and item_pool != null
	):
		return (
			"Event room '%s' has both loot_profile "
			+ "and legacy item_pool assigned."
		) % room_id

	if item_pool != null:
		return (
			"Event room '%s' still uses the legacy "
			+ "item_pool field."
		) % room_id

	if loot_profile != null:
		var profile_error: String = (
			loot_profile.validate_definition()
		)

		if not profile_error.is_empty():
			return profile_error
	if event_profile != null:
		var event_profile_error: String = (
			event_profile.validate_definition()
		)
		
		if not event_profile_error.is_empty():
			return event_profile_error
	if entry_dialogue != null:
		var dialogue_error: String = entry_dialogue.validate_definition()
		if not dialogue_error.is_empty():
			return dialogue_error
		if not entry_dialogue.matches_trigger(&"event_room_entry", room_id):
			return (
				"Event room '%s' has a dialogue bound to the wrong trigger."
				% room_id
			)
			
	return ""
