extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_seeded_generation_and_reachability()
	_test_route_state_and_backtracking()
	_test_encounter_outcome_and_first_clear_reward()
	_test_layer_1_encounter_composition_scale()
	_test_main_map_battle_launch_contract()
	_test_generated_room_item_placement()
	_test_generated_room_item_error_accumulation()

	if failures == 0:
		print("Layer 1 Node Map tests passed.")
	else:
		push_error("%d Node Map test(s) failed." % failures)
	quit(failures)

func _test_generated_room_item_placement() -> void:
	var blocked_graph: LayerMapGraph = (
		_make_generated_item_test_graph(
			false
		)
	)

	var independent_graph: LayerMapGraph = (
		_make_generated_item_test_graph(
			true
		)
	)

	var office_only_rule := (
		_make_generated_item_test_rule(
			&"office_only",
			&"shared_rusty_key",
			[
				_make_generated_item_candidate(
					&"butlers_office",
					GeneratedRoomItemHostCandidate
						.AccessPolicy
						.REACHABLE_WITHOUT_BLOCKING_ROOM,
					&"wine_cellar_warm_bottles"
				),
			]
		)
	)

	var office_only_rules: Array[GeneratedRoomItemPlacementRule] = [
		office_only_rule,
	]

	var blocked_result := (
		GeneratedRoomItemPlacementResolver.resolve(
			blocked_graph,
			office_only_rules,
			500
		)
	)

	_expect(
		not blocked_result.succeeded(),
		(
			"The Butler's Office must be rejected "
			+ "when the Wine Cellar blocks every route."
		)
	)

	var independent_result := (
		GeneratedRoomItemPlacementResolver.resolve(
			independent_graph,
			office_only_rules,
			500
		)
	)

	_expect(
		independent_result.succeeded()
		and _find_generated_assignment_host(
			independent_result.requests_by_node,
			&"office_only"
		) == &"office",
		(
			"The Butler's Office should become eligible "
			+ "when an independent route exists."
		)
	)

	var rusty_rule := (
		_make_generated_item_test_rule(
			&"shared_rusty_key",
			&"shared_rusty_key",
			[
				_make_generated_item_candidate(
					&"wine_cellar_warm_bottles",
					GeneratedRoomItemHostCandidate
						.AccessPolicy
						.NORMALLY_REACHABLE
				),
				_make_generated_item_candidate(
					&"butlers_office",
					GeneratedRoomItemHostCandidate
						.AccessPolicy
						.REACHABLE_WITHOUT_BLOCKING_ROOM,
					&"wine_cellar_warm_bottles"
				),
			]
		)
	)
	var fallback_rules: Array[GeneratedRoomItemPlacementRule] = [
		rusty_rule,
	]

	var fallback_result := (
		GeneratedRoomItemPlacementResolver.resolve(
			blocked_graph,
			fallback_rules,
			777
		)
	)

	_expect(
		fallback_result.succeeded(),
		(
			"The Rusty Key rule should succeed through "
			+ "the Wine Cellar when the Butler's Office "
			+ "candidate is blocked."
		)
	)

	_expect(
		not fallback_result.warnings.is_empty(),
		(
			"A successful generated-item rule should "
			+ "report rejected alternative candidates "
			+ "as warnings."
		)
	)

	_expect(
		"butlers_office"
		in fallback_result.get_warning_text(),
		(
			"The fallback warning should identify "
			+ "the rejected Butler's Office candidate."
		)
	)

	var bonus_rule := (
		_make_generated_item_test_rule(
			&"bonus_item",
			&"l01_bandage_roll",
			[
				_make_generated_item_candidate(
					&"wine_cellar_warm_bottles",
					GeneratedRoomItemHostCandidate
						.AccessPolicy
						.NORMALLY_REACHABLE
				),
				_make_generated_item_candidate(
					&"butlers_office",
					GeneratedRoomItemHostCandidate
						.AccessPolicy
						.REACHABLE_WITHOUT_BLOCKING_ROOM,
					&"wine_cellar_warm_bottles"
				),
			]
		)
	)

	var rusty_only_rules: Array[GeneratedRoomItemPlacementRule] = [
		rusty_rule,
	]

	var rusty_then_bonus: Array[GeneratedRoomItemPlacementRule] = [
		rusty_rule,
		bonus_rule,
	]

	var bonus_then_rusty: Array[GeneratedRoomItemPlacementRule] = [
		bonus_rule,
		rusty_rule,
	]

	var rusty_only_result := (
		GeneratedRoomItemPlacementResolver.resolve(
			independent_graph,
			rusty_only_rules,
			777
		)
	)

	var rusty_then_bonus_result := (
		GeneratedRoomItemPlacementResolver.resolve(
			independent_graph,
			rusty_then_bonus,
			777
		)
	)

	var bonus_then_rusty_result := (
		GeneratedRoomItemPlacementResolver.resolve(
			independent_graph,
			bonus_then_rusty,
			777
		)
	)

	var original_rusty_host: StringName = (
		_find_generated_assignment_host(
			rusty_only_result.requests_by_node,
			&"shared_rusty_key"
		)
	)

	_expect(
		original_rusty_host != &"",
		"The Rusty Key rule should resolve a host."
	)

	_expect(
		original_rusty_host
		== _find_generated_assignment_host(
			rusty_then_bonus_result.requests_by_node,
			&"shared_rusty_key"
		),
		(
			"Adding another generated-item rule must "
			+ "not relocate the Rusty Key."
		)
	)

	_expect(
		original_rusty_host
		== _find_generated_assignment_host(
			bonus_then_rusty_result.requests_by_node,
			&"shared_rusty_key"
		),
		(
			"Changing rule order must not relocate "
			+ "the Rusty Key."
		)
	)

	_expect(
		GeneratedRoomItemPlacementResolver.make_rule_seed(
			777,
			&"shared_rusty_key"
		)
		!= GeneratedRoomItemPlacementResolver.make_rule_seed(
			777,
			&"rusty_key_2"
		),
		(
			"Similar assignment IDs must receive "
			+ "different deterministic seeds."
		)
	)

