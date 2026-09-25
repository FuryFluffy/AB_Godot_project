class_name LayerMapGenerator
extends RefCounted


const COLUMN_COUNT: int = 7
const MIN_PLAYABLE_NODES: int = 10
const MAX_PLAYABLE_NODES: int = 13
const ROOM_CATALOG: LayerRoomCatalogDefinition = preload(
	"res://data/rooms/layer_1_2_room_catalog.tres"
)
const LAYER_1_RUSTY_KEY_REWARD_SOURCE: RoomLootSourceDefinition = preload(
	"res://data/rewards/sources/layer1_rusty_key.tres"
)
const SERAPHINE_RECRUITMENT_ENCOUNTER_ID: StringName = (
	&"layer_1_seraphine_ruined_chapel"
)
const JAILER_FIRST_ENCOUNTER_ID: StringName = (
	&"layer_2_jailer_first_containment"
)
const JAILER_BOSS_ID: StringName = JAILER_FIRST_ENCOUNTER_ID
const BLOOD_NUN_BOSS_ID: StringName = &"layer_1_blood_nun"
const LAYER_2_FIRST_SLICE_ENCOUNTER_ID: StringName = (
	&"layer_2_farthest_cell_kept_watch"
)
const LAYER_1_EVENT_ROOM_POOL: Array[StringName] = [
	&"wine_cellar_warm_bottles",
	&"butlers_office",
	&"wax_prep_room",
]
const DINING_SERVICE_HALL_ROOM_ID: StringName = &"dining_service_hall"
const DINING_SERVICE_HALL_ENCOUNTER_ID: StringName = (
	&"layer_1_dining_service_hall"
)
const DINING_SERVICE_HALL_TEMPLATE_ID: StringName = (
	&"dining_service_hall_regular"
)

var room_catalog: LayerRoomCatalogDefinition
var last_generation_error: String = ""


func _init(
	authored_room_catalog: LayerRoomCatalogDefinition = ROOM_CATALOG
) -> void:
	room_catalog = authored_room_catalog


func generate_layer_1(
	run_seed: int,
	defeated_boss_ids: Array[StringName] = []
) -> LayerMapGraph:
	last_generation_error = ""
	var preparation: Dictionary = _prepare_layer_1_rooms(run_seed)
	if not String(preparation.get("error", "")).is_empty():
		last_generation_error = String(preparation.get("error"))
		return null
	var rng := _make_layer_rng(run_seed, &"layer_1")
	var graph: LayerMapGraph = LayerMapGraph.new()
	graph.layer_id = &"layer_1"
	graph.layer_number = 1
	graph.display_name = "Layer 1 — Lower Castle Route"
	graph.run_seed = run_seed
	graph.column_count = COLUMN_COUNT

	var start_room: LayerRoomDefinition = preparation.get("start") as LayerRoomDefinition
	var start: MapNodeState = _make_registered_node(
		&"l1_c0_n0",
		0,
		0,
		MapNodeState.NodeType.START,
		start_room,
		run_seed,
		graph.layer_id
	)
	start.visited = true
	start.cleared = true
	start.reward_claimed = true
	graph.add_node(start)
	graph.start_node_id = start.node_id

	var first_room: LayerRoomDefinition = preparation.get("first_battle") as LayerRoomDefinition
	var first_node := _make_registered_node(
		&"l1_c1_n0", 1, 0, MapNodeState.NodeType.BATTLE,
		first_room, run_seed, graph.layer_id
	)
	first_node.display_name = "Corrupted Butler — False Welcome"
	first_node.encounter_id = &"layer_1_corrupted_butler_opening"
	first_node.encounter_template_id = &"lower_kitchen_regular"
	graph.add_node(first_node)

	var middle_rooms: Array[LayerRoomDefinition] = preparation.get("middle_rooms")
	var middle_index: int = 0
	var middle_counts: Array[int] = preparation.get("middle_counts")
	for column_offset: int in range(middle_counts.size()):
		var column: int = column_offset + 2
		for row: int in range(middle_counts[column_offset]):
			var room: LayerRoomDefinition = middle_rooms[middle_index]
			middle_index += 1
			var node := _make_registered_node(
				StringName("l1_c%d_n%d" % [column, row]),
				column,
				row,
				_get_layer_1_room_node_type(room),
				room,
				run_seed,
				graph.layer_id
			)
			_configure_registered_layer_1_content(node, room)
			graph.add_node(node)

	var chapel_room: LayerRoomDefinition = preparation.get("pre_exit") as LayerRoomDefinition
	var chapel := _make_registered_node(
		&"l1_c5_n0", 5, 0, MapNodeState.NodeType.BATTLE,
		chapel_room, run_seed, graph.layer_id
	)
	chapel.display_name = "Ruined Chapel — False Prayer"
	chapel.encounter_id = SERAPHINE_RECRUITMENT_ENCOUNTER_ID
	chapel.encounter_template_id = &"ruined_chapel_regular"
	graph.add_node(chapel)

	var boss_room: LayerRoomDefinition = preparation.get("exit") as LayerRoomDefinition
	var boss: MapNodeState = _make_registered_node(
		&"l1_c6_n0",
		COLUMN_COUNT - 1,
		0,
		MapNodeState.NodeType.BOSS,
		boss_room,
		run_seed,
		graph.layer_id
	)
	boss.encounter_id = &"layer_1_blood_nun"
	boss.encounter_template_id = &"blood_nun_processing_chapel_boss"
	if defeated_boss_ids.has(BLOOD_NUN_BOSS_ID):
		boss.display_name = "Cleared Processing Chapel"
		boss.encounter_id = &""
		boss.encounter_template_id = &""
		boss.cleared = true
		boss.reward_claimed = true
	graph.add_node(boss)
	graph.boss_node_id = boss.node_id

	_connect_generated_columns(graph, rng)
	last_generation_error = validate_generated_layer(graph)
	if not last_generation_error.is_empty():
		return null
	return graph


