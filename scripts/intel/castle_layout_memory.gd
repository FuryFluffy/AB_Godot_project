class_name CastleLayoutMemory
extends RefCounted

## Retained graphs are memory records, never resumed run progress. New expeditions
## rebuild content and accessibility from current authoring and campaign boss deaths.
static func remember(layouts: Dictionary, graph: LayerMapGraph) -> void:
	if graph != null and graph.layer_id in [&"layer_1", &"layer_2"] and graph.start_node_id in [&"l1_c0_n0", &"l2_refuge_farthest_cell"]:
		layouts[String(graph.layer_id)] = graph.to_snapshot()

static func validate(raw: Variant) -> String:
	if not raw is Dictionary:
		return "Castle layouts must be a dictionary."
	for key: Variant in raw:
		if key not in ["layer_1", "layer_2"] or not raw[key] is Dictionary:
			return "Invalid remembered castle layer."
		var restored: Dictionary = LayerMapGraph.from_snapshot(raw[key])
		if not String(restored.error).is_empty():
			return String(restored.error)
		var graph: LayerMapGraph = restored.graph
		if String(graph.layer_id) != key or graph.layer_number != int(String(key).trim_prefix("layer_")):
			return "Remembered castle layer does not match its identity."
	return ""

static func generate(generator: RefCounted, layer: int, seed_value: int, defeated: Array[StringName], memory: Dictionary = {}) -> LayerMapGraph:
	var layout_seed: int = int(memory.get("layout_seed", memory.get("run_seed", seed_value)))
	var fresh: LayerMapGraph = generator.generate_layer_1(layout_seed, defeated) if layer == 1 else generator.generate_layer_2_run(layout_seed, defeated)
	if fresh == null:
		return null
	if memory.is_empty():
		return fresh
	var restored: Dictionary = LayerMapGraph.from_snapshot(memory)
	if not String(restored.error).is_empty():
		generator.last_generation_error = String(restored.error)
		return null
	var graph: LayerMapGraph = restored.graph
	# Each memory expedition mixes the new choice with the previous run identity.
	var content_seed: int = StableSeedMixer.make_seed(seed_value, &"castle_memory_next_run", StringName(str(graph.run_seed)))
	if content_seed == graph.run_seed:
		content_seed += 1
	graph.run_seed = content_seed
	for node: MapNodeState in graph.nodes.values():
		var authored: MapNodeState = fresh.get_map_node(node.node_id)
		if authored == null or authored.authored_room_id != node.authored_room_id or authored.node_type != node.node_type:
			generator.last_generation_error = "The remembered layout no longer matches its authored rooms."
			return null
		# Preserve only layout identity and discovered type knowledge from old nodes.
		var known: bool = node.type_known
		var reset: Dictionary = authored.to_snapshot()
		reset.column = node.column
		reset.row = node.row
		reset.outgoing_ids = node.outgoing_ids.duplicate()
		reset.incoming_ids = node.incoming_ids.duplicate()
		reset.type_known = known
		reset.content_seed = StableSeedMixer.make_seed(content_seed, &"generated_map_node", StringName("%s:%s:%s" % [graph.layer_id, node.node_id, node.authored_room_id]))
		if node.node_type == MapNodeState.NodeType.REST:
			reset.rest_offer_id = RoomRestRules.assigned_offer(int(reset.content_seed), node.node_id)
		graph.nodes[node.node_id] = MapNodeState.from_snapshot(reset).node
	for id: Variant in graph.edge_states:
		var known: bool = graph.edge_states[id].known
		# Knowledge is retained, but yesterday's keys/open doors grant no access.
		if not fresh.edge_states.has(id):
			generator.last_generation_error = "The remembered route no longer matches current authoring."
			return null
		graph.edge_states[id] = (fresh.edge_states[id] as Dictionary).duplicate(true)
		graph.edge_states[id].known = known
	return graph

static func refresh_authored_locks(graph: LayerMapGraph, catalog: Resource) -> void:
	# Exit bindings are authored in the room scenes. Read their initial lock state
	# without entering rooms, rolling loot, invoking interactions or marking visits.
	for node: MapNodeState in graph.nodes.values():
		var definition: Resource = catalog.get_room(node.room_definition_id)
		if definition == null or definition.presentation_scene == null:
			continue
		var presentation: Node = definition.presentation_scene.instantiate()
		var exits: Array[RoomExitHotspot] = []
		var locks: Array[RoomLockHotspot] = []
		var queue: Array[Node] = [presentation]
		while not queue.is_empty():
			var child: Node = queue.pop_front()
			if child is RoomExitHotspot: exits.append(child)
			if child is RoomLockHotspot: locks.append(child)
			queue.append_array(child.get_children())
		for room_exit: RoomExitHotspot in exits:
			var targets: Array[StringName] = room_exit.destination_node_ids.duplicate()
			if targets.is_empty() and exits.size() == 1:
				targets.assign(node.outgoing_ids)
			for target: StringName in targets:
				if not node.outgoing_ids.has(target): continue
				var edge: Dictionary = graph.edge_states[graph.edge_id(node.node_id, target)]
				edge.exit_id = String(presentation.get_path_to(room_exit))
				for lock: RoomLockHotspot in locks:
					if lock.get_exit_hotspot() == room_exit and not lock.is_unlocked:
						edge.unlocked = false
		presentation.free()
