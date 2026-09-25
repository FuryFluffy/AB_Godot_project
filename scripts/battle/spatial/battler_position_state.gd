class_name BattlerPositionState
extends RefCounted


var battler_id: StringName
var anchor_id: StringName
var position_index: int = -1


func _init(
	new_battler_id: StringName = &"",
	new_anchor_id: StringName = &"",
	new_position_index: int = -1
) -> void:
	battler_id = new_battler_id
	anchor_id = new_anchor_id
	position_index = new_position_index
