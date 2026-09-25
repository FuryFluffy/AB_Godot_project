@tool
class_name BattlerVisualStateDefinition
extends Resource


const ALLOWED_POSE_KEYS: Array[StringName] = [
	&"idle",
	&"move",
	&"attack",
	&"cast",
	&"defend",
	&"block",
	&"hurt",
	&"defeated",
]
const ALLOWED_ORIENTATION_KEYS: Array[StringName] = [
	&"front",
	&"back",
]


@export_group("State")
@export var pose_key: StringName = &"idle"
@export var orientation_key: StringName = &"front"
@export var texture: Texture2D

@export_group("Corrections")
@export var offset_correction: Vector2 = Vector2.ZERO
@export var scale_correction: Vector2 = Vector2.ONE


func get_state_key() -> String:
	return "%s|%s" % [String(pose_key), String(orientation_key)]


func validate_definition() -> String:
	if pose_key not in ALLOWED_POSE_KEYS:
		return "Battler visual state has invalid pose '%s'." % pose_key
	if orientation_key not in ALLOWED_ORIENTATION_KEYS:
		return (
			"Battler visual state has invalid orientation '%s'."
			% orientation_key
		)
	if texture == null:
		return "Battler visual state '%s' has no texture." % get_state_key()
	if scale_correction.x <= 0.0 or scale_correction.y <= 0.0:
		return (
			"Battler visual state '%s' requires positive scale correction."
			% get_state_key()
		)
	return ""
