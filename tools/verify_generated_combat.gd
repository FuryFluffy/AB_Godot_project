extends "res://tools/verify_run_backpack.gd"
## Isolated production-entry fixture. Outcomes are forced after real encounters start.

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--combat-captures="):
			captures = argument.trim_prefix("--combat-captures=")
	CampaignSaveSlotStore.set_test_save_directory("user://stage17_generated_combat")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	var trio: Dictionary = _find_elite(1, 3)
	var pair: Dictionary = _find_elite(1, 2)
	var dungeon: Dictionary = _find_elite(2, 2)
	for spec: Array in [[trio, 3, Vector2i(1920,1080)], [trio, 1, Vector2i(1280,720)], [trio, 2, Vector2i(1024,768)], [pair, 3, Vector2i(1600,900)], [dungeon, 3, Vector2i(1280,720)]]:
		await _encounter(spec[0], spec[1], spec[2], false)
	# Existing authored Normal node exercises the real post-fight item offer.
	await _encounter({"seed":333,"layer":2,"node":&"l2_c1_n0","enemies":2}, 3, Vector2i(1280,720), false)
	await _encounter(dungeon, 3, Vector2i(1280,720), true)
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 17 native combat: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _find_elite(layer: int, enemies: int) -> Dictionary:
	var generator := LayerMapGenerator.new()
	var run := RunState.new()
	for seed: int in range(1, 51):
		var graph: LayerMapGraph = generator.generate_layer_1(seed) if layer == 1 else generator.generate_layer_2_run(seed)
		for node: MapNodeState in graph.nodes.values():
			if node.node_type == MapNodeState.NodeType.ELITE and run._make_enemy_composition(node, StableSeedMixer.make_seed(seed, &"encounter_composition", node.node_id)).size() == enemies:
				return {"seed":seed,"layer":layer,"node":node.node_id,"enemies":enemies}
	_check(false, "Generated formation exists")
	return {}

