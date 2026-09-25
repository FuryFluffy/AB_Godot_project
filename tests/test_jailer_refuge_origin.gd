extends SceneTree


const REFUGE_ORIGIN: DialogueDefinition = preload(
	"res://data/dialogue/layer2_refuge_origin.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const TEST_DIRECTORY: String = "user://abyssal_bloom_jailer_origin_tests"


var failures: int = 0


func _init() -> void:
	CampaignSaveSlotStore.set_test_save_directory(TEST_DIRECTORY)
	_cleanup()
	_test_immediate_jailer_and_refuge_origin()
	_cleanup()
	CampaignSaveSlotStore.clear_test_save_directory()

	if failures == 0:
		print("Immediate Jailer and Bloom Refuge origin tests passed.")
	else:
		push_error("%d Jailer/Refuge test(s) failed." % failures)
	quit(failures)


func _test_immediate_jailer_and_refuge_origin() -> void:
	var generator := LayerMapGenerator.new()
	var party: Dictionary = {
		&"lysandra": _heroine_snapshot(10, 4, 100, 8),
		&"mira": _heroine_snapshot(9, 6, 100, 12),
		&"seraphine": _heroine_snapshot(8, 8, 100, 4),
	}
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		27072026,
		generator.generate_layer_2_entry(27072026),
		[],
		party
	)
	run.opening_completed = true
	run.campaign_lifecycle.begin_refugeless_ascent(
		RunState.BLOOD_NUN_GO_DOWN_CHOICE_ID
	)
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	var initial_save_flags: Dictionary = (
		run.narrative_state.flags_by_scope.get(&"save", {}) as Dictionary
	)
	initial_save_flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	var entry_error: String = run.begin_immediate_jailer_encounter()
	var seed_error: String = run.prepare_pending_node_seed()
	var active_save_error: String = CampaignSaveSlotStore.save_active_run_slot(
		1,
		run,
		KnowledgeState.new(),
		"pre_node"
	)
	var encounter: EncounterDefinition = run.make_encounter_definition()
	_expect(
		initialize_error.is_empty()
		and entry_error.is_empty()
		and seed_error.is_empty()
		and active_save_error.is_empty()
		and run.pending_node_id == RunState.JAILER_FIRST_NODE_ID
		and encounter != null
		and encounter.encounter_id == RunState.JAILER_FIRST_ENCOUNTER_ID
		and encounter.enemy_ids == [&"jailer"]
		and encounter.difficulty_label == "Hard Major Boss",
		"Go Down must enter the playable Jailer boss immediately."
	)

	var defeat := EncounterOutcome.new()
	defeat.result = EncounterOutcome.Result.DEFEAT
	defeat.encounter_id = RunState.JAILER_FIRST_ENCOUNTER_ID
	defeat.source_node_id = RunState.JAILER_FIRST_NODE_ID
	defeat.party_snapshot = {
		&"lysandra": _heroine_snapshot(0, 0, 85, 8),
		&"mira": _heroine_snapshot(0, 0, 85, 12),
		&"seraphine": _heroine_snapshot(0, 0, 85, 4),
	}
	defeat.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	defeat.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	var recovered: Dictionary = run.make_full_wipe_recovery_party_snapshot(
		defeat,
		BATTLER_CATALOG
	)
	var story_outcome: StoryDialogueOutcome = _make_refuge_story_outcome(
		run,
		defeat,
		recovered
	)
	var layer_2_graph: LayerMapGraph = run.graph
	var apply_error: String = run.apply_first_jailer_defeat_and_refuge_origin(
		defeat,
		story_outcome,
		generator.generate_bloom_refuge_holding_state(run.run_seed),
		BATTLER_CATALOG
	)
	var lysandra: Dictionary = run.party_snapshot.get(&"lysandra", {})
	var save_flags: Dictionary = (
		run.narrative_state.flags_by_scope.get(&"save", {}) as Dictionary
	)
	var refuge_save_error: String = CampaignSaveSlotStore.save_refuge_slot(
		1,
		run,
		KnowledgeState.new()
	)
	var saved_document: Dictionary = _read_json(
		CampaignSaveSlotStore.get_slot_path(1)
	)
	var bloom_after_origin: int = run.bloom
	var duplicate_error: String = (
		run.apply_first_jailer_defeat_and_refuge_origin(
			defeat,
			story_outcome,
			generator.generate_bloom_refuge_holding_state(run.run_seed),
			BATTLER_CATALOG
		)
	)
	_expect(
		apply_error.is_empty()
		and run.graph.layer_id == &"bloom_refuge"
		and run.current_node_id == &"bloom_refuge_farthest_cell"
		and run.pending_node_id == &""
		and run.archived_layer_graphs.get(&"layer_2") == layer_2_graph
		and not layer_2_graph.get_map_node(
			RunState.JAILER_FIRST_NODE_ID
		).cleared
		and bool(save_flags.get(
			RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID,
			false
		))
		and run.narrative_state.resolved_interaction_ids.has(
			RunState.REFUGE_ORIGIN_STORY_ID
		)
		and int(lysandra.get("hp", 0)) == (
			BATTLER_CATALOG.get_battler(&"lysandra").max_hp
		)
		and int(lysandra.get("mp", -1)) == (
			BATTLER_CATALOG.get_battler(&"lysandra").max_mp
		)
		and int(lysandra.get("resolve", 0)) == 85,
		"First Jailer defeat must atomically establish the Refuge and preserve the -15 Resolve consequence."
	)
	_expect(
		refuge_save_error.is_empty()
		and saved_document.get("active_run_snapshot", 1) == null
		and not bool(CampaignSaveSlotStore.get_slot_summary(1).get(
			"resumable",
			true
		))
		and not duplicate_error.is_empty()
		and run.bloom == bloom_after_origin
		and not run.has_defeated_boss(RunState.JAILER_BOSS_ID),
		"Jailer defeat must establish and save the Refuge once without resolving the boss or retaining Continue."
	)


