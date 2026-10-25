extends "res://tools/verify_run_hud.gd"
## Stage 11: real encounter/room hosts, injected native input and isolated data.
const ITEMS = preload("res://data/items/layer_1_2_item_catalog.tres")
const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
const HEROES: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--backpack-captures="):
			captures = argument.trim_prefix("--backpack-captures=")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	view.size = Vector2i(1280, 720)
	view.size_2d_override = Vector2i(1920, 1080)
	await _combat_ui()
	await _exploration_ui()
	print("Stage 11 native Backpack: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	await process_frame
	await process_frame
	quit(failures)

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		view.push_input(event, true)
		await process_frame

func _right_click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		view.push_input(event, true)
		await process_frame

func _combat_ui() -> void:
	var encounter: CombatEncounter = preload("res://scenes/battle/combat_encounter.tscn").instantiate()
	view.add_child(encounter)
	await _settle()
	var service: RunBackpackController = encounter.combat_engine.backpack
	var actor: BattlerState = encounter.get_battler_state(&"lysandra")
	_check(encounter.battle_flow_controller.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST).is_empty(), "Actual encounter starts")
	var panel: RunBackpackPanel = encounter.backpack_panel
	var hud: ReusableCombatHUD = encounter.reusable_hud
	service.inventory.backpacks_by_heroine[&"lysandra"][0] = {"slot_index": 0, "item_id": "l01_bandage_roll", "quantity": 4}
	var loadout: PersonalEquipmentLoadoutState = service.equipment.get_loadout(&"lysandra")
	var spare := EquipmentInstance.new()
	spare.initialize(&"stage11_visual_weapon", actor.weapon_state.definition)
	spare.set_condition_clamped(0)
	loadout.register_instance(spare)
	service.inventory.backpacks_by_heroine[&"lysandra"][1] = BackpackPayload.equipment_slot(1, spare.instance_id)
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await _settle()
		var before: Dictionary = service.snapshot()
		await _click(hud.dock.backpack_button.get_global_rect().get_center())
		await _settle()
		_check(panel.visible and panel.owner_id == &"lysandra" and service.snapshot() == before, "Open starts on actor and is free")
		_check(panel.backpack.grid.columns == 3 and panel.backpack.grid.get_child_count() == 15 and hud.item_bar.slot_buttons.size() == 6, "Shared 3×5 bag and exactly six HUD items")
		_check(Rect2(Vector2.ZERO, view.size_2d_override).encloses(panel.frame.get_global_rect()) and panel.frame.get_global_rect().end.y < hud.dock.log_tab.position.y, "Panel clears dock and Log tab")
		await _shot(resolution, "combat_backpack")
		await _right_click((panel.backpack.grid.get_child(0) as Control).get_global_rect().get_center())
		_check(panel.visible and panel.menu.visible, "Right-click opens item context instead of closing Backpack")
		await _shot(resolution, "context_cost")
		await _cancel()
		_check(panel.visible and not panel.menu.visible, "Nested cancel closes context only")
		panel.backpack.heroine_selector.select(1)
		panel.backpack.heroine_selector.item_selected.emit(1)
		await _settle()
		_check(panel.owner_id == &"mira" and encounter.battle_runtime.selected_battler_id == &"lysandra" and panel.status.text.contains("Read only"), "Other heroine browsing is read only and never changes actor")
		await _shot(resolution, "readonly_mira")
		await _cancel()
		_check(not panel.visible and service.snapshot() == before, "Browsing and cancel spend nothing")
	# Controller source/destination interaction uses the same transaction.
	await _key(KEY_B)
	await _settle()
	_check(panel.visible, "Keyboard Backpack shortcut opens")
	var source: Button = panel.backpack.grid.get_child(0)
	source.grab_focus()
	await _key(KEY_MENU)
	_check(panel.menu.visible, "Keyboard context menu available")
	panel.menu.hide()
	panel._context_action(2)
	panel.amount.value = 1
	panel.split.confirmed.emit()
	panel.split.hide()
	await _settle()
	var actions: int = actor.current_actions
	var destination: int = 3
	# Explicitly empty a native slot in this isolated fixture.
	service.item_bar.slots[destination].clear()
	# Refresh the request after the fixture-only slot edit.
	panel.context_request = service.request(RefugeInventoryTransfer.address(&"backpack", 0, &"lysandra"))
	panel._arm(1)
	panel.refresh()
	await _click(hud.item_bar.slot_buttons[destination].get_global_rect().get_center())
	_check(actor.current_actions == actions - 1 and service.item_bar.get_slot(destination).quantity == 1 and service.inventory.get_backpack_snapshot(&"lysandra")[0].quantity == 3, "HUD Item Bar receives split without using the item; one Action")
	await _settle()
	_check(not hud.item_bar.slot_buttons[5].disabled, "Deferred combat presentation retains empty inventory destinations")
	await _shot(Vector2i(1024, 768), "after_transfer")
	# Real mouse drag goes through Godot's drag forwarding, with one paid commit.
	service.inventory.backpacks_by_heroine[&"lysandra"][2] = {"slot_index": 2, "item_id": "l01_smelling_salts", "quantity": 1}
	service.item_bar.slots[5].clear()
	panel.refresh()
	await _settle()
	actions = actor.current_actions
	await _drag_between((panel.backpack.grid.get_child(2) as Control).get_global_rect().get_center(), hud.item_bar.slot_buttons[5].get_global_rect().get_center())
	_check(actor.current_actions == actions - 1 and service.item_bar.get_slot(5).quantity == 1 and BackpackPayload.is_empty(service.inventory.get_backpack_snapshot(&"lysandra")[2]), "Native mouse drag commits once and conserves source")
	# Input shields prevent party selection/commands/field clicks behind panel.
	await _click(hud.mira_card.get_global_rect().get_center())
	await _click(hud.command_bar.move_button.get_global_rect().get_center())
	_check(encounter.battle_runtime.selected_battler_id == &"lysandra" and not encounter.battle_runtime.is_selecting_move, "Panel blocks party and commands behind it")
	await _cancel()
	actor.add_grapple_track(&"stage11_fixture_grapple")
	await _settle()
	await _key(KEY_B)
	_check(not panel.visible and hud.dock.backpack_button.disabled, "Grapple rejects keyboard shortcut and button")
	actor.remove_grapple_track(&"stage11_fixture_grapple")
	await _settle()
	await _key(KEY_B)
	_check(panel.visible, "Backpack reopens after Grapple ends")
	actor.add_grapple_track(&"stage11_fixture_grapple")
	await _settle()
	_check(not panel.visible, "Grapple invalidates an already open panel")
	actor.remove_grapple_track(&"stage11_fixture_grapple")
	encounter.queue_free()
	await process_frame

