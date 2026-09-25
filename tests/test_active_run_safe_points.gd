extends SceneTree


const DIALOGUE_FIXTURES = preload(
	"res://tests/dialogue_production_test_fixtures.gd"
)


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const TEST_DIRECTORY: String = "user://abyssal_bloom_active_run_tests"

var failures: int = 0


func _init() -> void:
	CampaignSaveSlotStore.set_test_save_directory(TEST_DIRECTORY)
	_cleanup()
	_test_pre_and_post_round_trip()
	_test_jailer_to_reverse_layer_2_safe_points_and_refuge_clear()
	_test_malformed_restore_is_transactional()
	_test_write_failure_and_latest_continue_selection()
	_test_backup_recovery_and_clear()
	_test_refuge_return_and_defeat_clear_continue()
	_test_refuge_controls_are_not_production_reachable()
	_cleanup()
	CampaignSaveSlotStore.force_test_write_failure = false
	CampaignSaveSlotStore.clear_test_save_directory()
	if failures == 0:
		print("Active-run safe-point tests passed.")
	else:
		push_error("%d active-run safe-point test(s) failed." % failures)
	quit(failures)


func _test_pre_and_post_round_trip() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_active_layer_2_run(generator)
	var knowledge := KnowledgeState.new()
	knowledge.discovered_entries = {"butlers_records": true}
	var target_id := &"l2_c1_n0"
	var generated_target: MapNodeState = run.graph.get_map_node(target_id)
	var travel_error: String = run.travel_to(target_id)
	var seed_error: String = run.prepare_pending_node_seed()
	var saved_seed: int = run.pending_node_seed
	var premature_post_error: String = CampaignSaveSlotStore.save_active_run_slot(
		1, run, knowledge, "post_node"
	)
	var pre_save_error: String = CampaignSaveSlotStore.save_active_run_slot(
		1, run, knowledge, "pre_node"
	)
	var pre_document: Dictionary = _read_json(
		CampaignSaveSlotStore.get_slot_path(1)
	)
	var active: Dictionary = pre_document.get("active_run_snapshot", {}) as Dictionary
	var active_keys: Array[String] = []
	for key: Variant in active.keys():
		active_keys.append(String(key))
	active_keys.sort()
	var restored := RunState.new()
	var restore_error: String = restored.restore_active_run_snapshot(
		active,
		BATTLER_CATALOG
	)
	var restored_encounter: EncounterDefinition = restored.make_encounter_definition()
	_expect(
		travel_error.is_empty()
		and seed_error.is_empty()
		and not premature_post_error.is_empty()
		and pre_save_error.is_empty()
		and int(pre_document.get("save_version", 0)) == 3
		and active_keys == [
			"campaign_seed", "layer_id", "map_snapshot", "run_snapshot",
			"safe_point_kind", "selected_node_id", "selected_node_seed",
		]
		and String(active.get("safe_point_kind", "")) == "pre_node"
		and String(active.get("selected_node_id", "")) == String(target_id)
		and int(active.get("selected_node_seed", 0)) == saved_seed
		and restore_error.is_empty()
		and restored.pending_node_id == target_id
		and restored.pending_node_seed == saved_seed
		and generated_target != null
		and generated_target.authored_room_id == &"chain_maintenance_room"
		and generated_target.content_seed > 0
		and restored.graph.get_map_node(target_id).authored_room_id
		== generated_target.authored_room_id
		and restored.graph.get_map_node(target_id).content_seed
		== generated_target.content_seed
		and restored_encounter != null
		and restored_encounter.encounter_seed == saved_seed
		and restored.run_inventory.get_key_quantity(&"shared_rusty_key") == 1
		and restored.run_inventory.material_pouch.is_empty()
		and restored.run_inventory.get_memento_id(&"mira") == &"l01_hollow_livery_pin"
		and not restored.active_run_refuge_boundary_snapshot.is_empty(),
		"A pre-node v3 safe point must round-trip exact deterministic state. save=%s restore=%s"
		% [pre_save_error, restore_error]
	)

	var bloom_before: int = run.bloom
	var complete_error: String = run.complete_pending_node(4)
	var stale_pre_error: String = CampaignSaveSlotStore.save_active_run_slot(
		1, run, knowledge, "pre_node"
	)
	var post_save_error: String = CampaignSaveSlotStore.save_active_run_slot(
		1, run, knowledge, "post_node"
	)
	var post_document: Dictionary = _read_json(
		CampaignSaveSlotStore.get_slot_path(1)
	)
	var post_active: Dictionary = post_document.get("active_run_snapshot", {}) as Dictionary
	var post_restored := RunState.new()
	var post_restore_error: String = post_restored.restore_active_run_snapshot(
		post_active,
		BATTLER_CATALOG
	)
	var post_node: MapNodeState = post_restored.graph.get_map_node(target_id)
	_expect(
		complete_error.is_empty()
		and not stale_pre_error.is_empty()
		and post_save_error.is_empty()
		and post_restore_error.is_empty()
		and String(post_active.get("safe_point_kind", "")) == "post_node"
		and post_active.get("selected_node_id", 1) == null
		and post_active.get("selected_node_seed", 1) == null
		and post_restored.pending_node_id == &""
		and post_node != null and post_node.cleared and post_node.reward_claimed
		and post_restored.bloom == bloom_before + 4
		and post_restored.complete_pending_node(4) != "",
		"A post-node safe point must retain one resolved reward and no replay target."
	)


