extends SceneTree

var checks: int = 0
var failures: int = 0
const BATTLERS = preload("res://data/battlers/battler_catalog.tres")

func _init() -> void:
	_generation()
	_discovery_and_locks()
	_event_encounter_independence()
	_saved_knowledge()
	_reverse_entry()
	_entry_rollback()
	_scouting_discovery()
	print("Stage 15 map state: %d checks, %d failures." % [checks, failures])
	quit(failures)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _generation() -> void:
	var generator := LayerMapGenerator.new()
	for seed: int in range(1, 101):
		for layer: int in [1, 2]:
			var graph: LayerMapGraph = generator.generate_layer_1(seed) if layer == 1 else generator.generate_layer_2_run(seed)
			_check(graph != null, "Generates layer %d seed %d: %s" % [layer, seed, generator.last_generation_error])
			if graph == null:
				continue
			_check(generator.validate_generated_layer(graph).is_empty(), "All topology/gate/content constraints hold")
			_check(generator.validate_special_room_quotas(graph, true).is_empty(), "Reserved special positions satisfy final quotas")
			var future_inactive: bool = true
			for node: MapNodeState in graph.nodes.values():
				future_inactive = future_inactive and (node.requires_event_room() if node.node_type in [MapNodeState.NodeType.ALCHEMY,MapNodeState.NodeType.WORKSHOP] else true)
			_check(generator.validate_special_room_quotas(graph).is_empty() and future_inactive, "All special quotas are executable through Stage 21")
			var copy: LayerMapGraph = LayerMapGraph.from_snapshot(graph.to_snapshot()).graph
			_check(copy != null and copy.to_snapshot() == graph.to_snapshot(), "New graph fields round-trip before play")
			for id: String in copy.reserved_node_types:
				copy.get_map_node(StringName(id)).node_type = int(copy.reserved_node_types[id]) as MapNodeState.NodeType
			_check(generator.validate_special_room_quotas(copy).is_empty(), "Test-only activation exercises actual type quotas")
			var rules: Array[GeneratedRoomItemPlacementRule] = []
			if layer == 1:
				rules = generator.make_layer_1_generated_room_item_rules()
			var placements: GeneratedRoomItemPlacementResult = GeneratedRoomItemPlacementResolver.resolve(graph, rules, seed)
			_check(placements.succeeded(), "Required key stays reachable for every seed")
	for graph: LayerMapGraph in [generator.generate_layer_2_entry(1), generator.generate_layer_3_entry(1), generator.generate_bloom_refuge_holding_state(1)]:
		_check(graph.nodes.size() == 2 and graph.validate_graph().is_empty(), "Story/holding graphs remain small special transitions")
	var broken: LayerMapGraph = generator.generate_layer_1(1)
	broken.get_map_node(broken.start_node_id).outgoing_ids.append(&"missing")
	_check(not broken.validate_graph().is_empty(), "Malformed graph rejects missing edges without dereferencing null")

func _graph() -> LayerMapGraph:
	var graph := LayerMapGraph.new()
	graph.run_seed = 42
	graph.column_count = 4
	for spec: Array in [["start", 0, 0], ["room", 1, 0], ["side", 2, 0], ["secret", 2, 1], ["boss", 3, 0]]:
		var node := MapNodeState.new()
		node.node_id = StringName(spec[0])
		node.display_name = "Private " + spec[0]
		node.column = spec[1]
		node.row = spec[2]
		graph.add_node(node)
	graph.start_node_id = &"start"
	graph.boss_node_id = &"boss"
	graph.get_map_node(&"start").node_type = MapNodeState.NodeType.START
	graph.get_map_node(&"start").visited = true
	graph.get_map_node(&"start").cleared = true
	graph.get_map_node(&"boss").node_type = MapNodeState.NodeType.BOSS
	graph.get_map_node(&"room").room_definition_id = &"butlers_office"
	graph.connect_nodes(&"start", &"room")
	graph.connect_nodes(&"room", &"side")
	graph.connect_nodes(&"room", &"secret")
	graph.connect_nodes(&"side", &"boss")
	graph.edge_states[graph.edge_id(&"room", &"secret")].hidden = true
	return graph

func _run_for(graph: LayerMapGraph) -> RunState:
	var run := RunState.new()
	_check(run.initialize(42, graph, [], {&"lysandra": {"hp": 8, "mp": 3}}).is_empty(), "Fixture run initializes")
	run.opening_completed = true
	return run

func _outcome(run: RunState, clear: bool, unlocked: bool) -> EventRoomOutcome:
	var result := EventRoomOutcome.new()
	result.source_node_id = &"room"
	result.clear_node = clear
	result.party_snapshot = run.party_snapshot.duplicate(true)
	result.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	result.run_inventory_snapshot = run.run_inventory.get_snapshot()
	result.room_state_snapshot = run.get_event_room_state(&"room", &"butlers_office").to_snapshot()
	result.exit_states[run.graph.edge_id(&"room", &"side")] = {"exit_id": "Exit", "unlocked": unlocked}
	return result

