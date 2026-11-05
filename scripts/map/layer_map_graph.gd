class_name LayerMapGraph
extends RefCounted


var layer_id: StringName = &"layer_1"
var layer_number: int = 1
var display_name: String = "Layer 1 — Lower Castle Route"
var run_seed: int = 0
# Stable layout identity is independent of new expedition content randomness.
var layout_seed: int = 0
var column_count: int = 7
var nodes: Dictionary = {}
# Edge identity is derived from the existing directed topology; traversal is reciprocal.
var edge_states: Dictionary = {}
# Reserved positions only. These do not activate unauthored special-room services.
var reserved_node_types: Dictionary = {}
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
		"layout_seed": layout_seed if layout_seed > 0 else run_seed,
		"column_count": column_count,
		"start_node_id": String(start_node_id),
		"boss_node_id": String(boss_node_id),
		"nodes": serialized_nodes,
		"edge_states": edge_states.duplicate(true),
		"reserved_node_types": reserved_node_types.duplicate(true),
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
	var layout_value: Variant = snapshot.get("layout_seed", restored.run_seed)
	if typeof(layout_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(layout_value)) or float(layout_value) != floorf(float(layout_value)) or layout_value <= 0:
		return {"error": "Invalid castle layout seed.", "graph": null}
	restored.layout_seed = int(layout_value)
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
	var knowledge_error: String = restored._restore_knowledge(snapshot)
	if not knowledge_error.is_empty():
		return {"error": knowledge_error, "graph": null}
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
	_ensure_edge(from_id, to_id)
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
	if get_map_node(start_node_id) == null or get_map_node(boss_node_id) == null:
		return "Layer map requires valid start and boss nodes."
	for value: Variant in nodes.values():
		var node: MapNodeState = value as MapNodeState
		if node == null or node.column >= column_count:
			return "Layer map contains an invalid node."
		if node.node_id != start_node_id and node.incoming_ids.is_empty():
			return "Map node %s has no incoming route." % node.node_id
		var unique: Dictionary = {}
		for next_id: StringName in node.outgoing_ids:
			var target: MapNodeState = get_map_node(next_id)
			if target == null or target.column != node.column + 1 or not target.incoming_ids.has(node.node_id) or unique.has(next_id):
				return "Map contains an invalid or duplicate outgoing edge."
			unique[next_id] = true
		unique.clear()
		for previous_id: StringName in node.incoming_ids:
			var source: MapNodeState = get_map_node(previous_id)
			if source == null or not source.outgoing_ids.has(node.node_id) or unique.has(previous_id):
				return "Map contains an invalid or duplicate incoming edge."
			unique[previous_id] = true
	var frontier: Array[StringName] = [start_node_id]
	var reachable: Dictionary = {}
	while not frontier.is_empty():
		var id: StringName = frontier.pop_front()
		if reachable.has(id):
			continue
		reachable[id] = true
		frontier.append_array(get_map_node(id).outgoing_ids)
	return "" if reachable.size() == nodes.size() else "Layer map has unreachable rooms."


func edge_id(a: StringName, b: StringName) -> String:
	var node: MapNodeState = get_map_node(a)
	if node == null:
		return ""
	if node.outgoing_ids.has(b):
		return "%s>%s" % [a, b]
	if node.incoming_ids.has(b):
		return "%s>%s" % [b, a]
	return ""


func _ensure_edge(a: StringName, b: StringName) -> void:
	var id: String = edge_id(a, b)
	if not id.is_empty() and not edge_states.has(id):
		edge_states[id] = {"known": false, "hidden": false, "unlocked": true, "exit_id": ""}


func connected_ids(id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var node: MapNodeState = get_map_node(id)
	if node != null:
		result.append_array(node.outgoing_ids)
		result.append_array(node.incoming_ids)
	return result


func is_connection_known(a: StringName, b: StringName) -> bool:
	var state: Dictionary = edge_states.get(edge_id(a, b), {})
	return bool(state.get("known", false))


func is_connection_accessible(a: StringName, b: StringName) -> bool:
	var state: Dictionary = edge_states.get(edge_id(a, b), {})
	var target: MapNodeState = get_map_node(b)
	return is_connection_known(a, b) and not bool(state.get("hidden", false)) and bool(state.get("unlocked", false)) and target != null and target.travel_enabled


func reveal_adjacency(id: StringName, identify_types: bool = false) -> void:
	var node: MapNodeState = get_map_node(id)
	if node == null:
		return
	node.type_known = true
	for neighbor_id: StringName in connected_ids(id):
		_ensure_edge(id, neighbor_id)
		var state: Dictionary = edge_states[edge_id(id, neighbor_id)]
		if state.hidden or not state.unlocked:
			continue
		state.known = true
		if identify_types:
			get_map_node(neighbor_id).type_known = true


func initialize_entry_knowledge(id: StringName) -> void:
	# Called at actual entry/lifecycle boundaries, never from a UI query.
	for value: Variant in nodes.values():
		var node: MapNodeState = value
		for next_id: StringName in node.outgoing_ids:
			_ensure_edge(node.node_id, next_id)
		if node.visited:
			node.type_known = true
			if node.cleared or node.exit_completed:
				reveal_adjacency(node.node_id)
	reveal_adjacency(id)


func _restore_knowledge(snapshot: Dictionary) -> String:
	if not snapshot.has("edge_states"):
		# Legacy saves retain their topology; discover only visited/resolved adjacency.
		initialize_entry_knowledge(start_node_id)
	else:
		var raw: Variant = snapshot.edge_states
		if not raw is Dictionary:
			return "Map edge knowledge must be a dictionary."
		var expected: Dictionary = {}
		for value: Variant in nodes.values():
			var node: MapNodeState = value
			for next_id: StringName in node.outgoing_ids:
				expected[edge_id(node.node_id, next_id)] = true
		if raw.size() != expected.size():
			return "Map edge knowledge does not match its topology."
		for key: Variant in raw:
			if not key is String or not expected.has(key) or not raw[key] is Dictionary:
				return "Map edge knowledge contains an invalid edge."
			var state: Dictionary = raw[key]
			for field: String in ["known", "hidden", "unlocked"]:
				if not state.get(field) is bool:
					return "Map edge knowledge contains invalid %s." % field
			if not state.get("exit_id") is String:
				return "Map edge knowledge contains invalid exit visibility."
		edge_states = raw.duplicate(true)
	var reserved: Variant = snapshot.get("reserved_node_types", {})
	if not reserved is Dictionary:
		return "Map special-room reservations must be a dictionary."
	for key: Variant in reserved:
		if not key is String or get_map_node(StringName(key)) == null:
			return "Map special-room reservation has an invalid node."
		var type: Variant = reserved[key]
		if not (type is int or type is float) or float(type) != floorf(float(type)) or int(type) not in [MapNodeState.NodeType.ELITE, MapNodeState.NodeType.TRAP, MapNodeState.NodeType.TREASURY, MapNodeState.NodeType.REST, MapNodeState.NodeType.ALCHEMY, MapNodeState.NodeType.WORKSHOP]:
			return "Map special-room reservation has an invalid type."
	reserved_node_types = {}
	for key: String in reserved:
		reserved_node_types[key] = int(reserved[key])
	return ""