func _test_generated_room_item_error_accumulation(
) -> void:
	var graph: LayerMapGraph = (
		_make_generated_item_test_graph(
			true
		)
	)

	var duplicate_first := (
		_make_generated_item_test_rule(
			&"duplicate_assignment",
			&"shared_rusty_key",
			[
				_make_generated_item_candidate(
					&"wine_cellar_warm_bottles",
					GeneratedRoomItemHostCandidate
						.AccessPolicy
						.NORMALLY_REACHABLE
				),
			]
		)
	)

	var duplicate_second := (
		_make_generated_item_test_rule(
			&"duplicate_assignment",
			&"l01_bandage_roll",
			[
				_make_generated_item_candidate(
					&"butlers_office",
					GeneratedRoomItemHostCandidate
						.AccessPolicy
						.NORMALLY_REACHABLE
				),
			]
		)
	)

	var missing_room_rule := (
		_make_generated_item_test_rule(
			&"missing_room_assignment",
			&"l01_smelling_salts",
			[
				_make_generated_item_candidate(
					&"room_that_does_not_exist",
					GeneratedRoomItemHostCandidate
						.AccessPolicy
						.NORMALLY_REACHABLE
				),
			]
		)
	)

	var rules: Array[GeneratedRoomItemPlacementRule] = [
		duplicate_first,
		duplicate_second,
		missing_room_rule,
	]

	var result := (
		GeneratedRoomItemPlacementResolver.resolve(
			graph,
			rules,
			900
		)
	)

	_expect(
		not result.succeeded(),
		"Malformed generated-item rules should fail."
	)

	_expect(
		_generated_item_errors_contain(
			result,
			"Duplicate generated room-item assignment_id"
		),
		(
			"Resolver validation should report "
			+ "duplicate assignment IDs."
		)
	)

	_expect(
		_generated_item_errors_contain(
			result,
			"missing_room_assignment"
		),
		(
			"Resolver validation should also report "
			+ "the independent missing-host error."
		)
	)

	_expect(
		result.requests_by_node.is_empty(),
		(
			"A failed placement profile must not "
			+ "return partial requests."
		)
	)

func _make_generated_item_candidate(
	room_definition_id: StringName,
	access_policy: GeneratedRoomItemHostCandidate.AccessPolicy,
	blocking_room_definition_id: StringName = &""
) -> GeneratedRoomItemHostCandidate:
	var candidate := (
		GeneratedRoomItemHostCandidate.new()
	)

	candidate.room_definition_id = (
		room_definition_id
	)

	candidate.access_policy = access_policy

	candidate.blocking_room_definition_id = (
		blocking_room_definition_id
	)

	return candidate


