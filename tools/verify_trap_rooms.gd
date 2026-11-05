extends "res://tools/verify_treasuries.gd"
## Production alarm lifecycle; route is primed, outcomes forced after live combat starts.

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trap-captures="):
			captures = argument.trim_prefix("--trap-captures=")
	CampaignSaveSlotStore.set_test_save_directory("user://stage19_traps")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.physics_object_picking = true
	view.notify_mouse_entered()
	await _trap_room(1)
	await _trap_room(2)
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 19 production trap rooms: %d checks, %d failures." % [checks,failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _trap_room(layer: int) -> void:
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	CampaignSaveSlotStore.delete_slot(1)
	var scene: Node = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(scene)
	var main: AbyssalBloomMainController = scene.get_node("Controller")
	main.active_save_slot_id = 1
	var party: Dictionary = {}
	for id: StringName in HEROES:
		var hero: BattlerDefinition = BATTLERS.get_battler(id)
		party[id] = {"hp":hero.max_hp,"mp":hero.max_mp,"resolve":70,"corruption":0}
	var graph: LayerMapGraph = main.generator.generate_layer_1(333) if layer == 1 else main.generator.generate_layer_2_run(333)
	_check(main.run_state.initialize(333,graph,[],party).is_empty(),"Trap run initializes")
	main.run_state.opening_completed = true
	main.run_state.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	if layer == 2:
		main.run_state.initialize(333,main.generator.generate_bloom_refuge_holding_state(333),[],party)
		main.run_state.opening_completed = true
		main.run_state.completed_layer_ids = [&"layer_1"]
		main.run_state.narrative_state.recruited_heroine_ids = HEROES.duplicate()
		main.run_state.campaign_lifecycle.restore_legacy_refuge(333)
		var flags: Dictionary = main.run_state.narrative_state.flags_by_scope.get(&"save",{})
		flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
		flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
		main.run_state.ensure_refuge_ownership_initialized()
		_check(main.run_state.begin_next_layer_2_run(graph).is_empty(),"Trap defeat fixture starts through Refuge ownership")
		main.run_state.run_inventory.material_pouch["mat_l01_red_wax"] = 3
	var node: MapNodeState
	for candidate: MapNodeState in graph.nodes.values():
		if candidate.node_type == MapNodeState.NodeType.TRAP:
			node = candidate
			break
	var origin: MapNodeState = graph.get_map_node(node.incoming_ids[0])
	origin.visited = true
	origin.cleared = true
	origin.exit_completed = true
	origin.encounter_cleared = origin.has_encounter_content()
	origin.reward_claimed = true
	main.run_state.current_node_id = origin.node_id
	graph.reveal_adjacency(origin.node_id)
	main.run_state.run_changed.connect(main._refresh_map)
	main.map_view.bind_map(graph,main.run_state)
	main.boot_fallback.hide()
	main.map_screen.show()
	main._refresh_map()
	await _settle()
	await _click(main.map_view.node_buttons[node.node_id].get_global_rect().get_center())
	await _click(main.travel_button.get_global_rect().get_center())
	await _settle()
	var room: EventRoomScreen = main.active_event_room
	_check(room != null and main.active_battle == null,"Map Travel opens production Trap room")
	if room == null:
		push_error(main.node_detail_label.text)
		scene.queue_free()
		await process_frame
		return
	var state: EventRoomInstanceState = room.instance_state
	_check(state.local_state.item_spawns.size() == 4 and room.active_pickups.size() == 3 and room.active_containers.size() == 1,"Three visible items and a concealed cache use shared Loot")
	_check(state.local_state.item_traps.size() in [1,2],"Production assignment leaves at least one visible safe item")
	while room.mode_controller.is_dialogue_active():
		room._on_dialogue_advance_requested()
		await _settle()
	var entry_traps: Dictionary = room.instance_state.local_state.item_traps.duplicate(true)
	var initial_load: String = main.continue_active_run_slot(1)
	await _settle()
	room = main.active_event_room
	state = room.instance_state
	_check(initial_load.is_empty() and not room.mode_controller.is_dialogue_active() and JSON.parse_string(JSON.stringify(state.local_state.item_traps)) == JSON.parse_string(JSON.stringify(entry_traps)),"Prepared-room Continue preserves observer results and does not repeat detection dialogue")
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1024,768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920,roundi(1920.0*resolution.y/resolution.x))
		await _settle()
		var shown := Rect2(room.presentation.position,room.definition.fitted_source_size*room.presentation.scale)
		_check(Rect2(Vector2.ZERO,Vector2(view.size_2d_override.x,room.exploration_hud.dock.backdrop.position.y)).encloses(shown),"Trap room stays above HUD at every aspect")
		await _shot(resolution,"layer%d_traps" % layer)
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	await _settle()
	var bridge: RoomTrapController = room.trap_controller
	var id: String = bridge.traps().keys()[0]
	# Force only effect kind for deterministic end-to-end alarm coverage.
	bridge.traps()[id].definition = preload("res://data/exploration/traps/alarm.tres").saved_definition()
	var untouched: Array = state.local_state.item_spawns.duplicate(true)
	CampaignSaveSlotStore.force_test_write_failure = true
	if layer == 1:
		room._open_world_item_loot(StringName(id))
		var service := room.backpack_controller as RunLootController
		var result: Dictionary = _collect(service,0,1,&"mira")
		_check(result.moved == 1 and bridge.traps()[id].alarm_pending,"Committed item queues the saved alarm")
	else:
		bridge.traps()[id].detected = true
		bridge.traps()[id].definition.disarm_successes = 999
		bridge.intercept(id)
		bridge.owner_picker.select(1)
		bridge._disarm()
		_check(bridge.traps()[id].alarm_pending and state.local_state.item_spawns == untouched,"Failed Disarm queues alarm while leaving item uncollected")
	await create_timer(0.6).timeout
	await _settle()
	_check(main.active_battle == null and main.active_event_room != null and bridge.choice.visible and bridge.blocking(),"Failed pre-alarm write retains room and blocks further interactions")
	CampaignSaveSlotStore.force_test_write_failure = false
	bridge._disarm() # Retry button routes back to the pending alarm checkpoint.
	await _settle()
	var battle: CombatEncounter = main.active_battle
	_check(battle != null and main.active_event_room == null,"Alarm transitions from room to party combat")
	if battle == null or battle.get_battler_state(&"hollow_servant_instance_2") == null:
		_check(false,"Two independent Hollow Servants initialize")
		push_error(main.node_detail_label.text)
		scene.queue_free()
		await process_frame
		return
	var encounter: EncounterDefinition = battle.pending_encounter_definition
	_check(encounter.enemy_ids == [&"hollow_servant",&"hollow_servant_instance_2"] and encounter.party_ids == HEROES,"Alarm uses two existing Hollow sheets and the active party")
	_check(BATTLERS.get_battler(&"hollow_servant_instance_2") == null,"Encounter-local enemy instances do not mutate canonical sheets")
	var a: BattlerState = battle.get_battler_state(&"hollow_servant")
	var b: BattlerState = battle.get_battler_state(&"hollow_servant_instance_2")
	a.apply_damage(1)
	_check(a != b and b.current_hp == b.definition.max_hp,"Repeated enemy instances have independent HP")
	await _click(battle.reusable_hud.command_bar.end_phase_button.get_global_rect().get_center())
	await _settle()
	_check(battle.battle_runtime.battle_state.encounter_started,"Alarm uses the existing Begin/order combat flow")
	var selections: Array[StringName] = []
	for enemy_id: StringName in encounter.enemy_ids:
		var marker: BattleMarker = battle._get_battler_marker(enemy_id)
		marker.battler_selected.connect(func(selected: StringName) -> void: selections.append(selected))
		battle._set_attack_targeting_markers(true,[enemy_id])
		await _click(marker.select_button.get_global_rect().get_center())
		_check(selections.has(enemy_id),"Both repeated enemies remain independently targetable")
	battle._set_attack_targeting_markers(false)
	await _shot(Vector2i(1280,720),"layer%d_alarm" % layer)
	var pre: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document.active_run_snapshot
	_check(pre.safe_point_kind == "pre_node" and pre.run_snapshot.event_room_snapshots[String(node.node_id)].local_state.item_traps[id].alarm_pending,"Pre-alarm checkpoint includes committed pickup and pending alarm")
	var encounter_seed: int = encounter.encounter_seed
	var error: String = main.continue_active_run_slot(1)
	_check(error.is_empty(),"Continue restores interrupted alarm: " + error)
	await create_timer(0.6).timeout
	await _settle()
	battle = main.active_battle
	_check(battle != null and battle.pending_encounter_definition.encounter_seed == encounter_seed,"Interrupted alarm resumes same encounter without new trap roll")
	if battle == null:
		scene.queue_free()
		await process_frame
		return
	var before_bloom: int = main.run_state.bloom
	battle.battle_runtime.battle_state.outcome = BattleState.Outcome.VICTORY
	battle._emit_encounter_outcome_if_ready()
	await _settle()
	var awarded: int = main.pending_outcome.bloom_reward
	_check(main.return_overlay.visible and main.return_to_map_button.text == "Return to room","Alarm victory offers continuation without separate fight loot")
	CampaignSaveSlotStore.force_test_write_failure = true
	main._on_return_to_map_pressed()
	await _settle()
	_check(main.active_battle != null and main.active_event_room == null and main.run_state.bloom == before_bloom+awarded,"Failed victory checkpoint retains summary and awards once")
	CampaignSaveSlotStore.force_test_write_failure = false
	main._on_return_to_map_pressed()
	await _settle()
	room = main.active_event_room
	_check(room != null and main.active_battle == null,"Victory reopens remaining room")
	if room == null:
		push_error(main.return_summary_label.text)
		scene.queue_free()
		await process_frame
		return
	_check(main.run_state.bloom == before_bloom+awarded and not node.solved,"Alarm awards once without solving remaining room contents")
	_check(room.instance_state.local_state.item_traps[id].alarm_resolved,"Resolved alarm remains saved independently of item collection")
	var remaining: Array = room.instance_state.local_state.item_spawns.duplicate(true)
	var after: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document.active_run_snapshot
	_check(after.safe_point_kind == "pre_node" and after.run_snapshot.event_room_snapshots[String(node.node_id)].local_state.item_traps[id].alarm_resolved,"Post-alarm checkpoint resumes the unresolved room")
	var bad: Dictionary = after.duplicate(true)
	bad.run_snapshot.event_room_snapshots[String(node.node_id)].local_state.item_traps[id].triggered = 1
	_check(not main.run_state.restore_active_run_snapshot(bad,BATTLERS).is_empty(),"Production loader rejects malformed explicit trap flags")
	error = main.continue_active_run_slot(1)
	await create_timer(0.4).timeout
	await _settle()
	room = main.active_event_room
	_check(error.is_empty() and room != null and main.active_battle == null and main.run_state.bloom == before_bloom+awarded,"Continue after victory does not replay combat or rewards")
	if room != null:
		_check(JSON.stringify(room.instance_state.local_state.item_spawns) == JSON.stringify(remaining),"Room continuation preserves all item identities and remainders")
		var same: int = 0
		for record: Dictionary in room.instance_state.local_state.item_spawns:
			if String(record.spawn_id) != id and JSON.parse_string(JSON.stringify(untouched)).has(JSON.parse_string(JSON.stringify(record))):
				same += 1
		_check(same == 3,"Alarm leaves all other item and hidden cache records untouched")
		await _shot(Vector2i(1280,720),"layer%d_after_alarm" % layer)
		if layer == 2:
			# Force a lethal failed disarm after the alarm to verify ordinary loss rules.
			bridge = room.trap_controller
			var trap: Dictionary = bridge.traps()[id]
			trap.definition = preload("res://data/exploration/traps/poison.tres").saved_definition()
			trap.definition.disarm_successes = 999
			trap.triggered = false
			trap.alarm_resolved = false
			trap.disarm_result = {}
			for actor: BattlerState in room.party_states.values():
				actor.current_hp = 1 if actor.definition.battler_id == &"mira" else 0
				actor.is_defeated = actor.current_hp == 0
			bridge.intercept(id)
			bridge._disarm()
			await _settle()
			_check(main.active_event_room == null and main.pending_outcome != null and main.pending_outcome.result == EncounterOutcome.Result.DEFEAT,"Lethal stat trap enters ordinary party-defeat flow")
			main._on_return_to_map_pressed()
			await _settle()
			_check(main.active_refuge != null and main.run_state.refuge_ownership.banked_materials.get("mat_l01_red_wax",0) >= 3,"Trap defeat returns to Refuge and banks run Materials")
	scene.queue_free()
	await process_frame
	await process_frame
