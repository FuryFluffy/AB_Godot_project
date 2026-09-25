class_name AttackTargetingResult
extends RefCounted


var is_legal: bool = false
var error_message: String = ""

var spatial_range: BattlefieldState.SpatialRange = (
	BattlefieldState.SpatialRange.BEYOND
)
var spatial_range_label: String = "Beyond"

var has_line_of_sight: bool = true
var blocked_by_cover: bool = false
var blocking_terrain_names: Array[String] = []

var attack_dice_modifier: int = 0
var suppress_skill_modification: bool = false


func allow() -> AttackTargetingResult:
	is_legal = true
	error_message = ""
	return self


func deny(message: String) -> AttackTargetingResult:
	is_legal = false
	error_message = message
	return self