func _make_generated_item_test_rule(
	assignment_id: StringName,
	item_id: StringName,
	candidates: Array[
		GeneratedRoomItemHostCandidate
	]
) -> GeneratedRoomItemPlacementRule:
	var rule := (
		GeneratedRoomItemPlacementRule.new()
	)

	rule.assignment_id = assignment_id
	rule.item_id = item_id
	rule.quantity = 1

	rule.required_anchor_tag = (
		&"key_accessible"
	)

	rule.candidates = candidates

	return rule


func _find_generated_assignment_host(
	requests_by_node: Dictionary,
	assignment_id: StringName
) -> StringName:
	for node_value: Variant in (
		requests_by_node.keys()
	):
		var node_id: StringName = StringName(
			node_value
		)

		var requests: Array = (
			requests_by_node.get(
				node_value,
				[]
			) as Array
		)

		for request_value: Variant in requests:
			if not (request_value is Dictionary):
				continue

			var request := (
				request_value as Dictionary
			)

			if StringName(
				request.get(
					"assignment_id",
					""
				)
			) == assignment_id:
				return node_id

	return &""


func _generated_item_errors_contain(
	result: GeneratedRoomItemPlacementResult,
	search_text: String
) -> bool:
	for error_message: String in result.errors:
		if search_text in error_message:
			return true

	return false


func _make_generated_item_test_graph(
	has_independent_office_route: bool
) -> LayerMapGraph:
	var graph := LayerMapGraph.new()
	graph.layer_id = &"generated_item_test"
	graph.column_count = 4

	var start := MapNodeState.new()
	start.node_id = &"start"
	start.column = 0
	start.row = 0
	start.node_type = MapNodeState.NodeType.START
	start.display_name = "Start"
	start.visited = true
	start.cleared = true

	var wine_cellar := MapNodeState.new()
	wine_cellar.node_id = &"wine_cellar"
	wine_cellar.column = 1
	wine_cellar.row = 0
	wine_cellar.node_type = (
		MapNodeState.NodeType.EVENT
	)
	wine_cellar.display_name = "Wine Cellar"
	wine_cellar.room_definition_id = (
		&"wine_cellar_warm_bottles"
	)

	var office := MapNodeState.new()
	office.node_id = &"office"
	office.column = 2
	office.row = 0
	office.node_type = (
		MapNodeState.NodeType.EVENT
	)
	office.display_name = "Butler's Office"
	office.room_definition_id = (
		&"butlers_office"
	)

	var boss := MapNodeState.new()
	boss.node_id = &"boss"
	boss.column = 3
	boss.row = 0
	boss.node_type = MapNodeState.NodeType.BOSS
	boss.display_name = "Boss"

	graph.add_node(start)
	graph.add_node(wine_cellar)
	graph.add_node(office)
	graph.add_node(boss)

	graph.start_node_id = start.node_id
	graph.boss_node_id = boss.node_id

	graph.connect_nodes(
		start.node_id,
		wine_cellar.node_id
	)

	graph.connect_nodes(
		wine_cellar.node_id,
		office.node_id
	)

	if has_independent_office_route:
		var alternate := MapNodeState.new()
		alternate.node_id = &"alternate"
		alternate.column = 1
		alternate.row = 1
		alternate.node_type = (
			MapNodeState.NodeType.ROOM
		)
		alternate.display_name = "Alternate Route"

		graph.add_node(
			alternate
		)

		graph.connect_nodes(
			start.node_id,
			alternate.node_id
		)

		graph.connect_nodes(
			alternate.node_id,
			office.node_id
		)

	graph.connect_nodes(
		office.node_id,
		boss.node_id
	)

	return graph

func _test_seeded_generation_and_reachability() -> void:
	var generator: LayerMapGenerator = LayerMapGenerator.new()
	var first: LayerMapGraph = generator.generate_layer_1(27072026)
	var second: LayerMapGraph = generator.generate_layer_1(27072026)
	_expect(
		first.validate_graph().is_empty(),
		"Generated Layer 1 graph should be fully reachable."
	)
	_expect(
		_graph_signature(first) == _graph_signature(second),
		"Identical run seeds must generate identical graphs."
	)
	_expect(
		first.column_count == 7,
		"The provisional vertical slice should use seven columns."
	)
	_expect(
		first.get_map_node(first.boss_node_id).display_name
		== "Blood Nun Processing Chapel",
		"Layer 1 must retain the fixed Blood Nun boss constraint."
	)
	_expect(
		first.get_map_node(first.boss_node_id).encounter_template_id
		== &"blood_nun_processing_chapel_boss",
		"The generated boss node should retain its battlefield template ID."
	)


