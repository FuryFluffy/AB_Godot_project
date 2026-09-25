class_name AbilityUseResult
extends RefCounted


var succeeded: bool = false
var error_message: String = ""
var caster_id: StringName = &""
var target_id: StringName = &""
var ability: AbilityDefinition
var action_spent: int = 0
var mp_spent: int = 0
var effect_amount: int = 0
var log_lines: Array[String] = []


func fail(message: String) -> AbilityUseResult:
	succeeded = false
	error_message = message
	return self


func append_log(message: String) -> void:
	if not message.is_empty():
		log_lines.append(message)
