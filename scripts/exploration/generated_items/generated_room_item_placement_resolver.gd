class_name GeneratedRoomItemPlacementResolver
extends RefCounted


const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)

static func resolve(
	graph: LayerMapGraph,
	rules: Array[GeneratedRoomItemPlacementRule],
	run_seed: int
) -> GeneratedRoomItemPlacementResult:
	var result := GeneratedRoomItemPlacementResult.new()

	var graph_can_resolve: bool = graph != null

	if graph == null:
		result.errors.append(
			"Generated room-item placement received no graph."
		)
	else:
		var graph_error: String = graph.validate_graph()

		if not graph_error.is_empty():
			result.errors.append(
				"Generated room-item placement received "
				+ "an invalid graph: "
				+ graph_error
			)

			graph_can_resolve = false

	var invalid_rule_indices: Dictionary = {}
	var indices_by_assignment_id: Dictionary = {}

	# Validate every rule before attempting placement.
	for rule_index: int in range(
		rules.size()
	):
		var rule: GeneratedRoomItemPlacementRule = (
			rules[rule_index]
		)

		var rule_label: String = (
			"Generated room-item rule %d"
			% rule_index
		)

		if rule == null:
			result.errors.append(
				"%s is null."
				% rule_label
			)

			invalid_rule_indices[
				rule_index
			] = true

			continue

		var rule_errors: Array[String] = (
			rule.collect_validation_errors(
				rule_label
			)
		)

		if not rule_errors.is_empty():
			result.errors.append_array(
				rule_errors
			)

			invalid_rule_indices[
				rule_index
			] = true

		if rule.assignment_id == &"":
			continue

		var assignment_key: String = String(
			rule.assignment_id
		)

		var stored_indices: Array = (
			indices_by_assignment_id.get(
				assignment_key,
				[]
			) as Array
		)

		stored_indices.append(
			rule_index
		)

		indices_by_assignment_id[
			assignment_key
		] = stored_indices

	# Duplicate assignment IDs invalidate every rule
	# carrying that ID, but validation continues.
	for assignment_value: Variant in (
		indices_by_assignment_id.keys()
	):
		var assignment_key: String = String(
			assignment_value
		)

		var duplicate_indices: Array = (
			indices_by_assignment_id.get(
				assignment_key,
				[]
			) as Array
		)

		if duplicate_indices.size() <= 1:
			continue

		result.errors.append(
			(
				"Duplicate generated room-item "
				+ "assignment_id '%s' appears %d times."
			)
			% [
				assignment_key,
				duplicate_indices.size(),
			]
		)

		for index_value: Variant in duplicate_indices:
			invalid_rule_indices[
				int(index_value)
			] = true

	if graph_can_resolve:
		var valid_rules: Array[GeneratedRoomItemPlacementRule] = []

		for rule_index: int in range(
			rules.size()
		):
			if invalid_rule_indices.has(
				rule_index
			):
				continue

			var rule: GeneratedRoomItemPlacementRule = (
				rules[rule_index]
			)

			if rule != null:
				valid_rules.append(
					rule
				)

		# Rule order must not alter the output.
		valid_rules.sort_custom(
			func(
				left: GeneratedRoomItemPlacementRule,
				right: GeneratedRoomItemPlacementRule
			) -> bool:
				return (
					String(left.assignment_id)
					< String(right.assignment_id)
				)
		)

		for rule: GeneratedRoomItemPlacementRule in (
			valid_rules
		):
			_resolve_rule(
				graph,
				rule,
				run_seed,
				result
			)

	# Placement is transactional. A partially valid
	# profile never produces partially applied requests.
	if not result.errors.is_empty():
		result.requests_by_node.clear()

	return result

static func make_rule_seed(
	run_seed: int,
	assignment_id: StringName
) -> int:
	return StableSeedMixer.make_seed(
		run_seed,
		&"generated_room_item",
		assignment_id
	)

