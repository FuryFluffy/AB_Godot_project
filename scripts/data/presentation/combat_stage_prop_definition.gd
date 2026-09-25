@tool
class_name CombatStagePropDefinition
extends Resource


const ALLOWED_DEPTH_BANDS: Array[StringName] = [
	&"rear",
	&"mid",
	&"foreground",
]


@export_group("Identity")
@export var prop_id: StringName

@export_group("Artwork")
@export var rear_texture: Texture2D
@export var body_texture: Texture2D
@export var front_mask_texture: Texture2D

@export_group("Placement")
@export var position: Vector2
@export var scale: Vector2 = Vector2.ONE
@export var rotation_degrees: float = 0.0
@export var depth_band: StringName = &"mid"
@export var floor_anchor: Vector2 = Vector2(0.5, 1.0)
@export_range(-20, 20, 1) var z_order_bias: int = 0

@export_group("Rules Boundary")
@export var mechanical: bool = false
@export var battlefield_rule_id: StringName


func has_art() -> bool:
	return (
		rear_texture != null
		or body_texture != null
		or front_mask_texture != null
	)


func validate_definition() -> String:
	if prop_id == &"":
		return "A combat-stage prop has no prop_id."
	if not has_art():
		return "Combat-stage prop '%s' has no artwork." % prop_id
	if depth_band not in ALLOWED_DEPTH_BANDS:
		return "Combat-stage prop '%s' has invalid depth band '%s'." % [
			prop_id,
			depth_band,
		]
	if scale.x <= 0.0 or scale.y <= 0.0:
		return "Combat-stage prop '%s' requires positive scale." % prop_id
	if (
		floor_anchor.x < 0.0
		or floor_anchor.x > 1.0
		or floor_anchor.y < 0.0
		or floor_anchor.y > 1.0
	):
		return "Combat-stage prop '%s' has a non-normalized floor anchor." % prop_id
	if front_mask_texture != null and depth_band != &"foreground":
		return "Combat-stage prop '%s' has a front mask outside the foreground band." % prop_id
	if mechanical and battlefield_rule_id == &"":
		return "Mechanical prop '%s' has no matching battlefield rule ID." % prop_id
	if not mechanical and battlefield_rule_id != &"":
		return "Decorative prop '%s' must not claim a battlefield rule." % prop_id
	return ""