func generate_layer_2_entry(run_seed: int) -> LayerMapGraph:
	last_generation_error = ""
	# The downward stair from the Blood Nun chamber reaches Layer 2 at its
	# EXIT end. The player does not enter an intake corridor or begin ordinary
	# Dungeon exploration here; the Jailer is waiting at the foot of the stair.
	var graph := LayerMapGraph.new()
	graph.layer_id = &"layer_2"
	graph.layer_number = 2
	graph.display_name = "Layer 2 — The Dungeon Exit"
	graph.run_seed = run_seed
	graph.column_count = 2

	var threshold_room: LayerRoomDefinition = _get_single_tagged_room(2, &"pre_boss")
	var boss_room: LayerRoomDefinition = _get_single_tagged_room(2, &"boss")
	if threshold_room == null or boss_room == null:
		last_generation_error = "Layer 2 registry is missing its pre-boss or boss role."
		return null
	var threshold := _make_registered_node(
		&"l2_jailer_threshold",
		0,
		0,
		MapNodeState.NodeType.START,
		threshold_room,
		run_seed,
		graph.layer_id
	)
	threshold.display_name = "Stair Beneath the Processing Chapel"
	threshold.visited = true
	threshold.cleared = true
	threshold.reward_claimed = true
	graph.add_node(threshold)
	graph.start_node_id = threshold.node_id

	var jailer := _make_registered_node(
		&"l2_jailer_first_encounter",
		1,
		0,
		MapNodeState.NodeType.BOSS,
		boss_room,
		run_seed,
		graph.layer_id
	)
	jailer.display_name = "The Jailer — Containment Landing"
	jailer.encounter_id = &"layer_2_jailer_first_containment"
	jailer.encounter_template_id = &"jailer_containment_landing_boss"
	graph.add_node(jailer)
	graph.boss_node_id = jailer.node_id
	graph.connect_nodes(threshold.node_id, jailer.node_id)
	return graph


func generate_layer_3_entry(run_seed: int) -> LayerMapGraph:
	# The upward stair skips Layer 2 and reaches the harder Layer 3 route.
	# Only its threshold is exposed until that layer receives a content pass.
	var graph := LayerMapGraph.new()
	graph.layer_id = &"layer_3"
	graph.layer_number = 3
	graph.display_name = "Layer 3 — Lower Halls Threshold"
	graph.run_seed = run_seed
	graph.column_count = 2

	var threshold := _make_node(
		&"l3_lower_halls_threshold",
		0,
		0,
		MapNodeState.NodeType.START,
		"Lower Halls Threshold"
	)
	threshold.visited = true
	threshold.cleared = true
	threshold.reward_claimed = true
	graph.add_node(threshold)
	graph.start_node_id = threshold.node_id

	var content_gate := _make_node(
		&"l3_content_gate",
		1,
		0,
		MapNodeState.NodeType.BOSS,
		"The Harder Route Beyond"
	)
	content_gate.travel_enabled = false
	content_gate.locked_reason = (
		"Go Up reaches Layer 3. Its encounters begin in a later content "
		+ "milestone."
	)
	graph.add_node(content_gate)
	graph.boss_node_id = content_gate.node_id
	graph.connect_nodes(threshold.node_id, content_gate.node_id)
	return graph


