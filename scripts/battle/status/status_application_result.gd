class_name StatusApplicationResult
extends RefCounted


var succeeded: bool = false
var replaced_existing: bool = false
var error_message: String = ""
var instance: StatusInstance


func fail(message: String) -> StatusApplicationResult:
	succeeded = false
	error_message = message
	return self

