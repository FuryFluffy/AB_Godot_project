class_name RoomLootContainerHotspot
extends ExplorationInteractable
## Presentation and intent only. Contents/claims belong to the room instance.

signal contents_requested(container_id: StringName)

@export var container_id: StringName
@export var display_name: String = "Container"
@export var concealed: bool = false
@export var inspection_name: String = "Floorboards"
@export var required_lock_id: StringName
var revealed: bool = false
var exhausted: bool = false

func get_interaction_id() -> StringName:
	return container_id

func get_interaction_display_name() -> String:
	return inspection_name if concealed and not revealed else display_name

func get_interaction_prompt() -> String:
	if concealed and not revealed:
		return "Click to inspect"
	return "Empty" if exhausted else "Click to open"

func _interaction_requested() -> void:
	contents_requested.emit(container_id)