func generate_bloom_refuge_holding_state(run_seed: int) -> LayerMapGraph:
	last_generation_error = ""
	# This tiny graph is a lifecycle boundary, not the future Layer 2 layout.
	# It gives RunState a valid active location while the dedicated Refuge UI
	# remains open after the origin dialogue.
	var graph := LayerMapGraph.new()
	graph.layer_id = &"bloom_refuge"
	graph.layer_number = 2
	graph.display_name = "Bloom Refuge — Farthest Cell"
	graph.run_seed = run_seed
	graph.column_count = 2

	var refuge_room: LayerRoomDefinition = _get_single_tagged_room(2, &"refuge_origin")
	var gate_room: LayerRoomDefinition = _get_single_tagged_room(2, &"pre_boss")
	if refuge_room == null or gate_room == null:
		last_generation_error = "Layer 2 registry is missing its Refuge or pre-boss role."
		return null
	var refuge := _make_registered_node(
		&"bloom_refuge_farthest_cell",
		0,
		0,
		MapNodeState.NodeType.START,
		refuge_room,
		run_seed,
		graph.layer_id
	)
	refuge.display_name = "Bloom Refuge — Farthest Cell"
	refuge.visited = true
	refuge.cleared = true
	refuge.reward_claimed = true
	graph.add_node(refuge)
	graph.start_node_id = refuge.node_id

	var next_run_gate := _make_registered_node(
		&"bloom_refuge_next_run_gate",
		1,
		0,
		MapNodeState.NodeType.BOSS,
		gate_room,
		run_seed,
		graph.layer_id
	)
	next_run_gate.display_name = "Layer 2 Preparation"
	next_run_gate.travel_enabled = false
	next_run_gate.locked_reason = (
		"The dedicated Refuge hub owns preparation and the next-run launch."
	)
	graph.add_node(next_run_gate)
	graph.boss_node_id = next_run_gate.node_id
	graph.connect_nodes(refuge.node_id, next_run_gate.node_id)
	return graph


