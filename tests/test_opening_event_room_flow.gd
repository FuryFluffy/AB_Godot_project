extends SceneTree


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)
const LORE_CATALOG: LoreCatalogDefinition = preload(
	"res://data/lore/lore_catalog.tres"
)
const BUTLERS_OFFICE: EventRoomDefinition = preload(
	"res://data/exploration/rooms/layer1/butlers_office.tres"
)
const WINE_CELLAR: EventRoomDefinition = preload(
	"res://data/exploration/rooms/layer1/wine_cellar_warm_bottles.tres"
)


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_canonical_solo_opening_handoff()
	_test_mira_recruitment_battle_and_aftermath()
	_test_seraphine_ruined_chapel_recruitment()
	_test_blood_nun_full_wipe_recovery()
	await _test_exploration_party_strip_reflow()
	_test_story_dialogue_backdrops()
	await _test_recovered_party_can_enter_butlers_office()
	_test_deterministic_event_room_assignment_and_key_reachability()
	_test_event_room_back_completion_and_persistence()
	await _test_locked_exit_survives_dialogue_restore()
	await _test_wine_offer_consumes_room_bottle_only()

	if failures == 0:
		print("Opening and Event-room flow tests passed.")
	else:
		push_error(
			"%d opening/Event-room flow test(s) failed."
			% failures
		)
	quit(failures)


func _test_canonical_solo_opening_handoff() -> void:
	var seed: int = 27072026
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph = generator.generate_layer_1(seed)
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		seed,
		graph,
		generator.make_layer_1_generated_room_item_rules()
	)
	_expect(
		initialize_error.is_empty(),
		"The Layer 1 run should initialize before the story opening."
	)
	_expect(
		run.requires_opening_encounter()
		and not run.can_enter_generated_map(),
		"The generated map must remain gated before the corridor victory."
	)

	var first_map_node: MapNodeState = graph.get_nodes_in_column(1)[0]
	_expect(
		not run.can_travel_to(first_map_node.node_id),
		"Map travel must remain locked while the story opening is pending."
	)

	var encounter: EncounterDefinition = (
		run.make_opening_encounter_definition()
	)
	_expect(
		encounter != null
		and encounter.encounter_id == RunState.OPENING_ENCOUNTER_ID
		and encounter.source_node_id == RunState.OPENING_SOURCE_NODE_ID
		and encounter.party_ids == [&"lysandra"]
		and encounter.enemy_ids == [&"hollow_servant"]
		and encounter.template != null
		and encounter.template.template_id
		== &"opening_servant_corridor_opening",
		"The canonical opening must be Lysandra versus one Hollow Servant in the corridor."
	)
	_expect(
		first_map_node.encounter_id
		== &"layer_1_corrupted_butler_opening",
		"Mira's Corrupted Butler encounter must remain a separate map encounter."
	)

	var victory: EncounterOutcome = _make_opening_victory(run, 4)
	var handoff_error: String = (
		run.apply_opening_encounter_outcome(victory)
	)
	_expect(
		handoff_error.is_empty()
		and run.can_enter_generated_map()
		and not run.requires_opening_encounter(),
		"Opening victory should reveal the already-generated Layer 1 map."
	)
	_expect(
		run.party_snapshot.size() == 1
		and run.party_snapshot.has(&"lysandra")
		and int((run.party_snapshot[&"lysandra"] as Dictionary)["hp"])
		== 7
		and run.inventory_snapshot.size()
		== SixSlotInventoryState.SLOT_COUNT
		and run.bloom == 4,
		"Opening victory must preserve Lysandra, inventory, and Bloom exactly."
	)
	_expect(
		run.can_travel_to(first_map_node.node_id),
		"The first generated map connection should unlock after victory."
	)
	_expect(
		run.travel_to(first_map_node.node_id).is_empty(),
		"The first generated combat node should be enterable after the opening."
	)
	var butler_encounter: EncounterDefinition = (
		run.make_encounter_definition()
	)
	_expect(
		butler_encounter != null
		and butler_encounter.enemy_ids == [&"corrupted_butler"]
		and butler_encounter.party_ids == [&"lysandra", &"mira"]
		and not run.narrative_state.recruited_heroine_ids.has(&"mira"),
		(
			"Mira must join her recruitment battle as a scene ally while "
			+ "remaining unrecruited until the aftermath dialogue."
		)
	)
	_expect(
		not run.apply_opening_encounter_outcome(victory).is_empty()
		and run.bloom == 4,
		"The opening outcome and its Bloom reward must not apply twice."
	)


func _test_mira_recruitment_battle_and_aftermath() -> void:
	var run: RunState = _make_run_at_butler_encounter()
	var encounter: EncounterDefinition = run.make_encounter_definition()
	_expect(
		encounter != null
		and encounter.encounter_id
		== RunState.MIRA_RECRUITMENT_ENCOUNTER_ID
		and encounter.party_ids == [&"lysandra", &"mira"]
		and encounter.authored_room_id == &"lower_kitchen"
		and encounter.template != null
		and encounter.template.template_id == &"lower_kitchen_regular"
		and encounter.template.battlefield_scene.resource_path.ends_with(
			"lower_kitchen_battlefield.tscn"
		),
		"The Corrupted Butler encounter must stage Lysandra and Mira together."
	)
	var pending_node: MapNodeState = run.graph.get_map_node(
		run.pending_node_id
	)
	pending_node.encounter_template_id = &"ruined_chapel_regular"
	var migrated_encounter: EncounterDefinition = run.make_encounter_definition()
	_expect(
		migrated_encounter != null
		and migrated_encounter.template == RunState.LOWER_KITCHEN_TEMPLATE,
		"An active-run snapshot carrying the former template ID should resolve the Corrupted Butler in Lower Kitchen."
	)
	_finish_mira_recruitment_test(run, encounter)


