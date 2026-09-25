extends SceneTree


const BLOOD_NUN_AFTERMATH: DialogueDefinition = preload(
	"res://data/dialogue/layer1_blood_nun_aftermath.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)


var failures: int = 0


func _init() -> void:
	_test_blood_nun_aftermath_route(
		RunState.BLOOD_NUN_GO_UP_CHOICE_ID,
		&"layer_3",
		&"l3_lower_halls_threshold"
	)
	_test_blood_nun_aftermath_route(
		RunState.BLOOD_NUN_GO_DOWN_CHOICE_ID,
		&"layer_2",
		&"l2_jailer_threshold"
	)
	_test_layer_boundary_discards_completed_layer_reward_state()
	_test_invalid_aftermath_is_atomic()

	if failures == 0:
		print("Layer 1 to Layer 2 transition tests passed.")
	else:
		push_error("%d layer-transition test(s) failed." % failures)
	quit(failures)


func _test_blood_nun_aftermath_route(
	route_choice_id: StringName,
	expected_layer_id: StringName,
	expected_start_node_id: StringName
) -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_run_at_blood_nun(generator)
	var completed_layer_1_graph: LayerMapGraph = run.graph
	var combat_outcome: EncounterOutcome = _make_blood_nun_victory(run)
	var story_outcome: StoryDialogueOutcome = _make_aftermath_outcome(
		run,
		combat_outcome,
		route_choice_id
	)
	var destination_graph: LayerMapGraph = (
		generator.generate_layer_3_entry(run.run_seed)
		if route_choice_id == RunState.BLOOD_NUN_GO_UP_CHOICE_ID
		else generator.generate_layer_2_entry(run.run_seed)
	)
	var apply_error: String = run.apply_blood_nun_aftermath(
		combat_outcome,
		story_outcome,
		destination_graph
	)

	var save_flags: Dictionary = (
		run.narrative_state.flags_by_scope.get(&"save", {}) as Dictionary
	)
	var destination_node: MapNodeState = destination_graph.get_map_node(
		(
			&"l3_content_gate"
			if expected_layer_id == &"layer_3"
			else RunState.JAILER_FIRST_NODE_ID
		)
	)
	_expect(
		apply_error.is_empty()
		and run.graph == destination_graph
		and run.graph.layer_id == expected_layer_id
		and run.graph.layer_number == (3 if expected_layer_id == &"layer_3" else 2)
		and run.current_node_id == expected_start_node_id
		and run.selected_node_id == expected_start_node_id
		and run.pending_node_id == &""
		and run.completed_layer_ids.has(&"layer_1")
		and run.archived_layer_graphs.get(&"layer_1") == completed_layer_1_graph
		and completed_layer_1_graph.get_map_node(
			completed_layer_1_graph.boss_node_id
		).cleared
		and run.completed_encounters.has(RunState.BLOOD_NUN_ENCOUNTER_ID)
		and bool(save_flags.get(RunState.LAYER_1_COMPLETED_FLAG_ID, false))
		and run.narrative_state.choice_ids.has(route_choice_id)
		and run.narrative_state.resolved_interaction_ids.has(
			RunState.BLOOD_NUN_AFTERMATH_STORY_ID
		)
		and run.party_snapshot.keys().size() == 3
		and run.inventory_snapshot == combat_outcome.inventory_snapshot
		and run.bloom == 49
		and destination_node != null
		and (
			(
				not destination_node.travel_enabled
				and not run.can_travel_to(destination_node.node_id)
			)
			if expected_layer_id == &"layer_3"
			else run.can_travel_to(destination_node.node_id)
		),
		"Blood Nun victory must atomically enter Layer 3 upward or the Jailer downward."
	)

	var bloom_after_transition: int = run.bloom
	_expect(
		not run.apply_blood_nun_aftermath(
			combat_outcome,
			story_outcome,
			destination_graph
		).is_empty()
		and run.bloom == bloom_after_transition,
		"The Blood Nun completion reward and transition must not apply twice."
	)


func _test_invalid_aftermath_is_atomic() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_run_at_blood_nun(generator)
	var original_graph: LayerMapGraph = run.graph
	var original_bloom: int = run.bloom
	var combat_outcome: EncounterOutcome = _make_blood_nun_victory(run)
	var invalid_story := StoryDialogueOutcome.new()
	invalid_story.story_id = RunState.BLOOD_NUN_AFTERMATH_STORY_ID
	invalid_story.source_node_id = run.pending_node_id
	invalid_story.inventory_snapshot = combat_outcome.inventory_snapshot.duplicate(true)
	invalid_story.party_snapshot = combat_outcome.party_snapshot.duplicate(true)

	var apply_error: String = run.apply_blood_nun_aftermath(
		combat_outcome,
		invalid_story,
		generator.generate_layer_2_entry(run.run_seed)
	)
	_expect(
		not apply_error.is_empty()
		and run.graph == original_graph
		and run.graph.layer_id == &"layer_1"
		and run.pending_node_id == original_graph.boss_node_id
		and run.bloom == original_bloom
		and not run.completed_layer_ids.has(&"layer_1"),
		"An incomplete aftermath must leave every Layer 1 state value untouched."
	)


func _test_layer_boundary_discards_completed_layer_reward_state() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_run_at_blood_nun(generator)
	var generated_node_id: StringName = &""
	var generated_request: Dictionary = {}
	for node_value: Variant in run.generated_room_item_requests.keys():
		var requests: Array = run.generated_room_item_requests.get(
			node_value,
			[]
		) as Array
		if requests.is_empty() or not (requests[0] is Dictionary):
			continue
		generated_node_id = StringName(node_value)
		generated_request = (requests[0] as Dictionary).duplicate(true)
		break
	var generated_node: MapNodeState = run.graph.get_map_node(
		generated_node_id
	)
	if generated_node != null and not generated_request.is_empty():
		var room_state: EventRoomInstanceState = run.get_event_room_state(
			generated_node_id,
			generated_node.room_definition_id
		)
		var assignment: Dictionary = generated_request.duplicate(true)
		assignment["spawn_id"] = "generated_transition_fixture"
		assignment["anchor_id"] = "transition_fixture_anchor"
		assignment["collected"] = false
		room_state.local_state["item_spawns"] = [assignment]
		run.event_room_snapshots[generated_node_id] = room_state.to_snapshot()

	for node_value: Variant in run.graph.nodes.values():
		var node := node_value as MapNodeState
		if node == null or node.reward_source_id == &"":
			continue
		run._resolve_and_route_node_reward(node)
		break

	var original_run_seed: int = run.run_seed
	var destination_seed: int = run.get_refugeless_world_seed()
	var combat_outcome: EncounterOutcome = _make_blood_nun_victory(run)
	var story_outcome: StoryDialogueOutcome = _make_aftermath_outcome(
		run,
		combat_outcome,
		RunState.BLOOD_NUN_GO_DOWN_CHOICE_ID
	)
	var apply_error: String = run.apply_blood_nun_aftermath(
		combat_outcome,
		story_outcome,
		generator.generate_layer_2_entry(destination_seed)
	)
	var snapshot: Dictionary = run.make_active_run_snapshot(
		"post_node",
		KnowledgeState.new()
	)
	var restored := RunState.new()
	var restore_error: String = restored.restore_active_run_snapshot(
		snapshot,
		BATTLER_CATALOG
	)
	var jailer_entry_error: String = run.begin_immediate_jailer_encounter()
	var jailer_seed_error: String = run.prepare_pending_node_seed()
	var jailer_snapshot: Dictionary = run.make_active_run_snapshot(
		"pre_node",
		KnowledgeState.new()
	)
	var jailer_restored := RunState.new()
	var jailer_restore_error: String = jailer_restored.restore_active_run_snapshot(
		jailer_snapshot,
		BATTLER_CATALOG
	)
	_expect(
		generated_node != null
		and not generated_request.is_empty()
		and destination_seed != original_run_seed
		and apply_error.is_empty()
		and run.event_room_snapshots.is_empty()
		and run.generated_room_item_requests.is_empty()
		and run.reward_resolutions.is_empty()
		and not snapshot.is_empty()
		and restore_error.is_empty()
		and restored.graph.layer_id == &"layer_2"
		and jailer_entry_error.is_empty()
		and jailer_seed_error.is_empty()
		and not jailer_snapshot.is_empty()
		and jailer_restore_error.is_empty()
		and jailer_restored.pending_node_id == RunState.JAILER_FIRST_NODE_ID,
		"A derived-seed layer transition must discard completed Layer 1 reward state and write valid post-node and Jailer pre-node safe points. %s %s"
		% [restore_error, jailer_restore_error]
	)


func _make_run_at_blood_nun(
	generator: LayerMapGenerator
) -> RunState:
	var seed: int = 27072026
	var party_snapshot: Dictionary = {
		&"lysandra": _heroine_snapshot(8, 2, 71, 9),
		&"mira": _heroine_snapshot(5, 4, 63, 14),
		&"seraphine": _heroine_snapshot(6, 7, 78, 6),
	}
	var run := RunState.new()
	run.initialize(
		seed,
		generator.generate_layer_1(seed),
		generator.make_layer_1_generated_room_item_rules(),
		party_snapshot
	)
	run.opening_completed = true
	run.bloom = 12
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	var boss_node: MapNodeState = run.graph.get_map_node(
		run.graph.boss_node_id
	)
	boss_node.visited = true
	run.current_node_id = boss_node.node_id
	run.selected_node_id = boss_node.node_id
	run.pending_node_id = boss_node.node_id
	return run


func _make_blood_nun_victory(run: RunState) -> EncounterOutcome:
	var outcome := EncounterOutcome.new()
	outcome.result = EncounterOutcome.Result.VICTORY
	outcome.encounter_id = RunState.BLOOD_NUN_ENCOUNTER_ID
	outcome.source_node_id = run.pending_node_id
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	outcome.bloom_reward = 37
	return outcome


func _make_aftermath_outcome(
	run: RunState,
	combat_outcome: EncounterOutcome,
	route_choice_id: StringName
) -> StoryDialogueOutcome:
	var context := DialogueContext.new()
	context.current_party_ids = [&"lysandra", &"mira", &"seraphine"]
	context.present_actor_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
		&"blood_nun",
	]
	context.recruited_heroine_ids = [&"lysandra", &"mira", &"seraphine"]
	context.flags_by_scope = run.narrative_state.flags_by_scope.duplicate(true)

	var runner := DialogueRunner.new()
	var start_error: String = runner.start(BLOOD_NUN_AFTERMATH, context)
	var first_result: DialogueResult = runner.advance()
	var completion: DialogueResult = runner.choose(route_choice_id)
	_expect(
		start_error.is_empty()
		and not first_result.completed
		and completion.completed
		and completion.selected_choice_id == route_choice_id,
		"The authored Blood Nun aftermath must expose and complete both locked routes."
	)

	var story_outcome := StoryDialogueOutcome.new()
	story_outcome.story_id = RunState.BLOOD_NUN_AFTERMATH_STORY_ID
	story_outcome.source_node_id = run.pending_node_id
	story_outcome.inventory_snapshot = combat_outcome.inventory_snapshot.duplicate(true)
	story_outcome.party_snapshot = combat_outcome.party_snapshot.duplicate(true)
	story_outcome.dialogue_result_snapshots = [completion.to_snapshot()]
	return story_outcome


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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