func generate_layer_2_run(
	run_seed: int,
	defeated_boss_ids: Array[StringName] = []
) -> LayerMapGraph:
	last_generation_error = ""
	var preparation: Dictionary = _prepare_layer_2_rooms(run_seed)
	if not String(preparation.get("error", "")).is_empty():
		last_generation_error = String(preparation.get("error"))
		return null
	var rng := _make_layer_rng(run_seed, &"layer_2")
	var graph := LayerMapGraph.new()
	graph.layer_id = &"layer_2"
	graph.layer_number = 2
	graph.display_name = "Layer 2 — The Dungeon"
	graph.run_seed = run_seed
	graph.column_count = COLUMN_COUNT

	var start_room: LayerRoomDefinition = preparation.get("start") as LayerRoomDefinition
	var refuge_gate := _make_registered_node(
		&"l2_refuge_farthest_cell",
		0,
		0,
		MapNodeState.NodeType.START,
		start_room,
		run_seed,
		graph.layer_id
	)
	refuge_gate.display_name = "Bloom Refuge — Farthest Cell"
	refuge_gate.visited = true
	refuge_gate.cleared = true
	refuge_gate.reward_claimed = true
	graph.add_node(refuge_gate)
	graph.start_node_id = refuge_gate.node_id

	var first_room: LayerRoomDefinition = preparation.get("first_battle") as LayerRoomDefinition
	var first_node := _make_registered_node(
		&"l2_c1_n0", 1, 0, MapNodeState.NodeType.BATTLE,
		first_room, run_seed, graph.layer_id
	)
	first_node.display_name = "Farthest Cell Passage — Kept Watch"
	first_node.encounter_id = LAYER_2_FIRST_SLICE_ENCOUNTER_ID
	first_node.encounter_template_id = &"layer_2_chain_maintenance_regular"
	first_node.reward_source_id = &"l02_kept_watch_chain_oil"
	graph.add_node(first_node)

	var middle_rooms: Array[LayerRoomDefinition] = preparation.get("middle_rooms")
	var middle_index: int = 0
	var middle_counts: Array[int] = preparation.get("middle_counts")
	for column_offset: int in range(middle_counts.size()):
		var column: int = column_offset + 2
		for row: int in range(middle_counts[column_offset]):
			var room: LayerRoomDefinition = middle_rooms[middle_index]
			middle_index += 1
			var node := _make_registered_node(
				StringName("l2_c%d_n%d" % [column, row]),
				column,
				row,
				MapNodeState.NodeType.ROOM,
				room,
				run_seed,
				graph.layer_id
			)
			_configure_registered_room_content(node, room)
			graph.add_node(node)

	var gate_room: LayerRoomDefinition = preparation.get("pre_exit") as LayerRoomDefinition
	var gate_node := _make_registered_node(
		&"l2_c5_n0", 5, 0, MapNodeState.NodeType.ROOM,
		gate_room, run_seed, graph.layer_id
	)
	_configure_registered_room_content(gate_node, gate_room)
	graph.add_node(gate_node)

	var boss_room: LayerRoomDefinition = preparation.get("exit") as LayerRoomDefinition
	var jailer := _make_registered_node(
		&"l2_jailer_first_encounter",
		COLUMN_COUNT - 1,
		0,
		MapNodeState.NodeType.BOSS,
		boss_room,
		run_seed,
		graph.layer_id
	)
	jailer.display_name = "The Jailer — Dungeon Exit"
	jailer.encounter_id = JAILER_FIRST_ENCOUNTER_ID
	jailer.encounter_template_id = &"jailer_containment_landing_boss"
	if defeated_boss_ids.has(JAILER_BOSS_ID):
		jailer.display_name = "Cleared Dungeon Exit"
		jailer.encounter_id = &""
		jailer.encounter_template_id = &""
		jailer.cleared = true
		jailer.reward_claimed = true
	graph.add_node(jailer)
	graph.boss_node_id = jailer.node_id
	_connect_generated_columns(graph, rng)
	last_generation_error = validate_generated_layer(graph)
	if not last_generation_error.is_empty():
		return null
	return graph


func generate_refugeless_reverse_layer_2(
	run_seed: int,
	defeated_boss_ids: Array[StringName] = []
) -> LayerMapGraph:
	# Reuse the registered-room topology verbatim. RunState enters this graph at
	# its cleared boss node, and its reciprocal traversal rules carry the
	# surviving Refuge-less party back toward the farthest-cell start node.
	var resolved_boss_ids: Array[StringName] = defeated_boss_ids.duplicate()
	if not resolved_boss_ids.has(JAILER_BOSS_ID):
		resolved_boss_ids.append(JAILER_BOSS_ID)
	var graph: LayerMapGraph = generate_layer_2_run(
		run_seed,
		resolved_boss_ids
	)
	if graph != null:
		graph.display_name = "Layer 2 — Return to the Farthest Cell"
	return graph


func make_layer_1_generated_room_item_rules(
) -> Array[GeneratedRoomItemPlacementRule]:
	var wine_cellar_candidate := (
		GeneratedRoomItemHostCandidate.new()
	)

	wine_cellar_candidate.room_definition_id = (
		&"wine_cellar_warm_bottles"
	)

	wine_cellar_candidate.access_policy = (
		GeneratedRoomItemHostCandidate
			.AccessPolicy
			.NORMALLY_REACHABLE
	)

	var office_candidate := (
		GeneratedRoomItemHostCandidate.new()
	)

	office_candidate.room_definition_id = (
		&"butlers_office"
	)

	office_candidate.access_policy = (
		GeneratedRoomItemHostCandidate
			.AccessPolicy
			.REACHABLE_WITHOUT_BLOCKING_ROOM
	)

	office_candidate.blocking_room_definition_id = (
		&"wine_cellar_warm_bottles"
	)

	var candidates: Array[GeneratedRoomItemHostCandidate] = [
		wine_cellar_candidate,
		office_candidate,
	]

	var rusty_key_rule := (
		GeneratedRoomItemPlacementRule.new()
	)

	rusty_key_rule.assignment_id = (
		&"layer_1_rusty_key_01"
	)

	rusty_key_rule.reward_source = LAYER_1_RUSTY_KEY_REWARD_SOURCE

	rusty_key_rule.required_anchor_tag = (
		&"key_accessible"
	)

	rusty_key_rule.candidates = candidates

	var rules: Array[GeneratedRoomItemPlacementRule] = [
		rusty_key_rule,
	]

	return rules


