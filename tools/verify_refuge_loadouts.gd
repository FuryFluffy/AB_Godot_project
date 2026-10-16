extends "res://tools/preview_refuge_room.gd"
## Isolated Stage 04 native input and exact-resolution captures; no campaign slot.
var qa_view := SubViewport.new()
var failures: int = 0
var capture_directory: String = ""
var initial_ownership: Dictionary = {}

func _run() -> void:
	await super._run()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--loadout-captures="):
			capture_directory = argument.trim_prefix("--loadout-captures=")
	initial_ownership = screen.current_run_state.refuge_ownership.to_snapshot()
	root.add_child(qa_view)
	qa_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	qa_view.size_2d_override_stretch = true
	qa_view.gui_embed_subwindows = true
	qa_view.notify_mouse_entered()
	screen.reparent(qa_view, false)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]:
		qa_view.size = resolution
		qa_view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await create_timer(0.3).timeout
		await _verify(resolution)
	print("Stage 04 native Loadouts fixture: %d failures." % failures)
	quit(failures)

func _seed_inventory_fixture(ownership: RefugeOwnershipState) -> void:
	super._seed_inventory_fixture(ownership)
	# Existing authored IDs; the existing fixture carries Lysandra's sword in Mira.
	for item: ItemDefinition in ownership.item_catalog.items:
		if item.canonical_workbook_item and item.content_category == ItemDefinition.ContentCategory.MEMENTO and item.item_id != &"l01_hollow_livery_pin":
			_check(ownership.assign_memento(&"seraphine", item.item_id).is_empty(), "Equip authored fixture Memento")
			break

func _verify(resolution: Vector2i) -> void:
	var state: RefugeOwnershipState = screen.current_run_state.refuge_ownership
	_check(state.restore_from_snapshot(initial_ownership, screen.management.ITEM_CATALOG, BATTLERS, state.known_heroine_ids).is_empty(), "Reset isolated fixture")
	screen._refresh_all()
	screen.room_shell.open_station(&"loadouts")
	var view: RefugeLoadoutsView = screen.loadouts_view
	view.selector.select(2)
	view.selector.item_selected.emit(2)
	await create_timer(0.15).timeout
	_check(view.rows.get_child_count() == 4 and view.heroine_id == &"seraphine", "%s four rows and named selector" % resolution)
	await _shot(resolution, "main")
	var before: Dictionary = state.to_snapshot()
	await _click(view.change_buttons[&"main_hand"])
	_check(view.chooser.visible and view.choices.size() >= 2 and view.candidate_list.has_focus(), "%s Change opens candidates and focuses list" % resolution)
	view.candidate_list.select(0)
	await _action(&"ui_down")
	_check(view.candidate_list.get_selected_items() == PackedInt32Array([1]), "%s native direction input selects next candidate" % resolution)
	_check(view.destination_hint.text.contains("Mira") and state.to_snapshot() == before, "%s preview names source without mutation" % resolution)
	await _shot(resolution, "weapon_sources")
	await _click(view.equip_button)
	_check(not view.chooser.visible and screen.current_run_state.refuge_ownership.equipment_loadouts_by_heroine[&"seraphine"].slots.main_hand != before.heroine_records.seraphine.equipment_loadout.slots.main_hand, "%s Equip commits through native button" % resolution)
	await _shot(resolution, "equipped")
	await _click(view.change_buttons[&"memento"])
	_check(view.choices.size() >= 2, "%s Memento source available" % resolution)
	view.candidate_list.select(1)
	view.candidate_list.item_selected.emit(1)
	await _shot(resolution, "memento_sources")
	var snapshot: Dictionary = screen.current_run_state.refuge_ownership.to_snapshot()
	await _cancel()
	_check(not view.chooser.visible and screen.room_shell.modal.visible and snapshot == screen.current_run_state.refuge_ownership.to_snapshot(), "%s Escape backs out without equipping" % resolution)
	await _click(view.change_buttons[&"off_hand"])
	_check(view.choices.size() == 1 and view.choices[0].display_name == "Nothing", "%s Off Hand does not invent gear" % resolution)
	await _click(screen.room_shell.close_button)
	_check(not view.chooser.visible and screen.room_shell.modal.visible and qa_view.gui_get_focus_owner() == view.change_buttons[&"off_hand"], "%s Close behaves as Back and restores Change focus" % resolution)
	await _cancel()
	_check(not screen.room_shell.modal.visible and qa_view.gui_get_focus_owner() == screen.room_shell.hotspots[&"loadouts"], "%s Cancel returns to weapon stand" % resolution)

func _click(button: Button) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		qa_view.push_input(event, true)
		await process_frame
	await create_timer(0.1).timeout

func _cancel() -> void:
	await _action(&"ui_cancel")

func _action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	qa_view.push_input(event, true)
	await process_frame
	event.pressed = false
	qa_view.push_input(event, true)
	await process_frame

func _shot(resolution: Vector2i, label: String) -> void:
	if capture_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await RenderingServer.frame_post_draw
	var captured: Image = qa_view.get_texture().get_image()
	_check(captured.get_size() == resolution, "Exact capture %s" % resolution)
	var file: String = capture_directory.path_join("%dx%d_%s.png" % [resolution.x, resolution.y, label])
	_check(captured.save_png(file) == OK, "Screenshot " + file)

func _check(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
