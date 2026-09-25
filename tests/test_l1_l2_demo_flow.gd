extends SceneTree


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const DIALOGUE_FIXTURES = preload(
	"res://tests/dialogue_production_test_fixtures.gd"
)


var failures: int = 0


func _init() -> void:
	_test_jailer_victory_activates_reverse_layer_2_transactionally()
	_test_reverse_traversal_establishes_refuge_once()
	if failures == 0:
		print("Layer 1 to reverse Layer 2 demo-flow tests passed.")
	else:
		push_error("%d demo-flow test(s) failed." % failures)
	quit(failures)


func _test_jailer_victory_activates_reverse_layer_2_transactionally() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_jailer_run(generator)
	var victory: EncounterOutcome = _make_jailer_victory(run)
	var invalid_graph: LayerMapGraph = generator.generate_layer_2_run(
		run.get_refugeless_layer_seed(2),
		run.get_defeated_boss_ids()
	)
	var entry_graph: LayerMapGraph = run.graph
	var bloom_before: int = run.bloom
	var victory_story: StoryDialogueOutcome = (
		DIALOGUE_FIXTURES.make_jailer_victory_outcome(run, victory)
	)
	var invalid_error: String = run.apply_jailer_victory(
		victory,
		victory_story,
		invalid_graph
	)
	_expect(
		not invalid_error.is_empty()
		and run.graph == entry_graph
		and run.pending_node_id == RunState.JAILER_FIRST_NODE_ID
		and run.bloom == bloom_before
		and not run.has_defeated_boss(RunState.JAILER_BOSS_ID),
		"A malformed reverse route must not partially resolve the Jailer victory."
	)

	var reverse_graph: LayerMapGraph = (
		generator.generate_refugeless_reverse_layer_2(
			run.get_refugeless_layer_seed(2),
			run.get_defeated_boss_ids()
		)
	)
	var victory_error: String = run.apply_jailer_victory(
		victory,
		victory_story,
		reverse_graph
	)
	var jailer: MapNodeState = run.graph.get_map_node(
		RunState.JAILER_FIRST_NODE_ID
	)
	_expect(
		victory_error.is_empty()
		and run.graph == reverse_graph
		and run.graph.start_node_id == RunState.LAYER_2_FARTHEST_CELL_NODE_ID
		and run.current_node_id == RunState.JAILER_FIRST_NODE_ID
		and run.selected_node_id == RunState.JAILER_FIRST_NODE_ID
		and run.pending_node_id == &""
		and run.is_refugeless_ascent()
		and not run.has_established_refuge()
		and run.has_defeated_boss(RunState.JAILER_BOSS_ID)
		and jailer != null
		and jailer.cleared
		and jailer.reward_claimed
		and jailer.encounter_id == &""
		and jailer.encounter_template_id == &""
		and run.bloom == bloom_before + victory.bloom_reward,
		"A real Jailer victory must enter the deterministic full graph at its cleared exit side."
	)
	var resolved_bloom: int = run.bloom
	_expect(
		not run.apply_jailer_victory(
			victory,
			victory_story,
			reverse_graph
		).is_empty()
		and run.bloom == resolved_bloom,
		"The defeated Jailer and its reward must not replay."
	)