func _test_layer_1_encounter_composition_scale() -> void:
	var graph: LayerMapGraph = (
		LayerMapGenerator.new().generate_layer_1(27072026)
	)
	var run: RunState = RunState.new()
	var initialize_error: String = run.initialize(
		27072026,
		graph,
		[],
		_full_party_snapshot()
	)
	_expect(
		initialize_error.is_empty(),
		"Composition fixture should initialize a current party: %s"
		% initialize_error
	)
	if not initialize_error.is_empty():
		return
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		if node == null or not node.requires_battle():
			continue
		run.pending_node_id = node.node_id
		var encounter: EncounterDefinition = (
			run.make_encounter_definition()
		)
		_expect(
			encounter != null
			and not encounter.enemy_ids.is_empty(),
			"Every battle node should resolve a concrete enemy composition."
		)
		if encounter == null:
			continue
		_expect(
			encounter.template != null
			and encounter.spawn_assignments.size()
			== encounter.get_all_battler_ids().size(),
			"Every battle node should resolve its battlefield and neutral spawn assignments."
		)
		var expected_template_id: StringName = &"ruined_chapel_regular"
		if node.node_type == MapNodeState.NodeType.BOSS:
			expected_template_id = &"blood_nun_processing_chapel_boss"
		elif node.encounter_id == RunState.MIRA_RECRUITMENT_ENCOUNTER_ID:
			expected_template_id = &"lower_kitchen_regular"
		_expect(
			encounter.template.template_id == expected_template_id,
			"Battle nodes should select the expected authored battlefield template."
		)
		if node.node_type == MapNodeState.NodeType.BATTLE:
			if (
				node.encounter_id
				== &"layer_1_corrupted_butler_opening"
			):
				_expect(
					encounter.enemy_ids == [&"corrupted_butler"],
					"The mandatory opening special should contain only the Corrupted Butler."
				)
				continue
			_expect(
				encounter.enemy_ids.size() in [1, 2],
				"Regular Layer 1 battles must contain one or two enemies."
			)
			for enemy_id: StringName in encounter.enemy_ids:
				_expect(
					enemy_id in [
						&"hollow_servant",
						&"knife_footman",
						&"prayer_rag_novice",
					],
					"Regular battles may use only Layer 1 Standards."
				)
		elif node.node_type == MapNodeState.NodeType.ELITE:
			_expect(
				encounter.enemy_ids.size() in [2, 3],
				"Elite Layer 1 battles should contain two or three enemies."
			)
		elif node.node_type == MapNodeState.NodeType.BOSS:
			_expect(
				encounter.enemy_ids
				== [&"blood_nun", &"prayer_rag_novice"],
				"The Layer 1 boss composition must remain fixed."
			)


func _test_route_state_and_backtracking() -> void:
	var graph: LayerMapGraph = _make_branch_backtracking_graph()
	var run: RunState = RunState.new()
	_expect(
		run.initialize(12345, graph).is_empty(),
		"RunState should initialize from a valid graph."
	)
	run.opening_completed = true
	var next_id: StringName = &"lower_1"
	_expect(
		run.can_travel_to(next_id),
		"A connected first-column node should be available."
	)
	run.travel_to(next_id)
	_expect(
		run.pending_node_id == next_id,
		"First arrival should create a pending node resolution."
	)
	run.complete_pending_node(2)
	_expect(
		graph.get_map_node(next_id).cleared,
		"Completing a node should mark it cleared."
	)
	_expect(
		run.can_travel_to(graph.start_node_id),
		"Backtracking to the connected visited start should be free."
	)
	run.travel_to(&"lower_2")
	run.complete_pending_node(0)
	run.travel_to(&"lower_3")
	run.complete_pending_node(0)
	_expect(
		run.can_travel_to(&"backward_unknown"),
		"A directly connected unexplored node should remain available "
		+ "even when its authored edge points toward the current node."
	)
	run.travel_to(&"backward_unknown")
	_expect(
		run.current_node_id == &"backward_unknown"
		and run.pending_node_id == &"backward_unknown",
		"Backward-directed exploration should enter and reveal the "
		+ "connected unknown node normally."
	)
	run.complete_pending_node(0)
	run.travel_to(&"lower_3")
	_expect(
		run.can_travel_to(&"upper_event"),
		"A distant cleared node on another explored branch should be "
		+ "reachable through the cleared route."
	)
	_expect(
		run.get_backtrack_route(&"upper_event")
		== [
			&"lower_2",
			&"lower_1",
			&"start",
			&"upper_1",
			&"upper_event",
		],
		"Free backtracking should reconstruct the full explored route."
	)
	run.travel_to(&"upper_event")
	_expect(
		run.current_node_id == &"upper_event"
		and run.pending_node_id == &"",
		"Backtracking to a cleared Event should not rerun its resolution."
	)
	_expect(
		run.can_travel_to(&"upper_unknown"),
		"The unexplored node after the cleared Event should become "
		+ "available after branch switching."
	)
	_expect(
		not run.can_travel_to(&"lower_unknown"),
		"Free backtracking must not jump across an unexplored route."
	)


