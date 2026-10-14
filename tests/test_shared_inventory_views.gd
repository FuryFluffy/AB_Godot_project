extends SceneTree

const BATTLER_CATALOG = preload("res://data/battlers/battler_catalog.tres")
const ITEM_CATALOG = preload("res://data/items/layer_1_2_item_catalog.tres")
const HEROINE_IDS: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
const MEMENTO: StringName = &"l01_hollow_livery_pin"
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_mixed_ownership()
	await _test_inventory_views()
	print("Stage 02 shared inventory tests: %d failures." % failures)
	quit(failures)

func _expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _test_mixed_ownership() -> void:
	var refuge: RefugeOwnershipState = _make_refuge()
	# Normalize the pre-existing redundant loadout memento mirror first.
	refuge.restore_from_snapshot(refuge.to_snapshot(), ITEM_CATALOG, BATTLER_CATALOG, HEROINE_IDS)
	var loadout: Dictionary = refuge.equipment_loadouts_by_heroine[&"lysandra"]
	var id := StringName(loadout.slots.main_hand)
	_expect(refuge.unequip_owned_slot(&"lysandra", EquipmentDefinition.Slot.MAIN_HAND).is_empty(), "Unequip fixture gear.")
	_expect(refuge.move_unequipped_equipment_to_stash(&"lysandra", id).is_empty(), "Stash fixture gear.")
	var gear: Dictionary = refuge.stash_equipment_instances[id].duplicate(true)
	gear.current_condition = maxi(0, int(gear.current_condition) - 1)
	refuge.stash_equipment_instances[id] = gear
	_expect(refuge.move_stash_equipment_to_heroine(id, &"mira").is_empty(), "Equipment enters a named Backpack.")
	_expect(refuge.preparation_slots_by_heroine[&"mira"][0].equipment_instance_id == String(id) and not refuge.stash_equipment_instances.has(id), "Equipment moves to exactly one bag slot.")
	_expect(refuge.equipment_loadouts_by_heroine[&"mira"].instances[String(id)] == gear, "Instance and condition remain in the existing registry.")
	_expect(refuge.add_preparation_item(&"mira", MEMENTO).is_empty(), "Carried Memento uses its Item ID.")
	_expect(refuge.add_preparation_item(&"mira", &"l01_bandage_roll", 2).is_empty(), "Ordinary items must not overwrite equipment.")
	_expect(refuge.preparation_slots_by_heroine[&"mira"][0].equipment_instance_id == String(id) and refuge.preparation_slots_by_heroine[&"mira"][1].item_id == String(MEMENTO), "Equipment and Mementos consume distinct slots.")
	_expect(not refuge.move_preparation_item_to_item_bar(&"mira", MEMENTO, 1).is_empty(), "Carried Mementos cannot enter Item Bar.")
	_expect(refuge.get("memento_slots_by_heroine")[&"mira"] == null, "Carrying a Memento must not equip it or activate its effects.")
	var snapshot: Dictionary = refuge.to_snapshot()
	var restored := RefugeOwnershipState.new()
	_expect(restored.restore_from_snapshot(snapshot, ITEM_CATALOG, BATTLER_CATALOG, HEROINE_IDS).is_empty() and JSON.stringify(restored.to_snapshot()) == JSON.stringify(snapshot), "Mixed Refuge inventory round-trips without migration or duplicates.")
	var restored_before_invalid: Dictionary = restored.to_snapshot()
	for fault: String in ["duplicate", "unknown", "equipped", "quantity", "mixed"]:
		var invalid: Dictionary = snapshot.duplicate(true)
		var bag: Array = invalid.heroine_records.mira.preparation_slots
		match fault:
			"duplicate": bag[4] = BackpackPayload.equipment_slot(4, id)
			"unknown": bag[0].equipment_instance_id = "missing:instance"
			"equipped": invalid.heroine_records.mira.equipment_loadout.slots.main_hand = String(id)
			"quantity": bag[0].quantity = 2
			"mixed": bag[0].item_id = "l01_bandage_roll"
		_expect(not restored.restore_from_snapshot(invalid, ITEM_CATALOG, BATTLER_CATALOG, HEROINE_IDS).is_empty() and restored.to_snapshot() == restored_before_invalid, "Invalid %s reference rolls back every field." % fault)
	var full: Dictionary = snapshot.duplicate(true)
	for index: int in range(1, 15):
		full.heroine_records.mira.preparation_slots[index] = {"slot_index": index, "item_id": String(MEMENTO), "quantity": 1}
	_expect(restored.restore_from_snapshot(full, ITEM_CATALOG, BATTLER_CATALOG, HEROINE_IDS).is_empty(), "Full mixed bag restores.")
	var before_full: Dictionary = restored.to_snapshot()
	_expect(not restored.add_preparation_item(&"mira", &"l01_bandage_roll").is_empty() and restored.to_snapshot() == before_full, "Equipment occupies capacity and cannot be overwritten by automatic placement.")
	var launch: Dictionary = refuge.make_run_start_transfer()
	_expect(String(launch.error).is_empty(), "Mixed Backpack launches through the existing boundary: %s" % launch.error)
	if not String(launch.error).is_empty():
		return
	var inventory: RunInventoryState = launch.run_inventory
	var equipment: RunEquipmentState = launch.run_equipment
	var away: RefugeOwnershipState = launch.refuge_state
	var run_copy := RunInventoryState.new()
	run_copy.initialize(ITEM_CATALOG, HEROINE_IDS)
	_expect(run_copy.restore_from_snapshot(inventory.get_snapshot()).is_empty(), "Mixed active-run inventory restores.")
	var gear_copy := RunEquipmentState.new()
	_expect(gear_copy.initialize_from_snapshot(BATTLER_CATALOG, HEROINE_IDS, run_copy, equipment.get_snapshot()).is_empty(), "Active-run equipment validates the same references.")
	var entries: Array[Dictionary] = InventorySlotPresenter.run_backpack(run_copy, gear_copy, &"mira")
	_expect(entries.size() == 15 and entries[0].kind == "Equipment" and entries[0].condition == gear.current_condition and entries[1].kind == "Memento" and not entries[1].has("condition"), "Run adapter uses the same exact instance record and no invented Memento condition.")
	for defeated: bool in [false, true]:
		var returned: Dictionary = away.make_run_return_transfer(inventory, equipment, defeated)
		_expect(String(returned.error).is_empty(), "Return boundary succeeds: %s" % returned.error)
		if not String(returned.error).is_empty():
			continue
		var home: RefugeOwnershipState = returned.refuge_state
		var bag: Array = home.preparation_slots_by_heroine[&"mira"]
		_expect(bag[0].equipment_instance_id == String(id) and home.equipment_loadouts_by_heroine[&"mira"].instances[String(id)] == gear, "Registered equipment survives return/defeat with exact condition and location.")
		_expect(BackpackPayload.is_empty(bag[1]) == defeated and BackpackPayload.is_empty(bag[2]) == defeated, "Defeat loses carried Mementos/ordinary items; voluntary return retains them.")
		_expect(home.stash_item_stacks == refuge.stash_item_stacks and home.banked_materials == refuge.banked_materials, "Presentation does not alter Stash or banked Materials.")

