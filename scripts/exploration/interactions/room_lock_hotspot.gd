class_name RoomLockHotspot
extends ExplorationInteractable


signal interaction_requested(lock_id: StringName)


@export_group("Identity")
@export var lock_id: StringName = &""
@export var required_item_id: StringName = &"shared_rusty_key"

@export_group("Messages")
@export_multiline var locked_message: String = (
	"The door is locked. The lock looks rusty."
)
@export_multiline var wrong_item_message: String = (
	"The selected item does not fit the rusty lock."
)
@export_multiline var success_message: String = (
	"The key shattered, but the door is unlocked."
)
@export var display_name: String = "Locked Door"
@export var hover_prompt: String = "Click to inspect"

@export_group("Behaviour")
@export var consume_required_item: bool = true

@export_group("Presentation")
@export var closed_visual_path: NodePath
@export var open_visual_path: NodePath
@export var exit_hotspot_path: NodePath


var is_unlocked: bool = false


func validate_lock() -> String:
	if lock_id == &"":
		return "A room lock requires a stable lock_id."

	if required_item_id == &"":
		return "Room lock '%s' has no required item." % lock_id

	if get_node_or_null(closed_visual_path) == null:
		return (
			"Room lock '%s' cannot find its closed visual."
			% lock_id
		)

	if get_node_or_null(open_visual_path) == null:
		return (
			"Room lock '%s' cannot find its open visual."
			% lock_id
		)

	if not (
		get_node_or_null(exit_hotspot_path)
		is RoomExitHotspot
	):
		return (
			"Room lock '%s' cannot find its exit hotspot."
			% lock_id
		)

	return ""


func apply_unlocked_state(
	new_is_unlocked: bool
) -> void:
	is_unlocked = new_is_unlocked

	var closed_visual := get_node_or_null(
		closed_visual_path
	) as CanvasItem

	var open_visual := get_node_or_null(
		open_visual_path
	) as CanvasItem

	var exit_hotspot := get_node_or_null(
		exit_hotspot_path
	) as RoomExitHotspot

	if closed_visual != null:
		closed_visual.visible = not is_unlocked

	if open_visual != null:
		open_visual.visible = is_unlocked

	if exit_hotspot != null:
		exit_hotspot.enabled = is_unlocked

	set_interaction_enabled(not is_unlocked)


func get_exit_hotspot() -> RoomExitHotspot:
	return get_node_or_null(
		exit_hotspot_path
	) as RoomExitHotspot

func get_interaction_id() -> StringName:
	return lock_id


func get_interaction_display_name() -> String:
	return display_name


func get_interaction_prompt() -> String:
	return hover_prompt


func _interaction_requested() -> void:
	if is_unlocked:
		return

	interaction_requested.emit(
		lock_id
	)
func _get_hover_visual() -> CanvasItem:
	if closed_visual_path.is_empty():
		return null

	return get_node_or_null(
		closed_visual_path
	) as CanvasItem