func _test_seraphine_ruined_chapel_recruitment() -> void:
	var run: RunState = _make_run_at_seraphine_encounter()
	var chapel_node: MapNodeState = run.graph.get_map_node(
		run.pending_node_id
	)
	_expect(
		chapel_node != null
		and chapel_node.column == LayerMapGenerator.COLUMN_COUNT - 2
		and chapel_node.encounter_id
		== RunState.SERAPHINE_RECRUITMENT_ENCOUNTER_ID
		and run.requires_seraphine_recruitment_prelude(),
		"The mandatory penultimate Layer 1 node must begin Seraphine's prelude."
	)

	var prelude := load(
		"res://data/dialogue/layer1_seraphine_recruitment_prelude.tres"
	) as DialogueDefinition
	var prelude_context := DialogueContext.new()
	prelude_context.current_party_ids = [&"lysandra", &"mira"]
	prelude_context.present_actor_ids = [&"lysandra", &"mira", &"seraphine"]
	prelude_context.recruited_heroine_ids = [&"lysandra", &"mira"]
	var prelude_runner := DialogueRunner.new()
	var start_error: String = prelude_runner.start(
		prelude,
		prelude_context
	)
	var entry_result: DialogueResult = (
		prelude_runner.consume_pending_transition_result()
	)
	var presented_node: DialogueNodeDefinition = (
		prelude_runner.get_current_node()
	)
	_expect(
		start_error.is_empty()
		and entry_result.automatic_transition_ids
		== [&"seraphine_arrival_with_mira"]
		and entry_result.outcomes.size() == 1
		and presented_node != null
		and presented_node.text
		== "This place remembers prayer, but not mercy.",
		"Seraphine's prelude must apply its entry result before routing to the locked line."
	)
	var prelude_completion: DialogueResult = prelude_runner.choose(
		&"seraphine_recruitment_stand_beneath_ward"
	)
	_expect(
		prelude_completion.completed,
		"Standing beneath Seraphine's ward should complete the mandatory prelude."
	)

	var prelude_outcome := StoryDialogueOutcome.new()
	prelude_outcome.story_id = (
		RunState.SERAPHINE_RECRUITMENT_PRELUDE_STORY_ID
	)
	prelude_outcome.source_node_id = chapel_node.node_id
	prelude_outcome.party_snapshot = run.party_snapshot.duplicate(true)
	prelude_outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	prelude_outcome.dialogue_result_snapshots = [
		entry_result.to_snapshot(),
		prelude_completion.to_snapshot(),
	]
	_expect(
		run.apply_seraphine_recruitment_prelude(prelude_outcome).is_empty()
		and not run.requires_seraphine_recruitment_prelude()
		and not run.narrative_state.recruited_heroine_ids.has(&"seraphine"),
		"The prelude must persist its run flag without recruiting Seraphine early."
	)

	var encounter: EncounterDefinition = run.make_encounter_definition()
	_expect(
		encounter != null
		and encounter.party_ids == [&"lysandra", &"mira", &"seraphine"]
		and encounter.enemy_ids == [&"prayer_rag_novice", &"hollow_servant"]
		and encounter.difficulty_label == "Recruitment Special",
		"The Ruined Chapel battle must stage all three heroines against the false-prayer formation."
	)

	var combat_outcome := EncounterOutcome.new()
	combat_outcome.result = EncounterOutcome.Result.VICTORY
	combat_outcome.encounter_id = encounter.encounter_id
	combat_outcome.source_node_id = encounter.source_node_id
	combat_outcome.party_snapshot = {
		&"lysandra": _make_heroine_snapshot(5, 2, 46, 13),
		&"mira": _make_heroine_snapshot(4, 1, 44, 15),
		&"seraphine": _make_heroine_snapshot(6, 4, 63, 4),
	}
	combat_outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	combat_outcome.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	combat_outcome.bloom_reward = 5

	var aftermath := load(
		"res://data/dialogue/layer1_seraphine_recruitment_aftermath.tres"
	) as DialogueDefinition
	var aftermath_context := DialogueContext.new()
	aftermath_context.current_party_ids = [&"lysandra", &"mira", &"seraphine"]
	aftermath_context.present_actor_ids = [&"lysandra", &"mira", &"seraphine"]
	aftermath_context.recruited_heroine_ids = [&"lysandra", &"mira"]
	var aftermath_runner := DialogueRunner.new()
	var aftermath_error: String = aftermath_runner.start(
		aftermath,
		aftermath_context
	)
	aftermath_runner.consume_pending_transition_result()
	var aftermath_completion: DialogueResult = aftermath_runner.choose(
		&"seraphine_recruitment_continue_together"
	)
	var story_outcome := StoryDialogueOutcome.new()
	story_outcome.story_id = (
		RunState.SERAPHINE_RECRUITMENT_AFTERMATH_STORY_ID
	)
	story_outcome.source_node_id = chapel_node.node_id
	story_outcome.party_snapshot = combat_outcome.party_snapshot.duplicate(true)
	story_outcome.inventory_snapshot = (
		combat_outcome.inventory_snapshot.duplicate(true)
	)
	story_outcome.dialogue_result_snapshots = [
		aftermath_completion.to_snapshot(),
	]
	var apply_error: String = run.apply_seraphine_recruitment_aftermath(
		combat_outcome,
		story_outcome
	)
	_expect(
		aftermath_error.is_empty()
		and aftermath_completion.completed
		and apply_error.is_empty()
		and chapel_node.cleared
		and run.party_snapshot.has(&"seraphine")
		and run.narrative_state.recruited_heroine_ids.has(&"seraphine")
		and run.bloom == 5,
		"The aftermath must recruit Seraphine, clear the chapel, and grant its Bloom exactly once."
	)
	_expect(
		not run.apply_seraphine_recruitment_aftermath(
			combat_outcome,
			story_outcome
		).is_empty()
		and run.bloom == 5,
		"Seraphine's recruitment transaction must reject duplicate application."
	)

	var defeated_run: RunState = _make_run_at_seraphine_encounter()
	var defeated_encounter: EncounterDefinition = (
		defeated_run.make_encounter_definition()
	)
	var defeat := EncounterOutcome.new()
	defeat.result = EncounterOutcome.Result.DEFEAT
	defeat.encounter_id = defeated_encounter.encounter_id
	defeat.source_node_id = defeated_encounter.source_node_id
	defeat.party_snapshot = {
		&"lysandra": _make_heroine_snapshot(0, 0, 35, 20),
		&"mira": _make_heroine_snapshot(0, 0, 32, 24),
		&"seraphine": _make_heroine_snapshot(0, 0, 50, 10),
	}
	defeat.inventory_snapshot = defeated_run.inventory_snapshot.duplicate(true)
	var recovered_party: Dictionary = (
		defeated_run.make_full_wipe_recovery_party_snapshot(
			defeat,
			BATTLER_CATALOG
		)
	)
	var recovered_narrative: Dictionary = (
		defeated_run.make_full_wipe_recovery_narrative_snapshot()
	)
	var restarted_run := RunState.new()
	var restarted_graph := LayerMapGenerator.new().generate_layer_1(27072026)
	var no_generated_rules: Array[GeneratedRoomItemPlacementRule] = []
	restarted_run.initialize(
		27072026,
		restarted_graph,
		no_generated_rules,
		recovered_party,
		recovered_narrative
	)
	_expect(
		recovered_party.has(&"lysandra")
		and recovered_party.has(&"mira")
		and not recovered_party.has(&"seraphine")
		and restarted_run.narrative_state.recruited_heroine_ids.has(&"mira")
		and not restarted_run.narrative_state.recruited_heroine_ids.has(&"seraphine")
		and not restarted_run._has_narrative_flag(
			&"run",
			RunState.SERAPHINE_PRELUDE_FLAG_ID
		)
		and restarted_run.make_opening_encounter_definition().party_ids
		== [&"lysandra", &"mira"],
		"A chapel wipe must preserve Mira, exclude Seraphine, and clear run-local prelude state."
	)