func _discovery_and_locks() -> void:
	var graph: LayerMapGraph = _graph()
	var run: RunState = _run_for(graph)
	_check(graph.is_connection_known(&"start", &"room") and not graph.get_map_node(&"boss").type_known, "Entry reveals eligible edges; boss stays unknown")
	_check(run.travel_to(&"room").is_empty() and not graph.is_connection_known(&"room", &"side"), "Entering/visiting does not expose further adjacency")
	_check(run.apply_event_room_outcome(_outcome(run, false, false)).is_empty(), "Back commits a locked exit without discovering beyond it")
	_check(not graph.is_connection_known(&"room", &"side") and not graph.get_map_node(&"side").type_known, "Locked exit reveals neither edge nor destination type")
	_check(run.travel_to(&"room").is_empty(), "Unresolved room can be revisited")
	_check(run.apply_event_room_outcome(_outcome(run, true, false)).is_empty(), "Another successful exit can resolve visit while this exit is locked")
	_check(not graph.get_map_node(&"room").solved and graph.get_map_node(&"room").exit_completed, "Successful exit is distinct from Solved")
	_check(not run.can_travel_to(&"side") and not run.can_travel_to(&"secret"), "Locked and hidden connections block travel")
	_check(run.apply_event_room_outcome(_outcome(run, true, true)).is_empty(), "Unlocked successful exit publishes discovery")
	_check(run.can_travel_to(&"side") and not graph.get_map_node(&"side").type_known and not graph.get_map_node(&"secret").type_known, "Without Scouting, eligible adjacency reveals routes without identifying types")
	_check(run.travel_to(&"side").is_empty() and graph.get_map_node(&"side").type_known, "Known unlocked edge is traversable and entry identifies its room")
	run.complete_pending_node()
	_check(run.get_backtrack_route(&"start") == [&"room", &"start"], "Existing BFS traverses a discovered multi-edge route")
	graph.edge_states[graph.edge_id(&"start", &"room")].unlocked = false
	_check(run.get_backtrack_route(&"start").is_empty() and not run.can_travel_to(&"start"), "An intermediate locked edge blocks backtracking")
	graph.edge_states[graph.edge_id(&"start", &"room")].unlocked = true
	graph.edge_states[graph.edge_id(&"start", &"room")].known = false
	_check(run.get_backtrack_route(&"start").is_empty(), "An intermediate unknown edge blocks backtracking")
	var before: Dictionary = run.make_active_run_snapshot("post_node", KnowledgeState.new())
	var invalid: EventRoomOutcome = _outcome(run, true, true)
	invalid.source_node_id = &"side"
	_check(not run.apply_event_room_outcome(invalid).is_empty() and before == run.make_active_run_snapshot("post_node", KnowledgeState.new()), "Invalid outcome leaves live state unchanged")

func _saved_knowledge() -> void:
	var graph: LayerMapGraph = _graph()
	var run: RunState = _run_for(graph)
	run.travel_to(&"room")
	run.prepare_pending_node_seed()
	var pre: Dictionary = run.make_active_run_snapshot("pre_node", KnowledgeState.new())
	var resumed := RunState.new()
	_check(resumed.restore_active_run_snapshot(pre, BATTLERS).is_empty(), "Pre-node Continue restores graph knowledge")
	_check(resumed.pending_node_seed == run.pending_node_seed and not resumed.graph.is_connection_known(&"room", &"side"), "Interrupted node keeps seed and pre-exit knowledge")
	run.apply_event_room_outcome(_outcome(run, true, true))
	graph.get_map_node(&"room").rest_used = true
	var post: Dictionary = run.make_active_run_snapshot("post_node", KnowledgeState.new())
	_check(resumed.restore_active_run_snapshot(post, BATTLERS).is_empty() and resumed.graph.to_snapshot() == graph.to_snapshot(), "Post-node Continue keeps exact layout, flags and knowledge")
	var baseline: Dictionary = resumed.make_active_run_snapshot("post_node", KnowledgeState.new())
	for bad: Variant in [null, [], {"missing>edge": {"known": true}}]:
		var invalid: Dictionary = post.duplicate(true)
		invalid.map_snapshot.graph.edge_states = bad
		_check(not resumed.restore_active_run_snapshot(invalid, BATTLERS).is_empty() and resumed.make_active_run_snapshot("post_node", KnowledgeState.new()) == baseline, "Malformed edge state rejects transactionally")
	for field: String in ["type_known", "exit_completed", "encounter_cleared", "solved", "rest_used"]:
		var invalid: Dictionary = post.duplicate(true)
		invalid.map_snapshot.graph.nodes[0][field] = 1
		_check(not resumed.restore_active_run_snapshot(invalid, BATTLERS).is_empty() and resumed.make_active_run_snapshot("post_node", KnowledgeState.new()) == baseline, "Malformed %s rejects transactionally" % field)
	var legacy: Dictionary = post.duplicate(true)
	legacy.map_snapshot.graph.erase("edge_states")
	legacy.map_snapshot.graph.erase("reserved_node_types")
	for node: Dictionary in legacy.map_snapshot.graph.nodes:
		for field: String in ["type_known", "exit_completed", "encounter_cleared", "solved", "rest_used"]:
			node.erase(field)
	_check(resumed.restore_active_run_snapshot(legacy, BATTLERS).is_empty(), "Legacy graph restores without regenerating topology")
	_check(not resumed.graph.get_map_node(&"room").solved and not resumed.graph.get_map_node(&"room").rest_used, "Legacy event clearance does not fabricate Solved or Rest use")
	for type: int in range(MapNodeState.NodeType.TRAP, MapNodeState.NodeType.WORKSHOP + 1):
		var node: Dictionary = graph.get_map_node(&"room").to_snapshot()
		node.node_type = type
		_check(String(MapNodeState.from_snapshot(node).error).is_empty(), "Appended special type round-trips")

