extends "res://tools/preview_refuge_room.gd"
## No campaign slots. Recipe mappings are explicit process-local fixtures only.
var qa_view := SubViewport.new()
var failures: int = 0
var capture_directory: String = ""
var fixtures: Array[RefugeRecipeDefinition] = []
var initial_ownership: Dictionary = {}

func _run() -> void:
	await super._run()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--production-captures="):
			capture_directory = argument.trim_prefix("--production-captures=")
	if "--recipe-fixtures" in OS.get_cmdline_user_args():
		for station: RefugeRecipeDefinition.Station in [RefugeRecipeDefinition.Station.ALCHEMY, RefugeRecipeDefinition.Station.CRAFTING]:
			var recipe := RefugeRecipeDefinition.new()
			recipe.recipe_id = StringName("fixture:production:%d" % station)
			recipe.display_name = "Fixture tonic" if station == RefugeRecipeDefinition.Station.ALCHEMY else "Fixture bandage"
			recipe.action = RefugeRecipeDefinition.Action.PRODUCE_ITEM
			recipe.station = station
			recipe.output_item_id = &"l01_servants_tonic" if station == RefugeRecipeDefinition.Station.ALCHEMY else &"l01_bandage_roll"
			recipe.output_quantity = 2
			for material: MaterialDefinition in screen.management.MATERIAL_CATALOG.materials:
				recipe.material_inputs[String(material.item_id)] = 1
				screen.current_run_state.refuge_ownership.banked_materials[String(material.item_id)] = 3
			screen.management.RECIPE_CATALOG.recipes.append(recipe)
			fixtures.append(recipe)
	screen._refresh_all()
	screen.show_status("Production fixture · recipe mappings are test data · no campaign slot.")
	screen.room_shell.open_station(&"alchemy")
	if "--production-interactive" in OS.get_cmdline_user_args():
		return
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
		for index: int in range(2):
			await _verify(resolution, index)
	for recipe: RefugeRecipeDefinition in fixtures:
		screen.management.RECIPE_CATALOG.recipes.erase(recipe)
	print("Stage 06 native production fixture: %d failures." % failures)
	quit(failures)

func _verify(resolution: Vector2i, index: int) -> void:
	var state: RefugeOwnershipState = screen.current_run_state.refuge_ownership
	_check(state.restore_from_snapshot(initial_ownership, screen.management.ITEM_CATALOG, BATTLERS, state.known_heroine_ids).is_empty(), "Reset isolated ownership")
	screen._refresh_all()
	var id: StringName = &"alchemy" if index == 0 else &"crafting"
	screen.room_shell.open_station(id)
	await create_timer(0.15).timeout
	var view: RefugeProductionView = screen.production_views[index]
	_check(screen.room_shell.active_station == id and screen.room_shell.panel.position.x > qa_view.size_2d_override.x * 0.4, "%s %s separate right-side station" % [resolution, id])
	var before: Dictionary = screen.current_run_state.refuge_ownership.to_snapshot()
	if fixtures.is_empty():
		_check(view.entries.is_empty() and view.action_button.disabled, "Production unavailable without authored recipes")
		await _shot(resolution, String(id) + "_empty")
	else:
		view.recipes.grab_focus()
		await _action(&"ui_down")
		_check(before == screen.current_run_state.refuge_ownership.to_snapshot() and view.entries[0].inputs.size() == 4, "Four-ingredient browsing changes no ownership")
		await _shot(resolution, String(id) + "_preview")
		await _click(view.action_button)
		_check(screen.current_run_state.refuge_ownership.stash_item_stacks.size() == 1 and screen.current_run_state.refuge_ownership.stash_item_stacks[0].quantity == 2, "Native production creates exact output once in Stash")
		for material: MaterialDefinition in screen.management.MATERIAL_CATALOG.materials:
			_check(screen.current_run_state.refuge_ownership.get_banked_material_quantity(material.item_id) == 2, "Native production consumes one " + material.display_name)
		await _shot(resolution, String(id) + "_produced")
	await _action(&"ui_cancel")
	_check(not screen.room_shell.modal.visible and qa_view.gui_get_focus_owner() == screen.room_shell.hotspots[id], "Cancel restores dedicated station hotspot")

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