func _test_blood_nun_full_wipe_recovery() -> void:
	var seed: int = 27072026
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph = generator.generate_layer_1(seed)
	var run := RunState.new()
	run.initialize(
		seed,
		graph,
		generator.make_layer_1_generated_room_item_rules()
	)
	run.opening_completed = true
	run.party_snapshot = {
		&"lysandra": _make_heroine_snapshot(7, 3, 40, 20),
		&"mira": _make_heroine_snapshot(5, 4, 38, 24),
		&"seraphine": _make_heroine_snapshot(6, 5, 42, 16),
	}
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	var boss_node: MapNodeState = graph.get_map_node(graph.boss_node_id)
	run.current_node_id = boss_node.node_id
	run.selected_node_id = boss_node.node_id
	run.pending_node_id = boss_node.node_id
	var encounter: EncounterDefinition = run.make_encounter_definition()
	var defeat := EncounterOutcome.new()
	defeat.result = EncounterOutcome.Result.DEFEAT
	defeat.encounter_id = encounter.encounter_id
	defeat.source_node_id = encounter.source_node_id
	defeat.party_snapshot = {
		&"lysandra": _make_heroine_snapshot(0, 0, 25, 20),
		&"mira": _make_heroine_snapshot(0, 0, 23, 24),
		&"seraphine": _make_heroine_snapshot(0, 0, 27, 16),
	}
	defeat.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	var recovered: Dictionary = run.make_full_wipe_recovery_party_snapshot(
		defeat,
		BATTLER_CATALOG
	)
	var recovered_narrative: Dictionary = (
		run.make_full_wipe_recovery_narrative_snapshot()
	)
	_expect(
		encounter != null
		and encounter.is_boss
		and recovered.size() == 3
		and int((recovered[&"lysandra"] as Dictionary)["hp"]) > 0
		and int((recovered[&"mira"] as Dictionary)["hp"]) > 0
		and int((recovered[&"seraphine"] as Dictionary)["hp"]) > 0
		and int((recovered[&"lysandra"] as Dictionary)["resolve"]) == 25
		and int((recovered[&"mira"] as Dictionary)["resolve"]) == 23
		and int((recovered[&"seraphine"] as Dictionary)["resolve"]) == 27,
		"A Blood Nun wipe must recover all recruited heroines for a fresh Layer 1 opening."
	)
	var restarted_graph: LayerMapGraph = generator.generate_layer_1(seed)
	var restart_error: String = run.initialize(
		seed,
		restarted_graph,
		generator.make_layer_1_generated_room_item_rules(),
		recovered,
		recovered_narrative
	)
	_expect(
		restart_error.is_empty()
		and run.narrative_state != null
		and run.narrative_state.recruited_heroine_ids
		== [&"lysandra", &"mira", &"seraphine"]
		and not run.get_narrative_state_snapshot().is_empty(),
		"Reusing RunState after a wipe must restore a live three-heroine narrative state."
	)


