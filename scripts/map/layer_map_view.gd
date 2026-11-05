class_name LayerMapView
extends Control


signal map_node_pressed(node_id: StringName)


const ART = preload("res://scripts/map/map_art_library.gd")
const NODE_SIZE: Vector2 = Vector2(88.0, 88.0)
const LEFT_MARGIN: float = 42.0
const RIGHT_MARGIN: float = 42.0
const TOP_MARGIN: float = 54.0
const ROW_GAP: float = 32.0
const MAX_ZOOM: float = 2.5
const ZOOM_STEP: float = 0.25


var graph: LayerMapGraph
var run_state: RunState
var node_buttons: Dictionary = {}
# Presentation only: never serialized or copied into graph/run state.
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var toolbar: HBoxContainer
var zoom_label: Label
var map_content: Control
var _dragging: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	map_content = Control.new()
	map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_content)
	toolbar = HBoxContainer.new()
	toolbar.position = Vector2(12, 8)
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)
	_add_control("−", "Zoom out", func() -> void: set_zoom(zoom - ZOOM_STEP, size * 0.5))
	zoom_label = Label.new()
	zoom_label.custom_minimum_size.x = 62
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(zoom_label)
	_add_control("+", "Zoom in", func() -> void: set_zoom(zoom + ZOOM_STEP, size * 0.5))
	_add_control("Fit map", "Show every room position", reset_view)
	_add_control("Current room", "Focus the current room without travelling", focus_current_room)
	toolbar.tooltip_text = "Mouse wheel: zoom • Middle drag: pan • Arrow keys: focus rooms • Enter: select"
	_update_transform()


func bind_map(
	new_graph: LayerMapGraph,
	new_run_state: RunState
) -> void:
	_dragging = false
	graph = new_graph
	zoom = 1.0
	pan = Vector2.ZERO
	run_state = new_run_state
	_rebuild_buttons()
	_update_transform()


func refresh() -> void:
	if graph == null or run_state == null:
		return
	for node_id_value: Variant in node_buttons.keys():
		var node_id: StringName = StringName(node_id_value)
		var button: Button = node_buttons[node_id] as Button
		var node: MapNodeState = graph.get_map_node(node_id)
		_configure_button(button, node)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(ART.texture("background"), _map_rect(), false)
	if graph == null:
		return
	draw_set_transform(pan, 0.0, Vector2.ONE * zoom)
	for route: Dictionary in visible_routes():
		var from: Vector2 = _node_center(graph.get_map_node(route.from))
		var to: Vector2 = _node_center(graph.get_map_node(route.to))
		var color := Color(0.66, 0.56, 0.35, 0.95) if route.visited else Color(0.76, 0.62, 0.37, 1.0)
		var direction: Vector2 = (to - from).normalized()
		var half_size: Vector2 = _node_size() * 0.5 + Vector2(4, 4)
		var trim: float = minf(half_size.x / maxf(absf(direction.x), 0.001), half_size.y / maxf(absf(direction.y), 0.001))
		draw_line(from + direction * trim, to - direction * trim, color, 3.0, true)
		if not route.unlocked:
			var center: Vector2 = (from + to) * 0.5
			_draw_asset(ART.texture("state_assets", "known_lock"), Rect2(center - Vector2(18, 18), Vector2(36, 36)))
	draw_set_transform(Vector2.ZERO)


func visible_routes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph == null:
		return result
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value
		for target: StringName in node.outgoing_ids:
			if graph.is_connection_known(node.node_id, target):
				result.append({"from": node.node_id, "to": target,
					"unlocked": graph.edge_states[graph.edge_id(node.node_id, target)].unlocked and not graph.edge_states[graph.edge_id(node.node_id, target)].hidden,
					"visited": node.visited and graph.get_map_node(target).visited})
	return result


func _rebuild_buttons() -> void:
	node_buttons.clear()
	for child: Node in map_content.get_children():
		map_content.remove_child(child)
		child.queue_free()
	if graph == null:
		return
	for column: int in range(graph.column_count):
		for node: MapNodeState in graph.get_nodes_in_column(column):
			var button: Button = Button.new()
			button.clip_text = true
			button.custom_minimum_size = _node_size()
			button.size = _node_size()
			button.position = _node_top_left(node)
			button.pressed.connect(
				_on_node_button_pressed.bind(node.node_id)
			)
			map_content.add_child(button)
			button.focus_entered.connect(_ensure_visible.bind(node.node_id))
			button.focus_entered.connect(refresh)
			button.focus_exited.connect(refresh)
			button.gui_input.connect(_node_input.bind(node.node_id))
			node_buttons[node.node_id] = button
			_configure_button(button, node)


