class_name RoomEncounterHotspot
extends ExplorationInteractable


signal encounter_requested(trigger_id: StringName)


@export_group("Identity")
@export var trigger_id: StringName

@export_group("Interaction")
@export var display_name: String = "Encounter"
@export var hover_prompt: String = "Click to proceed"
@export var hover_visual_path: NodePath


func validate_hotspot() -> String:
	if trigger_id == &"":
		return "A room encounter hotspot requires a trigger_id."
	return ""


func get_interaction_id() -> StringName:
	return trigger_id


func get_interaction_display_name() -> String:
	return display_name


func get_interaction_prompt() -> String:
	return hover_prompt


func _interaction_requested() -> void:
	encounter_requested.emit(trigger_id)


func _get_hover_visual() -> CanvasItem:
	if hover_visual_path.is_empty():
		return null
	return get_node_or_null(hover_visual_path) as CanvasItem