func _prepare_layer_1_rooms(run_seed: int) -> Dictionary:
	var common_error: String = _validate_generation_inputs(run_seed, 1)
	if not common_error.is_empty():
		return {"error": common_error}
	var start: LayerRoomDefinition = _get_single_tagged_room(1, &"start")
	var pre_exit: LayerRoomDefinition = _get_single_tagged_room(1, &"recruitment")
	var exit: LayerRoomDefinition = _get_single_tagged_room(1, &"boss")
	if start == null or pre_exit == null or exit == null:
		return {"error": "Layer 1 registry is missing its unique start, recruitment, or boss role."}
	var event_rooms: Array[LayerRoomDefinition] = []
	for room_id: StringName in LAYER_1_EVENT_ROOM_POOL:
		var event_room: LayerRoomDefinition = room_catalog.get_room(room_id)
		if (
			event_room == null
			or event_room.layer_number != 1
			or event_room.exploration_definition == null
		):
			return {"error": "Layer 1 required Event room '%s' is not executable." % room_id}
		event_rooms.append(event_room)
	var excluded: Dictionary = _make_room_set([start, pre_exit, exit])
	for event_room: LayerRoomDefinition in event_rooms:
		excluded[event_room.room_id] = true
	var rng := _make_layer_rng(run_seed, &"layer_1_selection")
	var first_battle: LayerRoomDefinition = room_catalog.get_room(
		&"lower_kitchen"
	)
	if (
		first_battle == null
		or first_battle.layer_number != 1
		or not first_battle.strong_battle_candidate
		or first_battle.production_battlefields.is_empty()
	):
		return {"error": "Layer 1 registry is missing the authored Lower Kitchen recruitment battle room."}
	excluded[first_battle.room_id] = true
	var middle_counts: Array[int] = [
		3,
		2 + rng.randi_range(0, 1),
		2 + rng.randi_range(0, 1),
	]
	var middle_size: int = middle_counts[0] + middle_counts[1] + middle_counts[2]
	_shuffle_rooms(event_rooms, rng)
	var middle_rooms: Array[LayerRoomDefinition] = event_rooms.duplicate()
	var fillers: Array[LayerRoomDefinition] = _get_generic_candidates(1, excluded)
	_shuffle_rooms(fillers, rng)
	var filler_count: int = middle_size - middle_rooms.size()
	if fillers.size() < filler_count:
		return {"error": "Layer 1 registry has only %d safe filler rooms; %d are required." % [fillers.size(), filler_count]}
	for index: int in range(filler_count):
		middle_rooms.append(fillers[index])
	return {
		"error": "", "start": start, "first_battle": first_battle,
		"middle_rooms": middle_rooms, "middle_counts": middle_counts,
		"pre_exit": pre_exit, "exit": exit,
	}


