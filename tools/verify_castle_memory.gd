extends "res://tools/verify_run_backpack.gd"
## Production Main, Refuge, departure/save and combat hosts; prior story is fixture-controlled.
var main: AbyssalBloomMainController
var scene: Node

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--memory-captures="):
			captures = argument.trim_prefix("--memory-captures=")
	CampaignSaveSlotStore.set_test_save_directory("user://stage23_interface")
	CampaignSaveSlotStore.delete_slot(1)
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	scene = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(scene)
	main = scene.get_node("Controller")
	main.active_save_slot_id = 1
	var party: Dictionary = {}
	for id: StringName in HEROES:
		var definition: BattlerDefinition = BATTLERS.get_battler(id)
		party[id] = {"hp":definition.max_hp,"mp":definition.max_mp,"resolve":definition.starting_resolve,"corruption":definition.starting_corruption}
	main.run_state.initialize(2202,main.generator.generate_bloom_refuge_holding_state(2202),[],party)
	main.run_state.opening_completed = true
	main.run_state.completed_layer_ids = [&"layer_1"]
	main.run_state.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	main.run_state.campaign_lifecycle.restore_legacy_refuge(2202)
	main.run_state.narrative_state.flags_by_scope[&"save"][RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	main.run_state.narrative_state.flags_by_scope[&"save"][RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	main.run_state.bloom = 50000
	main.run_state.campaign_lifecycle.mark_boss_defeated(RunState.JAILER_BOSS_ID)
	main.run_state.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	main.run_state.ensure_refuge_ownership_initialized()
	main.run_state.run_changed.connect(main._refresh_map)
	_check(main._save_active_refuge().is_empty(),"Production Refuge slot created")
	main.boot_fallback.hide()
	main._show_refuge_hub()
	await _settle()
	await _intel_ui()
	await _departure()

	scene.queue_free()
	await process_frame
	CampaignSaveSlotStore.force_test_write_failure = false
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 23 native Memory/Passage: %d checks, %d failures." % [checks,failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _open_intel() -> RefugeExpeditionView:
	main.active_refuge.room_shell.open_station(&"expedition")
	main.active_refuge.expedition_view.show_section(&"intel")
	await _settle()
	return main.active_refuge.expedition_view

func _click_option(id: StringName) -> void:
	var button: Button = main.active_refuge.expedition_view.intel_buttons[id]
	button.grab_focus()
	await _settle()
	await _click(button.get_global_rect().get_center())
	await _settle()

func _tab(index: int) -> void:
	var tabs: TabBar = main.active_refuge.expedition_view.intel_tabs
	tabs.grab_focus()
	await _settle()
	await _click(tabs.global_position + tabs.get_tab_rect(index).get_center())
	await _settle()

func _intel_ui() -> void:
	var old: LayerMapGraph = main.generator.generate_layer_2_run(2301, main.run_state.get_defeated_boss_ids())
	old.get_nodes_in_column(3)[0].type_known = true
	CastleLayoutMemory.remember(main.run_state.refuge_ownership.castle_layouts, old)
	_check(main._save_active_refuge().is_empty(), "Last layout saved at Refuge")
	var expedition: RefugeExpeditionView = await _open_intel()
	for resolution: Vector2i in [Vector2i(1920,1080), Vector2i(1600,900), Vector2i(1280,720), Vector2i(1024,768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0*resolution.y/resolution.x))
		await _tab(0)
		_check(expedition.passage_purchase_selector.item_count == 2 and expedition.purchase_layer == 1, "Only both defeated authored bosses offered")
		_check(expedition.intel_buttons.conquerors_passage.text == "100 Bloom" and expedition.intel_buttons.castle_memory.text == "10 Bloom", "Approved one-run prices shown before click")
		expedition.intel_buttons.conquerors_passage.grab_focus()
		await _settle()
		await _shot(resolution,"memory_passage_temporary")
		await _tab(1)
		_check(expedition.intel_buttons.conquerors_passage.text == "10000 Bloom", "Permanent price shown for selected layer")
		expedition.intel_buttons.conquerors_passage.grab_focus()
		await _settle()
		await _shot(resolution,"memory_passage_permanent")
	await _tab(0)
	var before: Dictionary = main.run_state.refuge_ownership.to_snapshot()
	CampaignSaveSlotStore.force_test_write_failure = true
	await _click_option(&"conquerors_passage")
	_check(main.run_state.bloom == 50000 and main.run_state.refuge_ownership.to_snapshot() == before, "Real failed purchase leaves wallet and layer ownership unchanged")
	CampaignSaveSlotStore.force_test_write_failure = false
	await _click_option(&"conquerors_passage")
	_check(main.run_state.bloom == 49900 and main.run_state.refuge_ownership.pending_passage_layers == [1], "Actual Layer 1 purchase")
	# Exercise keyboard layer choice before committing its price.
	expedition.passage_purchase_selector.grab_focus()
	await _settle()
	await _key(KEY_DOWN)
	await _settle()
	if expedition.purchase_layer != 2:
		expedition.passage_purchase_selector.select(1)
		expedition.passage_purchase_selector.item_selected.emit(1)
		await _settle()
	_check(expedition.purchase_layer == 2 and expedition.intel_buttons.conquerors_passage.text == "200 Bloom", "Layer 2 selection shows scaled price")
	await _click_option(&"conquerors_passage")
	await _click_option(&"castle_memory")
	_check(main.run_state.bloom == 49690 and main.run_state.refuge_ownership.pending_passage_layers == [1,2], "Layer 2 and Memory purchased once")
	await _cancel()
	await _cancel()
	_check(main.load_campaign_slot(1).is_empty(), "Load restores preparation including remembered layout")
	await _settle()
	expedition = await _open_intel()
	_check(main.run_state.refuge_ownership.selected_passage_layer == 2 and main.run_state.refuge_ownership.pending_passage_layers == [1,2], "Closing and Load retain paid layers and chosen departure")
	expedition.show_section(&"hub")
	await _settle()
	var normal_index: int = expedition.departure_selector.get_item_index(0)
	expedition.departure_selector.select(normal_index)
	expedition.departure_selector.item_selected.emit(normal_index)
	await _settle()
	_check(main.run_state.refuge_ownership.selected_passage_layer == 0 and main.run_state.refuge_ownership.pending_passage_layers == [1,2] and main.run_state.bloom == 49690, "Changing to ordinary departure retains paid shortcuts without refund")
	var boss_index: int = expedition.departure_selector.get_item_index(2)
	expedition.departure_selector.select(boss_index)
	expedition.departure_selector.item_selected.emit(boss_index)
	await _settle()
	await _shot(view.size,"passage_departure_selection")

func _departure() -> void:
	main.active_refuge.seed_edit.text = "2302"
	await _settle()
	var before: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	CampaignSaveSlotStore.force_test_write_failure = true
	main.active_refuge.begin_button.grab_focus()
	await _settle()
	await _click(main.active_refuge.begin_button.get_global_rect().get_center())
	await _settle()
	_check(main.active_refuge != null and main.run_state.refuge_ownership.pending_passage_layers == [1,2], "Failed Explore consumes no shortcut")
	_check(CampaignSaveSlotStore.read_document_for_load(1).document == before, "Failed Explore preserves atomic document")
	CampaignSaveSlotStore.force_test_write_failure = false
	await _click(main.active_refuge.begin_button.get_global_rect().get_center())
	await _settle()
	_check(main.active_refuge == null and main.run_state.current_node_id == main.run_state.graph.boss_node_id and main.run_state.graph.layout_seed == 2301, "Actual Explore starts at defeated boss on remembered layout")
	_check(main.run_state.refuge_ownership.pending_passage_layers == [1] and main.run_state.bloom == 0, "Only used Passage consumed, no departure recharge")
	var document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	_check(document.refuge_snapshot.pending_passage_layers.size() == 1 and int(document.refuge_snapshot.pending_passage_layers[0]) == 1 and document.refuge_snapshot.selected_passage_layer == 0, "Fallback preserves unused entitlement, never used one")
	var graph: Dictionary = main.run_state.graph.to_snapshot()
	_check(main.continue_active_run_slot(1).is_empty(), "Continue from real boss-start departure")
	await _settle()
	_check(main.run_state.graph.to_snapshot() == graph and main.run_state.refuge_ownership.pending_passage_layers == [1], "Continue preserves topology, knowledge and unused entitlement")
	var preceding: StringName = main.run_state.graph.connected_ids(main.run_state.current_node_id)[0]
	_check(main.run_state.can_travel_to(preceding), "Adjacent backtracking available after Continue")
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1024,768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920,roundi(1920.0*resolution.y/resolution.x))
		await _settle()
		await _shot(resolution,"memory_boss_start")
	_check(main._commit_refuge_return(null).is_empty(), "Production Return persists latest memory")
	await _settle()
	_check(main.load_campaign_slot(1).is_empty(), "Load latest returned memory")
	await _settle()
	_check(main.run_state.refuge_ownership.castle_layouts.layer_2.run_seed == int(graph.run_seed) and main.run_state.refuge_ownership.pending_passage_layers == [1], "Returned layout and unused shortcut survive durable Load")

	# Use the still-paid Layer 1 entitlement through the real production departure.
	main.active_refuge.room_shell.open_station(&"expedition")
	var expedition: RefugeExpeditionView = main.active_refuge.expedition_view
	expedition.show_section(&"hub")
	await _settle()
	var index: int = expedition.departure_selector.get_item_index(1)
	expedition.departure_selector.select(index)
	expedition.departure_selector.item_selected.emit(index)
	main.active_refuge.seed_edit.text = "2303"
	await _settle()
	main.active_refuge.begin_button.grab_focus()
	await _settle()
	await _click(main.active_refuge.begin_button.get_global_rect().get_center())
	await _settle()
	_check(main.active_refuge == null and main.run_state.graph.layer_id == &"layer_1" and main.run_state.current_node_id == main.run_state.graph.boss_node_id, "Unused Layer 1 Passage starts its corresponding expedition")
	_check(main.run_state.refuge_ownership.pending_passage_layers.is_empty() and not main.run_state.generated_room_item_requests.is_empty(), "Layer 1 consumes only its entitlement and prepares fresh key placement")
	var keys: Dictionary = main.run_state.generated_room_item_requests.duplicate(true)
	_check(main.continue_active_run_slot(1).is_empty(), "Continue Layer 1 Passage")
	await _settle()
	_check(JSON.parse_string(JSON.stringify(main.run_state.generated_room_item_requests)) == JSON.parse_string(JSON.stringify(keys)), "Continue preserves fresh key placement instead of rerolling it")
	await _shot(view.size,"layer1_boss_start")

	var previous_room: StringName = main.run_state.graph.connected_ids(main.run_state.current_node_id)[0]
	main.run_state.select_node(previous_room)
	main._on_travel_pressed()
	await _settle()
	_check(main.run_state.graph.layer_id == &"layer_1" and main.run_state.current_node_id == previous_room and main.active_battle != null, "Actual backtracking enters the adjacent authored encounter without crossing layers")
