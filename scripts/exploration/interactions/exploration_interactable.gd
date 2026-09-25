class_name ExplorationInteractable
extends Area2D


signal interaction_hover_changed(
	interactable: ExplorationInteractable,
	is_hovered: bool
)

signal interaction_activated(
	interactable: ExplorationInteractable
)


var interaction_enabled: bool = true
var _interaction_hovered: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not mouse_entered.is_connected(
		_on_interaction_mouse_entered
	):
		mouse_entered.connect(
			_on_interaction_mouse_entered
		)

	if not mouse_exited.is_connected(
		_on_interaction_mouse_exited
	):
		mouse_exited.connect(
			_on_interaction_mouse_exited
		)

	input_pickable = interaction_enabled


func set_interaction_enabled(
	new_enabled: bool
) -> void:
	interaction_enabled = new_enabled
	input_pickable = new_enabled

	if (
		not interaction_enabled
		and _interaction_hovered
	):
		_set_interaction_hovered(
			false
		)


func is_interaction_enabled() -> bool:
	return interaction_enabled


func can_interact() -> bool:
	return (
		interaction_enabled
		and visible
	)


func request_interaction() -> void:
	if not can_interact():
		return

	interaction_activated.emit(
		self
	)

	_interaction_requested()


func refresh_interaction_visual() -> void:
	_apply_hover_visual(
		_interaction_hovered
	)


func get_interaction_id() -> StringName:
	return &""


func get_interaction_display_name() -> String:
	return ""


func get_interaction_prompt() -> String:
	return ""


func _input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int
) -> void:
	if not can_interact():
		return

	if (
		event is InputEventMouseButton
		and event.button_index
		== MOUSE_BUTTON_LEFT
		and event.pressed
	):
		# Interaction callbacks may synchronously remove their room from the tree.
		# Acknowledge the supplied viewport before handing control to them.
		var input_viewport := _viewport as Viewport
		if input_viewport != null:
			input_viewport.set_input_as_handled()

		request_interaction()


func _on_interaction_mouse_entered() -> void:
	if not can_interact():
		return

	_set_interaction_hovered(
		true
	)


func _on_interaction_mouse_exited() -> void:
	if not _interaction_hovered:
		return

	_set_interaction_hovered(
		false
	)


func _set_interaction_hovered(
	is_hovered: bool
) -> void:
	_interaction_hovered = is_hovered

	_apply_hover_visual(
		is_hovered
	)

	interaction_hover_changed.emit(
		self,
		is_hovered
	)

	_interaction_hover_state_changed(
		is_hovered
	)


func _apply_hover_visual(
	is_hovered: bool
) -> void:
	var hover_visual: CanvasItem = (
		_get_hover_visual()
	)

	if hover_visual == null:
		return

	if is_hovered:
		hover_visual.modulate = (
			_get_hover_modulate()
		)
	else:
		hover_visual.modulate = (
			_get_idle_modulate()
		)


func _get_hover_visual() -> CanvasItem:
	return null


func _get_hover_modulate() -> Color:
	return Color(
		1.2,
		1.12,
		0.82,
		1.0
	)


func _get_idle_modulate() -> Color:
	return Color.WHITE


func _interaction_hover_state_changed(
	_is_hovered: bool
) -> void:
	pass


func _interaction_requested() -> void:
	pass