func _test_malformed_restore_is_transactional() -> void:
	var generator := LayerMapGenerator.new()
	var source: RunState = _make_active_layer_2_run(generator)
	source.travel_to(&"l2_c1_n0")
	source.prepare_pending_node_seed()
	var snapshot: Dictionary = source.make_active_run_snapshot(
		"pre_node", KnowledgeState.new()
	)
	var malformed: Dictionary = snapshot.duplicate(true)
	var malformed_run: Dictionary = malformed.get("run_snapshot", {}) as Dictionary
	var malformed_inventory: Dictionary = malformed_run.get("run_inventory", {}) as Dictionary
	malformed_inventory["key_chain"] = {"shared_rusty_key": -1}
	var target: RunState = _make_active_layer_2_run(generator)
	target.bloom = 123
	var before_graph: Dictionary = target.graph.to_snapshot()
	var before_inventory: Dictionary = target.run_inventory.get_snapshot()
	var restore_error: String = target.restore_active_run_snapshot(
		malformed,
		BATTLER_CATALOG
	)
	_expect(
		not restore_error.is_empty()
		and target.bloom == 123
		and target.graph.to_snapshot() == before_graph
		and target.run_inventory.get_snapshot() == before_inventory,
		"Malformed active-run data must not partially mutate the current run."
	)


func _test_jailer_to_reverse_layer_2_safe_points_and_refuge_clear() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_refugeless_jailer_run(generator)
	var knowledge := KnowledgeState.new()
	var seed_error: String = run.prepare_pending_node_seed()
	var saved_pre_seed: int = run.pending_node_seed
	var pre_save_error: String = CampaignSaveSlotStore.save_active_run_slot(
		2,
		run,
		knowledge,
		"pre_node"
	)
	var pre_document: Dictionary = _read_json(
		CampaignSaveSlotStore.get_slot_path(2)
	)
	var pre_active: Dictionary = pre_document.get(
		"active_run_snapshot",
		{}
	) as Dictionary
	var pre_restored := RunState.new()
	var pre_restore_error: String = pre_restored.restore_active_run_snapshot(
		pre_active,
		BATTLER_CATALOG
	)

	var victory := EncounterOutcome.new()
	victory.result = EncounterOutcome.Result.VICTORY
	victory.encounter_id = RunState.JAILER_FIRST_ENCOUNTER_ID
	victory.source_node_id = RunState.JAILER_FIRST_NODE_ID
	victory.party_snapshot = run.party_snapshot.duplicate(true)
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
	var post_save_error: String = CampaignSaveSlotStore.save_active_run_slot(
		2,
		run,
		knowledge,
		"post_node"
	)
	var post_document: Dictionary = _read_json(
		CampaignSaveSlotStore.get_slot_path(2)
	)
	var post_active: Dictionary = post_document.get(
		"active_run_snapshot",
		{}
	) as Dictionary
	var post_restored := RunState.new()
	var post_restore_error: String = post_restored.restore_active_run_snapshot(
		post_active,
		BATTLER_CATALOG
	)
	var restored_jailer: MapNodeState = post_restored.graph.get_map_node(
		RunState.JAILER_FIRST_NODE_ID
	) if post_restore_error.is_empty() else null
	_expect(
		seed_error.is_empty()
		and pre_save_error.is_empty()
		and pre_restore_error.is_empty()
		and pre_restored.pending_node_id == RunState.JAILER_FIRST_NODE_ID
		and pre_restored.pending_node_seed == saved_pre_seed
		and victory_error.is_empty()
		and post_save_error.is_empty()
		and post_restore_error.is_empty()
		and post_restored.pending_node_id == &""
		and post_restored.current_node_id == RunState.JAILER_FIRST_NODE_ID
		and post_restored.graph.start_node_id
		== RunState.LAYER_2_FARTHEST_CELL_NODE_ID
		and post_restored.is_refugeless_ascent()
		and not post_restored.has_established_refuge()
		and restored_jailer != null
		and restored_jailer.cleared
		and restored_jailer.reward_claimed
		and restored_jailer.encounter_id == &"",
		"Pre-Jailer and post-victory safe points must restore the exact transition without replaying the boss."
	)

	var traversal_error: String = _complete_reverse_route(run)
	var establish_error: String = run.establish_refuge_at_farthest_cell(
		generator.generate_bloom_refuge_holding_state(run.run_seed),
		BATTLER_CATALOG,
		DIALOGUE_FIXTURES.make_farthest_cell_outcome(run)
	)
	var refuge_save_error: String = CampaignSaveSlotStore.save_refuge_slot(
		2,
		run,
		knowledge
	)
	var refuge_document: Dictionary = _read_json(
		CampaignSaveSlotStore.get_slot_path(2)
	)
	_expect(
		traversal_error.is_empty()
		and establish_error.is_empty()
		and refuge_save_error.is_empty()
		and refuge_document.get("active_run_snapshot", 1) == null
		and not bool(CampaignSaveSlotStore.get_slot_summary(2).get(
			"resumable",
			true
		)),
		"Farthest Cell Refuge establishment must replace the active Continue boundary."
	)