func _encounter(spec: Dictionary, count: int, resolution: Vector2i, defeat: bool) -> void:
	view.size = resolution
	view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
	CampaignSaveSlotStore.delete_slot(1)
	var scene: Node = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(scene)
	var main: AbyssalBloomMainController = scene.get_node("Controller")
	main.active_save_slot_id = 1
	var party: Dictionary = {}
	var ids: Array[StringName] = []
	for id: StringName in HEROES.slice(0,count):
		var hero: BattlerDefinition = BATTLERS.get_battler(id)
		party[id] = {"hp":hero.max_hp,"mp":hero.max_mp,"resolve":70,"corruption":10}
		ids.append(id)
	var graph: LayerMapGraph = main.generator.generate_layer_1(spec.seed) if spec.layer == 1 else main.generator.generate_layer_2_run(spec.seed)
	_check(main.run_state.initialize(spec.seed, graph, [], party).is_empty(), "Run initializes with chosen party")
	main.run_state.opening_completed = true
	main.run_state.narrative_state.recruited_heroine_ids = ids
	if defeat:
		# Start a real Refuge-owned expedition so existing defeat ownership is tested.
		main.run_state.initialize(spec.seed, main.generator.generate_bloom_refuge_holding_state(spec.seed), [], party)
		main.run_state.opening_completed = true
		main.run_state.completed_layer_ids = [&"layer_1"]
		main.run_state.narrative_state.recruited_heroine_ids = ids
		main.run_state.campaign_lifecycle.restore_legacy_refuge(spec.seed)
		var flags: Dictionary = main.run_state.narrative_state.flags_by_scope.get(&"save", {})
		flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
		flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
		main.run_state.ensure_refuge_ownership_initialized()
		_check(main.run_state.begin_next_layer_2_run(graph).is_empty(), "Defeat fixture leaves Refuge through production ownership boundary")
		main.run_state.run_inventory.material_pouch["mat_l01_red_wax"] = 3
		main.run_state.run_inventory.backpacks_by_heroine[&"lysandra"][0] = {"slot_index":0,"item_id":"l01_bandage_roll","quantity":1}
	var gear_before: Dictionary = main.run_state.run_equipment.get_snapshot()
	var node: MapNodeState = graph.get_map_node(spec.node)
	var origin: MapNodeState = graph.get_map_node(node.incoming_ids[0])
	origin.visited = true
	origin.cleared = true
	origin.exit_completed = true
	origin.encounter_cleared = origin.has_encounter_content()
	origin.reward_claimed = true
	main.run_state.current_node_id = origin.node_id
	graph.reveal_adjacency(origin.node_id)
	main.run_state.run_changed.connect(main._refresh_map)
	main.map_view.bind_map(graph, main.run_state)
	main.boot_fallback.hide()
	main.map_screen.show()
	main._refresh_map()
	await _settle()
	await _click(main.map_view.node_buttons[node.node_id].get_global_rect().get_center())
	await _click(main.travel_button.get_global_rect().get_center())
	await _settle()
	var battle: CombatEncounter = main.active_battle
	_check(battle != null and main.active_event_room == null and not main.map_screen.visible, "Map Travel directly launches combat with no exploration host")
	if battle == null:
		push_error(main.node_detail_label.text)
		scene.queue_free()
		await process_frame
		return
	var definition: EncounterDefinition = battle.pending_encounter_definition
	_check(definition.enemy_ids.size() == spec.enemies and definition.party_ids == ids and battle.active_combat_stage != null, "Actual combat scene uses supported formation, unchanged party and authored stage")
	for id: StringName in definition.get_all_battler_ids():
		_check(battle.get_battler_state(id) != null, "Every authored spawn has a live battler")
	await _click(battle.reusable_hud.command_bar.end_phase_button.get_global_rect().get_center())
	await _settle()
	_check(battle.battle_runtime.battle_state.encounter_started, "Existing Begin/order flow starts the live encounter")
	if spec.layer == 1 and spec.enemies == 3 and count == 3:
		var support: BattleMarker = battle._get_battler_marker(&"prayer_rag_novice")
		# Target mode ignores heroine rectangles, including transparent hair padding.
		var selected: Array[StringName] = []
		support.battler_selected.connect(func(id: StringName): selected.append(id))
		battle._set_attack_targeting_markers(true, [&"prayer_rag_novice"])
		await _click(support.select_button.get_global_rect().get_center())
		_check(selected == [&"prayer_rag_novice"], "Trio support receives target clicks with all three heroines present")
		battle._set_attack_targeting_markers(false)
	var label: String = "layer%d_%s_%d_enemies_%d_heroines" % [spec.layer,spec.node,spec.enemies,count]
	await _shot(resolution,label)
	if defeat:
		for id: StringName in ids:
			var hero: BattlerState = battle.get_battler_state(id)
			hero.current_hp = 0
			hero.is_defeated = true
			hero.current_resolve = 55
		battle.battle_runtime.battle_state.outcome = BattleState.Outcome.DEFEAT
	else:
		battle.battle_runtime.battle_state.outcome = BattleState.Outcome.VICTORY
	battle._emit_encounter_outcome_if_ready()
	await _settle()
	if not defeat and node.reward_source_id != &"":
		var panel: RunBackpackPanel = battle.backpack_panel
		_check(panel.visible and not main.return_overlay.visible, "Authored Normal loot opens before summary")
		await _key(KEY_ESCAPE)
		_check(panel.confirmation.visible, "Leaving fight surplus requires confirmation")
		await _key(KEY_ESCAPE)
		_check(panel.visible and not panel.confirmation.visible, "Cancelling abandonment preserves loot offer")
		await _key(KEY_ESCAPE)
		await _click(Vector2(panel.confirmation.position) + panel.confirmation.get_ok_button().get_global_rect().get_center())
		await _settle()
	_check(main.return_overlay.visible and main.pending_outcome != null, "Outcome displays production summary")
	await _shot(resolution,label + ("_defeat" if defeat else "_victory"))
	var bloom: int = main.run_state.bloom
	gear_before = main.run_state.run_equipment.get_snapshot()
	await _click(main.return_to_map_button.get_global_rect().get_center())
	await _settle()
	if defeat:
		_check(main.active_battle == null and main.run_state.graph.layer_id == &"bloom_refuge" and main.run_state.pending_node_id == &"" and not main.run_state.can_travel_to(node.node_id), "Defeat ends old expedition and cannot retry its Elite")
		_check(main.run_state.refuge_ownership.banked_materials.get("mat_l01_red_wax",0) == 3 and BackpackPayload.is_empty(main.run_state.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][0]) and main.run_state.party_snapshot[&"lysandra"].resolve == 55, "Defeat banks remaining materials, loses carried contents and retains Resolve consequence")
		_check(JSON.parse_string(JSON.stringify(main.run_state.refuge_ownership.equipment_loadouts_by_heroine)) == JSON.parse_string(JSON.stringify(gear_before.get("loadouts_by_heroine", {}))), "Defeat preserves registered equipment identity and condition")
		var empty_bar: bool = true
		for slot: Dictionary in main.run_state.refuge_ownership.prepared_item_bar_slots:
			empty_bar = empty_bar and BackpackPayload.is_empty(slot)
		_check(empty_bar, "Defeat loses shared Item Bar contents")
		var document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
		_check(document.get("active_run_snapshot") == null, "Continue cannot restore the ended run")
		await _shot(resolution,"defeat_refuge")
	else:
		_check(main.active_battle == null and main.active_event_room == null and main.map_screen.visible and node.solved and node.encounter_cleared and main.run_state.bloom == bloom + 4, "Victory returns to map with one existing Bloom reward and resolved/Solved node")
		_check(main.run_state.travel_to(origin.node_id).is_empty(), "Backtracking after victory remains available")
		main.run_state.select_node(node.node_id)
		main._on_travel_pressed()
		await _settle()
		_check(main.active_battle == null and main.active_event_room == null and main.run_state.pending_node_id == &"" and main.run_state.bloom == bloom + 4, "Production revisit launches no enemies/exploration and awards nothing")
		await _shot(resolution,label + "_resolved_map")
	scene.queue_free()
	await process_frame
	await process_frame
