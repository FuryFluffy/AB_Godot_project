extends "res://tools/verify_run_backpack.gd"
## Stage 16 production map presentation fixture; all state alterations below are test-only.

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
	_check(main.run_state.initialize(333, graph, main.generator.make_layer_1_generated_room_item_rules(), {&"lysandra": {"hp": 8, "mp": 4}}).is_empty(), "Production map initializes")
	main.run_state.opening_completed = true
	main.run_state.run_changed.connect(main._refresh_map)
	var map: LayerMapView = main.map_view
	map.bind_map(graph, main.run_state)
	main.boot_fallback.hide()
	main.map_screen.show()
	main._refresh_map()
	var initial_graph: Dictionary = graph.to_snapshot()
	var initial_current: StringName = main.run_state.current_node_id
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		map.reset_view()
		await _settle()
		_check(map.get_global_rect().encloses(map.toolbar.get_global_rect()), "Map controls fit at %s" % resolution)
		await _click(map.toolbar.get_child(2).get_global_rect().get_center())
		_check(map.zoom == 1.25, "Plus button zooms")
		await _click(map.toolbar.get_child(0).get_global_rect().get_center())
		_check(map.zoom == 1, "Minus button zooms out")
		var at: Vector2 = map.get_global_rect().get_center() + Vector2(0, 160)
		await _mouse_button(at, MOUSE_BUTTON_WHEEL_UP, true)
		await _mouse_button(at, MOUSE_BUTTON_WHEEL_UP, false)
		_check(map.zoom == 1.25, "Wheel zooms through real viewport input")
		var old_pan: Vector2 = map.pan
		await _mouse_button(at, MOUSE_BUTTON_MIDDLE, true)
		var motion := InputEventMouseMotion.new()
		motion.position = at - Vector2(40, 30)
		motion.global_position = motion.position
		motion.relative = Vector2(-40, -30)
		motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		view.push_input(motion, true)
		await process_frame
		await _mouse_button(motion.position, MOUSE_BUTTON_MIDDLE, false)
		_check(map.pan.distance_to(old_pan + Vector2(-40, -30)) < 1, "Middle drag pans by pointer movement")
		map.set_zoom(99, map.size * 0.5)
		_check(map.zoom == map.MAX_ZOOM, "Zoom has an upper bound")
		var boss: Button = map.node_buttons[graph.boss_node_id]
		boss.grab_focus()
		await _settle()
		_check(map.get_global_rect().encloses(boss.get_global_rect()) and boss.get_global_rect().position.y >= map.get_global_rect().position.y + map.TOP_MARGIN, "Off-screen focus reveals complete node below toolbar")
		await _key(KEY_ENTER)
		_check(main.run_state.selected_node_id == graph.boss_node_id and main.node_title_label.text == "Unknown room" and main.travel_button.disabled, "Zoomed keyboard selection keeps unknown room private and inaccessible")
		await _key(KEY_LEFT)
		_check(view.gui_get_focus_owner() != boss and map.get_global_rect().encloses(view.gui_get_focus_owner().get_global_rect()), "Directional focus reaches and reveals an adjacent position")
		await _click(map.toolbar.get_child(4).get_global_rect().get_center())
		_check(view.gui_get_focus_owner() == map.node_buttons[initial_current] and main.run_state.current_node_id == initial_current, "Current room focuses without travelling")
		await _shot(resolution, "navigation_zoom")
		await _click(map.toolbar.get_child(3).get_global_rect().get_center())
		_check(map.zoom == 1.0 and map.pan == Vector2.ZERO, "Fit map resets presentation")
		var fit: bool = true
		for button: Button in map.node_buttons.values():
			fit = fit and map.get_global_rect().encloses(button.get_global_rect())
		_check(fit, "Fit map includes every room")
		_check(graph.to_snapshot() == initial_graph, "Presentation never mutates graph knowledge or completion")
		await _shot(resolution, "navigation_fit")
	map.set_zoom(-10, map.size * 0.5)
	_check(map.zoom == 1 and map.pan == Vector2.ZERO, "Zoom lower bound keeps the complete graph usable")
	map.set_zoom(2, map.size * 0.5)
	map.pan = Vector2(999999, -999999)
	map._update_transform()
	_check(map.pan.x == 0 and is_equal_approx(map.pan.y, -map.size.y), "Pan stays within the zoomed map bounds")
	map.focus_current_room()
	var selected_before: StringName = main.run_state.selected_node_id
	var current_button: Button = map.node_buttons[initial_current]
	var previous_zoom: float = map.zoom
	await _mouse_button(current_button.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP, true)
	await _mouse_button(current_button.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP, false)
	_check(map.zoom > previous_zoom, "Wheel zoom also works over a node button")
	map.focus_current_room()
	for pressed: bool in [true, false]:
		var gamepad := InputEventJoypadButton.new()
		gamepad.button_index = JOY_BUTTON_DPAD_RIGHT
		gamepad.pressed = pressed
		view.push_input(gamepad, true)
		await process_frame
	_check(view.gui_get_focus_owner() != current_button and map.get_global_rect().encloses(view.gui_get_focus_owner().get_global_rect()), "Injected gamepad direction focuses a visible room")
	_check(main.run_state.selected_node_id == selected_before and main.run_state.current_node_id == initial_current, "Focus movement alone neither selects nor travels")
	map.reset_view()
	# Fixtures supply known/hidden/locked state; the view must only query it.
	var start: MapNodeState = graph.get_map_node(graph.start_node_id)
	var target: StringName = start.outgoing_ids[0]
	var edge: Dictionary = graph.edge_states[graph.edge_id(start.node_id, target)]
	edge.known = true
	edge.hidden = false
	edge.unlocked = false
	map.refresh()
	var lock_shown: bool = false
	for route: Dictionary in map.visible_routes():
		if route.from == start.node_id and route.to == target:
			lock_shown = not route.unlocked
	_check(lock_shown and not main.run_state.can_travel_to(target), "Known locked route is drawn but remains inaccessible")
	await _shot(Vector2i(1024, 768), "known_locked_route")
	edge.hidden = true
	lock_shown = false
	for route: Dictionary in map.visible_routes():
		if route.from == start.node_id and route.to == target:
			lock_shown = not route.unlocked
	_check(lock_shown and not main.run_state.can_travel_to(target), "Stage 22 Intel-known hidden passage is shown as blocked, never traversable")
	edge.known = false
	var hidden: bool = true
	for route: Dictionary in map.visible_routes():
		hidden = hidden and not (route.from == start.node_id and route.to == target)
	_check(hidden, "Undiscovered hidden passage still suppresses both line and lock")
	map.set_zoom(2, map.size * 0.5)
	map.bind_map(graph, main.run_state)
	await _settle()
	_check(map.zoom == 1 and map.pan == Vector2.ZERO and map.map_content.get_child_count() == graph.nodes.size(), "Rebinding resets view without duplicate buttons or stale navigation")
	# Exercise every supplied type and coexistence of independent state overlays.
	var art = preload("res://scripts/map/map_art_library.gd")
	for group: String in ["node_assets", "state_assets", "intel_assets", "trap_markers"]:
		for key: String in art.manifest()[group]:
			_check(art.texture(group, key) != null, "Manifest resolves %s/%s" % [group, key])
	_check(art.texture("intel_assets", "battle_sense") == art.texture("node_assets", "normal_combat") and art.texture("trap_markers", "trap_identified") == art.texture("intel_assets", "scouting"), "Manifest aliases reuse the exact supplied textures")
	var kinds: Array[int] = [MapNodeState.NodeType.START, MapNodeState.NodeType.ROOM, MapNodeState.NodeType.BATTLE, MapNodeState.NodeType.ELITE, MapNodeState.NodeType.BOSS, MapNodeState.NodeType.TRAP, MapNodeState.NodeType.TREASURY, MapNodeState.NodeType.REST, MapNodeState.NodeType.ALCHEMY, MapNodeState.NodeType.WORKSHOP]
	var index: int = 0
	var rest: MapNodeState
	for node: MapNodeState in graph.nodes.values():
		node.type_known = index < kinds.size()
		if node.type_known:
			node.node_type = kinds[index]
			node.display_name = node.get_type_label() + " — art fixture"
		if node.node_type == MapNodeState.NodeType.REST:
			rest = node
		index += 1
	rest.visited = true
	rest.solved = true
	rest.rest_used = true
	rest.encounter_cleared = false
	main.run_state.current_node_id = rest.node_id
	main.run_state.selected_node_id = rest.node_id
	for state: Dictionary in graph.edge_states.values():
		state.hidden = false
		state.known = true
	map.refresh()
	main._refresh_map()
	var rest_button: Button = map.node_buttons[rest.node_id]
	rest_button.grab_focus()
	await _settle()
	var all_states: bool = true
	for name: String in ["Current", "Type", "Visited", "Solved", "RestUsed", "Selection", "Focus"]:
		all_states = all_states and rest_button.get_node(name).visible
	_check(all_states and rest_button.get_meta("art_key") == "rest", "Current, Visited, Solved, Rest used, selection and independent focus coexist with the Rest emblem")
	_check(rest_button.get_node("Current").get_index() < rest_button.get_node("Type").get_index(), "Current bloom is drawn behind the medallion")
	var overview: Dictionary = graph.to_snapshot()
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		map.reset_view()
		await _settle()
		var background: Rect2 = map._map_rect()
		_check(is_equal_approx(background.size.aspect(), art.texture("background").get_size().aspect()), "Parchment preserves its aspect ratio")
		await _shot(resolution, "approved_art_states")
	_check(graph.to_snapshot() == overview, "All overlays render without changing game state")
	var next_graph: LayerMapGraph = main.generator.generate_layer_2_run(333)
	main.run_state.graph = next_graph
	main.run_state.current_node_id = next_graph.start_node_id
	main.run_state.selected_node_id = next_graph.start_node_id
	map.bind_map(next_graph, main.run_state)
	await _settle()
	_check(map.node_buttons.size() == next_graph.nodes.size() and not map.node_buttons.has(graph.start_node_id), "Changing layers while a node is focused discards old focus callbacks and buttons safely")
	scene.queue_free()
	await process_frame
	await process_frame
	print("Stage 16 map navigation: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _mouse_button(at: Vector2, index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = index
	event.pressed = pressed
	view.push_input(event, true)
	await process_frame