func _test_exploration_party_strip_reflow() -> void:
	var hud_scene := load(
		"res://scenes/exploration/components/exploration_hud.tscn"
	) as PackedScene
	var hud := hud_scene.instantiate() as ExplorationHUD
	root.add_child(hud)
	await process_frame
	hud.set_active_party_ids([&"lysandra", &"mira"])
	_expect(
		hud.lysandra_card.visible
		and hud.mira_card.visible
		and not hud.seraphine_card.visible
		and is_equal_approx(hud.party_strip.offset_top, -270.0),
		"The exploration Party Strip must collapse to two visible heroine cards."
	)
	hud.set_active_party_ids([&"lysandra"])
	_expect(
		hud.lysandra_card.visible
		and not hud.mira_card.visible
		and not hud.seraphine_card.visible
		and is_equal_approx(hud.party_strip.offset_top, -152.0),
		"The exploration Party Strip must collapse to one visible heroine card."
	)
	hud.set_active_party_ids([&"lysandra", &"mira", &"seraphine"])
	_expect(
		hud.seraphine_card.visible
		and is_equal_approx(hud.party_strip.offset_top, -388.0),
		"The exploration Party Strip must restore its authored three-card height."
	)
	root.remove_child(hud)
	hud.free()


func _test_story_dialogue_backdrops() -> void:
	var template: EncounterTemplateDefinition = preload(
		"res://data/encounters/ruined_chapel_template.tres"
	)
	var battlefield: Node = template.battlefield_scene.instantiate()
	var scene_background := battlefield.get_node(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	var dialogue := DialogueDefinition.new()
	_expect(
		scene_background != null
		and scene_background.texture != null
		and dialogue.background_override == null,
		"Story dialogue should default to its launching scene's background."
	)
	var override_texture := load(
		"res://assets/exploration/layer1/butler_office/09_Butlers_Office.png"
	) as Texture2D
	dialogue.background_override = override_texture
	_expect(
		dialogue.background_override == override_texture,
		"A DialogueDefinition must still permit an explicit cutaway background."
	)
	battlefield.free()


func _test_recovered_party_can_enter_butlers_office() -> void:
	var recovered_party_sets: Array = [
		[&"lysandra", &"mira"],
		[&"lysandra", &"mira", &"seraphine"],
	]
	for party_value: Variant in recovered_party_sets:
		var party_ids: Array[StringName] = []
		var party_array: Array = party_value as Array
		for heroine_value: Variant in party_array:
			party_ids.append(StringName(heroine_value))
		var generator := LayerMapGenerator.new()
		var graph: LayerMapGraph = generator.generate_layer_1(27072026)
		var party_snapshot: Dictionary = {}
		for heroine_id: StringName in party_ids:
			party_snapshot[heroine_id] = _make_heroine_snapshot(8, 5, 35, 10)
		var narrative := NarrativeState.new()
		narrative.recruited_heroine_ids = party_ids.duplicate()
		var run := RunState.new()
		var initial_error: String = run.initialize(
			27072026,
			graph,
			generator.make_layer_1_generated_room_item_rules()
		)
		var initialize_error: String = run.initialize(
			27072026,
			generator.generate_layer_1(27072026),
			generator.make_layer_1_generated_room_item_rules(),
			party_snapshot,
			narrative.to_snapshot()
		)
		var office_node: MapNodeState
		for node_value: Variant in run.graph.nodes.values():
			var candidate := node_value as MapNodeState
			if candidate != null and candidate.room_definition_id == &"butlers_office":
				office_node = candidate
				break
		if office_node == null:
			_expect(false, "The recovery map must contain Butler's Office.")
			continue
		var screen_scene := load(
			"res://scenes/exploration/event_room_screen.tscn"
		) as PackedScene
		var screen := screen_scene.instantiate() as EventRoomScreen
		root.add_child(screen)
		await process_frame
		var preparation_error: String = screen.prepare_room(
			BUTLERS_OFFICE,
			run.get_event_room_state(office_node.node_id, BUTLERS_OFFICE.room_id),
			ITEM_CATALOG,
			BATTLER_CATALOG,
			LORE_CATALOG,
			KnowledgeState.new(),
			1,
			run.inventory_snapshot,
			run.party_snapshot,
			run.get_narrative_state_snapshot()
		)
		_expect(
			initial_error.is_empty()
			and initialize_error.is_empty()
			and run.narrative_state != null
			and office_node != null
			and preparation_error.is_empty()
			and screen.presentation != null
			and screen.current_party_ids == party_ids,
			"Butler's Office must load after a wipe with %d recruited heroines."
			% party_ids.size()
		)
		root.remove_child(screen)
		screen.free()


func _finish_mira_recruitment_test(
	run: RunState,
	encounter: EncounterDefinition
) -> void:
	var combat_outcome := EncounterOutcome.new()
	combat_outcome.result = EncounterOutcome.Result.VICTORY
	combat_outcome.encounter_id = encounter.encounter_id
	combat_outcome.source_node_id = encounter.source_node_id
	combat_outcome.party_snapshot = {
		&"lysandra": _make_heroine_snapshot(6, 2, 58, 8),
		&"mira": _make_heroine_snapshot(5, 3, 47, 11),
	}
	combat_outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	combat_outcome.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	combat_outcome.bloom_reward = 4

	var story_outcome := StoryDialogueOutcome.new()
	story_outcome.story_id = RunState.MIRA_RECRUITMENT_STORY_ID
	story_outcome.source_node_id = encounter.source_node_id
	story_outcome.party_snapshot = combat_outcome.party_snapshot.duplicate(true)
	story_outcome.inventory_snapshot = (
		combat_outcome.inventory_snapshot.duplicate(true)
	)
	story_outcome.dialogue_result_snapshots = [{
		"dialogue_id": String(RunState.MIRA_RECRUITMENT_STORY_ID),
		"selected_choice_id": "mira_recruitment_continue_together",
		"outcomes": [{
			"kind": DialogueOutcomeDefinition.Kind.RECRUIT_HEROINE,
			"scope": "run",
			"subject_id": "mira",
			"key": "",
			"integer_value": 1,
			"boolean_value": true,
		}],
		"session_snapshot": {
			"dialogue_id": String(RunState.MIRA_RECRUITMENT_STORY_ID),
			"current_node_id": "",
			"visited_node_ids": ["first_line"],
			"selected_choice_ids": [
				"mira_recruitment_continue_together",
			],
			"completed": true,
		},
	}]

	var source_node: MapNodeState = run.graph.get_map_node(
		encounter.source_node_id
	)
	var apply_error: String = run.apply_mira_recruitment_aftermath(
		combat_outcome,
		story_outcome
	)
	_expect(
		apply_error.is_empty()
		and source_node.cleared
		and run.pending_node_id == &""
		and run.party_snapshot.has(&"lysandra")
		and run.party_snapshot.has(&"mira")
		and run.narrative_state.recruited_heroine_ids.has(&"mira")
		and run.bloom == 4,
		"The aftermath must recruit Mira, preserve both combat states, clear the node, and grant Bloom once."
	)
	_expect(
		not run.apply_mira_recruitment_aftermath(
			combat_outcome,
			story_outcome
		).is_empty()
		and run.bloom == 4,
		"Mira's recruitment aftermath must not be applied twice."
	)

	var defeated_run: RunState = _make_run_at_butler_encounter()
	var defeated_encounter: EncounterDefinition = (
		defeated_run.make_encounter_definition()
	)
	var defeat := EncounterOutcome.new()
	defeat.result = EncounterOutcome.Result.DEFEAT
	defeat.encounter_id = defeated_encounter.encounter_id
	defeat.source_node_id = defeated_encounter.source_node_id
	defeat.party_snapshot = {
		&"lysandra": _make_heroine_snapshot(0, 0, 40, 20),
		&"mira": _make_heroine_snapshot(0, 0, 40, 20),
	}
	defeat.inventory_snapshot = defeated_run.inventory_snapshot.duplicate(true)
	var recovery_snapshot: Dictionary = (
		defeated_run.make_full_wipe_recovery_party_snapshot(
			defeat,
			BATTLER_CATALOG
		)
	)
	_expect(
		recovery_snapshot.has(&"lysandra")
		and not recovery_snapshot.has(&"mira")
		and int(
			(recovery_snapshot[&"lysandra"] as Dictionary).get("hp", 0)
		) == 8
		and int(
			(recovery_snapshot[&"lysandra"] as Dictionary).get("mp", 0)
		) == 8
		and int(
			(recovery_snapshot[&"lysandra"] as Dictionary).get(
				"resolve",
				0
			)
		) == 40
		and int(
			(recovery_snapshot[&"lysandra"] as Dictionary).get(
				"corruption",
				0
			)
		) == 20
		and not defeated_run.narrative_state.recruited_heroine_ids.has(&"mira"),
		(
			"Early full-wipe recovery must restore recruited heroines' "
			+ "HP/MP, preserve Resolve/Corruption, and exclude unrecruited Mira."
		)
	)
	var restarted_graph: LayerMapGraph = LayerMapGenerator.new().generate_layer_1(
		27072026
	)
	var restarted_run := RunState.new()
	var no_generated_rules: Array[GeneratedRoomItemPlacementRule] = []
	restarted_run.initialize(
		27072026,
		restarted_graph,
		no_generated_rules,
		recovery_snapshot
	)
	_expect(
		restarted_run.requires_opening_encounter()
		and restarted_run.party_snapshot.has(&"lysandra")
		and int(
			(restarted_run.party_snapshot[&"lysandra"] as Dictionary).get(
				"resolve",
				0
			)
		) == 40,
		(
			"The recovered snapshot must seed the restarted opening without "
			+ "discarding the full-wipe Resolve consequence."
		)
	)


func _test_deterministic_event_room_assignment_and_key_reachability() -> void:
	var generator := LayerMapGenerator.new()
	for seed: int in [27072026, 111, 222, 333, 56489751432]:
		var first: LayerMapGraph = generator.generate_layer_1(seed)
		var second: LayerMapGraph = generator.generate_layer_1(seed)
		var chapel_nodes: Array[MapNodeState] = first.get_nodes_in_column(
			LayerMapGenerator.COLUMN_COUNT - 2
		)
		var chapel: MapNodeState = (
			chapel_nodes[0] if chapel_nodes.size() == 1 else null
		)
		var chapel_is_mandatory: bool = (
			chapel != null
			and chapel.encounter_id
			== RunState.SERAPHINE_RECRUITMENT_ENCOUNTER_ID
			and chapel.outgoing_ids == [first.boss_node_id]
		)
		if chapel_is_mandatory:
			for approach: MapNodeState in first.get_nodes_in_column(
				LayerMapGenerator.COLUMN_COUNT - 3
			):
				chapel_is_mandatory = (
					chapel_is_mandatory
					and approach.outgoing_ids.has(chapel.node_id)
				)
		_expect(
			chapel_is_mandatory,
			"Every generated route must pass through Seraphine's Ruined Chapel before the boss for seed %d."
			% seed
		)
		var first_signature: PackedStringArray = (
			_get_event_room_signature(first)
		)
		_expect(
			first_signature == _get_event_room_signature(second)
			and _signature_contains_required_event_rooms(first_signature),
			"Event-room assignment must be complete and deterministic for seed %d."
			% seed
		)

		var run := RunState.new()
		var initialize_error: String = run.initialize(
			seed,
			first,
			generator.make_layer_1_generated_room_item_rules()
		)
		var host_id: StringName = _find_assignment_host(
			run.generated_room_item_requests,
			&"layer_1_rusty_key_01"
		)
		var host: MapNodeState = first.get_map_node(host_id)
		var host_is_valid: bool = (
			initialize_error.is_empty()
			and host != null
			and host.room_definition_id in [
				&"wine_cellar_warm_bottles",
				&"butlers_office",
			]
			and _is_reachable(first, host_id)
		)
		if (
			host_is_valid
			and host.room_definition_id == &"butlers_office"
		):
			host_is_valid = _is_reachable(
				first,
				host_id,
				&"wine_cellar_warm_bottles"
			)
		_expect(
			host_is_valid,
			(
				"The generated Rusty Key must remain reachable without "
				+ "crossing the locked Wine Cellar for seed %d."
			)
			% seed
		)


func _test_event_room_back_completion_and_persistence() -> void:
	var seed: int = 27072026
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph = generator.generate_layer_1(seed)
	var run := RunState.new()
	run.initialize(
		seed,
		graph,
		generator.make_layer_1_generated_room_item_rules()
	)
	_expect(
		run.apply_opening_encounter_outcome(
			_make_opening_victory(run, 0)
		).is_empty(),
		"The Event-room flow test should first complete the canonical opening."
	)

	var route: Array[StringName] = _find_route_to_first_event(graph)
	_expect(
		not route.is_empty(),
		"Generated Layer 1 should expose a route to an Event room."
	)
	if route.is_empty():
		return

	var event_id: StringName = route.back()
	for node_id: StringName in route:
		if node_id == event_id:
			break
		_expect(
			run.travel_to(node_id).is_empty(),
			"The cleared setup route should remain traversable."
		)
		run.complete_pending_node(0)

	var origin_id: StringName = run.current_node_id
	_expect(
		run.travel_to(event_id).is_empty(),
		"The Event room should be enterable from its generated route."
	)
	var event_node: MapNodeState = graph.get_map_node(event_id)
	var room_state: EventRoomInstanceState = run.get_event_room_state(
		event_id,
		event_node.room_definition_id
	)
	room_state.local_state["item_spawns"] = [
		{
			"spawn_id": "test_item",
			"entry_id": "warm_wine",
			"collected": true,
		},
	]
	room_state.local_state["event_spawns"] = [
		{
			"spawn_id": "test_event",
			"entry_id": "red_wax_vial_entry",
			"resolved": true,
			"outcome_id": "test_outcome",
		},
	]

	var back_outcome := EventRoomOutcome.new()
	back_outcome.source_node_id = event_id
	back_outcome.clear_node = false
	back_outcome.room_state_snapshot = room_state.to_snapshot()
	back_outcome.inventory_snapshot = _make_inventory_snapshot(2)
	back_outcome.party_snapshot = {
		&"lysandra": {
			"hp": 6,
			"mp": 1,
			"resolve": 54,
			"corruption": 13,
		}
	}
	back_outcome.bloom_delta = 7

	_expect(
		run.apply_event_room_outcome(back_outcome).is_empty()
		and run.current_node_id == origin_id
		and not event_node.cleared,
		"Back should preserve room state and return to the entrance without clearing the node."
	)
	_expect(
		run.bloom == 7
		and int(run.inventory_snapshot[0].get("quantity", 0)) == 2
		and int((run.party_snapshot[&"lysandra"] as Dictionary)["hp"])
		== 6,
		"Event-room Back must hand off Bloom, inventory, and party state."
	)

	var restored: EventRoomInstanceState = run.get_event_room_state(
		event_id,
		event_node.room_definition_id
	)
	var restored_items: Array = restored.local_state.get(
		"item_spawns",
		[]
	) as Array
	var restored_events: Array = restored.local_state.get(
		"event_spawns",
		[]
	) as Array
	_expect(
		not restored_items.is_empty()
		and bool((restored_items[0] as Dictionary).get("collected", false))
		and not restored_events.is_empty()
		and bool((restored_events[0] as Dictionary).get("resolved", false)),
		"Collected items and resolved room events must remain resolved on revisit."
	)

	_expect(
		run.travel_to(event_id).is_empty(),
		"An unresolved Event room should be re-enterable after Back."
	)
	var clear_outcome := EventRoomOutcome.new()
	clear_outcome.source_node_id = event_id
	clear_outcome.clear_node = true
	clear_outcome.room_state_snapshot = restored.to_snapshot()
	clear_outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	clear_outcome.party_snapshot = run.party_snapshot.duplicate(true)
	clear_outcome.bloom_delta = 0
	_expect(
		run.apply_event_room_outcome(clear_outcome).is_empty()
		and event_node.cleared
		and run.current_node_id == event_id
		and run.pending_node_id == &""
		and run.bloom == 7,
		"Room completion should clear the node without replaying already-transferred Bloom."
	)


func _test_locked_exit_survives_dialogue_restore() -> void:
	var screen_scene := load(
		"res://scenes/exploration/event_room_screen.tscn"
	) as PackedScene
	var room_scene := load(
		"res://scenes/exploration/rooms/layer1/wine_cellar_warm_bottles.tscn"
	) as PackedScene
	_expect(
		screen_scene != null and room_scene != null,
		"Wine Cellar lock regression scenes should load."
	)
	if screen_scene == null or room_scene == null:
		return

	var screen := screen_scene.instantiate() as EventRoomScreen
	root.add_child(screen)
	await process_frame
	var room: Node = room_scene.instantiate()
	screen.room_host.add_child(room)
	screen.presentation = room
	var room_lock := room.find_child(
		"RustyDoorLock",
		true,
		false
	) as RoomLockHotspot
	var room_exit := room.find_child(
		"RoomExitHotspot",
		true,
		false
	) as RoomExitHotspot
	_expect(
		room_lock != null and room_exit != null,
		"Wine Cellar should expose its linked lock and exit hotspots."
	)
	if room_lock != null and room_exit != null:
		screen.active_locks[room_lock.lock_id] = room_lock
		room_lock.apply_unlocked_state(false)
		screen._set_room_interactions_enabled(false)
		screen._set_room_interactions_enabled(true)
		var room_outcome_emitted: Array[bool] = [false]
		screen.room_outcome_ready.connect(
			func(_outcome: EventRoomOutcome) -> void:
				room_outcome_emitted[0] = true
		)
		screen._on_exit_requested(room_exit)
		_expect(
			not room_exit.is_interaction_enabled()
			and room_lock.is_interaction_enabled()
			and not room_outcome_emitted[0],
			(
				"Ending dialogue must leave a locked exit disabled, and the "
				+ "exit handler must reject passage until explicit unlock."
			)
		)

	root.remove_child(screen)
	screen.free()


func _test_wine_offer_consumes_room_bottle_only() -> void:
	var screen_scene := load(
		"res://scenes/exploration/event_room_screen.tscn"
	) as PackedScene
	var screen := screen_scene.instantiate() as EventRoomScreen
	root.add_child(screen)
	await process_frame

	var room_state := EventRoomInstanceState.new()
	room_state.source_node_id = &"layer_1_wine_offer_test"
	room_state.room_id = WINE_CELLAR.room_id
	room_state.generation_seed = 27072026
	var carried_inventory: Array[Dictionary] = _make_inventory_snapshot(1)
	var prepare_error: String = screen.prepare_room(
		WINE_CELLAR,
		room_state,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		LORE_CATALOG,
		KnowledgeState.new(),
		1,
		carried_inventory,
		{
			&"lysandra": _make_heroine_snapshot(1, 1, 40, 20),
			&"mira": _make_heroine_snapshot(0, 1, 40, 20),
		},
		NarrativeState.new().to_snapshot()
	)
	await process_frame
	await process_frame

	var before_carried_wine: int = (
		screen.inventory.get_slot(2).quantity
		if screen.inventory != null
		else -1
	)
	var offer_result: DialogueResult
	if screen.dialogue_runner != null:
		offer_result = screen.dialogue_runner.choose(&"wine_cellar_accept")
		screen._handle_dialogue_result(offer_result)

	var guaranteed_consumed: bool = false
	var optional_pickups_unchanged: bool = true
	var assignments: Array = room_state.local_state.get("item_spawns", []) as Array
	for assignment_value: Variant in assignments:
		var assignment := assignment_value as Dictionary
		if StringName(assignment.get("source_id", "")) == &"wine_cellar_specific":
			guaranteed_consumed = bool(assignment.get("collected", false))
		elif StringName(assignment.get("item_id", "")) == &"l01_warm_wine_flask":
			optional_pickups_unchanged = optional_pickups_unchanged and not bool(
				assignment.get("collected", false)
			)

	var party_snapshot: Dictionary = screen._capture_party_snapshot()
	var lysandra: Dictionary = party_snapshot.get(&"lysandra", {}) as Dictionary
	var mira: Dictionary = party_snapshot.get(&"mira", {}) as Dictionary
	var mira_state := screen.party_states.get(&"mira") as BattlerState
	_expect(
		prepare_error.is_empty()
		and offer_result != null
		and offer_result.error_message.is_empty()
		and guaranteed_consumed
		and optional_pickups_unchanged
		and screen.inventory.get_slot(2).quantity == before_carried_wine
		and int(lysandra.get("hp", 0)) == 8
		and int(lysandra.get("mp", 0)) == 8
		and int(lysandra.get("resolve", 0)) == 50
		and int(lysandra.get("corruption", 0)) == 30
		and int(mira.get("hp", 0)) == 5
		and int(mira.get("mp", 0)) == 7
		and mira_state != null
		and not mira_state.is_defeated
		and mira_state.current_actions == 0
		and mira_state.max_actions == 0,
		(
			"Accepting the Wine offer must consume only the guaranteed room bottle, "
			+ "leave carried/optional bottles untouched, revive defeated heroines, "
			+ "and apply the full party effect."
		)
	)

	root.remove_child(screen)
	screen.free()


func _make_run_at_butler_encounter() -> RunState:
	var seed: int = 27072026
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph = generator.generate_layer_1(seed)
	var run := RunState.new()
	run.initialize(
		seed,
		graph,
		generator.make_layer_1_generated_room_item_rules()
	)
	run.apply_opening_encounter_outcome(
		_make_opening_victory(run, 0)
	)
	var first_map_node: MapNodeState = graph.get_nodes_in_column(1)[0]
	run.travel_to(first_map_node.node_id)
	return run


func _make_run_at_seraphine_encounter() -> RunState:
	var seed: int = 27072026
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph = generator.generate_layer_1(seed)
	var run := RunState.new()
	run.initialize(
		seed,
		graph,
		generator.make_layer_1_generated_room_item_rules()
	)
	run.opening_completed = true
	run.party_snapshot = {
		&"lysandra": _make_heroine_snapshot(7, 3, 50, 10),
		&"mira": _make_heroine_snapshot(5, 4, 48, 12),
	}
	run.narrative_state.recruited_heroine_ids = [&"lysandra", &"mira"]
	var chapel_node: MapNodeState = graph.get_nodes_in_column(
		LayerMapGenerator.COLUMN_COUNT - 2
	)[0]
	chapel_node.visited = true
	run.current_node_id = chapel_node.node_id
	run.selected_node_id = chapel_node.node_id
	run.pending_node_id = chapel_node.node_id
	return run


func _make_heroine_snapshot(
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


func _make_opening_victory(
	run: RunState,
	bloom_reward: int
) -> EncounterOutcome:
	var outcome := EncounterOutcome.new()
	outcome.result = EncounterOutcome.Result.VICTORY
	outcome.encounter_id = RunState.OPENING_ENCOUNTER_ID
	outcome.source_node_id = RunState.OPENING_SOURCE_NODE_ID
	outcome.party_snapshot = {
		&"lysandra": {
			"hp": 7,
			"mp": 2,
			"resolve": 61,
			"corruption": 9,
			"item_guard": 0,
			"weapon_damage": 0,
			"weapon_broken": false,
			"armor_damage": 0,
			"armor_broken": false,
			"shield_damage": 0,
			"shield_broken": false,
		}
	}
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.heroine_progression_snapshot = {
		&"lysandra": (
			run.heroine_progression_snapshot[&"lysandra"]
			as Dictionary
		).duplicate(true)
	}
	outcome.bloom_reward = bloom_reward
	return outcome


func _make_inventory_snapshot(
	first_quantity: int
) -> Array[Dictionary]:
	return [
		{"slot_index": 0, "item_id": "l01_bandage_roll", "quantity": first_quantity},
		{"slot_index": 1, "item_id": "l01_smelling_salts", "quantity": 1},
		{"slot_index": 2, "item_id": "l01_warm_wine_flask", "quantity": 1},
		{"slot_index": 3, "item_id": "", "quantity": 0},
		{"slot_index": 4, "item_id": "l01_red_wax_ampoule", "quantity": 1},
		{"slot_index": 5, "item_id": "", "quantity": 0},
	]


func _get_event_room_signature(
	graph: LayerMapGraph
) -> PackedStringArray:
	var signature := PackedStringArray()
	for node_value: Variant in graph.nodes.values():
		var node := node_value as MapNodeState
		if node != null and node.room_definition_id != &"":
			signature.append(
				"%s@%s" % [
					node.room_definition_id,
					node.node_id,
				]
			)
	signature.sort()
	return signature


func _signature_contains_required_event_rooms(
	signature: PackedStringArray
) -> bool:
	for room_id: StringName in LayerMapGenerator.LAYER_1_EVENT_ROOM_POOL:
		var found := false
		for entry: String in signature:
			if entry.begins_with("%s@" % room_id):
				found = true
				break
		if not found:
			return false
	return true


func _find_assignment_host(
	requests_by_node: Dictionary,
	assignment_id: StringName
) -> StringName:
	for node_value: Variant in requests_by_node.keys():
		var requests: Array = requests_by_node.get(
			node_value,
			[]
		) as Array
		for request_value: Variant in requests:
			if (
				request_value is Dictionary
				and StringName(
					(request_value as Dictionary).get(
						"assignment_id",
						""
					)
				) == assignment_id
			):
				return StringName(node_value)
	return &""


func _is_reachable(
	graph: LayerMapGraph,
	target_id: StringName,
	blocked_room_id: StringName = &""
) -> bool:
	var frontier: Array[StringName] = [graph.start_node_id]
	var visited: Dictionary = {}
	while not frontier.is_empty():
		var node_id: StringName = frontier.pop_front()
		if visited.has(node_id):
			continue
		visited[node_id] = true
		if node_id == target_id:
			return true
		var node: MapNodeState = graph.get_map_node(node_id)
		if node == null:
			continue
		for next_id: StringName in node.outgoing_ids:
			var next_node: MapNodeState = graph.get_map_node(next_id)
			if (
				next_node != null
				and (
					blocked_room_id == &""
					or next_node.room_definition_id
					!= blocked_room_id
				)
			):
				frontier.append(next_id)
	return false


func _find_route_to_first_event(
	graph: LayerMapGraph
) -> Array[StringName]:
	var frontier: Array[Dictionary] = [{
		"node_id": graph.start_node_id,
		"route": [],
	}]
	var visited: Dictionary = {}
	while not frontier.is_empty():
		var entry: Dictionary = frontier.pop_front()
		var node_id := StringName(entry.get("node_id", ""))
		if visited.has(node_id):
			continue
		visited[node_id] = true
		var node: MapNodeState = graph.get_map_node(node_id)
		var route: Array[StringName] = []
		for route_value: Variant in (entry.get("route", []) as Array):
			route.append(StringName(route_value))
		if (
			node_id != graph.start_node_id
			and node != null
			and node.requires_event_room()
		):
			return route
		if node == null:
			continue
		for next_id: StringName in node.outgoing_ids:
			var next_route: Array[StringName] = route.duplicate()
			next_route.append(next_id)
			frontier.append({
				"node_id": next_id,
				"route": next_route,
			})
	return []


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
