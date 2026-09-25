class_name GeneratedRoomItemPlacementResult
extends RefCounted


var requests_by_node: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []


func succeeded() -> bool:
	return errors.is_empty()


func get_error_text() -> String:
	var lines := PackedStringArray()

	for error_message: String in errors:
		lines.append(error_message)

	return "\n".join(lines)


func get_warning_text() -> String:
	var lines := PackedStringArray()

	for warning_message: String in warnings:
		lines.append(warning_message)

	return "\n".join(lines)
