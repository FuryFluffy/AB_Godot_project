class_name FieldStationHotspot
extends ExplorationInteractable
signal station_requested
@export var display_name: String = "Production station"
func get_interaction_display_name() -> String:
	return display_name
func get_interaction_prompt() -> String:
	return "Open production · Run Materials → Backpack"
func _interaction_requested() -> void:
	station_requested.emit()