func _exploration_ui() -> void:
	var room: EventRoomScreen = preload("res://scenes/exploration/event_room_screen.tscn").instantiate()
	view.add_child(room)
	room.current_party_ids = HEROES.duplicate()
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp": 5, "mp": 5}
	var initial := RunInventoryState.new()
	initial.initialize(ITEMS, HEROES, false)
	var inventory_error: String = room._prepare_inventory(ITEMS, initial.get_item_bar_snapshot())
	_check(inventory_error.is_empty(), "Actual room inventory initializes: " + inventory_error)
	_check(room._prepare_party_strip(BATTLERS, party).is_empty(), "Actual room builds shared Backpack")
	var panel: RunBackpackPanel = room.exploration_hud.backpack_panel
	if panel == null:
		_check(false, "Exploration panel must exist")
		room.queue_free()
		await process_frame
		return
	var hud: ExplorationHUD = room.exploration_hud
	room.run_inventory.backpacks_by_heroine[&"mira"][0] = {"slot_index": 0, "item_id": "l01_bandage_roll", "quantity": 2}
	for count: int in [1, 2, 3]:
		room.backpack_controller.heroine_ids.assign(HEROES.slice(0, count))
		view.size = Vector2i(1280, 720)
		view.size_2d_override = Vector2i(1920, 1080)
		await _settle()
		await _key(KEY_B)
		await _settle()
		_check(panel.visible and panel.backpack.heroine_selector.item_count == count, "Exploration selector only shows supplied current party")
		_check(panel.find_child("Stash", true, false) == null and panel.status.text.contains("free"), "Exploration has no remote Stash and charges no Actions")
		await _shot(Vector2i(1280, 720), "exploration_%d" % count)
		await _cancel()
	room.backpack_controller.heroine_ids = HEROES.duplicate()
	await _key(KEY_B)
	await _settle()
	panel.backpack.heroine_selector.select(1)
	panel.backpack.heroine_selector.item_selected.emit(1)
	panel.context_request = room.backpack_controller.request(RefugeInventoryTransfer.address(&"backpack", 0, &"mira"))
	panel._arm(1)
	await _click(hud.item_bar.slot_buttons[4].get_global_rect().get_center())
	_check(room.inventory.get_slot(4).quantity == 1 and room.run_inventory.get_backpack_snapshot(&"mira")[0].quantity == 1 and room.party_states[&"mira"].current_actions == 0, "Exploration UI transfer uses current ownership without combat Actions")
	await _cancel()
	room.selected_item_slot_index = 4
	await _settle()
	await _key(KEY_B)
	_check(not panel.visible, "Pending field item target cannot be replaced through Backpack")
	room.selected_item_slot_index = -1
	room.mode_controller.set_mode(ExplorationModeController.Mode.DIALOGUE)
	await _settle()
	await _key(KEY_B)
	_check(not panel.visible, "Dialogue prevents shortcut bypass")
	room.queue_free()
	await process_frame

func _drag_between(from: Vector2, to: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = from
	move.global_position = from
	view.push_input(move, true)
	var press := InputEventMouseButton.new()
	press.position = from
	press.global_position = from
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	view.push_input(press, true)
	await process_frame
	for point: Vector2 in [from + Vector2(30, 0), to]:
		move = InputEventMouseMotion.new()
		move.position = point
		move.global_position = point
		move.relative = point - from
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		view.push_input(move, true)
		await process_frame
	_check(view.gui_is_dragging(), "Godot native drag session is active")
	press = InputEventMouseButton.new()
	press.position = to
	press.global_position = to
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = false
	view.push_input(press, true)
	await _settle()
