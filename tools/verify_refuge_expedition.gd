extends "res://tools/preview_refuge_room.gd"
## Native UI fixture with isolated in-memory state, no production slot.
var qa_view := SubViewport.new()
var failures: int = 0
var capture_directory: String = ""
var launch_count: int = 0

func _run() -> void:
	await super._run()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expedition-captures="):
			capture_directory = argument.trim_prefix("--expedition-captures=")
	screen.show_status("Expedition review fixture · no production save slot connected.")
	screen.begin_layer_2_run_requested.connect(func(_seed: int) -> void: launch_count += 1)
	screen.set_actions_enabled(true)
	screen.room_shell.open_station(&"expedition")
	if "--expedition-interactive" in OS.get_cmdline_user_args():
		return
	root.add_child(qa_view)
	qa_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	qa_view.size_2d_override_stretch = true
	qa_view.gui_embed_subwindows = true
	qa_view.notify_mouse_entered()
	screen.reparent(qa_view, false)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1024, 768)]:
		qa_view.size = resolution
		qa_view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		screen.current_run_state.refuge_ownership.set_selected_party_order([&"lysandra", &"mira", &"seraphine"])
		screen.expedition_view._reset_draft()
		screen.room_shell.open_station(&"expedition")
		await create_timer(0.3).timeout
		await _verify(resolution)
	print("Stage 08 native Expedition fixture: %d failures." % failures)
	quit(failures)

func _verify(resolution: Vector2i) -> void:
	var view: RefugeExpeditionView = screen.expedition_view
	var before: Dictionary = screen.current_run_state.make_refuge_campaign_snapshot().duplicate(true)
	_check(view.floor_label.text == "Deepest floor reached: 2", "Hub reflects actual accessed Layer 2")
	await _shot(resolution, "hub")
	await _click(view.navigation[&"party"])
	_check(view.section == &"party" and screen.room_shell.panel.size.x > qa_view.size_2d_override.x * 0.9, "Party uses dedicated wide view")
	await _click(view.heroine_buttons[&"lysandra"].button)
	await _click(view.heroine_buttons[&"seraphine"].button)
	await _click(view.heroine_buttons[&"lysandra"].button)
	_check(view.draft == [&"mira", &"lysandra"] and screen.begin_button.disabled, "Sprite clicks form ordered draft and gate Explore")
	_check(before == screen.current_run_state.make_refuge_campaign_snapshot(), "Draft browsing changes no campaign state")
	_check(screen.room_shell.panel.get_global_rect().encloses(view.apply_button.get_global_rect()), "Party controls fit inside view")
	await _shot(resolution, "party_draft")
	await _action(&"ui_cancel")
	_check(view.section == &"hub" and view.draft == [&"mira", &"lysandra"], "Cancel retains draft at hub")
	await _click(view.navigation[&"party"])
	await _click(view.apply_button)
	_check(screen.current_run_state.refuge_ownership.selected_party_ids == [&"mira", &"lysandra"] and view.can_explore(), "Apply saves ordered party and enables Explore")
	await _action(&"ui_cancel")
	await _click(view.navigation[&"intel"])
	await _shot(resolution, "intel_run")
	view.intel_tabs.grab_focus()
	await _action(&"ui_right")
	_check(view.intel_tabs.current_tab == 1 and view.intel_list.get_child_count() == 10, "Permanent Intel lists approved options including Submit")
	await _shot(resolution, "intel_permanent")
	await _action(&"ui_cancel")
	await _click(view.navigation[&"level"])
	for index: int in range(3):
		await _click(view.progress_selector)
		await create_timer(0.4).timeout
		var start: int = view.progress_selector.get_popup().get_focused_item()
		var steps: int = index + 1 if start < 0 else (index - start + 3) % 3
		for step: int in range(steps):
			await _action(&"ui_down")
		await _action(&"ui_accept")
		_check(view.progress_heroine == [&"lysandra", &"mira", &"seraphine"][index], "Progression selector follows keyboard choice")
		view.progress_tabs.current_tab = index
		view._refresh_progression()
		_check(not view.progress_rows.is_empty() and view.upgrade_button.disabled, "Authored progression visible; unauthored upgrades unavailable")
		await _shot(resolution, ["stats", "skills", "heroine_upgrades"][index])
	await _action(&"ui_cancel")
	var launches: int = launch_count
	await _click(screen.begin_button)
	_check(launch_count == launches + 1, "Explore emits exactly one validated launch request")
	await _click(screen.room_shell.close_button)
	_check(not screen.room_shell.modal.visible and qa_view.gui_get_focus_owner() == screen.room_shell.hotspots[&"expedition"], "Closing restores map hotspot focus")

func _click(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		qa_view.push_input(event, true)
		await process_frame
	await create_timer(0.1).timeout

func _action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		qa_view.push_input(event, true)
		await process_frame

func _shot(resolution: Vector2i, label: String) -> void:
	screen.show_status("Expedition review fixture · no production save slot connected.")
	if capture_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await RenderingServer.frame_post_draw
	var captured: Image = qa_view.get_texture().get_image()
	_check(captured.get_size() == resolution, "Exact capture %s" % resolution)
	_check(captured.save_png(capture_directory.path_join("%dx%d_%s.png" % [resolution.x, resolution.y, label])) == OK, "Capture " + label)

func _check(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