func _test_encounter_outcome_and_first_clear_reward() -> void:
	var graph: LayerMapGraph = (
		LayerMapGenerator.new().generate_layer_1(8877)
	)
	var run: RunState = RunState.new()
	run.initialize(8877, graph)
	run.opening_completed = true
	var battle_route: Array[StringName] = _find_battle_route(run.graph)
	_expect(
		not battle_route.is_empty(),
		"Generated graph should expose a reachable battle route."
	)
	if battle_route.is_empty():
		return
	for node_id: StringName in battle_route:
		run.travel_to(node_id)
		var route_node: MapNodeState = graph.get_map_node(node_id)
		if not route_node.requires_battle():
			run.complete_pending_node(0)
	var battle_id: StringName = battle_route.back()
	var encounter: EncounterDefinition = run.make_encounter_definition()
	_expect(
		encounter != null
		and encounter.source_node_id == battle_id,
		"Battle nodes should create stable encounter definitions."
	)
	var outcome: EncounterOutcome = EncounterOutcome.new()
	outcome.result = EncounterOutcome.Result.VICTORY
	outcome.encounter_id = encounter.encounter_id
	outcome.source_node_id = battle_id
	outcome.bloom_reward = 4
	outcome.party_snapshot = {&"lysandra": {"hp": 5}}
	outcome.inventory_snapshot = _empty_item_bar_snapshot()
	outcome.inventory_snapshot[0] = {
		"slot_index": 0,
		"item_id": "l01_bandage_roll",
		"quantity": 1,
	}
	var apply_error: String = run.apply_encounter_outcome(outcome)
	_expect(
		apply_error.is_empty(),
		"Encounter outcome fixture should restore valid snapshots: %s"
		% apply_error
	)
	_expect(
		run.bloom == 4
		and graph.get_map_node(battle_id).reward_claimed,
		"Victory should apply the first-clear reward exactly once."
	)
	_expect(
		run.party_snapshot.has(&"lysandra")
		and run.inventory_snapshot.size() == 6
		and StringName(run.inventory_snapshot[0].get("item_id", ""))
		== &"l01_bandage_roll",
		"Encounter return should preserve party and inventory snapshots."
	)


func _full_party_snapshot() -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(10, 4, 75, 8),
		&"mira": _heroine_snapshot(9, 6, 72, 12),
		&"seraphine": _heroine_snapshot(8, 8, 80, 4),
	}


func _heroine_snapshot(
	hp: int,
	mp: int,
	resolve: int,
	corruption: int
) -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"resolve": resolve,
		"corruption": corruption,
		"item_guard": 0,
		"weapon_damage": 0,
		"weapon_broken": false,
		"armor_damage": 0,
		"armor_broken": false,
		"shield_damage": 0,
		"shield_broken": false,
	}


func _empty_item_bar_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for slot_index: int in range(6):
		snapshot.append({
			"slot_index": slot_index,
			"item_id": "",
			"quantity": 0,
		})
	return snapshot


func _test_main_map_battle_launch_contract() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/map/main_controller.gd"
	)
	_expect(
		"active_battle.base_seed = encounter.encounter_seed" in source,
		"The Node Map must pass its seed through CombatEncounter.base_seed."
	)
	_expect(
		"active_battle.test_seed" not in source,
		"The removed sandbox test_seed property must not block map battles."
	)


