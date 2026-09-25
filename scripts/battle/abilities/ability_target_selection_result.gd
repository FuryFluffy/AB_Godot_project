class_name AbilityTargetSelectionResult
extends RefCounted


var succeeded: bool = false
var error_message: String = ""
var selected_target_ids: Array[StringName] = []
var legal_target_ids: Array[StringName] = []
var remaining_target_count: int = 0


func fail(message: String) -> AbilityTargetSelectionResult:
	succeeded = false
	error_message = message
	return self
