extends "res://tools/preview_refuge_room.gd"
## Isolated Godot fixture. --salvage-fixture enables ONE NPC definition in memory
## solely for UI verification; no Resource or production campaign is written.
var qa_view := SubViewport.new()
var failures: int = 0
var capture_directory: String = ""
var initial_ownership: Dictionary = {}
var salvage_definition: EquipmentDefinition
var previous_availability: bool = false
var armor_id: StringName
const SALVAGE_ID: StringName = &"fixture:workbench:wax"

func _run() -> void:
	await super._run()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workbench-captures="):
			capture_directory = argument.trim_prefix("--workbench-captures=")
	var ownership: RefugeOwnershipState = screen.current_run_state.refuge_ownership
	armor_id = StringName(ownership.equipment_loadouts_by_heroine[&"seraphine"].slots.armor)
	ownership.equipment_loadouts_by_heroine[&"seraphine"].instances[String(armor_id)].current_condition = 0
	ownership.banked_materials["mat_l01_servant_cloth"] = 2
	if "--salvage-fixture" in OS.get_cmdline_user_args():
		salvage_definition = screen.management.EQUIPMENT_CATALOG.get_equipment(&"red_wax_drip")
		previous_availability = salvage_definition.player_refuge_available
		salvage_definition.player_refuge_available = true
		var instance := EquipmentInstance.new()
		_check(instance.initialize(SALVAGE_ID, salvage_definition, 0).is_empty(), "Create fixture-only salvage instance")
		ownership.stash_equipment_instances[SALVAGE_ID] = instance.to_snapshot()
		_check(ownership.move_stash_equipment_to_heroine(SALVAGE_ID, &"mira").is_empty(), "Place fixture in Mira Backpack")
	screen._refresh_all()
	screen.show_status("Workbench fixture · no production save · salvage eligibility is fixture-only.")
	screen.room_shell.open_station(&"repair")
	if "--workbench-interactive" in OS.get_cmdline_user_args():
		return
	initial_ownership = ownership.to_snapshot()
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
	if salvage_definition != null:
		salvage_definition.player_refuge_available = previous_availability
	print("Stage 05 native Workbench fixture: %d failures." % failures)
	quit(failures)

func _verify(resolution: Vector2i) -> void:
	var ownership: RefugeOwnershipState = screen.current_run_state.refuge_ownership
	_check(ownership.restore_from_snapshot(initial_ownership, screen.management.ITEM_CATALOG, BATTLERS, ownership.known_heroine_ids).is_empty(), "Reset fixture")
	screen._refresh_all()
	screen.room_shell.open_station(&"repair")
	var view: RefugeWorkbenchView = screen.workbench_view
	view.tabs.current_tab = 0
	await process_frame
	_check(view.repair_preview.text.contains("Seraphine") and view.repair_preview.text.contains("0/2 → 1/2"), "%s repair shows equipped source and actual result" % resolution)
	await _shot(resolution, "repair")
	await _click(screen.get_node("%RepairSelected"))
	_check(screen.management.get_equipment_entry(armor_id).condition == 1 and screen.current_run_state.refuge_ownership.get_banked_material_quantity(&"mat_l01_servant_cloth") == 1, "%s native Repair preserves source and charges once" % resolution)
	await _click_at(view.tabs.global_position + view.tabs.get_tab_rect(1).get_center())
	_check(view.salvage_page.visible and not view.repair_page.visible, "%s native Salvage tab" % resolution)
	if salvage_definition != null:
		screen.salvage_list.grab_focus()
		await _action(&"ui_down")
		_check(screen.salvage_list.get_selected_items() == PackedInt32Array([0]) and view.salvage_preview.text.contains("Mira"), "%s native candidate selection names Mira" % resolution)
		await _shot(resolution, "salvage")
		var before: Dictionary = screen.current_run_state.refuge_ownership.to_snapshot()
		await _click(screen.get_node("%SalvageSelected"))
		_check(screen.salvage_confirmation.visible, "%s native review opens confirmation" % resolution)
		await _shot(resolution, "confirmation")
		await _click(screen.salvage_confirmation.get_cancel_button())
		_check(not screen.salvage_confirmation.visible and before == screen.current_run_state.refuge_ownership.to_snapshot(), "%s native Cancel preserves equipment and Materials" % resolution)
		await _click(screen.get_node("%SalvageSelected"))
		await _click(screen.salvage_confirmation.get_ok_button())
		_check(screen.management.get_equipment_entry(SALVAGE_ID).is_empty() and screen.current_run_state.refuge_ownership.get_banked_material_quantity(&"mat_l01_red_wax") == 1, "%s native confirmation destroys one instance and banks one yield" % resolution)
	await _shot(resolution, "empty_salvage")
	await _action(&"ui_cancel")
	_check(not screen.room_shell.modal.visible and qa_view.gui_get_focus_owner() == screen.room_shell.hotspots[&"repair"], "%s Cancel restores Workbench hotspot focus" % resolution)

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	if control.get_window() != root:
		point += Vector2(control.get_window().position)
	await _click_at(point)

func _click_at(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
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
