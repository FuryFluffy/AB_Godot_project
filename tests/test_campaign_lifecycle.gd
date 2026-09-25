extends SceneTree


const DIALOGUE_FIXTURES = preload(
	"res://tests/dialogue_production_test_fixtures.gd"
)


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const UPPER_REFUGE_ORIGIN: DialogueDefinition = preload(
	"res://data/dialogue/layer2_refuge_origin_from_upper_route.tres"
)


var failures: int = 0


func _init() -> void:
	_test_fixed_tutorial_map_and_independent_combat_sequence()
	_test_real_jailer_victory_preserves_refugeless_campaign()
	_test_upper_route_wipe_establishes_refuge_and_keeps_bosses_defeated()
	if failures == 0:
		print("Campaign lifecycle and seed-scope tests passed.")
	else:
		push_error("%d campaign lifecycle test(s) failed." % failures)
	quit(failures)


func _test_fixed_tutorial_map_and_independent_combat_sequence() -> void:
	var generator := LayerMapGenerator.new()
	var seed: int = 27072026
	var first_graph: LayerMapGraph = generator.generate_layer_1(seed)
	var first := RunState.new()
	var first_error: String = first.initialize(seed, first_graph)
	var first_encounter: EncounterDefinition = (
		first.make_opening_encounter_definition()
	)
	var lifecycle_snapshot: Dictionary = (
		first.make_campaign_lifecycle_snapshot()
	)

	var retry_graph: LayerMapGraph = generator.generate_layer_1(seed)
	var retry := RunState.new()
	var retry_error: String = retry.initialize(
		seed,
		retry_graph,
		[],
		{},
		{},
		lifecycle_snapshot
	)
	var retry_encounter: EncounterDefinition = (
		retry.make_opening_encounter_definition()
	)
	_expect(
		first_error.is_empty()
		and retry_error.is_empty()
		and first.get_campaign_mode_id() == "TUTORIAL_PRE_REFUGE"
		and retry.get_campaign_mode_id() == "TUTORIAL_PRE_REFUGE"
		and _graph_signature(first_graph) == _graph_signature(retry_graph)
		and first_encounter != null
		and retry_encounter != null
		and first_encounter.encounter_seed != retry_encounter.encounter_seed,
		"Tutorial wipes must reuse one Layer 1 world without repeating combat RNG."
	)
	_expect(
		int(lifecycle_snapshot.get("tutorial_layer_1_seed", 0)) == seed
		and int(lifecycle_snapshot.get("campaign_seed", 0)) == seed,
		"Campaign and tutorial seed scopes must be explicit and restorable."
	)


func _test_real_jailer_victory_preserves_refugeless_campaign() -> void:
	var generator := LayerMapGenerator.new()
	var party: Dictionary = _full_party_snapshot(100)
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		8128,
		generator.generate_layer_2_entry(8128),
		[],
		party
	)
	run.opening_completed = true
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	run.campaign_lifecycle.begin_refugeless_ascent(
		RunState.BLOOD_NUN_GO_DOWN_CHOICE_ID
	)
	var entry_error: String = run.begin_immediate_jailer_encounter()
	var victory := EncounterOutcome.new()
	victory.result = EncounterOutcome.Result.VICTORY
	victory.encounter_id = RunState.JAILER_FIRST_ENCOUNTER_ID
	victory.source_node_id = RunState.JAILER_FIRST_NODE_ID
	victory.party_snapshot = party.duplicate(true)
	victory.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	victory.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	victory.bloom_reward = 25
	var reverse_graph: LayerMapGraph = (
		generator.generate_refugeless_reverse_layer_2(
			run.get_refugeless_layer_seed(2),
			run.get_defeated_boss_ids()
		)
	)
	var victory_error: String = run.apply_jailer_victory(
		victory,
		DIALOGUE_FIXTURES.make_jailer_victory_outcome(run, victory),
		reverse_graph
	)
	_expect(
		initialize_error.is_empty()
		and entry_error.is_empty()
		and victory_error.is_empty()
		and run.is_refugeless_ascent()
		and not run.has_established_refuge()
		and run.no_refuge_ending_is_eligible()
		and run.has_defeated_boss(RunState.JAILER_BOSS_ID)
		and run.campaign_lifecycle.refugeless_layer_seeds.size() == 10
		and run.graph == reverse_graph
		and run.current_node_id == RunState.JAILER_FIRST_NODE_ID
		and run.graph.get_map_node(RunState.JAILER_FIRST_NODE_ID).cleared
		and run.graph.get_map_node(
			RunState.JAILER_FIRST_NODE_ID
		).encounter_id == &"",
		"A legitimate Jailer victory must continue the campaign without creating the Refuge."
	)


