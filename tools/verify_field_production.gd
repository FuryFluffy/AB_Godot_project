extends "res://tools/verify_run_backpack.gd"
## Test-only recipes exercise the production path; shipped recipes stay empty.
const ROOMS = preload("res://data/exploration/rooms/event_room_catalog.tres")
var fixture_recipes: Array[RefugeRecipeDefinition] = []

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--field-captures="):
			captures = argument.trim_prefix("--field-captures=")
	CampaignSaveSlotStore.set_test_save_directory("user://stage21_field")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.physics_object_picking = true
	view.notify_mouse_entered()
	for layer: int in [1,2]:
		for kind: int in [MapNodeState.NodeType.ALCHEMY,MapNodeState.NodeType.WORKSHOP]:
			await _room(layer,kind)
	CampaignSaveSlotStore.force_test_write_failure = false
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 21 field production interface: %d checks, %d failures." % [checks,failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _room(layer: int, kind: int) -> void:
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	CampaignSaveSlotStore.delete_slot(1)
	var scene: Node = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(scene)
	var main: AbyssalBloomMainController = scene.get_node("Controller")
	main.active_save_slot_id = 1
	var graph: LayerMapGraph
	var node: MapNodeState
	var chosen_seed: int
	for seed: int in range(1,30):
		graph = main.generator.generate_layer_1(seed) if layer == 1 else main.generator.generate_layer_2_run(seed)
		for candidate: MapNodeState in graph.nodes.values():
			if candidate.node_type == kind:
				node = candidate
				break
		if node != null:
			chosen_seed = seed
			break
	var definition: EventRoomDefinition = ROOMS.get_room(node.room_definition_id)
	var original: FieldStationDefinition = definition.field_station
	definition.field_station = original.duplicate(true)
	var material: StringName = &"mat_l01_servant_cloth" if layer == 1 else &"mat_l02_prison_iron"
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp":3,"mp":3,"resolve":80,"corruption":10}
	main.run_state.initialize(chosen_seed,graph,[],party)
	main.run_state.opening_completed = true
	main.run_state.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	main.run_state.ensure_refuge_ownership_initialized()
	if layer == 2:
		main.run_state.refuge_ownership.banked_materials[String(material)] = 99
		main.run_state.active_run_refuge_boundary_snapshot = main.run_state.refuge_ownership.to_snapshot()
		var departure: Dictionary = main.run_state.refuge_ownership.make_run_start_transfer()
		main.run_state.refuge_ownership = departure.refuge_state
		main.run_state.run_inventory = departure.run_inventory
		main.run_state.run_equipment = departure.run_equipment
		main.run_state.campaign_lifecycle.establish_refuge()
		main.run_state.campaign_lifecycle.begin_refuge_run(chosen_seed)
		main.run_state.narrative_state.flags_by_scope[&"save"][RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
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
	_check(room != null and room.field_dialog != null,"Map Travel opens actual station")
	if room == null or room.field_dialog == null:
		push_error("Station launch detail: " + main.node_detail_label.text + " / " + main.boot_status_label.text)
		scene.queue_free()
		return
	_check(room.run_inventory.material_pouch.get(String(material),0) == 2 and room.instance_state.local_state.get("station_prepared",false),"First visit grants exactly authored run supplies")
	await _click(room.field_hotspot.global_position)
	await _settle()
	_check(room.field_dialog.visible and room.field_dialog.view.entries.is_empty() and room.field_dialog.view.action_button.disabled,"Shipped empty catalog cannot produce")
	await _shot(view.size,"l%d_%d_empty" % [layer,kind])
	room.field_dialog.hide()
	# Install test-only recipes: one discovery, one already-known recipe outside the discovery list, one still unknown.
	for i: int in range(3):
		var recipe := RefugeRecipeDefinition.new()
		recipe.recipe_id = StringName("fixture:field_%d" % i)
		recipe.display_name = "Fixture recipe %d — test only" % i
		recipe.action = RefugeRecipeDefinition.Action.PRODUCE_ITEM
		recipe.station = original.station
		recipe.starts_known = i == 1
		recipe.material_inputs = {String(material):1, "mat_l01_red_wax" if layer == 1 else "mat_l02_chain_links":1}
		recipe.output_item_id = &"l01_bandage_roll"
		recipe.output_quantity = 3
		fixture_recipes.append(recipe)
		RefugeOwnershipState.RECIPE_CATALOG.recipes.append(recipe)
	definition.field_station.recipe_discoveries = [fixture_recipes[0].recipe_id]
	# Recreate first entry with a failed durable write to verify supplies/knowledge rollback.
	main.run_state.event_room_snapshots[node.node_id].local_state.erase("station_prepared")
	main.run_state.run_inventory.material_pouch.clear()
	var before_document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	CampaignSaveSlotStore.force_test_write_failure = true
	main._launch_event_room(main.run_state.graph.get_map_node(node.node_id))
	await _settle()
	room = main.active_event_room
	_check(room.field_preparation_pending and room.field_retry_dialog.visible and room.run_inventory.material_pouch.is_empty() and not main.run_state.refuge_ownership.knows_recipe(fixture_recipes[0].recipe_id),"Failed first-visit write blocks entry without supplies or knowledge")
	_check(CampaignSaveSlotStore.read_document_for_load(1).document == before_document,"Failed grant preserves durable checkpoint")
	CampaignSaveSlotStore.force_test_write_failure = false
	await _click(Vector2(room.field_retry_dialog.position)+room.field_retry_dialog.get_ok_button().get_global_rect().get_center())
	await _settle()
	room = main.active_event_room
	_check(not room.field_preparation_pending and room.run_inventory.material_pouch[String(material)] == 2 and main.run_state.refuge_ownership.knows_recipe(fixture_recipes[0].recipe_id),"Retry grants supplies and permanent discovery exactly once")
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1024,768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920,roundi(1920.0*resolution.y/resolution.x))
		await _settle()
		await _click(room.field_hotspot.global_position)
		await _settle()
		var dialog: FieldProductionDialog = room.field_dialog
		_check(dialog.visible and dialog.view.entries.size() == 2,"All known station recipes appear, including one not discovered here")
		_check(Rect2(Vector2.ZERO,Vector2(view.size_2d_override)).encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"Field production dialog fits viewport")
		_check(Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(dialog.view.action_button.get_global_rect()),"Brew/Craft remains visible without scrolling")
		await _key(KEY_B)
		_check(not room.exploration_hud.backpack_panel.visible,"Station modal blocks background inventory")
		await _shot(resolution,"l%d_%d_preview" % [layer,kind])
		await _click(Vector2(dialog.position)+dialog.get_ok_button().get_global_rect().get_center())
		await _settle()
		_check(not dialog.visible and room.run_inventory.material_pouch[String(material)] == 2,"Close consumes nothing")
	await _click(room.field_hotspot.global_position)
	await _settle()
	var dialog: FieldProductionDialog = room.field_dialog
	dialog.recipient.select(dialog.heroine_ids.find(&"mira"))
	dialog.recipient.item_selected.emit(dialog.recipient.selected)
	await _settle()
	var before: Dictionary = room.run_inventory.get_snapshot()
	var refuge_before: Dictionary = main.run_state.refuge_ownership.to_snapshot()
	var before_craft_document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	CampaignSaveSlotStore.force_test_write_failure = true
	await _click(Vector2(dialog.position)+dialog.view.action_button.get_global_rect().get_center())
	await _settle()
	_check(room.run_inventory.get_snapshot() == before and dialog.status_label.text.contains("Campaign save write failed"),"Failed craft save consumes nothing and produces nothing")
	_check(CampaignSaveSlotStore.read_document_for_load(1).document == before_craft_document,"Failed craft retains previous durable checkpoint")
	CampaignSaveSlotStore.force_test_write_failure = false
	var request: Dictionary = before.duplicate(true)
	for count: int in range(2):
		dialog = main.active_event_room.field_dialog
		await _click(Vector2(dialog.position)+dialog.view.action_button.get_global_rect().get_center())
		await _settle()
		room = main.active_event_room
		_check(room.field_dialog.visible,"Successful craft keeps station available")
	_check(room.run_inventory.material_pouch.get(String(material),0) == 0,"Repeated crafting spends only current-run inputs")
	_check(room.run_inventory.get_backpack_snapshot(&"mira")[0].quantity == 4 and room.run_inventory.get_backpack_snapshot(&"mira")[1].quantity == 2 and room.run_inventory.get_backpack_snapshot(&"lysandra")[0].item_id == "","Output goes to selected Backpack")
	_check(main.run_state.refuge_ownership.to_snapshot() == refuge_before,"Bank and Stash unchanged by field production")
	_check(not String(main._commit_field_production(original.station,fixture_recipes[0].recipe_id,&"mira",request).error).is_empty(),"Stale duplicate craft rejects")
	var spent: Dictionary = room.run_inventory.get_snapshot()
	_check(not String(main._commit_field_production(original.station,fixture_recipes[0].recipe_id,&"mira",spent).error).is_empty() and spent == room.run_inventory.get_snapshot(),"Insufficient run Materials cannot borrow banked inputs")
	var error: String = main.continue_active_run_slot(1)
	await _settle()
	room = main.active_event_room
	_check(error.is_empty() and spent == room.run_inventory.get_snapshot() and main.run_state.refuge_ownership.knows_recipe(fixture_recipes[0].recipe_id),"Continue preserves exact consumed Materials, output and knowledge without regranting")
	var malformed: Dictionary = main.run_state.make_active_run_snapshot("pre_node",main.knowledge_state)
	malformed.run_snapshot.recipe_discoveries = ["unknown_recipe"]
	var restore_probe := RunState.new()
	_check(not restore_probe.restore_active_run_snapshot(malformed,BATTLERS).is_empty(),"Malformed active-run recipe knowledge rejects")
	await _click(room.map_exits[0].global_position)
	await _settle()
	node = main.run_state.graph.get_map_node(node.node_id)
	_check(node.solved,"Resolved authored station content can be Solved")
	main.run_state.travel_to(origin.node_id)
	main.run_state.select_node(node.node_id)
	main._on_travel_pressed()
	await _settle()
	room = main.active_event_room
	await _click(room.field_hotspot.global_position)
	await _settle()
	_check(room.field_dialog.visible and room.field_dialog.view.entries.size() == 2 and room.run_inventory.get_snapshot() == spent,"Solved station remains usable; revisit never replenishes supplies")
	if layer == 1:
		room.field_dialog.hide()
		var defeat := EncounterOutcome.new()
		defeat.result = EncounterOutcome.Result.DEFEAT
		defeat.encounter_id = &"fixture:tutorial_defeat"
		defeat.source_node_id = node.node_id
		defeat.inventory_snapshot = main.run_state.inventory_snapshot.duplicate(true)
		defeat.party_snapshot = main.run_state.party_snapshot.duplicate(true)
		for id: Variant in defeat.party_snapshot:
			defeat.party_snapshot[id].hp = 0
		main.pending_outcome = defeat
		var before_retry: RunState = main.run_state
		CampaignSaveSlotStore.force_test_write_failure = true
		main._restart_failed_run_from_beginning()
		_check(main.run_state == before_retry and main.pending_outcome == defeat,"Failed tutorial-retry save preserves summary and permanent knowledge")
		CampaignSaveSlotStore.force_test_write_failure = false
		main._restart_failed_run_from_beginning()
		await _settle()
		_check(main.active_battle != null and main.run_state.refuge_ownership.knows_recipe(fixture_recipes[0].recipe_id) and main.run_state.run_inventory.material_pouch.is_empty(),"Tutorial defeat keeps recipes while restarting with fresh run Materials")
		var opening_seed: int = main.active_battle.base_seed
		error = main.continue_active_run_slot(1)
		await _settle()
		_check(error.is_empty() and main.active_battle != null and main.active_battle.base_seed == opening_seed and not main.run_state.opening_completed and main.run_state.refuge_ownership.knows_recipe(fixture_recipes[0].recipe_id),"Interrupted tutorial retry resumes the same opening seed with permanent recipes")
	scene.queue_free()
	await process_frame
	definition.field_station = original
	for recipe: RefugeRecipeDefinition in fixture_recipes:
		RefugeOwnershipState.RECIPE_CATALOG.recipes.erase(recipe)
	fixture_recipes.clear()