func _test_reverse_traversal_establishes_refuge_once() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_jailer_run(generator)
	var reverse_graph: LayerMapGraph = (
		generator.generate_refugeless_reverse_layer_2(
			run.get_refugeless_layer_seed(2),
			run.get_defeated_boss_ids()
		)
	)
	var victory_error: String = run.apply_jailer_victory(
		_make_jailer_victory(run),
		DIALOGUE_FIXTURES.make_jailer_victory_outcome(
			run,
			_make_jailer_victory(run)
		),
		reverse_graph
	)
	var jailer: MapNodeState = run.graph.get_map_node(run.current_node_id)
	var first_reverse_id: StringName = (
		jailer.incoming_ids[0] if jailer != null and not jailer.incoming_ids.is_empty()
		else &""
	)
	var first_travel_error: String = run.travel_to(first_reverse_id)
	var first_complete_error: String = run.complete_pending_node()
	var return_to_jailer_error: String = run.travel_to(
		RunState.JAILER_FIRST_NODE_ID
	)
	var resume_reverse_error: String = run.travel_to(first_reverse_id)
	_expect(
		victory_error.is_empty()
		and first_reverse_id != &""
		and first_travel_error.is_empty()
		and first_complete_error.is_empty()
		and return_to_jailer_error.is_empty()
		and resume_reverse_error.is_empty(),
		"Reverse Layer 2 edges must be reciprocal after the Jailer is cleared."
	)

	var traversal_error: String = _travel_to_farthest_cell(run)
	var completed_reverse_graph: LayerMapGraph = run.graph
	var refuge_graph: LayerMapGraph = (
		generator.generate_bloom_refuge_holding_state(run.run_seed)
	)
	var establish_error: String = run.establish_refuge_at_farthest_cell(
		refuge_graph,
		BATTLER_CATALOG,
		DIALOGUE_FIXTURES.make_farthest_cell_outcome(run)
	)
	var save_flags: Dictionary = run.narrative_state.flags_by_scope.get(
		&"save",
		{}
	) as Dictionary
	var bloom_after_establishment: int = run.bloom
	var duplicate_error: String = run.establish_refuge_at_farthest_cell(
		refuge_graph,
		BATTLER_CATALOG,
		DIALOGUE_FIXTURES.make_farthest_cell_outcome(run)
	)
	_expect(
		traversal_error.is_empty()
		and establish_error.is_empty()
		and run.has_established_refuge()
		and run.get_campaign_mode_id() == "REFUGE_RUN"
		and run.graph == refuge_graph
		and run.current_node_id == &"bloom_refuge_farthest_cell"
		and run.archived_layer_graphs.get(&"layer_2") == completed_reverse_graph
		and bool(save_flags.get(
			RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID,
			false
		))
		and run.has_defeated_boss(RunState.JAILER_BOSS_ID)
		and not duplicate_error.is_empty()
		and run.bloom == bloom_after_establishment,
		"Reaching Farthest Cell alive must establish exactly one normal Refuge boundary."
	)


func _travel_to_farthest_cell(run: RunState) -> String:
	while run.current_node_id != RunState.LAYER_2_FARTHEST_CELL_NODE_ID:
		var current: MapNodeState = run.graph.get_map_node(run.current_node_id)
		if current == null or current.incoming_ids.is_empty():
			return "Reverse route ended before the Farthest Cell."
		var next_id: StringName = current.incoming_ids[0]
		var travel_error: String = run.travel_to(next_id)
		if not travel_error.is_empty():
			return travel_error
		if run.pending_node_id != &"":
			var complete_error: String = run.complete_pending_node()
			if not complete_error.is_empty():
				return complete_error
	return "" if run.is_at_refugeless_farthest_cell() else (
		"Farthest Cell did not expose the Refuge boundary."
	)


func _make_jailer_run(generator: LayerMapGenerator) -> RunState:
	var campaign_seed: int = 27072026
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		campaign_seed,
		generator.generate_layer_2_entry(campaign_seed),
		[],
		_full_party_snapshot()
	)
	_expect(initialize_error.is_empty(), "Jailer fixture must initialize.")
	run.opening_completed = true
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	run.campaign_lifecycle.begin_refugeless_ascent(
		RunState.BLOOD_NUN_GO_DOWN_CHOICE_ID
	)
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	var entry_error: String = run.begin_immediate_jailer_encounter()
	_expect(entry_error.is_empty(), "Go Down must enter the Jailer immediately.")
	return run


func _make_jailer_victory(run: RunState) -> EncounterOutcome:
	var outcome := EncounterOutcome.new()
	outcome.result = EncounterOutcome.Result.VICTORY
	outcome.encounter_id = RunState.JAILER_FIRST_ENCOUNTER_ID
	outcome.source_node_id = RunState.JAILER_FIRST_NODE_ID
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	outcome.bloom_reward = 25
	return outcome


func _full_party_snapshot() -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(10, 4, 73, 8),
		&"mira": _heroine_snapshot(9, 6, 69, 12),
		&"seraphine": _heroine_snapshot(8, 8, 81, 4),
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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
