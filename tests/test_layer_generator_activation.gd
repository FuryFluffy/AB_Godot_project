extends SceneTree


const ROOM_CATALOG: LayerRoomCatalogDefinition = preload(
	"res://data/rooms/layer_1_2_room_catalog.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)

var failures: int = 0


func _init() -> void:
	_test_deterministic_registered_generation()
	_test_seed_variation_and_topology()
	_test_structural_validation_rejects_corruption()
	_test_insufficient_registry_fails_transactionally()
	_test_snapshot_continue_and_backtracking()
	if failures == 0:
		print("Layer 1–2 generator activation tests passed.")
	else:
		push_error("%d generator activation test(s) failed." % failures)
	quit(failures)


func _test_deterministic_registered_generation() -> void:
	var generator := LayerMapGenerator.new()
	for layer_number: int in [1, 2]:
		var first: LayerMapGraph = _generate(generator, layer_number, 27072026)
		var second: LayerMapGraph = _generate(generator, layer_number, 27072026)
		_expect(first != null and second != null, "Both generated layers must exist.")
		if first == null or second == null:
			continue
		var authored_ids: Dictionary = {}
		var playable_count: int = 0
		var every_node_registered: bool = true
		for value: Variant in first.nodes.values():
			var node: MapNodeState = value as MapNodeState
			playable_count += 1 if node.node_type != MapNodeState.NodeType.START else 0
			var room: LayerRoomDefinition = ROOM_CATALOG.get_room(node.authored_room_id)
			every_node_registered = (
				every_node_registered
				and room != null
				and room.layer_number == layer_number
				and node.content_seed > 0
				and not authored_ids.has(node.authored_room_id)
			)
			authored_ids[node.authored_room_id] = true
		_expect(
			JSON.stringify(first.to_snapshot()) == JSON.stringify(second.to_snapshot())
			and generator.validate_generated_layer(first).is_empty()
			and playable_count >= LayerMapGenerator.MIN_PLAYABLE_NODES
			and playable_count <= LayerMapGenerator.MAX_PLAYABLE_NODES
			and every_node_registered,
			"Layer %d must be byte-equivalent for one seed and use unique registered rooms with stable seeds." % layer_number
		)
	var layer_1: LayerMapGraph = generator.generate_layer_1(8128)
	var layer_2: LayerMapGraph = generator.generate_layer_2_run(8128)
	_expect(
		_has_authored_rooms(layer_1, [
			&"opening_servant_corridor", &"wine_cellar_warm_bottles",
			&"butlers_office", &"wax_prep_room", &"ruined_chapel",
			&"blood_nun_processing_chapel", &"lower_kitchen",
		])
		and _has_authored_rooms(layer_2, [
			&"farthest_cell", &"chain_maintenance_room",
			&"jailers_gate_hall", &"jailers_containment_hall",
		]),
		"Every executable required L1/L2 registry anchor must be reserved."
	)
	var recruitment_node: MapNodeState = layer_1.get_nodes_in_column(1)[0]
	_expect(
		recruitment_node.authored_room_id == &"lower_kitchen"
		and recruitment_node.encounter_id
		== RunState.MIRA_RECRUITMENT_ENCOUNTER_ID
		and recruitment_node.encounter_template_id == &"lower_kitchen_regular",
		"The Corrupted Butler and Mira recruitment must use the authored Lower Kitchen room."
	)


func _test_seed_variation_and_topology() -> void:
	var generator := LayerMapGenerator.new()
	var first_l1: LayerMapGraph = generator.generate_layer_1(111)
	var second_l1: LayerMapGraph = generator.generate_layer_1(222)
	var first_l2: LayerMapGraph = generator.generate_layer_2_run(111)
	var second_l2: LayerMapGraph = generator.generate_layer_2_run(222)
	_expect(
		first_l1 != null and second_l1 != null
		and first_l2 != null and second_l2 != null
		and _route_signature(first_l1) != _route_signature(second_l1)
		and _route_signature(first_l2) != _route_signature(second_l2),
		"Different seeds should vary selected rooms or topology in both layers."
	)
	for seed: int in [1, 111, 222, 333, 27072026]:
		for layer_number: int in [1, 2]:
			var graph: LayerMapGraph = _generate(generator, layer_number, seed)
			_expect(
				graph != null and generator.validate_generated_layer(graph).is_empty(),
				"Layer %d seed %d must retain branching, convergence, gates, and full reachability." % [layer_number, seed]
			)


func _test_structural_validation_rejects_corruption() -> void:
	var generator := LayerMapGenerator.new()
	var missing_anchor: LayerMapGraph = generator.generate_layer_1(678)
	var wine_node := _get_authored_node(missing_anchor, &"wine_cellar_warm_bottles")
	wine_node.authored_room_id = &"servant_ledger_alcove"
	_expect(
		not generator.validate_generated_layer(missing_anchor).is_empty(),
		"Structural validation must reject a graph missing a required authored anchor."
	)
	var broken_edge: LayerMapGraph = generator.generate_layer_2_run(678)
	var start: MapNodeState = broken_edge.get_map_node(broken_edge.start_node_id)
	var first_id: StringName = start.outgoing_ids[0]
	broken_edge.get_map_node(first_id).incoming_ids.erase(start.node_id)
	_expect(
		not generator.validate_generated_layer(broken_edge).is_empty(),
		"Structural validation must reject a non-reciprocal generated edge."
	)
	var malformed_node: Dictionary = start.to_snapshot()
	malformed_node["content_seed"] = "not-an-integer"
	_expect(
		not String(MapNodeState.from_snapshot(malformed_node).get("error", "")).is_empty(),
		"Generated-node snapshot fields must reject malformed types safely."
	)


func _test_insufficient_registry_fails_transactionally() -> void:
	var incomplete := LayerRoomCatalogDefinition.new()
	for index: int in range(8):
		incomplete.rooms.append(ROOM_CATALOG.get_rooms_for_layer(1)[index])
	var generator := LayerMapGenerator.new(incomplete)
	var preserved: LayerMapGraph = LayerMapGenerator.new().generate_layer_1(444)
	var before: Dictionary = preserved.to_snapshot()
	var failed: LayerMapGraph = generator.generate_layer_1(444)
	_expect(
		failed == null
		and not generator.last_generation_error.is_empty()
		and preserved.to_snapshot() == before,
		"Insufficient registry data must fail clearly without returning a partial graph or mutating an active one."
	)


func _test_snapshot_continue_and_backtracking() -> void:
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph = generator.generate_layer_1(555)
	var restored_result: Dictionary = LayerMapGraph.from_snapshot(graph.to_snapshot())
	var restored_graph: LayerMapGraph = restored_result.get("graph") as LayerMapGraph
	var graph_round_trip_equal: bool = (
		restored_graph != null
		and JSON.stringify(restored_graph.to_snapshot()) == JSON.stringify(graph.to_snapshot())
	)
	var run := RunState.new()
	var initialize_error: String = run.initialize(555, graph, [], _full_party_snapshot())
	run.opening_completed = true
	var first: MapNodeState = graph.get_nodes_in_column(1)[0]
	run.travel_to(first.node_id)
	run.complete_pending_node(0)
	var target: MapNodeState = graph.get_nodes_in_column(2)[0]
	var travel_error: String = run.travel_to(target.node_id)
	var seed_error: String = run.prepare_pending_node_seed()
	var saved_seed: int = run.pending_node_seed
	var active: Dictionary = run.make_active_run_snapshot("pre_node", KnowledgeState.new())
	var continued := RunState.new()
	var continue_error: String = continued.restore_active_run_snapshot(active, BATTLER_CATALOG)
	var continued_seed: int = continued.pending_node_seed
	var complete_error: String = continued.complete_pending_node(3)
	var post: Dictionary = continued.make_active_run_snapshot("post_node", KnowledgeState.new())
	var post_run := RunState.new()
	var post_error: String = post_run.restore_active_run_snapshot(post, BATTLER_CATALOG)
	var return_error: String = continued.travel_to(first.node_id)
	var revisit_available: bool = continued.can_travel_to(target.node_id)
	var facts: Dictionary = {
		"initialize": initialize_error.is_empty(),
		"graph_restore_error": String(restored_result.get("error", "")).is_empty(),
		"graph_equal": graph_round_trip_equal,
		"travel": travel_error.is_empty(),
		"seed": seed_error.is_empty(),
		"continue": continue_error.is_empty(),
		"continued_seed": continued_seed == saved_seed,
		"content_seed": continued.graph.get_map_node(target.node_id).content_seed == target.content_seed,
		"complete": complete_error.is_empty(),
		"post": post_error.is_empty(),
		"reward_claimed": post_run.graph.get_map_node(target.node_id).reward_claimed,
		"no_replay": post_run.complete_pending_node(3) != "",
		"return": return_error.is_empty(),
		"revisit": revisit_available,
	}
	_expect(
		bool(facts.get("initialize"))
		and String(restored_result.get("error", "")).is_empty()
		and graph_round_trip_equal
		and travel_error.is_empty() and seed_error.is_empty()
		and continue_error.is_empty()
		and continued_seed == saved_seed
		and continued.graph.get_map_node(target.node_id).content_seed == target.content_seed
		and complete_error.is_empty() and post_error.is_empty()
		and post_run.graph.get_map_node(target.node_id).reward_claimed
		and post_run.complete_pending_node(3) != ""
		and return_error.is_empty() and revisit_available,
		(
			"Generated IDs, seeds, cleared rewards, Continue, and cleared-route backtracking must survive snapshots. "
			+ "init=%s restore_graph=%s travel=%s seed=%s continue=%s complete=%s post=%s return=%s revisit=%s"
		) % [
			initialize_error, String(restored_result.get("error", "")), travel_error,
			seed_error, continue_error, complete_error, post_error, return_error,
			revisit_available,
		] + " facts=%s" % facts
	)


func _generate(
	generator: LayerMapGenerator,
	layer_number: int,
	seed: int
) -> LayerMapGraph:
	return (
		generator.generate_layer_1(seed)
		if layer_number == 1
		else generator.generate_layer_2_run(seed)
	)


func _has_authored_rooms(graph: LayerMapGraph, required_ids: Array[StringName]) -> bool:
	if graph == null:
		return false
	var present: Dictionary = {}
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		present[node.authored_room_id] = true
	for room_id: StringName in required_ids:
		if not present.has(room_id):
			return false
	return true


func _get_authored_node(
	graph: LayerMapGraph,
	room_id: StringName
) -> MapNodeState:
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		if node.authored_room_id == room_id:
			return node
	return null


func _route_signature(graph: LayerMapGraph) -> String:
	var rows: Array[String] = []
	var node_ids: Array[StringName] = []
	for value: Variant in graph.nodes.keys():
		node_ids.append(StringName(value))
	node_ids.sort()
	for node_id: StringName in node_ids:
		var node: MapNodeState = graph.get_map_node(node_id)
		rows.append("%s:%s:%d:%s" % [
			node.node_id,
			node.authored_room_id,
			int(node.node_type),
			",".join(node.outgoing_ids),
		])
	return "|".join(rows)


func _full_party_snapshot() -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(10, 4, 75, 8),
		&"mira": _heroine_snapshot(9, 6, 72, 12),
		&"seraphine": _heroine_snapshot(8, 8, 80, 4),
	}


func _heroine_snapshot(hp: int, mp: int, resolve: int, corruption: int) -> Dictionary:
	return {
		"hp": hp, "mp": mp, "resolve": resolve, "corruption": corruption,
		"item_guard": 0, "weapon_damage": 0, "weapon_broken": false,
		"armor_damage": 0, "armor_broken": false,
		"shield_damage": 0, "shield_broken": false,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
