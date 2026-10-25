extends "res://tools/preview_refuge_room.gd"
## Isolated native Rest fixture; no authored recovery or production save writes.
var qa_view := SubViewport.new()
var failures: int = 0
var capture_directory: String = ""

func _run() -> void:
	await super._run()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rest-captures="):
			capture_directory = argument.trim_prefix("--rest-captures=")
	screen.show_status("Rest review fixture · no campaign save slot connected.")
	if "--rest-interactive" in OS.get_cmdline_user_args():
		screen.room_shell.open_station(&"rest")
		return
	root.add_child(qa_view)
	qa_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	qa_view.size_2d_override_stretch = true
	qa_view.gui_embed_subwindows = true
	qa_view.notify_mouse_entered()
	screen.reparent(qa_view, false)
	var before: Dictionary = screen.current_run_state.make_refuge_campaign_snapshot().duplicate(true)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]:
		qa_view.size = resolution
		qa_view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await create_timer(0.3).timeout
		await _click(screen.room_shell.hotspots[&"rest"])
		_check(screen.room_shell.active_station == &"rest", "Bed mouse interaction opens Rest")
		var view: RefugeRestView = screen.rest_view
		for index: int in range(3):
			# Actual keyboard navigation through the shared selector.
			await _click(view.heroine_selector)
			_check(view.heroine_selector.get_popup().visible, "Selector opens by mouse")
			await create_timer(0.4).timeout
			var popup: PopupMenu = view.heroine_selector.get_popup()
			var start: int = popup.get_focused_item()
			# Mouse-opened menus may start without keyboard focus (-1).
			var steps: int = index + 1 if start < 0 else (index - start + 3) % 3
			for step: int in range(steps):
				await _action(&"ui_down")
			await _action(&"ui_accept")
			await create_timer(0.15).timeout
			_check(not popup.visible, "Keyboard confirms and closes selector")
			_check(view.selected_heroine_id == [&"lysandra", &"mira", &"seraphine"][index], "Keyboard selects named heroine")
			var current: Dictionary = screen.current_run_state.party_snapshot[view.selected_heroine_id]
			_check(view.values.text.contains("Resolve: %s" % current.resolve) and view.values.text.contains("Corruption: %s" % current.corruption), "Actual selected values displayed")
			_check(view.restore_button.disabled and view.cleanse_button.disabled, "Both unauthored services disabled")
			await _click(view.restore_button)
			await _click(view.cleanse_button)
			_check(before == screen.current_run_state.make_refuge_campaign_snapshot(), "Browsing and unavailable actions leave campaign identical")
			_check(screen.room_shell.panel.get_global_rect().encloses(view.cleanse_button.get_global_rect()), "Recovery controls remain inside panel")
			await _shot(resolution, String(view.selected_heroine_id))
		await _click(view.heroine_selector)
		screen.handle_cancel()
		_check(not view.heroine_selector.get_popup().visible and screen.room_shell.active_station == &"rest", "Cancel closes selector first")
		await _action(&"ui_cancel")
		_check(not screen.room_shell.modal.visible and qa_view.gui_get_focus_owner() == screen.room_shell.hotspots[&"rest"], "Cancel returns focus to bed")
		await _click(screen.room_shell.hotspots[&"rest"])
		await _click(screen.room_shell.close_button)
		_check(not screen.room_shell.modal.visible and qa_view.gui_get_focus_owner() == screen.room_shell.hotspots[&"rest"], "Close button returns focus to bed")
	print("Stage 07 native Rest fixture: %d failures." % failures)
	quit(failures)

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