func _test_write_failure_and_latest_continue_selection() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_active_layer_2_run(generator)
	run.travel_to(&"l2_c1_n0")
	var lifecycle_before: Dictionary = run.make_campaign_lifecycle_snapshot()
	run.prepare_pending_node_seed()
	CampaignSaveSlotStore.force_test_write_failure = true
	var write_error: String = CampaignSaveSlotStore.save_active_run_slot(
		1, run, KnowledgeState.new(), "pre_node"
	)
	CampaignSaveSlotStore.force_test_write_failure = false
	var rollback_error: String = run.rollback_pending_node_entry(
		&"l2_c1_n0", false, lifecycle_before
	)
	_expect(
		not write_error.is_empty()
		and rollback_error.is_empty()
		and run.current_node_id == run.graph.start_node_id
		and run.pending_node_id == &""
		and run.campaign_lifecycle.combat_sequence_index
		== int(lifecycle_before.get("combat_sequence_index", -1)),
		"A failed pre-node write must permit transactional node-entry rollback."
	)

	var active_run: RunState = _make_active_layer_2_run(generator)
	active_run.travel_to(&"l2_c1_n0")
	active_run.prepare_pending_node_seed()
	var active_snapshot: Dictionary = active_run.make_active_run_snapshot(
		"pre_node", KnowledgeState.new()
	)
	var anchor: Dictionary = CampaignSaveStore.make_active_campaign_anchor_snapshot(
		active_run, KnowledgeState.new()
	)
	_write_json(
		CampaignSaveSlotStore.get_slot_path(1),
		CampaignSaveSlotStore.make_v3_envelope(
			1, anchor, active_run.campaign_lifecycle.campaign_seed,
			100, 200, {}, active_snapshot
		)
	)
	_write_json(
		CampaignSaveSlotStore.get_slot_path(2),
		CampaignSaveSlotStore.make_v3_envelope(
			2, anchor, active_run.campaign_lifecycle.campaign_seed,
			100, 300, {}, active_snapshot
		)
	)
	_expect(
		CampaignSaveSlotStore.get_latest_resumable_slot_id() == 2
		and bool(CampaignSaveSlotStore.get_slot_summary(2).get("resumable", false)),
		"Continue must select the newest validated non-null active-run safe point."
	)


