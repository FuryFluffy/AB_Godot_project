extends "res://tools/preview_refuge_room.gd"
## Native Godot input/visual fixture. Isolated user data; no production saves.
## Run with -- --inventory-fixture --transfer-captures=/tmp/ab-stage03-ui
var failures: int = 0
var capture_directory: String = ""
var qa_view := SubViewport.new()

func _run() -> void:
	await super._run()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--transfer-captures="):
			capture_directory = argument.trim_prefix("--transfer-captures=")
	root.add_child(qa_view)
	qa_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	qa_view.size_2d_override_stretch = true
	qa_view.gui_embed_subwindows = true
	qa_view.gui_disable_input = false
	qa_view.handle_input_locally = true
	qa_view.notify_mouse_entered()
	screen.reparent(qa_view, false)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]:
		qa_view.size = resolution
		qa_view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await create_timer(0.3).timeout
		await _verify(resolution)
	print("Stage 03 native input/visual fixture: %d failures." % failures)
	quit(failures)

func _check(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func _verify(resolution: Vector2i) -> void:
	screen.room_shell.open_station(&"stash")
	screen.room_shell.inventory_panel.show_backpacks(true)
	var state: RefugeOwnershipState = screen.current_run_state.refuge_ownership
	state.add_stash_item(&"l01_warm_wine_flask", 1)
	for index: int in range(15):
		state.preparation_slots_by_heroine[&"lysandra"][index] = {"slot_index": index, "item_id": "", "quantity": 0}
	state.preparation_slots_by_heroine[&"lysandra"][0] = {"slot_index": 0, "item_id": "l01_bandage_roll", "quantity": 4}
	for index: int in range(6):
		state.prepared_item_bar_slots[index] = {"slot_index": index, "item_id": "", "quantity": 0}
	screen.backpack_heroine_id = &"lysandra"
	screen._refresh_all()
	await create_timer(0.2).timeout
	var interaction: RefugeInventoryInteraction = screen.inventory_interaction
	var source: Button = screen.preparation_grid.get_child(0)
	var target: Button = screen.item_bar_grid.slot_buttons[2]
	# Real mouse input enters native Control drag forwarding.
	await _drag_input(source.get_global_rect().get_center(), target.get_global_rect().get_center())
	_check(screen.current_run_state.refuge_ownership.prepared_item_bar_slots[2].quantity == 4, "%s native mouse drag to empty bar slot" % resolution)
	await _shot(resolution, "moved")
	# Controller-equivalent context button opens the same native popup.
	target.grab_focus()
	var context := InputEventJoypadButton.new()
	context.button_index = JOY_BUTTON_Y
	context.pressed = true
	qa_view.push_input(context, true)
	await process_frame
	_check(interaction.menu.visible, "%s controller context menu" % resolution)
	await _shot(resolution, "context")
	interaction.menu.hide()
	interaction._context_action(3)
	await process_frame
	_check(interaction.split.visible, "%s split picker" % resolution)
	await _shot(resolution, "split")
	interaction.amount.value = 2
	interaction.split.get_ok_button().pressed.emit()
	await process_frame
	interaction.split.hide()
	_check(not interaction.pending.is_empty(), "%s split arms quantity without mutation" % resolution)
	# Native mouse split then cancellation via Escape's screen path.
	await _drag_input(target.get_global_rect().get_center(), (screen.preparation_grid.get_child(5) as Control).get_global_rect().get_center())
	_check(screen.current_run_state.refuge_ownership.prepared_item_bar_slots[2].quantity == 2 and screen.current_run_state.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][5].quantity == 2, "%s native split drag conserves remainder" % resolution)
	await _shot(resolution, "split_result")
	var before: Dictionary = screen.current_run_state.refuge_ownership.to_snapshot()
	await _mouse(target.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, true)
	await _motion(target.get_global_rect().get_center() + Vector2(25, -25), MOUSE_BUTTON_MASK_LEFT)
	_check(qa_view.gui_is_dragging(), "%s native drag starts" % resolution)
	screen.handle_cancel()
	await _mouse(target.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, false)
	_check(not qa_view.gui_is_dragging() and before == screen.current_run_state.refuge_ownership.to_snapshot() and screen.room_shell.modal.visible, "%s cancelled drag leaves inventory and parent open" % resolution)
	# Stash context opens real named-owner submenu, then saves one quick transfer.
	screen.room_shell.inventory_panel.show_backpacks(false)
	await process_frame
	screen.stash_items.select(0)
	screen.stash_items.grab_focus()
	qa_view.push_input(context, true)
	await process_frame
	_check(interaction.menu.visible, "%s Stash context opens" % resolution)
	interaction.menu.set_focused_item(0)
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	qa_view.push_input(right, true)
	await create_timer(0.25).timeout
	_check(interaction.heroines.visible and interaction.heroines.item_count == 3, "%s named heroine submenu" % resolution)
	await _shot(resolution, "named_transfer")
	interaction.heroines.hide()
	interaction.menu.hide()
	interaction._named_transfer(1)
	_check(String(screen.status_label.text).begins_with("Moved "), "%s named quick transfer completes" % resolution)
	screen.handle_cancel()

func _drag_input(from: Vector2, to: Vector2) -> void:
	await _motion(from, 0)
	await _mouse(from, MOUSE_BUTTON_LEFT, true)
	await _motion(from + Vector2(22, 0), MOUSE_BUTTON_MASK_LEFT)
	await _motion(to, MOUSE_BUTTON_MASK_LEFT)
	await _mouse(to, MOUSE_BUTTON_LEFT, false)
	await create_timer(0.15).timeout

func _mouse(at: Vector2, button: int, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = event.position
	event.button_index = button
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and button == MOUSE_BUTTON_LEFT else 0
	qa_view.push_input(event, true)
	await process_frame

func _motion(at: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = event.position
	event.relative = Vector2(22, 0)
	event.button_mask = mask
	qa_view.push_input(event, true)
	await process_frame

func _shot(resolution: Vector2i, label: String) -> void:
	if capture_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	var file: String = capture_directory.path_join("%dx%d_%s.png" % [resolution.x, resolution.y, label])
	var captured: Image = qa_view.get_texture().get_image()
	_check(captured.get_size() == resolution, "Exact capture dimensions %s" % resolution)
	var error: Error = captured.save_png(file)
	_check(error == OK, "Screenshot " + file)