func _test_inventory_views() -> void:
	var screen := load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	await process_frame
	var run: RunState = _make_established_run()
	_expect(screen.present(run, BATTLER_CATALOG, KnowledgeState.new(), false).is_empty(), "Inventory screen presents.")
	for item: ItemDefinition in ITEM_CATALOG.items:
		if item.canonical_workbook_item and item.content_category == ItemDefinition.ContentCategory.KEY:
			run.refuge_ownership.key_chain[String(item.item_id)] = 2
			break
	run.refuge_ownership.banked_materials["mat_l01_red_wax"] = 3
	screen._refresh_all()
	var shared_bar: Array[Dictionary] = screen.management.get_item_bar_entries()
	var shell: RefugeRoomShell = screen.room_shell
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	var loadout_owner: StringName = screen.selected_heroine_id
	shell.open_station(&"stash")
	await process_frame
	_expect(shell.inventory_panel.stash_page.is_visible_in_tree() and not screen.item_bar_grid.is_visible_in_tree(), "Chest opens Stash first without Item Bar.")
	shell.inventory_panel.backpacks_tab.pressed.emit()
	await process_frame
	_expect(screen.preparation_grid.columns == 3 and screen.preparation_grid.get_child_count() == 15, "Backpack has exactly three columns and five rows.")
	_expect(screen.item_bar_grid.is_visible_in_tree() and screen.item_bar_grid.slot_buttons.size() == 6 and not shell.panel.is_ancestor_of(screen.item_bar_grid), "Exactly one native six-slot Item Bar lives outside the inventory panel.")
	_expect(screen.item_bar_grid.size.y > 0 and screen.get_global_rect().encloses(screen.item_bar_grid.get_global_rect()), "Contextual bar has a visible size and fits entirely inside the viewport.")
	var buttons: Array[Button] = screen.item_bar_grid.slot_buttons
	for index: int in range(1, buttons.size()):
		_expect(buttons[index].get_global_rect().position.x >= buttons[index - 1].get_global_rect().end.x, "All six native Item Bar slots must be separately visible in one row.")
	shell._trap_focus()
	shell.close_button.grab_focus()
	var reached_bar: bool = false
	for step: int in range(40):
		var event := InputEventAction.new()
		event.action = "ui_focus_next"
		event.pressed = true
		root.push_input(event, true)
		await process_frame
		event = InputEventAction.new()
		event.action = "ui_focus_next"
		event.pressed = false
		root.push_input(event, true)
		var focused: Control = root.gui_get_focus_owner()
		var in_bar: bool = screen.item_bar_grid.is_ancestor_of(focused)
		reached_bar = reached_bar or in_bar
		_expect(in_bar or shell.panel.is_ancestor_of(focused), "Keyboard focus stays within inventory and its external Item Bar.")
	_expect(reached_bar, "Keyboard navigation reaches the external Item Bar.")
	_expect(screen.key_list.is_visible_in_tree() and not screen.preparation_grid.is_ancestor_of(screen.key_list), "Shared Key-ring uses no Backpack slot.")
	var keys: Array[String] = []
	for index: int in range(screen.key_list.item_count):
		keys.append(screen.key_list.get_item_text(index))
	screen.inventory_heroine.select(1)
	screen.inventory_heroine.item_selected.emit(1)
	await process_frame
	_expect(screen.backpack_heroine_id == &"mira" and screen.selected_heroine_id == loadout_owner and run.refuge_ownership.to_snapshot() == before, "Backpack browsing must not select Loadouts or change expedition/ownership.")
	_expect(screen.management.get_item_bar_entries() == shared_bar, "Heroine selection leaves shared Item Bar contents unchanged.")
	_expect(screen.key_list.item_count == 1 and "×2" in keys[0], "Key-ring renders actual shared key quantities.")
	for index: int in range(keys.size()):
		_expect(keys[index] == screen.key_list.get_item_text(index), "Heroine selection leaves shared keys unchanged.")
	screen.preparation_grid.get_child(0).pressed.emit()
	_expect(run.refuge_ownership.to_snapshot() == before, "Slot inspection is read-only.")
	shell.inventory_panel.stash_tab.pressed.emit()
	await process_frame
	_expect(not screen.item_bar_grid.is_visible_in_tree() and screen.material_list.is_visible_in_tree(), "Stash hides contextual bar and shows actual banked Materials.")
	_expect("×3" in screen.material_list.get_item_text(0), "Stash Materials display the actual banked balance.")
	shell.inventory_panel.show_backpacks(true)
	screen.handle_cancel()
	_expect(not screen.item_bar_grid.is_visible_in_tree() and not shell.modal.visible, "Closing inventory restores the Bloom-only room.")
	shell.open_station(&"stash")
	_expect(not shell.inventory_panel.showing_backpacks, "Reopening chest resets to Stash.")
	# Run-mode shell cannot reveal Stash, even if explicitly asked.
	shell.inventory_panel.configure(shell.inventory_panel.stash_page, shell.inventory_panel.backpacks_page, false)
	shell.inventory_panel.show_backpacks(false)
	_expect(not shell.inventory_panel.stash_tab.visible and not shell.inventory_panel.stash_page.visible and shell.inventory_panel.showing_backpacks, "Run presentation cannot expose remote Stash.")
	_expect(run.refuge_ownership.to_snapshot() == before, "Browsing and cancellation never mutate ownership.")
	screen.queue_free()
	await process_frame