func _prepare_layer_2_rooms(run_seed: int) -> Dictionary:
	var common_error: String = _validate_generation_inputs(run_seed, 2)
	if not common_error.is_empty():
		return {"error": common_error}
	var start: LayerRoomDefinition = _get_single_tagged_room(2, &"refuge_origin")
	var pre_exit: LayerRoomDefinition = _get_single_tagged_room(2, &"pre_boss")
	var exit: LayerRoomDefinition = _get_single_tagged_room(2, &"boss")
	var first_battle: LayerRoomDefinition
	for room: LayerRoomDefinition in room_catalog.get_rooms_for_layer(2):
		if room.production_battlefields.size() > 0 and not room.authoring_tags.has(&"boss"):
			if first_battle != null:
				return {"error": "Layer 2 registry has multiple non-boss production battle rooms."}
			first_battle = room
	if start == null or pre_exit == null or exit == null or first_battle == null:
		return {"error": "Layer 2 registry is missing its Refuge, first battle, pre-boss, or boss role."}
	var excluded: Dictionary = _make_room_set([start, first_battle, pre_exit, exit])
	var rng := _make_layer_rng(run_seed, &"layer_2_selection")
	var middle_counts: Array[int] = [
		3,
		2 + rng.randi_range(0, 1),
		2 + rng.randi_range(0, 1),
	]
	var middle_size: int = middle_counts[0] + middle_counts[1] + middle_counts[2]
	var middle_rooms: Array[LayerRoomDefinition] = _get_generic_candidates(2, excluded)
	_shuffle_rooms(middle_rooms, rng)
	if middle_rooms.size() < middle_size:
		return {"error": "Layer 2 registry has only %d safe filler rooms; %d are required." % [middle_rooms.size(), middle_size]}
	middle_rooms.resize(middle_size)
	return {
		"error": "", "start": start, "first_battle": first_battle,
		"middle_rooms": middle_rooms, "middle_counts": middle_counts,
		"pre_exit": pre_exit, "exit": exit,
	}


func _validate_generation_inputs(run_seed: int, layer_number: int) -> String:
	if run_seed <= 0:
		return "Layer %d generation requires a positive campaign-derived seed." % layer_number
	if room_catalog == null:
		return "Layer %d generation requires the authored room registry." % layer_number
	var catalog_error: String = room_catalog.validate_catalog()
	if not catalog_error.is_empty():
		return catalog_error
	if room_catalog.get_rooms_for_layer(layer_number).size() < MIN_PLAYABLE_NODES:
		return "Layer %d registry has insufficient authored rooms." % layer_number
	return ""


func _get_single_tagged_room(
	layer_number: int,
	tag: StringName
) -> LayerRoomDefinition:
	if room_catalog == null:
		return null
	var selected_room: LayerRoomDefinition
	for room: LayerRoomDefinition in room_catalog.get_rooms_for_layer(layer_number):
		if not room.authoring_tags.has(tag):
			continue
		if selected_room != null:
			return null
		selected_room = room
	return selected_room


func _get_generic_candidates(
	layer_number: int,
	excluded: Dictionary
) -> Array[LayerRoomDefinition]:
	var candidates: Array[LayerRoomDefinition] = []
	for room: LayerRoomDefinition in room_catalog.get_rooms_for_layer(layer_number):
		if excluded.has(room.room_id) or room.has_pending_art():
			continue
		if _room_has_any_tag(room, [
			&"boss", &"start", &"recruitment", &"refuge_origin",
			&"pre_boss", &"required_narrative", &"event",
		]):
			continue
		candidates.append(room)
	return candidates


func _room_has_any_tag(
	room: LayerRoomDefinition,
	tags: Array[StringName]
) -> bool:
	for tag: StringName in tags:
		if room.authoring_tags.has(tag):
			return true
	return false