func _make_refuge_story_outcome(
	run: RunState,
	combat_outcome: EncounterOutcome,
	recovered_party: Dictionary
) -> StoryDialogueOutcome:
	var context := DialogueContext.new()
	context.current_party_ids = [&"lysandra", &"mira", &"seraphine"]
	context.present_actor_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
		&"jailer",
	]
	context.recruited_heroine_ids = [&"lysandra", &"mira", &"seraphine"]
	context.flags_by_scope = run.narrative_state.flags_by_scope.duplicate(true)

	var runner := DialogueRunner.new()
	var start_error: String = runner.start(REFUGE_ORIGIN, context)
	for _step: int in range(5):
		runner.advance()
	var completion: DialogueResult = runner.choose(
		&"layer_2_refuge_rise_together"
	)
	_expect(
		start_error.is_empty()
		and completion.completed
		and completion.selected_choice_id == &"layer_2_refuge_rise_together",
		"The authored Refuge origin must reach its atomic completion choice."
	)

	var outcome := StoryDialogueOutcome.new()
	outcome.story_id = RunState.REFUGE_ORIGIN_STORY_ID
	outcome.source_node_id = combat_outcome.source_node_id
	outcome.inventory_snapshot = combat_outcome.inventory_snapshot.duplicate(true)
	outcome.party_snapshot = recovered_party.duplicate(true)
	outcome.dialogue_result_snapshots = [completion.to_snapshot()]
	return outcome


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


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value as Dictionary if value is Dictionary else {}


func _cleanup() -> void:
	for slot_id: int in range(1, CampaignSaveSlotStore.SLOT_COUNT + 1):
		CampaignSaveSlotStore.delete_slot(slot_id)
	var absolute: String = ProjectSettings.globalize_path(TEST_DIRECTORY)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