func _make_refuge() -> RefugeOwnershipState:
	var refuge := RefugeOwnershipState.new()
	var error: String = refuge.initialize_default(
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS,
		_make_party_snapshot()
	)
	_expect(error.is_empty(), "Refuge fixture must initialize.")
	return refuge


func _make_established_run() -> RunState:
	var generator := LayerMapGenerator.new()
	var run := RunState.new()
	run.initialize(
		27072026,
		generator.generate_bloom_refuge_holding_state(27072026),
		[],
		_make_party_snapshot()
	)
	run.opening_completed = true
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = HEROINE_IDS.duplicate()
	run.campaign_lifecycle.restore_legacy_refuge(27072026)
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	var save_flags: Dictionary = run.narrative_state.flags_by_scope.get(
		&"save", {}
	) as Dictionary
	save_flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	save_flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	return run


func _make_party_snapshot() -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(10, 4, 73, 8),
		&"mira": _heroine_snapshot(9, 6, 69, 12),
		&"seraphine": _heroine_snapshot(8, 8, 81, 4),
	}


func _heroine_snapshot(
	hp: int,
	mp: int,
	resolve: int,
	corruption: int
) -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"resolve": resolve,
		"corruption": corruption,
		"item_guard": 0,
		"weapon_damage": 0,
		"weapon_broken": false,
		"armor_damage": 0,
		"armor_broken": false,
		"shield_damage": 0,
		"shield_broken": false,
	}
