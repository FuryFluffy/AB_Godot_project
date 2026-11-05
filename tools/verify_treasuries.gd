extends "res://tools/verify_run_backpack.gd"
## Real Main/map/room/loot/save hosts; prior route is primed, not played manually.
const LORE = preload("res://data/lore/lore_catalog.tres")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--treasury-captures="):
			captures = argument.trim_prefix("--treasury-captures=")
	CampaignSaveSlotStore.set_test_save_directory("user://stage18_treasury")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.physics_object_picking = true
	view.notify_mouse_entered()
	await _treasury(1)
	await _treasury(2)
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 18 native Treasury: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _treasury(layer: int) -> void:
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
	_check(main.run_state.initialize(333,graph,[],party).is_empty(), "Treasury run initializes")
	main.run_state.opening_completed = true
	main.run_state.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	var node: MapNodeState
	for candidate: MapNodeState in graph.nodes.values():
		if candidate.node_type == MapNodeState.NodeType.TREASURY:
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
	_check(room != null and main.active_battle == null, "Real map Travel opens generated Treasury")
	if room == null:
		push_error(main.node_detail_label.text)
		scene.queue_free()
		await process_frame
		return
	print("Treasury fixture layer %d seed 333 node %s" % [layer,node.node_id])
	var state: EventRoomInstanceState = room.instance_state
	var assignments: Array = state.local_state.item_spawns
	_check(assignments.size() == 6 and room.active_pickups.size() == 2 and room.active_containers.size() == 3, "Seeded visible and multi-item container contents exist as runtime state")
	var cache: RoomLootContainerHotspot = room.active_containers[&"floor_cache"]
	_check(not cache.revealed and not cache.get_interaction_display_name().contains("Cache") and not room.is_authored_loot_resolved(), "Hidden content prevents Solved without disclosing rewards or counts")
	var panel: RunBackpackPanel = room.exploration_hud.backpack_panel
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1024,768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920,roundi(1920.0*resolution.y/resolution.x))
		await _settle()
		var shown := Rect2(room.presentation.position, room.definition.fitted_source_size * room.presentation.scale)
		_check(is_equal_approx(room.presentation.scale.x,room.presentation.scale.y) and Rect2(Vector2.ZERO,Vector2(view.size_2d_override.x,room.exploration_hud.dock.backdrop.position.y)).encloses(shown), "Room and hotspots preserve aspect ratio above the dock")
		await _shot(resolution,"layer%d_room" % layer)
		await _click((room.active_containers[&"chest"] as Node2D).global_position)
		await _settle()
		_check(panel.visible and panel.loot_column.visible and (room.backpack_controller as RunLootController).sources.size() == 2, "Coffer opens both source records through actual click at every aspect")
		await _shot(resolution,"layer%d_chest" % layer)
		var before: Array = assignments.duplicate(true)
		await _key(KEY_ESCAPE)
		await _settle()
		_check(not panel.visible and not panel.confirmation.visible and assignments == before, "Container close preserves every remainder with no fight abandonment")
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	await _settle()
	var service := room.backpack_controller as RunLootController
	# Force full capacity only; source contents remain exactly the authored seeded draw.
	var visible_id: StringName
	var record: Dictionary
	for candidate: Dictionary in assignments:
		if not candidate.has("container_id") and ITEMS.get_item(StringName(candidate.item_id)).content_category != ItemDefinition.ContentCategory.MATERIAL:
			visible_id = StringName(candidate.spawn_id)
			record = candidate
			break
	if visible_id != &"":
		for i: int in range(15):
			service.inventory.backpacks_by_heroine[&"lysandra"][i] = {"slot_index":i,"item_id":"l01_smelling_salts","quantity":ITEMS.get_item(&"l01_smelling_salts").stack_limit}
		await _click((room.active_pickups[visible_id] as Node2D).global_position)
		await _settle()
		var before: Dictionary = record.duplicate(true)
		var result: Dictionary = _collect(service,0,LootClaim.remaining(record),&"lysandra")
		_check(result.moved == 0 and record == before and room.active_pickups.has(visible_id), "Full bag leaves visible item and quantity intact")
		result = _collect(service,0,1,&"mira")
		_check(result.moved == 1 and LootClaim.remaining(record) == int(before.quantity)-1 and room.active_pickups.has(visible_id) == (LootClaim.remaining(record)>0), "Successful partial pickup removes only accepted quantity and exhausted sprite")
		await _key(KEY_ESCAPE)
		await _settle()
		# Remove capacity-only fixture inventory before remaining collection.
		for i: int in range(15):
			service.inventory.backpacks_by_heroine[&"lysandra"][i] = RefugeInventoryTransfer._at({},0,i,"backpack")
		panel.refresh()
	else:
		_check(false,"Seed 333 supplies a visible carried item for full-bag coverage")
	# Collect one chest item, close, exit and restore the exact remainder from disk.
	await _click((room.active_containers[&"chest"] as Node2D).global_position)
	await _settle()
	var chest_before: Array = service.sources.duplicate(true)
	var collected: Dictionary = _collect(service,0,1,&"mira")
	_check(collected.moved == 1 and service.sources[1] == chest_before[1], "Collecting one coffer item leaves its other source untouched")
	await _key(KEY_ESCAPE)
	await _settle()
	var remaining: Array = assignments.duplicate(true)
	var pre_node_doc: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	_check(pre_node_doc.active_run_snapshot.safe_point_kind == "pre_node", "Loot inspection/collection does not create a mid-room save")
	await _click(room.map_exits[0].global_position)
	await _settle()
	_check(main.active_event_room == null and main.map_screen.visible and node.exit_completed and not node.solved, "Open passage exits unsolved Treasury and reveals eligible routes")
	var document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	var saved: Dictionary = document.active_run_snapshot
	var restore_error: String = main.run_state.restore_active_run_snapshot(saved,BATTLERS)
	_check(restore_error.is_empty(), "Production post-resolution save restores: " + restore_error)
	node = main.run_state.graph.get_map_node(node.node_id)
	_check(JSON.parse_string(JSON.stringify(main.run_state.event_room_snapshots[node.node_id].local_state.item_spawns)) == JSON.parse_string(JSON.stringify(remaining)), "Load preserves exact item identities, seeds and partial container remainders")
	var bad: Dictionary = saved.duplicate(true)
	bad.run_snapshot.event_room_snapshots[String(node.node_id)].local_state.revealed_containers = {"floor_cache":1}
	var stable: Dictionary = main.run_state.make_active_run_snapshot("post_node",KnowledgeState.new())
	_check(not main.run_state.restore_active_run_snapshot(bad,BATTLERS).is_empty() and main.run_state.make_active_run_snapshot("post_node",KnowledgeState.new()) == stable, "Invalid explicit cache discovery rejects transactionally")
	# Revisit through actual travel after loading, never directly reroll room data.
	main.run_state.travel_to(origin.node_id)
	main.run_state.select_node(node.node_id)
	main._on_travel_pressed()
	await _settle()
	room = main.active_event_room
	_check(room != null, "Resolved visit still reopens authored Treasury contents")
	if room == null:
		scene.queue_free()
		await process_frame
		return
	service = room.backpack_controller as RunLootController
	panel = room.exploration_hud.backpack_panel
	_check(JSON.parse_string(JSON.stringify(room.instance_state.local_state.item_spawns)) == JSON.parse_string(JSON.stringify(remaining)), "Revisit does not reroll or duplicate earlier claims")
	for id: Variant in room.active_pickups.keys().duplicate():
		room._on_world_item_pickup_requested(StringName(id))
		_collect_all(service)
		await _key(KEY_ESCAPE)
	for id: StringName in [&"chest",&"drawer"]:
		room._on_container_contents_requested(id)
		_collect_all(service)
		await _key(KEY_ESCAPE)
	_check(not room.is_authored_loot_resolved(), "Collecting all visible/container rewards still leaves hidden content unsolved")
	cache = room.active_containers[&"floor_cache"]
	await _click(cache.global_position)
	await _settle()
	_check(cache.revealed and panel.visible and bool(room.instance_state.local_state.revealed_containers.floor_cache), "Inspecting authored floor location reveals saved cache and its loot")
	await _shot(Vector2i(1280,720),"layer%d_cache" % layer)
	_collect_all(service)
	await _key(KEY_ESCAPE)
	_check(room.is_authored_loot_resolved() and room.active_pickups.is_empty(), "Treasury solves only after every authored quantity is collected")
	await _click(room.map_exits[0].global_position)
	await _settle()
	_check(node.solved and node.exit_completed, "Solved publishes with existing room outcome and safe point")
	await _shot(Vector2i(1280,720),"layer%d_solved_map" % layer)
	main.run_state.travel_to(origin.node_id)
	main.run_state.select_node(node.node_id)
	main._on_travel_pressed()
	await _settle()
	room = main.active_event_room
	_check(room != null and room.is_authored_loot_resolved() and room.active_pickups.is_empty() and room.active_containers[&"floor_cache"].revealed, "Exhausted revisit retains discovery and produces no duplicate pickups")
	# An explicitly initialized empty list must not be treated as a fresh roll.
	if room != null:
		room.instance_state.local_state.item_spawns = []
		_check(room._prepare_room_items().is_empty() and room.instance_state.local_state.item_spawns.is_empty() and room.active_pickups.is_empty(), "Persisted empty contents never regenerate rewards")
	scene.queue_free()
	await process_frame
	await process_frame

func _collect(service: RunLootController, index: int, count: int, owner: StringName) -> Dictionary:
	var location: Dictionary = {"domain":"loot","index":index}
	var request: Dictionary = service.request(location)
	return service.collect(request,{"domain":"backpack","heroine":owner,"index":-1},count)

func _collect_all(service: RunLootController) -> void:
	for i: int in range(service.sources.size()):
		var left: int = LootClaim.remaining(service.sources[i])
		if left > 0:
			var result: Dictionary = _collect(service,i,left,&"seraphine")
			_check(String(result.error).is_empty() and result.moved == left, "Remaining source transfers once through production Loot transaction")
