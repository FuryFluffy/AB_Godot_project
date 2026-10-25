extends "res://tools/preview_refuge_room.gd"
## Isolated native Records fixture. Optional media is attached only in memory.
const MEDIA = preload("res://tests/fixtures/refuge_archive_fixture.gd")
var qa_view := SubViewport.new()
var failures: int = 0
var capture_directory: String = ""

func _run() -> void:
	await super._run()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--records-captures="):
			capture_directory = argument.trim_prefix("--records-captures=")
	screen.show_status("Records review fixture · no production save slot connected.")
	screen.current_knowledge_state.discovered_entries["butler_records"] = true
	screen.room_shell.open_station(&"records")
	if "--records-interactive" in OS.get_cmdline_user_args():
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
		screen.room_shell.open_station(&"records")
		await create_timer(0.3).timeout
		await _verify(resolution)
	print("Stage 09 native Records fixture: %d failures." % failures)
	qa_view.queue_free()
	await process_frame
	await process_frame
	quit(failures)

func _verify(resolution: Vector2i) -> void:
	var view: RefugeRecordsView = screen.records_view
	view.selected_ids.clear()
	view.catalog = RefugeRecordsView.LORE
	screen.current_knowledge_state.discovered_entries.clear()
	view.tabs.current_tab = 0
	view.refresh()
	_check(view.entries.is_empty(), "Undiscovered lore stays hidden")
	await _shot(resolution, "lore_empty")
	screen.current_knowledge_state.discovered_entries["butler_records"] = true
	view.refresh()
	_check(view.entries.size() == 1 and view.reading.text.contains("Butler's Records"), "Actual discovered lore is readable")
	await _shot(resolution, "lore")
	_check(screen.room_shell.panel.get_global_rect().encloses(view.reading_frame.get_global_rect()), "Reading pane fits station")
	view.tabs.grab_focus()
	await _action(&"ui_right")
	_check(view.tabs.current_tab == 1 and view.entries.is_empty(), "Keyboard selects truthful unavailable Bestiary")
	await _shot(resolution, "bestiary")
	await _action(&"ui_right")
	_check(view.tabs.current_tab == 2 and view.entries.is_empty(), "Keyboard selects truthful unavailable Run History")
	await _shot(resolution, "history")
	await _action(&"ui_right")
	_check(view.tabs.current_tab == 3 and view.entries.is_empty(), "Production Gallery has no invented media unlocks")
	await _shot(resolution, "gallery_empty")
	view.catalog = MEDIA.catalog()
	for entry: LoreEntryDefinition in view.catalog.entries:
		screen.current_knowledge_state.discovered_entries[String(entry.lore_id)] = true
	view.refresh()
	var before: Dictionary = screen.current_run_state.make_refuge_campaign_snapshot().duplicate(true)
	var known: Dictionary = screen.current_knowledge_state.to_snapshot()
	_check(view.image_button.visible and not view.replay_button.visible, "Image-only action mapping")
	await _shot(resolution, "gallery_fixture")
	await _click(view.image_button)
	_check(view.nested_mode == &"image" and view.viewer_image.texture == view.entries[0].archive_image, "Mouse opens larger image")
	await _shot(resolution, "image_fixture")
	await _action(&"ui_cancel")
	_check(view.nested_mode == &"" and qa_view.gui_get_focus_owner() == view.entry_list, "Escape restores Gallery focus")
	view.entry_list.grab_focus()
	await _action(&"ui_down")
	_check(view.entry_list.get_selected_items()[0] == 1 and not view.image_button.visible and view.replay_button.visible, "Keyboard selects scene-only entry")
	await _click(view.replay_button)
	_check(view.nested_mode == &"replay" and view.replay.runner != null, "Mouse opens isolated scene")
	await _shot(resolution, "replay_fixture")
	await _click(view.dialogue_panel.continue_button)
	_check(view.nested_mode == &"" and qa_view.gui_get_focus_owner() == view.entry_list, "Scene completion restores Gallery entry")
	await _click(view.replay_button)
	await _click(view.back_button)
	_check(view.nested_mode == &"" and view.replay.runner == null, "Back discards interrupted replay")
	_check(before == screen.current_run_state.make_refuge_campaign_snapshot() and known == screen.current_knowledge_state.to_snapshot(), "Gallery navigation preserves campaign and discovery")
	await _click(screen.room_shell.close_button)
	_check(not screen.room_shell.modal.visible and qa_view.gui_get_focus_owner() == screen.room_shell.hotspots[&"records"], "Close restores books hotspot focus")

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
	screen.show_status("Records review fixture · no production save slot connected.")
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
