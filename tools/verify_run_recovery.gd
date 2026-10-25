extends "res://tools/verify_run_backpack.gd"

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--recovery-captures="):
			captures = argument.trim_prefix("--recovery-captures=")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	view.size = Vector2i(1280, 720)
	view.size_2d_override = Vector2i(1920, 1080)
	await _rest_ui()
	await _return_ui()
	print("Stage 14 native Recovery: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	await process_frame
	await process_frame
	quit(failures)

func _dialog_click(dialog: Window, button: Button) -> void:
	await _click(Vector2(dialog.position) + button.get_global_rect().get_center())

func _rest_ui() -> void:
	var room: EventRoomScreen = preload("res://scenes/exploration/event_room_screen.tscn").instantiate()
	var main := AbyssalBloomMainController.new()
	var generator := LayerMapGenerator.new()
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp": 1, "mp": 0, "resolve": 70, "corruption": 10}
	party[&"mira"].hp = 0
	main.run_state.initialize(814, generator.generate_layer_1(814), generator.make_layer_1_generated_room_item_rules(), party)
	main.run_state.opening_completed = true
	main._configure_room_party(room)
	view.add_child(room)
	room.current_party_ids = HEROES.duplicate()
	var initial := RunInventoryState.new()
	initial.initialize(ITEMS, HEROES, false)
	_check(room._prepare_inventory(ITEMS, initial.get_item_bar_snapshot()).is_empty() and room._prepare_party_strip(BATTLERS, party).is_empty(), "Actual room prepares Rest callback")
	var hud: ExplorationHUD = room.exploration_hud
	var dialog: RunRecoveryDialog = room.recovery_dialog
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await _settle()
		await _click(hud.command_bar.recovery_button.get_global_rect().get_center())
		await _settle()
		_check(dialog.visible and dialog.dialog_text.contains("2 of 2") and main.run_state.ordinary_rest_uses == 0, "Rest opens minimal effects/count confirmation without consuming")
		await _key(KEY_B)
		_check(not hud.backpack_panel.visible and dialog.visible, "Confirmation blocks background Backpack shortcut")
		await _shot(resolution, "rest_confirmation")
		await _key(KEY_ESCAPE)
		await _settle()
		_check(not dialog.visible and hud.command_bar.recovery_button.has_focus() and room.party_states[&"mira"].is_defeated, "Cancel preserves defeated state and restores focus")
	await _click(hud.command_bar.recovery_button.get_global_rect().get_center())
	await _settle()
	await _dialog_click(dialog, dialog.get_ok_button())
	await _settle()
	_check(main.run_state.ordinary_rest_uses == 1 and not room.party_states[&"mira"].is_defeated and room.party_states[&"mira"].current_hp == 3 and room.party_states[&"mira"].current_mp == 4 and room.party_states[&"lysandra"].current_corruption == 20, "Native confirm heals/revives entire party and adds Corruption once")
	_check(hud.command_bar.recovery_button.text == "Rest (1/2)" and not hud.mira_card.name_label.text.contains("DEFEATED"), "HUD immediately shows revived status and remaining use")
	await _shot(Vector2i(1024, 768), "after_rest")
	room.selected_item_slot_index = 0
	await _settle()
	_check(hud.command_bar.recovery_button.disabled, "Pending item targeting blocks Rest")
	room.selected_item_slot_index = -1
	room.mode_controller.set_mode(ExplorationModeController.Mode.DIALOGUE)
	await _settle()
	_check(hud.command_bar.recovery_button.disabled, "Dialogue blocks Rest")
	room.mode_controller.set_mode(ExplorationModeController.Mode.FREE_EXPLORATION)
	await _key(KEY_B)
	await _settle()
	_check(hud.command_bar.recovery_button.disabled, "Backpack blocks Rest")
	await _key(KEY_ESCAPE)
	await _settle()
	await _click(hud.command_bar.party_button.get_global_rect().get_center())
	await _settle()
	_check(hud.command_bar.recovery_button.disabled, "Party inspection blocks Rest")
	await _key(KEY_ESCAPE)
	await _settle()
	await _click(hud.command_bar.recovery_button.get_global_rect().get_center())
	await _settle()
	await _dialog_click(dialog, dialog.get_ok_button())
	await _settle()
	_check(main.run_state.ordinary_rest_uses == 2 and hud.command_bar.recovery_button.disabled and hud.command_bar.recovery_button.text == "Rest (0/2)", "Two confirmed uses exhaust and disable Rest")
	room.queue_free()
	await process_frame
	main.free()

func _return_ui() -> void:
	CampaignSaveSlotStore.set_test_save_directory("user://stage14_native_return")
	CampaignSaveSlotStore.delete_slot(1)
	var main: Node = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(main)
	var host: AbyssalBloomMainController = main.get_node("Controller")
	var run: RunState = host.run_state
	var party: Dictionary = {}
	for id: StringName in HEROES:
		var definition: BattlerDefinition = BATTLERS.get_battler(id)
		party[id] = {"hp": definition.max_hp, "mp": definition.max_mp, "resolve": 70, "corruption": 10}
	run.initialize(814, host.generator.generate_bloom_refuge_holding_state(814), [], party)
	run.opening_completed = true
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	run.campaign_lifecycle.restore_legacy_refuge(814)
	run.narrative_state.flags_by_scope[&"save"][RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	run.narrative_state.flags_by_scope[&"save"][RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	var management := RefugeManagementController.new()
	_check(management.bind(run, BATTLERS, func() -> String: return "").is_empty(), "Production Return fixture binds Refuge")
	_check(run.begin_next_layer_2_run(host.generator.generate_layer_2_run(814)).is_empty(), "Production Return fixture starts run")
	host.active_save_slot_id = 1
	host.boot_fallback.hide()
	host.map_view.bind_map(run.graph, run)
	host.map_screen.show()
	host._refresh_map()
	host._on_return_to_refuge_pressed()
	await _settle()
	_check(host.map_return_dialog.visible, "Existing map Return also requires confirmation")
	await _key(KEY_ESCAPE)
	_check(run.graph.layer_id != &"bloom_refuge", "Map Return cancellation preserves run")
	var node: MapNodeState
	for candidate: MapNodeState in run.graph.nodes.values():
		if candidate.requires_event_room():
			node = candidate
			break
	_check(node != null, "Generated layer contains authored exploration room")
	if node == null:
		main.queue_free()
		CampaignSaveSlotStore.clear_test_save_directory()
		return
	run.pending_origin_node_id = run.current_node_id
	run.current_node_id = node.node_id
	run.selected_node_id = node.node_id
	run.pending_node_id = node.node_id
	node.visited = true
	run.prepare_pending_node_seed()
	_check(CampaignSaveSlotStore.save_active_run_slot(1, run, host.knowledge_state, "pre_node").is_empty(), "Pre-room production safe point saved")
	var durable: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	host._launch_event_room(node)
	await _settle()
	var room: EventRoomScreen = host.active_event_room
	_check(room != null, "Production room launch succeeds")
	if room == null:
		main.queue_free()
		CampaignSaveSlotStore.clear_test_save_directory()
		return
	room.stop_dialogue()
	await _settle()
	room.party_states[&"mira"].current_hp = 1
	room.run_inventory.material_pouch["mat_l01_red_wax"] = 3
	var service := room.backpack_controller as RunLootController
	var owner: PersonalEquipmentLoadoutState = room.run_equipment.get_loadout(&"mira")
	var equipment := EquipmentInstance.new(&"stage14_found_dagger", owner.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND).definition, 2)
	var source: Dictionary = {"source_id": "stage14_fixture", "binding_id": String(node.node_id), "spawn_id": "stage14_fixture", "quantity": 1, "item_id": "", "claimed": false, "deferred": false, "source_channel": 2, "equipment_snapshot": equipment.to_snapshot()}
	service.bind_sources([source])
	_check(service.collect(service.request(RefugeInventoryTransfer.address(&"loot", 0)), RefugeInventoryTransfer.address(&"backpack", -1, &"mira"), 1).error.is_empty(), "Fixture equipment enters live room bag through existing Loot transaction")
	var dialog: RunRecoveryDialog = room.recovery_dialog
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await _settle()
		await _click(room.exploration_command_bar.recovery_button.get_global_rect().get_center())
		await _settle()
		_check(dialog.visible and dialog.dialog_text == "Return to the Bloom Refuge?", "Room Return opens simple confirmation")
		await _shot(resolution, "return_confirmation")
		await _key(KEY_ESCAPE)
		_check(host.active_event_room == room and host.run_state == run, "Cancelled room Return preserves live ownership")
	CampaignSaveSlotStore.force_test_write_failure = true
	await _click(room.exploration_command_bar.recovery_button.get_global_rect().get_center())
	await _settle()
	await _dialog_click(dialog, dialog.get_ok_button())
	await _settle()
	_check(host.run_state == run and host.active_event_room == room and CampaignSaveSlotStore.read_document_for_load(1).document == durable and room.run_inventory.material_pouch.get("mat_l01_red_wax", 0) == 3, "Failed Return save keeps room, contents and previous durable boundary")
	CampaignSaveSlotStore.force_test_write_failure = false
	await _click(room.exploration_command_bar.recovery_button.get_global_rect().get_center())
	await _settle()
	await _dialog_click(dialog, dialog.get_ok_button())
	await _settle()
	_check(host.active_event_room == null and host.active_refuge != null and host.run_state.graph.layer_id == &"bloom_refuge" and host.run_state.refuge_ownership.banked_materials.get("mat_l01_red_wax", 0) == 3, "Retry commits Return once and banks live room materials")
	_check(CampaignSaveSlotStore.read_document_for_load(1).document.get("active_run_snapshot") == null, "Completed Return cannot reload an obsolete active run")
	var returned_gear: Dictionary = host.run_state.refuge_ownership.equipment_loadouts_by_heroine[&"mira"].instances
	_check(returned_gear.has("stage14_found_dagger") and returned_gear["stage14_found_dagger"].current_condition == 2, "Return retains newly collected equipment identity and condition")
	await _shot(Vector2i(1024, 768), "returned_refuge")
	main.queue_free()
	await process_frame
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
