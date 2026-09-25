class_name RoomExitHotspot
extends ExplorationInteractable


signal exit_requested


@export_group("Interaction")
@export var display_name: String = "Exit"
@export var hover_prompt: String = "Click to leave"
@export var hover_visual_path: NodePath


var enabled: bool:
	get:
		return is_interaction_enabled()

	set(value):
		set_interaction_enabled(
			value
		)


func get_interaction_display_name() -> String:
	return display_name


func get_interaction_prompt() -> String:
	return hover_prompt


func _interaction_requested() -> void:
	exit_requested.emit()

func _get_hover_visual() -> CanvasItem:
	if hover_visual_path.is_empty():
		return null
		
	return get_node_or_null(
		hover_visual_path
	) as CanvasItem
