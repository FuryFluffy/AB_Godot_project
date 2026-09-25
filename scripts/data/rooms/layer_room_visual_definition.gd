class_name LayerRoomVisualDefinition
extends Resource


enum PresentationUse {
	EXPLORATION = 1,
	BATTLE = 2,
	REFUGE = 4,
	STORY = 8,
}


@export_group("Identity")
@export var variant_id: StringName = &""
@export var display_name: String = ""

@export_group("Presentation")
@export_flags("Exploration", "Battle", "Refuge", "Story") var presentation_uses: int = (
	PresentationUse.EXPLORATION
)
@export var texture: Texture2D

@export_group("Art Status")
@export var art_pending: bool = false
@export_multiline var art_note: String = ""


func supports(use_flag: int) -> bool:
	return (presentation_uses & int(use_flag)) != 0


func validate_definition(room_id: StringName) -> String:
	if variant_id == &"":
		return "Room '%s' has a visual without a variant_id." % room_id
	if display_name.is_empty():
		return "Room '%s' visual '%s' has no display name." % [
			room_id,
			variant_id,
		]
	if presentation_uses == 0:
		return "Room '%s' visual '%s' has no presentation use." % [
			room_id,
			variant_id,
		]
	if art_pending and texture != null:
		return "Room '%s' visual '%s' is pending but has a texture." % [
			room_id,
			variant_id,
		]
	if not art_pending and texture == null:
		return "Room '%s' visual '%s' requires a texture." % [
			room_id,
			variant_id,
		]
	return ""
