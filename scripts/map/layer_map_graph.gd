class_name LayerMapGraph
extends RefCounted


var layer_id: StringName = &"layer_1"
var layer_number: int = 1
var display_name: String = "Layer 1 — Lower Castle Route"
var run_seed: int = 0
var column_count: int = 7
var nodes: Dictionary = {}
var start_node_id: StringName = &""
var boss_node_id: StringName = &""


func to_snapshot() -> Dictionary:
	var serialized_nodes: Array[Dictionary] = []
	var node_ids: Array[StringName] = []
	for value: Variant in nodes.keys():
		node_ids.append(StringName(value))
	node_ids.sort()
	for node_id: StringName in node_ids:
		var node: MapNodeState = get_map_node(node_id)
		if node != null:
			serialized_nodes.append(node.to_snapshot())
	return {
		"layer_id": String(layer_id),
		"layer_number": layer_number,
		"display_name": display_name,
		"run_seed": run_seed,
		"column_count": column_count,
		"start_node_id": String(start_node_id),
		"boss_node_id": String(boss_node_id),
		"nodes": serialized_nodes,
	}


static func from_snapshot(snapshot: Dictionary) -> Dictionary:
	var restored_layer_id := StringName(snapshot.get("layer_id", ""))
	var nodes_value: Variant = snapshot.get("nodes", null)
	if restored_layer_id == &"" or not (nodes_value is Array):
		return {"error": "Active-run map snapshot has an invalid layer or node list.", "graph": null}
	var restored := LayerMapGraph.new()
	restored.layer_id = restored_layer_id
	restored.layer_number = int(snapshot.get("layer_number", 0))
	restored.display_name = String(snapshot.get("display_name", ""))
	restored.run_seed = int(snapshot.get("run_seed", 0))
	restored.column_count = int(snapshot.get("column_count", 0))
	restored.start_node_id = StringName(snapshot.get("start_node_id", ""))
	restored.boss_node_id = StringName(snapshot.get("boss_node_id", ""))
	if restored.layer_number <= 0 or restored.run_seed <= 0 or restored.column_count <= 0:
		return {"error": "Active-run map snapshot has invalid generation data.", "graph": null}
	for value: Variant in nodes_value as Array:
		if not (value is Dictionary):
			return {"error": "Active-run map snapshot contains a malformed node.", "graph": null}
		var node_result: Dictionary = MapNodeState.from_snapshot(value as Dictionary)
		var node_error: String = String(node_result.get("error", ""))
		if not node_error.is_empty():
			return {"error": node_error, "graph": null}
		var node: MapNodeState = node_result.get("node") as MapNodeState
		if restored.nodes.has(node.node_id):
			return {"error": "Active-run map snapshot contains duplicate node IDs.", "graph": null}
		restored.add_node(node)
	var graph_error: String = restored.validate_graph()
	if not graph_error.is_empty():
		return {"error": graph_error, "graph": null}
	return {"error": "", "graph": restored}


func add_node(node: MapNodeState) -> void:
	assert(node != null and node.node_id != &"")
	nodes[node.node_id] = node


func get_map_node(node_id: StringName) -> MapNodeState:
	return nodes.get(node_id) as MapNodeState


func connect_nodes(from_id: StringName, to_id: StringName) -> String:
	var from_node: MapNodeState = get_map_node(from_id)
	var to_node: MapNodeState = get_map_node(to_id)
	if from_node == null or to_node == null:
		return "Cannot connect missing map nodes."
	if to_node.column != from_node.column + 1:
		return "Map edges must connect adjacent columns."
	if not from_node.outgoing_ids.has(to_id):
		from_node.outgoing_ids.append(to_id)
	if not to_node.incoming_ids.has(from_id):
		to_node.incoming_ids.append(from_id)
	return ""


func get_nodes_in_column(column: int) -> Array[MapNodeState]:
	var result: Array[MapNodeState] = []
	for value: Variant in nodes.values():
		var node: MapNodeState = value as MapNodeState
		if node != null and node.column == column:
			result.append(node)
	result.sort_custom(
		func(left: MapNodeState, right: MapNodeState) -> bool:
			return left.row < right.row
	)
	return result


func validate_graph() -> String:
	if get_map_node(start_node_id) == null:
		return "Layer map has no valid start node."
	if get_map_node(boss_node_id) == null:
		return "Layer map has no valid boss node."
	for value: Variant in nodes.values():
		var node: MapNodeState = value as MapNodeState
		if node == null:
			return "Layer map contains an invalid node."
		if node.node_id != start_node_id and node.incoming_ids.is_empty():
			return "Map node %s has no incoming route." % node.node_id
		if node.node_id != boss_node_id and node.outgoing_ids.is_empty():
			return "Map node %s has no outgoing route." % node.node_id
	return _validate_boss_reachable()


func _validate_boss_reachable() -> String:
	var frontier: Array[StringName] = [start_node_id]
	var visited_ids: Dictionary = {}
	while not frontier.is_empty():
		var current_id: StringName = frontier.pop_front()
		if visited_ids.has(current_id):
			continue
		visited_ids[current_id] = true
		if current_id == boss_node_id:
			return ""
		var current: MapNodeState = get_map_node(current_id)
		for next_id: StringName in current.outgoing_ids:
			frontier.append(next_id)
	return "The layer boss is not reachable from the start."