func _find_battle_route(graph: LayerMapGraph) -> Array[StringName]:
	var frontier: Array[Dictionary] = [{
		"node_id": graph.start_node_id,
		"route": [],
	}]
	var visited: Dictionary = {}
	while not frontier.is_empty():
		var entry: Dictionary = frontier.pop_front()
		var node_id: StringName = entry["node_id"]
		if visited.has(node_id):
			continue
		visited[node_id] = true
		var node: MapNodeState = graph.get_map_node(node_id)
		var route: Array[StringName] = []
		for route_id: StringName in entry["route"]:
			route.append(route_id)
		if node_id != graph.start_node_id and node.requires_battle():
			return route
		for next_id: StringName in node.outgoing_ids:
			var next_route: Array[StringName] = route.duplicate()
			next_route.append(next_id)
			frontier.append({
				"node_id": next_id,
				"route": next_route,
			})
	return []


func _make_branch_backtracking_graph() -> LayerMapGraph:
	var graph: LayerMapGraph = LayerMapGraph.new()
	graph.column_count = 5
	var specifications: Array[Dictionary] = [
		{
			"id": &"start",
			"column": 0,
			"row": 0,
			"type": MapNodeState.NodeType.START,
			"visited": true,
			"cleared": true,
		},
		{
			"id": &"upper_1",
			"column": 1,
			"row": 0,
			"type": MapNodeState.NodeType.ROOM,
			"visited": true,
			"cleared": true,
		},
		{
			"id": &"lower_1",
			"column": 1,
			"row": 1,
			"type": MapNodeState.NodeType.BATTLE,
		},
		{
			"id": &"upper_event",
			"column": 2,
			"row": 0,
			"type": MapNodeState.NodeType.EVENT,
			"visited": true,
			"cleared": true,
		},
		{
			"id": &"lower_2",
			"column": 2,
			"row": 1,
			"type": MapNodeState.NodeType.ITEM,
		},
		{
			"id": &"backward_unknown",
			"column": 2,
			"row": 2,
			"type": MapNodeState.NodeType.ROOM,
		},
		{
			"id": &"upper_unknown",
			"column": 3,
			"row": 0,
			"type": MapNodeState.NodeType.ROOM,
		},
		{
			"id": &"lower_3",
			"column": 3,
			"row": 1,
			"type": MapNodeState.NodeType.ITEM,
		},
		{
			"id": &"lower_unknown",
			"column": 3,
			"row": 2,
			"type": MapNodeState.NodeType.EVENT,
		},
		{
			"id": &"boss",
			"column": 4,
			"row": 0,
			"type": MapNodeState.NodeType.BOSS,
		},
	]
	for specification: Dictionary in specifications:
		var node: MapNodeState = MapNodeState.new()
		node.node_id = specification["id"]
		node.column = specification["column"]
		node.row = specification["row"]
		node.node_type = specification["type"]
		node.display_name = String(specification["id"])
		node.visited = bool(specification.get("visited", false))
		node.cleared = bool(specification.get("cleared", false))
		graph.add_node(node)
	graph.start_node_id = &"start"
	graph.boss_node_id = &"boss"
	graph.connect_nodes(&"start", &"upper_1")
	graph.connect_nodes(&"start", &"lower_1")
	graph.connect_nodes(&"upper_1", &"upper_event")
	graph.connect_nodes(&"lower_1", &"lower_2")
	graph.connect_nodes(&"lower_1", &"backward_unknown")
	graph.connect_nodes(&"upper_event", &"upper_unknown")
	graph.connect_nodes(&"lower_2", &"lower_3")
	graph.connect_nodes(&"backward_unknown", &"lower_3")
	graph.connect_nodes(&"lower_2", &"lower_unknown")
	graph.connect_nodes(&"upper_unknown", &"boss")
	graph.connect_nodes(&"lower_3", &"boss")
	graph.connect_nodes(&"lower_unknown", &"boss")
	return graph


func _graph_signature(graph: LayerMapGraph) -> String:
	var parts: PackedStringArray = []
	for column: int in range(graph.column_count):
		for node: MapNodeState in graph.get_nodes_in_column(column):
			var outgoing_text: PackedStringArray = []
			for outgoing_id: StringName in node.outgoing_ids:
				outgoing_text.append(String(outgoing_id))
			parts.append(
				"%s:%d:%s:%s"
				% [
					node.node_id,
					node.node_type,
					node.encounter_template_id,
					",".join(outgoing_text),
				]
			)
	return "|".join(parts)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
