class_name RoomRestHotspot
extends ExplorationInteractable
## Authored bed intent; all recovery and consumption belong to the run transaction.
signal rest_requested
@export var display_name: String = "Resting place"
var used: bool = false

func get_interaction_display_name() -> String:
	return display_name

func get_interaction_prompt() -> String:
	return "Rest already used" if used else "Click to preview this room's Rest offer"

func _interaction_requested() -> void:
	if not used:
		rest_requested.emit()
