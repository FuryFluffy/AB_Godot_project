extends "res://tools/verify_run_backpack.gd"
## Real production rooms and saves; prior travel is primed and offer IDs forced for coverage.

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rest-captures="):
			captures = argument.trim_prefix("--rest-captures=")
	CampaignSaveSlotStore.set_test_save_directory("user://stage20_rest_rooms")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.physics_object_picking = true
	view.notify_mouse_entered()
	for offer: int in range(1,7):
		await _room(offer)
	CampaignSaveSlotStore.force_test_write_failure = false
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 20 Rest room interface: %d checks, %d failures." % [checks,failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _room(offer: int) -> void:
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	CampaignSaveSlotStore.delete_slot(1)
	var scene: Node = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(scene)
	var main: AbyssalBloomMainController = scene.get_node("Controller")
	main.active_save_slot_id = 1
	var layer: int = 1 if offer % 2 == 1 else 2
	var graph: LayerMapGraph
	var node: MapNodeState
	var chosen_seed: int
	for seed: int in range(1,20):
		graph = main.generator.generate_layer_1(seed) if layer == 1 else main.generator.generate_layer_2_run(seed)
		for candidate: MapNodeState in graph.nodes.values():
			if candidate.node_type == MapNodeState.NodeType.REST:
				node = candidate
				break
		if node != null:
			chosen_seed = seed
			break
	node.rest_offer_id = offer
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp":1,"mp":1,"resolve":90,"corruption":75}
	# HP recovery includes defeated active heroines; non-HP offers leave them defeated.
	party[&"mira"].hp = 0
	main.run_state.initialize(chosen_seed,graph,[],party)
	main.run_state.opening_completed = true
	main.run_state.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	main.run_state.ordinary_rest_uses = 1
	main.run_state.bloom = 31
	main.run_state.run_inventory.material_pouch["mat_l01_red_wax"] = 7
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
	_check(room != null and main.active_battle == null,"Map Travel opens actual Rest room")
	if room == null:
		push_error(main.node_detail_label.text)
		scene.queue_free()
		await process_frame
		return
	_check(room.room_rest_hotspot != null and room.active_pickups.is_empty() and not room.room_rest_used,"Authored bed exposes a single unused service")
	var resolutions: Array[Vector2i] = [Vector2i(1280,720)]
	if offer in [1,6]:
		resolutions = [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1024,768)]
	for resolution: Vector2i in resolutions:
		view.size = resolution
		view.size_2d_override = Vector2i(1920,roundi(1920.0*resolution.y/resolution.x))
		await _settle()
		await _click(room.room_rest_hotspot.global_position)
		await _settle()
		var dialog: RunRecoveryDialog = room.room_rest_dialog
		_check(dialog.visible and dialog.request.offer_id == offer and dialog.request.after.size() == 3,"Bed click opens exactly the assigned offer with every recipient")
		_check(dialog.dialog_text.contains("Corruption") and dialog.dialog_text.contains("Lysandra") and dialog.dialog_text.contains("Mira") and dialog.dialog_text.contains("Seraphine"),"Preview names every heroine and resource consequence")
		_check(Rect2(Vector2.ZERO,Vector2(view.size_2d_override)).encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"Confirmation fits the actual viewport")
		var before: Dictionary = room._capture_party_snapshot()
		await _key(KEY_B)
		_check(not room.exploration_hud.backpack_panel.visible,"Rest confirmation blocks background inventory shortcuts")
		await _shot(resolution,"offer%d_preview" % offer)
		await _click(Vector2(dialog.position)+dialog.get_cancel_button().get_global_rect().get_center())
		await _settle()
		_check(not dialog.visible and not node.rest_used and room._capture_party_snapshot() == before,"Cancel consumes nothing")
	if offer == 1:
		await _click(room.map_exits[0].global_position)
		await _settle()
		_check(main.active_event_room == null and node.solved and not node.rest_used,"Completing empty room content does not spend unused Rest")
		var error: String = main.continue_active_run_slot(1)
		_check(error.is_empty(),"Unused completed room restores: " + error)
		node = main.run_state.graph.get_map_node(node.node_id)
		_check(node.rest_offer_id == offer and not node.rest_used and node.solved,"Load preserves offer independently of Solved")
		main.run_state.travel_to(origin.node_id)
		main.run_state.select_node(node.node_id)
		main._on_travel_pressed()
		await _settle()
		room = main.active_event_room
		_check(room != null and not room.room_rest_used,"Solved room can be revisited for its unused recovery")
	await _click(room.room_rest_hotspot.global_position)
	await _settle()
	var dialog: RunRecoveryDialog = room.room_rest_dialog
	var request: Dictionary = dialog.request.duplicate(true)
	var before: Dictionary = room._capture_party_snapshot()
	var old_document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	CampaignSaveSlotStore.force_test_write_failure = true
	await _click(Vector2(dialog.position)+dialog.get_ok_button().get_global_rect().get_center())
	await _settle()
	_check(not node.rest_used and main.active_event_room == room and room._capture_party_snapshot() == before,"Failed durable write applies no recovery or spent flag")
	_check(CampaignSaveSlotStore.read_document_for_load(1).document == old_document,"Failed Confirm preserves the previous durable checkpoint")
	CampaignSaveSlotStore.force_test_write_failure = false
	await _click(room.room_rest_hotspot.global_position)
	await _settle()
	dialog = room.room_rest_dialog
	request = dialog.request.duplicate(true)
	await _click(Vector2(dialog.position)+dialog.get_ok_button().get_global_rect().get_center())
	await _settle()
	room = main.active_event_room
	node = main.run_state.graph.get_map_node(node.node_id)
	_check(room != null and node.rest_used and room.room_rest_used,"Successful Confirm consumes the assigned room once")
	if room == null or not node.rest_used:
		push_error("Rest commit did not reopen its room")
		scene.queue_free()
		await process_frame
		return
	for id: StringName in HEROES:
		var actor: BattlerState = room.party_states[id]
		var expected: Dictionary = request.after[id]
		_check(actor.current_hp == expected.hp and actor.current_mp == expected.mp and actor.current_resolve == expected.resolve and actor.current_corruption == expected.corruption,"Actual recovery exactly matches per-heroine preview")
	_check(room.party_states[&"mira"].is_defeated == (offer not in [1,3,6]),"Only offers that restore HP revive a defeated active heroine")
	_check(main.run_state.ordinary_rest_uses == 1 and main.run_state.bloom == 31 and main.run_state.run_inventory.material_pouch["mat_l01_red_wax"] == 7,"Ordinary charges, Bloom and Materials are unchanged")
	var committed: Dictionary = room._capture_party_snapshot()
	_check(not main._commit_room_rest(request).is_empty() and committed == room._capture_party_snapshot(),"Duplicate/stale confirmation cannot apply twice")
	var error: String = main.continue_active_run_slot(1)
	await _settle()
	room = main.active_event_room
	_check(error.is_empty() and room != null and room.room_rest_used and room._capture_party_snapshot() == committed,"Continue preserves spent flag and exact recovered values")
	await _click(room.room_rest_hotspot.global_position)
	await _settle()
	_check(not room.room_rest_dialog.visible,"Spent bed cannot reopen a recovery confirmation")
	await _click(room.map_exits[0].global_position)
	await _settle()
	node = main.run_state.graph.get_map_node(node.node_id)
	_check(main.active_event_room == null and node.rest_used and node.solved,"Spent-Rest and Solved flags coexist after exit")
	_check(main._node_behavior_text(node).contains("has been used"),"Spent room details describe the working service rather than inactive content")
	await _shot(view.size,"offer%d_spent_map" % offer)
	scene.queue_free()
	await process_frame
	await process_frame