static func _resolve_rule(
	graph: LayerMapGraph,
	rule: GeneratedRoomItemPlacementRule,
	run_seed: int,
	result: GeneratedRoomItemPlacementResult
) -> void:
	var eligible_nodes_by_id: Dictionary = {}
	var candidate_notes: Array[String] = []

	for candidate: GeneratedRoomItemHostCandidate in (
		rule.candidates
	):
		var matching_nodes: Array[MapNodeState] = (
			_find_nodes_with_room_definition(
				graph,
				candidate.room_definition_id
			)
		)

		if matching_nodes.is_empty():
			candidate_notes.append(
				(
					"%s: room definition is not "
					+ "present in this graph"
				)
				% candidate.room_definition_id
			)

			continue

		var blocked_node_ids: Dictionary = {}

		if (
			candidate.access_policy
			== GeneratedRoomItemHostCandidate
				.AccessPolicy
				.REACHABLE_WITHOUT_BLOCKING_ROOM
		):
			blocked_node_ids = (
				_find_node_ids_with_room_definition(
					graph,
					candidate
						.blocking_room_definition_id
				)
			)

		var candidate_had_eligible_node: bool = false

		for node: MapNodeState in matching_nodes:
			if not _is_node_reachable(
				graph,
				node.node_id,
				blocked_node_ids
			):
				continue

			candidate_had_eligible_node = true

			eligible_nodes_by_id[
				node.node_id
			] = node

		if candidate_had_eligible_node:
			continue

		if (
			candidate.access_policy
			== GeneratedRoomItemHostCandidate
				.AccessPolicy
				.REACHABLE_WITHOUT_BLOCKING_ROOM
		):
			candidate_notes.append(
				(
					"%s: no matching node is reachable "
					+ "without passing through '%s'"
				)
				% [
					candidate.room_definition_id,
					candidate
						.blocking_room_definition_id,
				]
			)
		else:
			candidate_notes.append(
				(
					"%s: no matching node is "
					+ "reachable from the graph start"
				)
				% candidate.room_definition_id
			)

	if eligible_nodes_by_id.is_empty():
		var error_message: String = (
			"Generated room-item rule '%s' "
			+ "found no eligible host."
		) % rule.assignment_id

		if not candidate_notes.is_empty():
			error_message += (
				"\nCandidates checked:"
			)

			for note: String in candidate_notes:
				error_message += (
					"\n- %s"
					% note
				)

		result.errors.append(
			error_message
		)

		return

	for note: String in candidate_notes:
		result.warnings.append("Generated room item rule '%s': '%s'"
		% [
			rule.assignment_id,
			note,
		]
	)

	var eligible_nodes: Array[MapNodeState] = []

	for node_value: Variant in (
		eligible_nodes_by_id.values()
	):
		var node: MapNodeState = (
			node_value as MapNodeState
		)

		if node != null:
			eligible_nodes.append(
				node
			)

	eligible_nodes.sort_custom(
		func(
			left: MapNodeState,
			right: MapNodeState
		) -> bool:
			return (
				String(left.node_id)
				< String(right.node_id)
			)
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = make_rule_seed(
		run_seed,
		rule.assignment_id
	)

	var selected_node: MapNodeState = (
		eligible_nodes[
			rng.randi_range(
				0,
				eligible_nodes.size() - 1
			)
		]
	)
	var resolved_item_id: StringName = rule.item_id
	var resolved_quantity: int = rule.quantity
	var resolution_record: Dictionary = {}
	if rule.reward_source != null:
		var resolution: Dictionary = RewardSourceResolver.resolve(
			rule.reward_source,
			ITEM_CATALOG,
			graph.layer_number,
			run_seed,
			selected_node.node_id
		)
		var resolution_error: String = String(resolution.get("error", ""))
		if not resolution_error.is_empty():
			result.errors.append(resolution_error)
			return
		resolution_record = (resolution.get("record", {}) as Dictionary).duplicate(true)
		resolved_item_id = StringName(resolution_record.get("item_id", ""))
		resolved_quantity = int(resolution_record.get("quantity", 0))

	var node_requests: Array = (
		result.requests_by_node.get(
			selected_node.node_id,
			[]
		) as Array
	)

	var request: Dictionary = {
			"assignment_id": String(
				rule.assignment_id
			),
			"item_id": String(
				resolved_item_id
			),
			"quantity": resolved_quantity,
			"required_anchor_tag": String(
				rule.required_anchor_tag
			),
		}
	for record_key: Variant in resolution_record.keys():
		request[record_key] = resolution_record[record_key]
	node_requests.append(request)

	result.requests_by_node[
		selected_node.node_id
	] = node_requests


static func _find_nodes_with_room_definition(
	graph: LayerMapGraph,
	room_definition_id: StringName
) -> Array[MapNodeState]:
	var matches: Array[MapNodeState] = []

	for node_value: Variant in graph.nodes.values():
		var node: MapNodeState = (
			node_value as MapNodeState
		)

		if node == null:
			continue

		if (
			node.room_definition_id
			!= room_definition_id
		):
			continue

		matches.append(
			node
		)

	matches.sort_custom(
		func(
			left: MapNodeState,
			right: MapNodeState
		) -> bool:
			return (
				String(left.node_id)
				< String(right.node_id)
			)
	)

	return matches


static func _find_node_ids_with_room_definition(
	graph: LayerMapGraph,
	room_definition_id: StringName
) -> Dictionary:
	var node_ids: Dictionary = {}

	for node: MapNodeState in (
		_find_nodes_with_room_definition(
			graph,
			room_definition_id
		)
	):
		node_ids[node.node_id] = true

	return node_ids


static func _is_node_reachable(
	graph: LayerMapGraph,
	target_node_id: StringName,
	blocked_node_ids: Dictionary
) -> bool:
	if target_node_id == &"":
		return false

	if blocked_node_ids.has(
		graph.start_node_id
	):
		return false

	if blocked_node_ids.has(
		target_node_id
	):
		return false

	if target_node_id == graph.start_node_id:
		return true

	var frontier: Array[StringName] = [
		graph.start_node_id,
	]

	var visited: Dictionary = {
		graph.start_node_id: true,
	}

	while not frontier.is_empty():
		var current_node_id: StringName = (
			frontier.pop_front()
		)

		var current_node: MapNodeState = (
			graph.get_map_node(
				current_node_id
			)
		)

		if current_node == null:
			continue

		for next_node_id: StringName in (
			current_node.outgoing_ids
		):
			if blocked_node_ids.has(
				next_node_id
			):
				continue

			if visited.has(
				next_node_id
			):
				continue

			if next_node_id == target_node_id:
				return true

			visited[next_node_id] = true
			frontier.append(
				next_node_id
			)

	return false