func _test_backup_recovery_and_clear() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_active_layer_2_run(generator)
	run.travel_to(&"l2_c1_n0")
	run.prepare_pending_node_seed()
	var knowledge := KnowledgeState.new()
	var first_error: String = CampaignSaveSlotStore.save_active_run_slot(
		3, run, knowledge, "pre_node"
	)
	run.complete_pending_node(4)
	var second_error: String = CampaignSaveSlotStore.save_active_run_slot(
		3, run, knowledge, "post_node"
	)
	var corrupt: FileAccess = FileAccess.open(
		CampaignSaveSlotStore.get_slot_path(3), FileAccess.WRITE
	)
	if corrupt != null:
		corrupt.store_string("{broken")
		corrupt.close()
	var recovery: Dictionary = CampaignSaveSlotStore.read_document_for_load(3)
	var recovered_document: Dictionary = recovery.get("document", {}) as Dictionary
	var recovered_active: Dictionary = recovered_document.get(
		"active_run_snapshot", {}
	) as Dictionary
	_expect(
		first_error.is_empty() and second_error.is_empty()
		and bool(recovery.get("used_backup", false))
		and String(recovered_active.get("safe_point_kind", "")) == "pre_node",
		"A corrupt primary must recover the prior verified active-run safe point."
	)
	var clear_error: String = CampaignSaveSlotStore.clear_active_run_snapshot(3)
	var cleared: Dictionary = _read_json(CampaignSaveSlotStore.get_slot_path(3))
	_expect(
		clear_error.is_empty()
		and cleared.get("active_run_snapshot", 1) == null
		and not bool(CampaignSaveSlotStore.get_slot_summary(3).get("resumable", true)),
		"Run resolution/abandonment must atomically clear the Continue target."
	)


func _test_refuge_controls_are_not_production_reachable() -> void:
	var scene_text: String = FileAccess.get_file_as_string(
		"res://scenes/refuge/bloom_refuge_screen.tscn"
	)
	_expect(
		not scene_text.contains("SaveCampaign")
		and not scene_text.contains("LoadCampaign"),
		"Production Refuge must expose no Save/Load controls."
	)


func _test_refuge_return_and_defeat_clear_continue() -> void:
	_cleanup()
	var generator := LayerMapGenerator.new()
	var knowledge := KnowledgeState.new()
	var voluntary: RunState = _make_active_layer_2_run(generator)
	voluntary.travel_to(&"l2_c1_n0")
	voluntary.prepare_pending_node_seed()
	var active_save_error: String = CampaignSaveSlotStore.save_active_run_slot(
		1, voluntary, knowledge, "pre_node"
	)
	voluntary.reward_resolutions["test_return_boundary"] = {
		"transient_active_run_state": true,
	}
	var return_error: String = voluntary.return_current_run_to_refuge(
		generator.generate_bloom_refuge_holding_state(voluntary.run_seed),
		BATTLER_CATALOG
	)
	var return_save_error: String = CampaignSaveSlotStore.save_refuge_slot(
		1, voluntary, knowledge
	)
	var returned_document: Dictionary = _read_json(
		CampaignSaveSlotStore.get_slot_path(1)
	)
	_expect(
		active_save_error.is_empty()
		and return_error.is_empty()
		and return_save_error.is_empty()
		and voluntary.reward_resolutions.is_empty()
		and returned_document.get("active_run_snapshot", 1) == null,
		"Voluntary Refuge return must atomically replace active Continue state."
	)

	var defeated: RunState = _make_active_layer_2_run(generator)
	defeated.travel_to(&"l2_c1_n0")
	defeated.prepare_pending_node_seed()
	var defeat_active_error: String = CampaignSaveSlotStore.save_active_run_slot(
		2, defeated, knowledge, "pre_node"
	)
	defeated.reward_resolutions["test_defeat_boundary"] = {
		"transient_active_run_state": true,
	}
	var outcome := EncounterOutcome.new()
	outcome.result = EncounterOutcome.Result.DEFEAT
	outcome.encounter_id = &"layer_2_future_regular"
	outcome.source_node_id = &"l2_c1_n0"
	outcome.party_snapshot = defeated.party_snapshot.duplicate(true)
	for heroine_value: Variant in outcome.party_snapshot.values():
		if heroine_value is Dictionary:
			(heroine_value as Dictionary)["hp"] = 0
	outcome.inventory_snapshot = defeated.inventory_snapshot.duplicate(true)
	outcome.heroine_progression_snapshot = (
		defeated.heroine_progression_snapshot.duplicate(true)
	)
	var defeat_error: String = defeated.apply_post_refuge_defeat(
		outcome,
		generator.generate_bloom_refuge_holding_state(defeated.run_seed),
		BATTLER_CATALOG
	)
	var defeat_save_error: String = CampaignSaveSlotStore.save_refuge_slot(
		2, defeated, knowledge
	)
	var defeated_document: Dictionary = _read_json(
		CampaignSaveSlotStore.get_slot_path(2)
	)
	_expect(
		defeat_active_error.is_empty()
		and defeat_error.is_empty()
		and defeat_save_error.is_empty()
		and defeated.reward_resolutions.is_empty()
		and defeated_document.get("active_run_snapshot", 1) == null,
		"Full-party defeat must atomically replace active Continue state."
	)


