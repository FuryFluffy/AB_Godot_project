class_name LayerMapView
extends Control


signal map_node_pressed(node_id: StringName)


const NODE_SIZE: Vector2 = Vector2(156.0, 66.0)
const LEFT_MARGIN: float = 42.0
const RIGHT_MARGIN: float = 42.0
const TOP_MARGIN: float = 54.0
const ROW_GAP: float = 26.0


var graph: LayerMapGraph
var run_state: RunState
var node_buttons: Dictionary = {}


func _ready() -> void:
	resized.connect(_on_resized)


func bind_map(
	new_graph: LayerMapGraph,
	new_run_state: RunState
) -> void:
	graph = new_graph
	run_state = new_run_state
	_rebuild_buttons()
	queue_redraw()


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
	if graph == null:
		return
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		for target_id: StringName in node.outgoing_ids:
			var target: MapNodeState = graph.get_map_node(target_id)
			if target == null:
				continue
			var color: Color = Color(0.31, 0.29, 0.25, 0.72)
			if node.cleared and target.visited:
				color = Color(0.66, 0.56, 0.35, 0.95)
			draw_line(
				_node_center(node),
				_node_center(target),
				color,
				4.0,
				true
			)


func _rebuild_buttons() -> void:
	for child: Node in get_children():
		child.queue_free()
	node_buttons.clear()
	if graph == null:
		return
	for column: int in range(graph.column_count):
		for node: MapNodeState in graph.get_nodes_in_column(column):
			var button: Button = Button.new()
			button.custom_minimum_size = NODE_SIZE
			button.size = NODE_SIZE
			button.position = _node_top_left(node)
			button.pressed.connect(
				_on_node_button_pressed.bind(node.node_id)
			)
			button.tooltip_text = (
				"%s\nStable ID: %s"
				% [node.display_name, node.node_id]
			)
			add_child(button)
			node_buttons[node.node_id] = button
			_configure_button(button, node)


func _configure_button(
	button: Button,
	node: MapNodeState
) -> void:
	var map_state: MapNodeState.MapState = (
		run_state.get_node_map_state(node.node_id)
	)
	var type_visible: bool = (
		map_state != MapNodeState.MapState.LOCKED
		or node.node_type == MapNodeState.NodeType.BOSS
	)
	var type_label: String = (
		node.get_type_label()
		if type_visible
		else "Unknown"
	)
	var state_label: String = _state_label(map_state)
	button.text = "%s\n%s" % [type_label, state_label]
	button.disabled = (
		map_state == MapNodeState.MapState.LOCKED
		and node.node_type != MapNodeState.NodeType.BOSS
	)
	match map_state:
		MapNodeState.MapState.AVAILABLE:
			button.modulate = Color(0.95, 0.86, 0.65, 1.0)
		MapNodeState.MapState.SELECTED:
			button.modulate = Color(1.0, 0.72, 0.35, 1.0)
		MapNodeState.MapState.VISITED:
			button.modulate = Color(0.72, 0.72, 0.68, 1.0)
		MapNodeState.MapState.CLEARED:
			button.modulate = Color(0.64, 0.82, 0.62, 1.0)
		_:
			button.modulate = Color(0.42, 0.42, 0.45, 0.82)


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


func _node_top_left(node: MapNodeState) -> Vector2:
	var width_available: float = maxf(
		size.x - LEFT_MARGIN - RIGHT_MARGIN - NODE_SIZE.x,
		1.0
	)
	var x: float = (
		LEFT_MARGIN
		+ width_available
		* float(node.column)
		/ float(maxi(graph.column_count - 1, 1))
	)
	var column_nodes: Array[MapNodeState] = (
		graph.get_nodes_in_column(node.column)
	)
	var total_height: float = (
		column_nodes.size() * NODE_SIZE.y
		+ maxi(column_nodes.size() - 1, 0) * ROW_GAP
	)
	var y_start: float = maxf(
		TOP_MARGIN,
		(size.y - total_height) * 0.5
	)
	return Vector2(
		x,
		y_start + node.row * (NODE_SIZE.y + ROW_GAP)
	)


func _node_center(node: MapNodeState) -> Vector2:
	return _node_top_left(node) + NODE_SIZE * 0.5


func _on_node_button_pressed(node_id: StringName) -> void:
	map_node_pressed.emit(node_id)


func _on_resized() -> void:
	if graph == null:
		return
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		var button: Button = node_buttons.get(node.node_id) as Button
		if button != null:
			button.position = _node_top_left(node)
	queue_redraw()
