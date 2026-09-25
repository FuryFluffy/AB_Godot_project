class_name MultiTargetAttackState
extends RefCounted


var is_valid: bool = false
var error_message: String = ""
var caster_id: StringName = &""
var ability: AbilityDefinition
var attack_profile: WeaponDefinition
var target_ids: Array[StringName] = []
var next_target_index: int = 0
var current_target_id: StringName = &""
var mp_was_spent: bool = false


func fail(message: String) -> MultiTargetAttackState:
	is_valid = false
	error_message = message
	return self


func has_remaining_targets() -> bool:
	return next_target_index < target_ids.size()


func get_next_target_id() -> StringName:
	if not has_remaining_targets():
		return &""
	return target_ids[next_target_index]


func mark_current_target_complete() -> void:
	if current_target_id == &"":
		return
	next_target_index += 1
	current_target_id = &""
