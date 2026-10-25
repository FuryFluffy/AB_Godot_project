extends "res://tools/verify_run_backpack.gd"
## Actual room and encounter hosts; fixture outcomes avoid claiming a manual campaign playthrough.
const WINE = preload("res://data/exploration/rooms/layer1/wine_cellar_warm_bottles.tres")
const LORE = preload("res://data/lore/lore_catalog.tres")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--loot-captures="):
			captures = argument.trim_prefix("--loot-captures=")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	view.size = Vector2i(1280, 720)
	view.size_2d_override = Vector2i(1920, 1080)
	await _room_loot()
	await _fight_loot()
	print("Stage 12 native Loot: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	await process_frame
	await process_frame
	quit(failures)

func _room_loot() -> void:
	var room: EventRoomScreen = preload("res://scenes/exploration/event_room_screen.tscn").instantiate()
	view.add_child(room)
	var state := EventRoomInstanceState.new()
	state.source_node_id = &"stage12_wine_room"
	state.room_id = WINE.room_id
	state.generation_seed = 27072026
	var initial := RunInventoryState.new()
	initial.initialize(ITEMS, HEROES, false)
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp": 1, "mp": 1, "resolve": 70, "corruption": 10}
	_check(room.prepare_room(WINE, state, ITEMS, BATTLERS, LORE, KnowledgeState.new(), 1, initial.get_item_bar_snapshot(), party, NarrativeState.new().to_snapshot(), initial.get_snapshot()).is_empty(), "Authored Wine Cellar prepares")
	await _settle()
	room.stop_dialogue()
	await _settle()
	var record: Dictionary = state.local_state.item_spawns[0]
	var spawn := StringName(record.spawn_id)
	var panel: RunBackpackPanel = room.exploration_hud.backpack_panel
	var service := room.backpack_controller as RunLootController
	_check(service != null and room.active_pickups.has(spawn), "Authored room pickup exists")
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		room._on_world_item_pickup_requested(spawn)
		await _settle()
		_check(panel.visible and panel.loot_column.visible and panel.backpack.grid.get_child_count() == 15 and room.item_bar.slot_buttons.size() == 6, "Room Loot beside shared bag with one six-slot bar")
		_check(panel.loot_column.get_global_rect().end.x <= panel.backpack.get_global_rect().position.x and Rect2(Vector2.ZERO, view.size_2d_override).encloses(panel.frame.get_global_rect()) and panel.frame.get_global_rect().end.y < room.exploration_hud.dock.log_tab.position.y, "Adjacent Loot and Backpack fit above dock")
		var before: Dictionary = state.to_snapshot()
		await _shot(resolution, "room_loot")
		await _cancel()
		_check(not panel.visible and not panel.confirmation.visible and state.to_snapshot() == before and room.active_pickups.has(spawn), "Room close is non-destructive and never uses fight confirmation")
	room._on_world_item_pickup_requested(spawn)
	await _settle()
	var owner: StringName = panel.owner_id
	for i: int in range(15):
		service.inventory.backpacks_by_heroine[owner][i] = {"slot_index": i, "item_id": "l01_smelling_salts", "quantity": ITEMS.get_item(&"l01_smelling_salts").stack_limit}
	panel.refresh()
	await _settle()
	await _click((panel.loot_rows.get_child(0) as Control).get_global_rect().get_center())
	_check(not record.collected and room.active_pickups.has(spawn), "Failed full-bag collection preserves authored source")
	await _shot(Vector2i(1024, 768), "full_backpack")
	panel.backpack.heroine_selector.select(1)
	panel.backpack.heroine_selector.item_selected.emit(1)
	await _settle()
	await _drag_between((panel.loot_rows.get_child(0) as Control).get_global_rect().get_center(), (panel.backpack.grid.get_child(0) as Control).get_global_rect().get_center())
	_check(record.collected and not room.active_pickups.has(spawn), "Another heroine collects and removes only exhausted hotspot")
	await _cancel()
	# Carried-item operations are available during an offer, never applied on menu cancellation.
	room._on_world_item_pickup_requested(StringName(state.local_state.item_spawns[1].spawn_id))
	await _settle()
	if not panel.visible:
		service.bind_sources([record])
		panel.open_panel(&"mira")
	panel.owner_id = &"mira"
	service.inventory.backpacks_by_heroine[&"mira"][4] = {"slot_index": 4, "item_id": "l01_bandage_roll", "quantity": 3}
	panel.refresh()
	await _settle()
	await _right_click((panel.backpack.grid.get_child(4) as Control).get_global_rect().get_center())
	_check(panel.menu.visible and panel.menu.get_item_index(3) >= 0 and panel.menu.get_item_index(4) >= 0, "Loot carried context exposes Use and Discard")
	panel.menu.hide()
	panel._context_action(4)
	var before: Dictionary = service.snapshot()
	await _shot(Vector2i(1024, 768), "discard_confirmation")
	await _cancel()
	_check(panel.visible and not panel.confirmation.visible and service.snapshot() == before, "Discard cancellation changes nothing")
	panel._context_action(3)
	panel.confirm_target.select(1)
	await _click(panel.confirmation.get_ok_button().get_global_rect().get_center() + Vector2(panel.confirmation.position))
	_check(service.inventory.backpacks_by_heroine[&"mira"][4].quantity == 2 and room.party_states[&"mira"].current_hp > 1, "Use applies field heal to chosen heroine and consumes exactly one")
	await _cancel()
	var outcomes: Array[EventRoomOutcome] = []
	room.room_outcome_ready.connect(func(outcome: EventRoomOutcome) -> void: outcomes.append(outcome))
	room._emit_room_outcome(false)
	_check(outcomes.size() == 1 and outcomes[0].room_state_snapshot.local_state.item_spawns[0].collected, "Room outcome exports the same claim alongside inventory")
	var restored_state: EventRoomInstanceState = EventRoomInstanceState.from_snapshot(JSON.parse_string(JSON.stringify(state.to_snapshot())))
	var snapshot: Dictionary = service.inventory.get_snapshot()
	var party_snapshot: Dictionary = room._capture_party_snapshot()
	room.queue_free()
	await process_frame
	room = preload("res://scenes/exploration/event_room_screen.tscn").instantiate()
	view.add_child(room)
	_check(room.prepare_room(WINE, restored_state, ITEMS, BATTLERS, LORE, KnowledgeState.new(), 1, initial.get_item_bar_snapshot(), party_snapshot, NarrativeState.new().to_snapshot(), snapshot).is_empty(), "Serialized room and bags restore into actual room")
	room.stop_dialogue()
	_check(not room.active_pickups.has(spawn) and LootClaim.remaining(restored_state.local_state.item_spawns[0]) == 0 and int(restored_state.local_state.item_spawns[0].resolution_seed) == int(record.resolution_seed) and restored_state.local_state.item_spawns[0].item_id == record.item_id, "Revisit/load never rerolls or duplicates collected source")
	room.queue_free()
	await process_frame

func _fight_loot() -> void:
	var main: Node = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(main)
	var host: AbyssalBloomMainController = main.get_node("Controller")
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp": 10, "mp": 4, "resolve": 75, "corruption": 0}
	_check(host.run_state.initialize(8128, host.generator.generate_layer_2_run(8128), [], party).is_empty(), "Actual main controller run initializes")
	host.run_state.opening_completed = true
	host.run_state.travel_to(&"l2_c1_n0")
	host.run_state.prepare_pending_node_seed()
	host.boot_fallback.hide()
	host._launch_pending_battle()
	await _settle()
	var battle: CombatEncounter = host.active_battle
	_check(battle != null, "Production main controller launches authored encounter")
	if battle == null:
		main.queue_free()
		return
	battle.battle_runtime.battle_state.outcome = BattleState.Outcome.VICTORY
	battle._emit_encounter_outcome_if_ready()
	await _settle()
	var panel: RunBackpackPanel = battle.backpack_panel
	var service := panel.controller as RunLootController
	_check(panel.visible and service != null and panel.loot_column.visible and not host.return_overlay.visible, "Production victory offers Loot before summary")
	if service == null:
		main.queue_free()
		return
	var record: Dictionary = service.sources[0]
	var before: Dictionary = service.snapshot()
	await _shot(Vector2i(1024, 768), "fight_loot")
	await _cancel()
	_check(panel.confirmation.visible and panel.visible, "Fight close requires confirmed loss")
	await _shot(Vector2i(1024, 768), "fight_abandon_confirmation")
	await _cancel()
	_check(panel.visible and not panel.confirmation.visible and service.snapshot() == before and not host.return_overlay.visible, "Fight abandon cancellation keeps offer and source unchanged")
	await _cancel()
	await _click(panel.confirmation.get_ok_button().get_global_rect().get_center() + Vector2(panel.confirmation.position))
	await _settle()
	_check(not panel.visible and host.return_overlay.visible and record.abandoned_quantity == record.quantity and record.claimed, "Confirmed fight surplus loss advances to existing summary")
	_check(host.pending_outcome != null and host.pending_outcome.inventory_snapshot == battle.item_inventory.get_snapshot(), "Summary captures current bag/bar state after Loot management")
	main.queue_free()
	await process_frame

func _cancel() -> void:
	await _key(KEY_ESCAPE)
