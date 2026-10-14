extends SceneTree
## Isolated visual fixture: no campaign slot is created or loaded.
## godot4 --path . --script res://tools/preview_refuge_room.gd
## Optional: -- --capture-dir=/tmp/ab-refuge-review (captures then exits).

const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
var screen: BloomRefugeScreen


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var run := RunState.new()
	var party: Dictionary = {}
	for id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		var definition: BattlerDefinition = BATTLERS.get_battler(id)
		party[id] = {"hp": definition.max_hp, "mp": definition.max_mp, "resolve": definition.starting_resolve, "corruption": definition.starting_corruption, "item_guard": 0, "weapon_damage": 0, "weapon_broken": false, "armor_damage": 0, "armor_broken": false, "shield_damage": 0, "shield_broken": false}
	run.initialize(27072026, LayerMapGenerator.new().generate_bloom_refuge_holding_state(27072026), [], party)
	run.opening_completed = true
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = [&"lysandra", &"mira", &"seraphine"]
	run.campaign_lifecycle.restore_legacy_refuge(27072026)
	var flags: Dictionary = run.narrative_state.flags_by_scope.get(&"save", {})
	flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	screen = load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	var error: String = screen.present(run, BATTLERS, KnowledgeState.new(), false)
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	if "--inventory-fixture" in OS.get_cmdline_user_args():
		_seed_inventory_fixture(run.refuge_ownership)
		screen._refresh_all()
	screen.show_status("Room review fixture · no production save slot connected.")
	screen.begin_button.disabled = true
	screen.begin_button.tooltip_text = "Expedition launch is available through the normal campaign entry."
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			await _capture(argument.trim_prefix("--capture-dir="))
			quit()


func _capture(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var capture_view := SubViewport.new()
	capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_view.size_2d_override_stretch = true
	var display := SubViewportContainer.new()
	root.add_child(display)
	display.add_child(capture_view)
	screen.reparent(capture_view, false)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]:
		capture_view.size = resolution
		capture_view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await create_timer(0.3).timeout
		await _snapshot(directory, "%dx%d_room" % [resolution.x, resolution.y])
		(screen.room_shell.hotspots[&"records"] as Control).grab_focus()
		await _snapshot(directory, "%dx%d_focus" % [resolution.x, resolution.y])
		(screen.room_shell.hotspots[&"records"] as Control).release_focus()
		for id: StringName in screen.room_shell.pages:
			screen.room_shell.open_station(id)
			await _snapshot(directory, "%dx%d_%s" % [resolution.x, resolution.y, id])
			if id == &"stash":
				screen.room_shell.inventory_panel.show_backpacks(true)
				for hero_index: int in range(screen.inventory_heroine.item_count):
					screen.inventory_heroine.select(hero_index)
					screen._on_inventory_heroine_selected(hero_index)
					await _snapshot(directory, "%dx%d_backpack_%s" % [resolution.x, resolution.y, screen.backpack_heroine_id])
			screen.handle_cancel()
		for hotspot: RefugeRoomHotspot in screen.room_shell.hotspots.values():
			hotspot.release_focus()
		screen.room_shell.open_system()
		await _snapshot(directory, "%dx%d_system" % [resolution.x, resolution.y])
		screen.room_shell._system_action(&"settings")
		await _snapshot(directory, "%dx%d_settings" % [resolution.x, resolution.y])
		screen.handle_cancel()
		screen.handle_cancel()
		for hotspot: RefugeRoomHotspot in screen.room_shell.hotspots.values():
			hotspot.release_focus()


func _snapshot(directory: String, label: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var error: Error = screen.get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("Refuge screenshot %s: %s" % [label, error_string(error)])


func _seed_inventory_fixture(ownership: RefugeOwnershipState) -> void:
	# Authored IDs and condition, fixture-only ownership. No production slot writes.
	ownership.add_preparation_item(&"lysandra", &"l01_bandage_roll", 2)
	ownership.add_preparation_item(&"lysandra", &"l01_hollow_livery_pin", 1)
	ownership.add_preparation_item(&"mira", &"l01_smelling_salts", 2)
	ownership.add_stash_item(&"l01_warm_wine_flask", 2)
	ownership.move_stash_item_to_item_bar(&"l01_warm_wine_flask", 1)
	var id := StringName(ownership.equipment_loadouts_by_heroine[&"lysandra"].slots.main_hand)
	ownership.unequip_owned_slot(&"lysandra", EquipmentDefinition.Slot.MAIN_HAND)
	ownership.move_unequipped_equipment_to_stash(&"lysandra", id)
	ownership.move_stash_equipment_to_heroine(id, &"mira")
	ownership.banked_materials["mat_l01_red_wax"] = 3
