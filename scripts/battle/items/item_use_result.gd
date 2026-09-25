class_name ItemUseResult
extends RefCounted


var succeeded: bool = false
var error_message: String = ""
var actor_id: StringName = &""
var target_id: StringName = &""
var slot_index: int = -1
var item: ItemDefinition
var actions_spent: int = 0
var quantity_consumed: int = 0
var requires_attack_resolution: bool = false
var log_lines: Array[String] = []


func fail(
	message: String
) -> ItemUseResult:
	succeeded = false
	error_message = message
	return self


func append_log(
	message: String
) -> void:
	if not message.is_empty():
		log_lines.append(message)