func _test_upper_route_wipe_establishes_refuge_and_keeps_bosses_defeated() -> void:
	var generator := LayerMapGenerator.new()
	var party: Dictionary = _full_party_snapshot(85)
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		9931,
		generator.generate_layer_3_entry(9931),
		[],
		party
	)
	run.opening_completed = true
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	run.campaign_lifecycle.begin_refugeless_ascent(
		RunState.BLOOD_NUN_GO_UP_CHOICE_ID
	)
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	run.campaign_lifecycle.mark_boss_defeated(RunState.JAILER_BOSS_ID)
	run.pending_node_id = &"l3_content_gate"

	var defeat := EncounterOutcome.new()
	defeat.result = EncounterOutcome.Result.DEFEAT
	defeat.encounter_id = &"layer_3_future_encounter"
	defeat.source_node_id = &"l3_content_gate"
	defeat.party_snapshot = _defeated_party_snapshot(70)
	defeat.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	defeat.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	var recovered: Dictionary = run.make_full_wipe_recovery_party_snapshot(
		defeat,
		BATTLER_CATALOG
	)
	var story_outcome: StoryDialogueOutcome = _make_upper_refuge_story_outcome(
		run,
		defeat,
		recovered
	)
	var apply_error: String = run.apply_refugeless_defeat_and_refuge_origin(
		defeat,
		story_outcome,
		generator.generate_bloom_refuge_holding_state(9931),
		BATTLER_CATALOG
	)
	var later_layer_2: LayerMapGraph = generator.generate_layer_2_run(
		7711,
		run.get_defeated_boss_ids()
	)
	var cleared_jailer: MapNodeState = later_layer_2.get_map_node(
		RunState.JAILER_FIRST_NODE_ID
	)
	var later_layer_1: LayerMapGraph = generator.generate_layer_1(
		8811,
		run.get_defeated_boss_ids()
	)
	var cleared_blood_nun: MapNodeState = later_layer_1.get_map_node(
		&"l1_c6_n0"
	)
	_expect(
		initialize_error.is_empty()
		and apply_error.is_empty()
		and run.has_established_refuge()
		and run.get_campaign_mode_id() == "REFUGE_RUN"
		and not run.no_refuge_ending_is_eligible()
		and run.has_defeated_boss(RunState.BLOOD_NUN_BOSS_ID)
		and run.has_defeated_boss(RunState.JAILER_BOSS_ID)
		and cleared_jailer != null
		and cleared_jailer.cleared
		and cleared_jailer.encounter_id == &""
		and cleared_blood_nun != null
		and cleared_blood_nun.cleared
		and cleared_blood_nun.encounter_id == &"",
		"Any later Refuge-less wipe must establish the Refuge without reviving defeated bosses."
	)


func _make_upper_refuge_story_outcome(
	run: RunState,
	combat_outcome: EncounterOutcome,
	recovered_party: Dictionary
) -> StoryDialogueOutcome:
	var context := DialogueContext.new()
	context.current_party_ids = [&"lysandra", &"mira", &"seraphine"]
	context.present_actor_ids = [&"lysandra", &"mira", &"seraphine"]
	context.recruited_heroine_ids = [&"lysandra", &"mira", &"seraphine"]
	context.flags_by_scope = run.narrative_state.flags_by_scope.duplicate(true)

	var runner := DialogueRunner.new()
	var start_error: String = runner.start(UPPER_REFUGE_ORIGIN, context)
	for _step: int in range(5):
		runner.advance()
	var completion: DialogueResult = runner.choose(
		&"layer_2_refuge_rise_together"
	)
	_expect(
		start_error.is_empty()
		and completion.completed,
		"The upper-route Refuge origin dialogue must complete atomically."
	)

	var outcome := StoryDialogueOutcome.new()
	outcome.story_id = RunState.REFUGE_ORIGIN_STORY_ID
	outcome.source_node_id = combat_outcome.source_node_id
	outcome.inventory_snapshot = combat_outcome.inventory_snapshot.duplicate(true)
	outcome.party_snapshot = recovered_party.duplicate(true)
	outcome.dialogue_result_snapshots = [completion.to_snapshot()]
	return outcome


func _graph_signature(graph: LayerMapGraph) -> String:
	var node_ids: Array[StringName] = []
	for node_value: Variant in graph.nodes.keys():
		node_ids.append(StringName(node_value))
	node_ids.sort()
	var parts: Array[String] = []
	for node_id: StringName in node_ids:
		var node: MapNodeState = graph.get_map_node(node_id)
		var outgoing_strings: Array[String] = []
		for outgoing_id: StringName in node.outgoing_ids:
			outgoing_strings.append(String(outgoing_id))
		parts.append(
			"%s:%d:%d:%d:%s:%s"
			% [
				String(node.node_id),
				node.column,
				node.row,
				int(node.node_type),
				String(node.room_definition_id),
				",".join(outgoing_strings),
			]
		)
	return "|".join(parts)


func _full_party_snapshot(resolve_value: int) -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(10, 4, resolve_value, 8),
		&"mira": _heroine_snapshot(9, 6, resolve_value, 12),
		&"seraphine": _heroine_snapshot(8, 8, resolve_value, 4),
	}


func _defeated_party_snapshot(resolve_value: int) -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(0, 0, resolve_value, 8),
		&"mira": _heroine_snapshot(0, 0, resolve_value, 12),
		&"seraphine": _heroine_snapshot(0, 0, resolve_value, 4),
	}


func _heroine_snapshot(
	hp: int,
	mp: int,
	resolve_value: int,
	corruption: int
) -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"resolve": resolve_value,
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