func _reverse_entry() -> void:
	var graph: LayerMapGraph = LayerMapGenerator.new().generate_refugeless_reverse_layer_2(44)
	graph.get_map_node(graph.start_node_id).visited = false
	graph.get_map_node(graph.boss_node_id).visited = true
	graph.initialize_entry_knowledge(graph.boss_node_id)
	_check(not graph.get_map_node(graph.start_node_id).type_known and graph.get_map_node(graph.boss_node_id).reward_claimed, "Reverse entry neither reveals Farthest Cell nor re-awards dead boss")
	_check(graph.is_connection_known(graph.boss_node_id, graph.get_map_node(graph.boss_node_id).incoming_ids[0]), "Reverse entry discovers inward adjacency")

func _event_encounter_independence() -> void:
	var graph: LayerMapGraph = _graph()
	var node: MapNodeState = graph.get_map_node(&"room")
	node.encounter_id = RunState.DINING_SERVICE_HALL_ENCOUNTER_ID
	node.encounter_template_id = &"dining_service_hall_regular"
	var run: RunState = _run_for(graph)
	run.travel_to(&"room")
	_check(run.apply_event_room_outcome(_outcome(run, true, true)).is_empty(), "Room with encounter can commit its exit independently")
	_check(node.cleared and node.exit_completed and not node.encounter_cleared and not node.solved and not run.completed_encounters.has(node.encounter_id), "Exit cannot fabricate encounter victory or Solved")
	run.travel_to(&"start")
	_check(run.travel_to(&"room").is_empty() and run.pending_node_id == &"room", "Revisit keeps unresolved authored combat available")
	var victory := EncounterOutcome.new()
	victory.source_node_id = &"room"
	victory.encounter_id = node.encounter_id
	victory.result = EncounterOutcome.Result.VICTORY
	victory.bloom_reward = 4
	victory.party_snapshot = run.party_snapshot.duplicate(true)
	victory.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	_check(run.apply_encounter_outcome(victory).is_empty() and node.encounter_cleared and not node.solved and run.bloom == 4, "Actual room combat victory sets encounter flag and grants its reward after an earlier exit")

func _entry_rollback() -> void:
	var graph: LayerMapGraph = _graph()
	var run: RunState = _run_for(graph)
	graph.get_map_node(&"room").type_known = false
	var lifecycle: Dictionary = run.make_campaign_lifecycle_snapshot()
	_check(run.can_travel_to(&"room"), "Known connection can be accessible independently of type knowledge")
	run.travel_to(&"room")
	run.prepare_pending_node_seed()
	_check(run.rollback_pending_node_entry(&"room", false, lifecycle, false).is_empty() and not graph.get_map_node(&"room").type_known and not graph.get_map_node(&"room").visited, "Failed pre-node save rolls back type discovery with visitation")

func _scouting_discovery() -> void:
	var graph: LayerMapGraph = _graph()
	var run: RunState = _run_for(graph)
	_check(not graph.get_map_node(&"room").type_known and run.can_travel_to(&"room"), "Ordinary discovery exposes an accessible question mark, not a room type")
	graph.reveal_adjacency(&"start", true)
	_check(graph.get_map_node(&"room").type_known, "Explicit Scouting identification is supported independently of route discovery")
	graph.edge_states[graph.edge_id(&"room", &"side")].unlocked = false
	graph.reveal_adjacency(&"room", true)
	_check(not graph.get_map_node(&"side").type_known and not graph.get_map_node(&"secret").type_known, "Scouting adjacency cannot bypass locked or hidden exits")