func _configure_button(
	button: Button,
	node: MapNodeState
) -> void:
	var key: String = ART.node_key(node)
	button.set_meta("art_key", key)
	button.text = ""
	button.tooltip_text = node.display_name if node.type_known else "Unknown room"
	button.modulate = Color.WHITE
	button.disabled = false
	for style: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	if not button.has_node("Type"):
		_add_texture(button, "Current", ART.texture("state_assets", "current_bloom"), Vector2(-0.275, -0.275), Vector2(1.55, 1.55))
		_add_texture(button, "Type", ART.texture("node_assets", key), Vector2.ZERO, Vector2.ONE)
		_add_texture(button, "Visited", ART.texture("state_assets", "visited"), Vector2(-0.08, 0.78), Vector2(0.36, 0.36))
		_add_texture(button, "Solved", ART.texture("state_assets", "solved"), Vector2(0.75, 0.77), Vector2(0.38, 0.38))
		_add_texture(button, "RestUsed", ART.texture("state_assets", "rest_exhausted"), Vector2(-0.08, -0.12), Vector2(0.36, 0.36))
		_add_texture(button, "Selection", ART.texture("state_assets", "selection"), Vector2(-0.25, -0.25), Vector2(1.5, 1.5))
		_add_texture(button, "Focus", ART.texture("state_assets", "focus"), Vector2(-0.18, -0.18), Vector2(1.36, 1.36))
	(button.get_node("Type") as TextureRect).texture = ART.texture("node_assets", key)
	button.get_node("Current").visible = node.node_id == run_state.current_node_id
	button.get_node("Visited").visible = node.type_known and node.visited
	button.get_node("Solved").visible = node.type_known and node.solved
	button.get_node("RestUsed").visible = node.type_known and node.rest_used
	button.get_node("Selection").visible = node.node_id == run_state.selected_node_id
	button.get_node("Focus").visible = button.has_focus()
	if node.type_known:
		var states: PackedStringArray = []
		if node.node_id == run_state.current_node_id:
			states.append("Current room")
		if node.visited:
			states.append("Visited")
		if node.encounter_cleared:
			states.append("Encounter cleared")
		if node.solved:
			states.append("Solved")
		if node.rest_used:
			states.append("Rest used")
		if not states.is_empty():
			button.tooltip_text += "\n" + " • ".join(states)


func _add_texture(button: Button, name: String, texture: Texture2D, at: Vector2, extent: Vector2) -> void:
	var image := TextureRect.new()
	image.name = name
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.anchor_left = at.x
	image.anchor_top = at.y
	image.anchor_right = at.x + extent.x
	image.anchor_bottom = at.y + extent.y
	button.add_child(image)


func _draw_asset(texture: Texture2D, rect: Rect2) -> void:
	var extent: Vector2 = texture.get_size()
	extent *= minf(rect.size.x / extent.x, rect.size.y / extent.y)
	draw_texture_rect(texture, Rect2(rect.get_center() - extent * 0.5, extent), false)


func _map_rect() -> Rect2:
	var extent: Vector2 = ART.texture("background").get_size()
	extent *= minf(size.x / extent.x, size.y / extent.y)
	return Rect2((size - extent) * 0.5, extent)


func _safe_rect() -> Rect2:
	var map_rect: Rect2 = _map_rect()
	return Rect2(map_rect.position + map_rect.size * Vector2(0.12, 0.18), map_rect.size * Vector2(0.76, 0.64))


func _state_label(map_state: MapNodeState.MapState) -> String:
	match map_state:
		MapNodeState.MapState.AVAILABLE:
			return "Available"
		MapNodeState.MapState.SELECTED:
			return "Selected"
		MapNodeState.MapState.VISITED:
			return "Visited"
		MapNodeState.MapState.CLEARED:
			return "Cleared"
	return "Locked"


func _node_size() -> Vector2:
	var side: float = minf(NODE_SIZE.x, maxf(64.0, _safe_rect().size.x / maxi(graph.column_count, 1) - 12.0))
	return Vector2.ONE * side


