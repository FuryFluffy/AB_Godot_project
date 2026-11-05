class_name IntelMapEffects
extends RefCounted

const CATALOG = preload("res://data/intel/intel_catalog.tres")

static func apply(graph: LayerMapGraph, ids: Array[StringName], current: StringName) -> void:
	if graph == null or graph.layer_id == &"bloom_refuge":
		return
	for id: StringName in ids:
		var option: IntelOptionDefinition = CATALOG.get_option(id)
		if option == null or not option.available:
			continue
		match option.effect:
			IntelOptionDefinition.Effect.SCOUTING:
				graph.reveal_adjacency(current, true)
				for node: MapNodeState in graph.nodes.values():
					if node.visited and (node.cleared or node.exit_completed):
						graph.reveal_adjacency(node.node_id, true)
			IntelOptionDefinition.Effect.PATHFINDING:
				for edge: Dictionary in graph.edge_states.values():
					edge.known = true
			IntelOptionDefinition.Effect.COIN_ROUTE:
				_reveal_treasury_route(graph)
			_:
				var kinds: Array = []
				match option.effect:
					IntelOptionDefinition.Effect.BATTLE_SENSE: kinds = [MapNodeState.NodeType.BATTLE, MapNodeState.NodeType.ELITE]
					IntelOptionDefinition.Effect.SANCTUARY: kinds = [MapNodeState.NodeType.REST]
					IntelOptionDefinition.Effect.DANGER: kinds = [MapNodeState.NodeType.TRAP]
					IntelOptionDefinition.Effect.ARTISAN: kinds = [MapNodeState.NodeType.ALCHEMY, MapNodeState.NodeType.WORKSHOP]
				for node: MapNodeState in graph.nodes.values():
					if node.node_type in kinds:
						node.type_known = true

static func _reveal_treasury_route(graph: LayerMapGraph) -> void:
	var targets: Array[StringName] = []
	for node: MapNodeState in graph.nodes.values():
		if node.node_type == MapNodeState.NodeType.TREASURY:
			targets.append(node.node_id)
	if targets.is_empty():
		return
	targets.sort()
	var target: StringName = targets[posmod(graph.run_seed, targets.size())]
	var previous: Dictionary = {graph.start_node_id: &""}
	var queue: Array[StringName] = [graph.start_node_id]
	while not queue.is_empty() and not previous.has(target):
		var current: StringName = queue.pop_front()
		var neighbors: Array[StringName] = graph.connected_ids(current)
		neighbors.sort()
		for neighbor: StringName in neighbors:
			if not previous.has(neighbor):
				previous[neighbor] = current
				queue.append(neighbor)
	if not previous.has(target):
		return
	graph.get_map_node(target).type_known = true
	while target != graph.start_node_id:
		var parent: StringName = previous[target]
		graph.edge_states[graph.edge_id(parent,target)].known = true
		target = parent