func _make_room_set(rooms: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in rooms:
		var room: LayerRoomDefinition = value as LayerRoomDefinition
		if room != null:
			result[room.room_id] = true
	return result


func _shuffle_rooms(
	rooms: Array[LayerRoomDefinition],
	rng: RandomNumberGenerator
) -> void:
	for index: int in range(rooms.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: LayerRoomDefinition = rooms[index]
		rooms[index] = rooms[swap_index]
		rooms[swap_index] = temporary


func _make_layer_rng(run_seed: int, namespace_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = StableSeedMixer.make_seed(
		run_seed,
		&"authored_layer_generator",
		namespace_id
	)
	return rng


func _connect_generated_columns(
	graph: LayerMapGraph,
	rng: RandomNumberGenerator
) -> void:
	for column: int in range(graph.column_count - 1):
		var left: Array[MapNodeState] = graph.get_nodes_in_column(column)
		var right: Array[MapNodeState] = graph.get_nodes_in_column(column + 1)
		if left.is_empty() or right.is_empty():
			continue
		if column == 1:
			for right_node: MapNodeState in right:
				graph.connect_nodes(left[0].node_id, right_node.node_id)
			continue
		if column == graph.column_count - 3:
			for left_node: MapNodeState in left:
				graph.connect_nodes(left_node.node_id, right[0].node_id)
			continue
		for left_index: int in range(left.size()):
			var nearest_index: int = mini(left_index, right.size() - 1)
			graph.connect_nodes(left[left_index].node_id, right[nearest_index].node_id)
			if right.size() > 1 and rng.randi_range(0, 1) == 1:
				var alternate: int = (nearest_index + 1) % right.size()
				graph.connect_nodes(left[left_index].node_id, right[alternate].node_id)
		for right_node: MapNodeState in right:
			if right_node.incoming_ids.is_empty():
				var source: MapNodeState = left[rng.randi_range(0, left.size() - 1)]
				graph.connect_nodes(source.node_id, right_node.node_id)


func _make_registered_node(
	node_id: StringName,
	column: int,
	row: int,
	node_type: MapNodeState.NodeType,
	room: LayerRoomDefinition,
	run_seed: int,
	layer_id: StringName
) -> MapNodeState:
	var node := _make_node(node_id, column, row, node_type, room.display_name)
	node.authored_room_id = room.room_id
	node.content_seed = StableSeedMixer.make_seed(
		run_seed,
		&"generated_map_node",
		StringName("%s:%s:%s" % [layer_id, node_id, room.room_id])
	)
	return node


func _get_layer_1_room_node_type(
	_room: LayerRoomDefinition
) -> MapNodeState.NodeType:
	# Battles remain explicit route or room-encounter bindings. A completed
	# exploration presentation never turns a filler room into a generic battle.
	return MapNodeState.NodeType.ROOM


func _configure_registered_layer_1_content(
	node: MapNodeState,
	room: LayerRoomDefinition
) -> void:
	_configure_registered_room_content(node, room)
	if room.room_id == DINING_SERVICE_HALL_ROOM_ID:
		node.encounter_id = DINING_SERVICE_HALL_ENCOUNTER_ID
		node.encounter_template_id = DINING_SERVICE_HALL_TEMPLATE_ID


func _configure_registered_room_content(
	node: MapNodeState,
	room: LayerRoomDefinition
) -> void:
	if node == null or room == null or room.exploration_definition == null:
		return
	node.room_definition_id = room.room_id
	match room.room_id:
		&"wax_prep_room":
			node.reward_source_id = &"l01_wax_prep_red_wax_material"
		&"linen_sorting_room":
			node.reward_source_id = &"l01_linen_sorting_servant_cloth"
		&"polished_shackle_gallery":
			node.reward_source_id = &"l02_polished_gallery_chain_links"
		&"punishment_mechanism_room":
			node.reward_source_id = &"l02_punishment_room_prison_iron"


func validate_generated_layer(graph: LayerMapGraph) -> String:
	if graph == null or graph.layer_id not in [&"layer_1", &"layer_2"]:
		return "Authored generator validation requires a Layer 1 or Layer 2 graph."
	if room_catalog == null:
		return "Authored generator validation requires the room registry."
	var graph_error: String = graph.validate_graph()
	if not graph_error.is_empty():
		return graph_error
	var playable_count: int = 0
	var used_rooms: Dictionary = {}
	var has_branch: bool = false
	var has_convergence: bool = false
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		if node.node_type != MapNodeState.NodeType.START:
			playable_count += 1
		if node.authored_room_id == &"" or node.content_seed <= 0:
			return "Generated node '%s' lacks authored room identity or content seed." % node.node_id
		var room: LayerRoomDefinition = room_catalog.get_room(node.authored_room_id)
		if room == null or room.layer_number != graph.layer_number:
			return "Generated node '%s' uses an unregistered Layer %d room." % [node.node_id, graph.layer_number]
		if used_rooms.has(node.authored_room_id):
			return "Generated layer duplicates authored room '%s'." % node.authored_room_id
		used_rooms[node.authored_room_id] = true
		if not node.travel_enabled:
			return "Generated node '%s' is not traversable." % node.node_id
		for next_id: StringName in node.outgoing_ids:
			var next_node: MapNodeState = graph.get_map_node(next_id)
			if (
				next_node == null
				or next_node == node
				or next_node.column != node.column + 1
				or not next_node.incoming_ids.has(node.node_id)
			):
				return "Generated node '%s' has an invalid outgoing edge." % node.node_id
		for previous_id: StringName in node.incoming_ids:
			var previous_node: MapNodeState = graph.get_map_node(previous_id)
			if (
				previous_node == null
				or previous_node == node
				or previous_node.column != node.column - 1
				or not previous_node.outgoing_ids.has(node.node_id)
			):
				return "Generated node '%s' has an invalid incoming edge." % node.node_id
		has_branch = has_branch or node.outgoing_ids.size() > 1
		has_convergence = has_convergence or (
			node.node_id != graph.boss_node_id and node.incoming_ids.size() > 1
		)
	if playable_count < MIN_PLAYABLE_NODES or playable_count > MAX_PLAYABLE_NODES:
		return "Generated Layer %d has %d playable nodes; expected %d–%d." % [graph.layer_number, playable_count, MIN_PLAYABLE_NODES, MAX_PLAYABLE_NODES]
	if not has_branch or not has_convergence:
		return "Generated layer requires a genuine branch and pre-exit convergence."
	var required_rooms: Array[StringName] = []
	if graph.layer_id == &"layer_1":
		required_rooms.assign([
			&"opening_servant_corridor",
			&"wine_cellar_warm_bottles",
			&"butlers_office",
			&"wax_prep_room",
			&"ruined_chapel",
			&"blood_nun_processing_chapel",
		])
	else:
		required_rooms.assign([
			&"farthest_cell",
			&"chain_maintenance_room",
			&"jailers_gate_hall",
			&"jailers_containment_hall",
		])
	for room_id: StringName in required_rooms:
		if not used_rooms.has(room_id):
			return "Generated Layer %d omits required authored room '%s'." % [graph.layer_number, room_id]
	var reachable: Dictionary = _collect_reachable_ids(graph, graph.start_node_id, false)
	if reachable.size() != graph.nodes.size():
		return "Generated layer contains an inaccessible selected room."
	var reverse_reachable: Dictionary = _collect_reachable_ids(graph, graph.boss_node_id, true)
	if reverse_reachable.size() != graph.nodes.size():
		return "Generated layer contains a branch that cannot reach the exit route."
	var required_gate_ids: Array[StringName] = []
	if graph.layer_id == &"layer_1":
		required_gate_ids.assign([&"l1_c1_n0", &"l1_c5_n0"])
	else:
		required_gate_ids.assign([&"l2_c1_n0", &"l2_c5_n0"])
	for gate_id: StringName in required_gate_ids:
		if _can_reach_while_avoiding(graph, graph.boss_node_id, gate_id):
			return "Generated layer can bypass required gate '%s'." % gate_id
	return ""


func _collect_reachable_ids(
	graph: LayerMapGraph,
	start_id: StringName,
	reverse: bool
) -> Dictionary:
	var visited: Dictionary = {}
	var frontier: Array[StringName] = [start_id]
	while not frontier.is_empty():
		var node_id: StringName = frontier.pop_front()
		if visited.has(node_id):
			continue
		visited[node_id] = true
		var node: MapNodeState = graph.get_map_node(node_id)
		var next_ids: Array[StringName] = node.incoming_ids if reverse else node.outgoing_ids
		for next_id: StringName in next_ids:
			frontier.append(next_id)
	return visited


func _can_reach_while_avoiding(
	graph: LayerMapGraph,
	target_id: StringName,
	blocked_id: StringName
) -> bool:
	var visited: Dictionary = {blocked_id: true}
	var frontier: Array[StringName] = [graph.start_node_id]
	while not frontier.is_empty():
		var node_id: StringName = frontier.pop_front()
		if visited.has(node_id):
			continue
		if node_id == target_id:
			return true
		visited[node_id] = true
		var node: MapNodeState = graph.get_map_node(node_id)
		for next_id: StringName in node.outgoing_ids:
			frontier.append(next_id)
	return false


func _make_node(
	node_id: StringName,
	column: int,
	row: int,
	node_type: MapNodeState.NodeType,
	display_name: String
) -> MapNodeState:
	var node: MapNodeState = MapNodeState.new()
	node.node_id = node_id
	node.column = column
	node.row = row
	node.node_type = node_type
	node.display_name = display_name
	if node_type == MapNodeState.NodeType.ITEM:
		node.reward_source_id = &"demo_map_item_cache"
	if node.requires_battle():
		node.encounter_id = StringName(
			"layer_1_%s" % String(node.node_id)
		)
		node.encounter_template_id = &"ruined_chapel_regular"
	return node