func _node_top_left(node: MapNodeState) -> Vector2:
	var area: Rect2 = _safe_rect()
	var column_nodes: Array[MapNodeState] = graph.get_nodes_in_column(node.column)
	var gap: float = minf(_node_size().y + ROW_GAP, area.size.y / maxi(column_nodes.size(), 1))
	var x: float = area.position.x + (area.size.x - _node_size().x) * float(node.column) / maxi(graph.column_count - 1, 1)
	var y: float = area.get_center().y + (node.row - (column_nodes.size() - 1) * 0.5) * gap - _node_size().y * 0.5
	return Vector2(x, y)


func _node_center(node: MapNodeState) -> Vector2:
	return _node_top_left(node) + _node_size() * 0.5


func _on_node_button_pressed(node_id: StringName) -> void:
	map_node_pressed.emit(node_id)


func _on_resized() -> void:
	if graph == null:
		return
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		var button: Button = node_buttons.get(node.node_id) as Button
		if button != null:
			button.custom_minimum_size = _node_size()
			button.position = _node_top_left(node)
			button.size = _node_size()
	_update_transform()


func _add_control(text: String, hint: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	var icon_key: String = {"−": "zoom_out", "+": "zoom_in", "Current room": "recenter"}.get(text, "")
	if not icon_key.is_empty():
		button.icon = load(ART.ROOT + "map/controls/%s.png" % icon_key)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(44, 36)
	button.pressed.connect(callback)
	toolbar.add_child(button)


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_update_transform()


func set_zoom(value: float, anchor: Vector2) -> void:
	var next: float = clampf(value, 1.0, MAX_ZOOM)
	pan = anchor - (anchor - pan) * next / zoom
	zoom = next
	_update_transform()


func focus_current_room() -> void:
	if run_state == null:
		return
	var button: Button = node_buttons.get(run_state.current_node_id)
	if button != null:
		button.grab_focus()
		_ensure_visible(run_state.current_node_id)


func _update_transform() -> void:
	pan = pan.clamp(-size * (zoom - 1.0), Vector2.ZERO)
	if map_content != null:
		map_content.position = pan
		map_content.scale = Vector2.ONE * zoom
	if zoom_label != null:
		zoom_label.text = "%d%%" % roundi(zoom * 100)
	queue_redraw()


func _ensure_visible(node_id: StringName) -> void:
	var node: MapNodeState = graph.get_map_node(node_id)
	var rect := Rect2(_node_top_left(node) * zoom + pan, _node_size() * zoom)
	var viewport_rect := Rect2(Vector2(8, TOP_MARGIN), size - Vector2(16, TOP_MARGIN + 8))
	for axis: int in range(2):
		if rect.position[axis] < viewport_rect.position[axis]:
			pan[axis] += viewport_rect.position[axis] - rect.position[axis]
		elif rect.end[axis] > viewport_rect.end[axis]:
			pan[axis] -= rect.end[axis] - viewport_rect.end[axis]
	_update_transform()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_zoom(zoom + (ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else -ZOOM_STEP), get_local_mouse_position())
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if not event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			_dragging = false
			return
		pan += event.relative
		_update_transform()
		accept_event()


func _node_input(event: InputEvent, node_id: StringName) -> void:
	if event is InputEventMouse:
		if event is InputEventMouseMotion:
			event = event.duplicate()
			event.relative *= zoom
		_gui_input(event)
		return
	var direction := Vector2.ZERO
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		if event.is_action_pressed(action):
			direction = {&"ui_left": Vector2.LEFT, &"ui_right": Vector2.RIGHT, &"ui_up": Vector2.UP, &"ui_down": Vector2.DOWN}[action]
	if direction == Vector2.ZERO:
		return
	var origin: Vector2 = _node_center(graph.get_map_node(node_id))
	var nearest: Button
	var distance: float = INF
	for other_id: StringName in node_buttons:
		var delta: Vector2 = _node_center(graph.get_map_node(other_id)) - origin
		if delta.dot(direction) <= 1:
			continue
		var score: float = delta.length() + absf(delta.cross(direction)) * 2.0
		if score < distance:
			nearest = node_buttons[other_id]
			distance = score
	if nearest != null:
		nearest.grab_focus()
	accept_event()
