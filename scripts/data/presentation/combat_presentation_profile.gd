@tool
class_name CombatPresentationProfile
extends Resource

## Optional visual treatment. Does not define combat ranges, movement or damage.
@export var hud_scene: PackedScene
@export_range(0.0, 300.0) var reserved_bottom_height: float = 0.0
@export var cinematic_camera_enabled: bool = true
@export_range(1.0, 1.2, 0.01) var camera_zoom: float = 1.12
@export var smooth_movement_enabled: bool = true
@export_range(0.1, 1.0, 0.01) var movement_seconds: float = 0.42
@export var contact_shadows_enabled: bool = true
@export var effects_enabled: bool = true
@export var light_arrow_ability_id: StringName = &"seraphine_light_arrow"


func validate_definition() -> String:
	if camera_zoom < 1.0 or camera_zoom > 1.2:
		return "Presentation camera zoom must be between 1.0 and 1.2."
	if movement_seconds < 0.1 or movement_seconds > 1.0:
		return "Presentation movement duration must be between 0.1 and 1.0 seconds."
	return ""