func _make_active_layer_2_run(generator: LayerMapGenerator) -> RunState:
	var run := RunState.new()
	var party: Dictionary = {
		&"lysandra": _heroine_snapshot(10, 4, 73, 8),
		&"mira": _heroine_snapshot(9, 6, 69, 12),
		&"seraphine": _heroine_snapshot(8, 8, 81, 4),
	}
	run.initialize(
		27072026,
		generator.generate_bloom_refuge_holding_state(27072026),
		[],
		party
	)
	run.opening_completed = true
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = [&"lysandra", &"mira", &"seraphine"]
	run.campaign_lifecycle.restore_legacy_refuge(27072026)
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	var save_flags: Dictionary = run.narrative_state.flags_by_scope.get(&"save", {}) as Dictionary
	save_flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	save_flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	run.ensure_refuge_ownership_initialized()
	run.refuge_ownership.key_chain = {"shared_rusty_key": 1}
	run.refuge_ownership.assign_memento(&"mira", &"l01_hollow_livery_pin")
	var begin_error: String = run.begin_next_layer_2_run(
		generator.generate_layer_2_run(27072027)
	)
	_expect(begin_error.is_empty(), "Active-run fixture must leave the Refuge. %s" % begin_error)
	var loadout: PersonalEquipmentLoadoutState = run.run_equipment.get_loadout(&"lysandra")
	if loadout != null:
		var weapon: EquipmentInstance = loadout.get_equipped_instance(
			EquipmentDefinition.Slot.MAIN_HAND
		)
		if weapon != null:
			weapon.apply_condition_damage(1)
	return run


func _make_refugeless_jailer_run(generator: LayerMapGenerator) -> RunState:
	var campaign_seed: int = 28072026
	var run := RunState.new()
	var party: Dictionary = {
		&"lysandra": _heroine_snapshot(10, 4, 73, 8),
		&"mira": _heroine_snapshot(9, 6, 69, 12),
		&"seraphine": _heroine_snapshot(8, 8, 81, 4),
	}
	var initialize_error: String = run.initialize(
		campaign_seed,
		generator.generate_layer_2_entry(campaign_seed),
		[],
		party
	)
	run.opening_completed = true
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	run.campaign_lifecycle.begin_refugeless_ascent(
		RunState.BLOOD_NUN_GO_DOWN_CHOICE_ID
	)
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	var save_flags: Dictionary = run.narrative_state.flags_by_scope.get(
		&"save",
		{}
	) as Dictionary
	save_flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	var entry_error: String = run.begin_immediate_jailer_encounter()
	_expect(
		initialize_error.is_empty() and entry_error.is_empty(),
		"Refuge-less Jailer safe-point fixture must initialize."
	)
	return run


func _complete_reverse_route(run: RunState) -> String:
	while run.current_node_id != RunState.LAYER_2_FARTHEST_CELL_NODE_ID:
		var current: MapNodeState = run.graph.get_map_node(run.current_node_id)
		if current == null or current.incoming_ids.is_empty():
			return "Reverse Layer 2 route ended before the Farthest Cell."
		var travel_error: String = run.travel_to(current.incoming_ids[0])
		if not travel_error.is_empty():
			return travel_error
		if run.pending_node_id != &"":
			var complete_error: String = run.complete_pending_node()
			if not complete_error.is_empty():
				return complete_error
	return ""


func _heroine_snapshot(hp: int, mp: int, resolve: int, corruption: int) -> Dictionary:
	return {
		"hp": hp, "mp": mp, "resolve": resolve, "corruption": corruption,
		"item_guard": 0, "weapon_damage": 0, "weapon_broken": false,
		"armor_damage": 0, "armor_broken": false,
		"shield_damage": 0, "shield_broken": false,
	}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value as Dictionary if value is Dictionary else {}


func _write_json(path: String, value: Dictionary) -> void:
	var directory: DirAccess = DirAccess.open("user://")
	if directory != null:
		directory.make_dir_recursive(TEST_DIRECTORY.trim_prefix("user://"))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "\t"))
		file.close()


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
