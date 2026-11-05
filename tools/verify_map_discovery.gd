extends "res://tools/verify_run_backpack.gd"
## Isolated native Stage 15 fixture using the production Main scene and room hosts.

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--map-captures="):
			captures = argument.trim_prefix("--map-captures=")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	view.size = Vector2i(1280, 720)
	view.size_2d_override = Vector2i(1920, 1080)
	var scene: Node = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(scene)
	var main: AbyssalBloomMainController = scene.get_node("Controller")
	var graph: LayerMapGraph = main.generator.generate_layer_1(333)
	_check(main.run_state.initialize(333, graph, main.generator.make_layer_1_generated_room_item_rules(), {&"lysandra": {"hp": 8, "mp": 4}}).is_empty(), "Production Main binds a full generated layer")
	main.run_state.opening_completed = true
	main.run_state.run_changed.connect(main._refresh_map)
	main.map_view.bind_map(graph, main.run_state)
	main.boot_fallback.hide()
	main.map_screen.show()
	main._refresh_map()
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await _settle()
		var boss: Button = main.map_view.node_buttons[graph.boss_node_id]
		_check(boss.get_meta("art_key") == "unknown" and boss.tooltip_text == "Unknown room", "Unknown Boss has no type, identity or content tooltip")
		await _click(boss.get_global_rect().get_center())
		_check(main.node_title_label.text == "Unknown room" and not main.node_detail_label.text.contains("Blood Nun") and main.travel_button.disabled, "Selecting unknown node does not disclose content or permit travel")
		boss.grab_focus()
		await _key(KEY_ENTER)
		_check(main.run_state.selected_node_id == graph.boss_node_id and not graph.get_map_node(graph.boss_node_id).type_known, "Keyboard selection does not identify a room")
		var all_fit: bool = true
		var rectangles: Array[Rect2] = []
		for button: Button in main.map_view.node_buttons.values():
			all_fit = all_fit and main.map_view.get_global_rect().encloses(button.get_global_rect())
			for previous: Rect2 in rectangles:
				all_fit = all_fit and not previous.intersects(button.get_global_rect())
			rectangles.append(button.get_global_rect())
		_check(all_fit and rectangles.size() == graph.nodes.size(), "All positions fit without overlapping")
		await _shot(resolution, "unknown_map")
	# Resolve a visit through the real Wine Cellar lock and room handoff.
	var wine: MapNodeState
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value
		if node.room_definition_id == &"wine_cellar_warm_bottles":
			wine = node
	main.run_state.current_node_id = wine.node_id
	main.run_state.pending_node_id = wine.node_id
	main.run_state.pending_origin_node_id = wine.incoming_ids[0]
	wine.visited = true
	wine.type_known = true
	main._launch_event_room(wine)
	await _settle()
	var room: EventRoomScreen = main.active_event_room
	_check(room != null and room.map_exits.size() == 1 and room.map_exits[0].map_edge_ids.size() == wine.outgoing_ids.size(), "Production room exit binds every generated outgoing connection")
	var lock: RoomLockHotspot = room.active_locks.values()[0]
	var before: Dictionary = graph.to_snapshot()
	room._on_exit_requested(lock.get_exit_hotspot())
	_check(main.active_event_room == room and before == graph.to_snapshot(), "Locked exit cannot emit a successful outcome or reveal graph")
	var exit_states: Dictionary = room.capture_map_exit_states()
	var all_locked: bool = not exit_states.is_empty()
	for state: Dictionary in exit_states.values():
		all_locked = all_locked and not state.unlocked
	_check(all_locked, "Authored lock state is captured for each bound edge")
	# No reward/lock transaction invented: the fixture supplies the unlocked state.
	lock.apply_unlocked_state(true)
	var result: EventRoomOutcome = room.capture_room_outcome(true)
	_check(main.run_state.apply_event_room_outcome(result).is_empty(), "Real room outcome applies successful exit")
	_check(wine.exit_completed and not wine.solved and not wine.encounter_cleared, "Leaving exploration does not claim Solved or combat victory")
	var revealed: bool = true
	for target: StringName in wine.outgoing_ids:
		revealed = revealed and graph.is_connection_known(wine.node_id, target)
	_check(revealed, "Successful unlocked exit reveals eligible connections")
	main._retire_active_event_room()
	main.map_screen.show()
	main._refresh_map()
	await _settle()
	await _shot(Vector2i(1024, 768), "discovered_map")
	var saved: Dictionary = main.run_state.make_active_run_snapshot("post_node", main.knowledge_state)
	var loaded := RunState.new()
	_check(loaded.restore_active_run_snapshot(saved, BATTLERS).is_empty() and loaded.graph.to_snapshot() == graph.to_snapshot(), "Production room/map knowledge survives Continue snapshot")
	scene.queue_free()
	await process_frame
	await process_frame
	print("Stage 15 native map: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	await process_frame
	quit(failures)
