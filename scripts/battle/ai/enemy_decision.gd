class_name EnemyDecision
extends RefCounted


enum Type {
	NONE,
	ATTACK,
	MOVE,
	GRAPPLE,
	GRAPPLE_HOLD,
	GRAPPLE_PROGRESS,
	ABILITY,
	WAIT,
}


var type: Type = Type.NONE
var actor_id: StringName = &""
var target_id: StringName = &""
var source_rule: EnemyRuleDefinition
var ability_id: StringName = &""

var move_preview: MovementPreview
var destination_position_index: int = -1

var summary: String = ""


func is_valid() -> bool:
	if actor_id == &"" or source_rule == null:
		return false

	match type:
		Type.ATTACK:
			return target_id != &""
		Type.MOVE:
			return (
				target_id != &""
				and move_preview != null
				and destination_position_index >= 0
			)
		Type.GRAPPLE:
			return target_id != &""
		Type.GRAPPLE_HOLD, Type.GRAPPLE_PROGRESS:
			return true
		Type.ABILITY:
			return target_id != &"" and ability_id != &""
		Type.WAIT:
			return true

	return false
