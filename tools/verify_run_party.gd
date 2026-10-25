extends "res://tools/verify_run_backpack.gd"

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--party-captures="):
			captures = argument.trim_prefix("--party-captures=")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	view.size = Vector2i(1280, 720)
	view.size_2d_override = Vector2i(1920, 1080)
	await _party_ui()
	await _combat_order()
	print("Stage 13 native Party: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	await process_frame
	await process_frame
	quit(failures)

func _party_ui() -> void:
	var room: EventRoomScreen = preload("res://scenes/exploration/event_room_screen.tscn").instantiate()
	view.add_child(room)
	room.current_party_ids = HEROES.duplicate()
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp": 5, "mp": 5}
	var run := RunState.new()
	var generator := LayerMapGenerator.new()
	run.initialize(813, generator.generate_layer_1(813), generator.make_layer_1_generated_room_item_rules(), party)
	var main := AbyssalBloomMainController.new()
	main.run_state = run
	main._configure_room_party(room)
	var initial := RunInventoryState.new()
	initial.initialize(ITEMS, HEROES, false)
	_check(room._prepare_inventory(ITEMS, initial.get_item_bar_snapshot()).is_empty(), "Room inventory initializes")
	_check(room._prepare_party_strip(BATTLERS, party).is_empty(), "Room builds actual Party panel")
	var panel: RunPartyPanel = room.exploration_hud.party_panel
	var hud: ExplorationHUD = room.exploration_hud
	var before: Dictionary = room.backpack_controller.snapshot()
	var original_state: BattlerState = room.party_states[&"lysandra"]
	var selected_target: StringName = room.selected_heroine_id
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		await _settle()
		await _click(hud.command_bar.party_button.get_global_rect().get_center())
		await _settle()
		_check(panel.visible and panel.card_buttons.size() == 3, "Current members shown")
		_check(Rect2(Vector2.ZERO, view.size_2d_override).encloses(panel.frame.get_global_rect()) and panel.frame.get_global_rect().end.y < hud.dock.log_tab.position.y, "Party fits above dock and log tab")
		await _click((panel.card_buttons[&"mira"] as Button).get_global_rect().get_center())
		await _settle()
		_check(panel.selected == &"mira" and panel.details.text.contains("HP 5/") and panel.details.text.contains("Memento:"), "Inspection shows live heroine stats and loadout")
		await _shot(resolution, "party_inspection")
		panel.details.scroll_to_line(panel.details.get_line_count() - 1)
		await _settle()
		await _shot(resolution, "party_equipment")
		await _click(panel.abilities.get_global_rect().get_center())
		await _settle()
		_check(panel.ability_panel.visible, "Abilities opens existing read-only component")
		await _shot(resolution, "party_abilities")
		await _key(KEY_TAB)
		_check(panel.ability_panel.cancel_button.has_focus(), "Nested read-only Ability keeps keyboard focus on Back")
		await _key(KEY_ESCAPE)
		_check(panel.visible and not panel.ability_panel.visible, "Escape closes nested abilities first")
		await _click(panel.earlier.get_global_rect().get_center())
		await _settle()
		_check(room.party_display_order[0] == &"mira" and hud.dock.active_ids[0] == &"mira" and run.get_party_display_order()[0] == &"mira", "Click reorder updates panel and dock immediately")
		await _click(panel.later.get_global_rect().get_center())
		await _settle()
		await _key(KEY_B)
		await _click(hud.lysandra_card.get_global_rect().get_center())
		_check(not hud.backpack_panel.visible and room.selected_heroine_id == selected_target, "Modal blocks Backpack and field targeting behind it")
		await _key(KEY_ESCAPE)
		_check(not panel.visible and hud.command_bar.party_button.has_focus(), "Close restores Party button focus")
	_check(room.backpack_controller.snapshot() == before and room.party_states[&"lysandra"] == original_state and room.current_party_ids == HEROES, "Inspection/reordering preserve instances, roster and inventory ownership")
	room.party_order_commit = Callable()
	var all_states: Dictionary = room.party_states.duplicate()
	for count: int in [1, 2]:
		room.current_party_ids.assign(HEROES.slice(0, count))
		room.party_states.clear()
		for id: StringName in room.current_party_ids:
			room.party_states[id] = all_states[id]
		room._refresh_party_strip()
		await _settle()
		await _click(hud.command_bar.party_button.get_global_rect().get_center())
		await _settle()
		_check(panel.card_buttons.size() == count and (count != 1 or (panel.earlier.disabled and panel.later.disabled)), "Only active members appear; solo cannot reorder")
		_check(hud.mira_card.visible == (count >= 2) and not hud.seraphine_card.visible, "Subset dock matches the same current roster")
		await _shot(Vector2i(1024, 768), "party_%d" % count)
		await _key(KEY_ESCAPE)
	await _key(KEY_B)
	await _settle()
	room._toggle_party()
	_check(not panel.visible and hud.command_bar.party_button.disabled, "Backpack blocks opening Party")
	await _key(KEY_ESCAPE)
	await _settle()
	room._toggle_party()
	await _settle()
	room.selected_item_slot_index = 0
	await _settle()
	room._toggle_party()
	_check(not panel.visible and hud.command_bar.party_button.disabled, "Pending item target closes Party and blocks reopening")
	room.selected_item_slot_index = -1
	room.mode_controller.set_mode(ExplorationModeController.Mode.DIALOGUE)
	await _settle()
	room._toggle_party()
	_check(not panel.visible and hud.command_bar.party_button.disabled, "Dialogue blocks Party")
	room.queue_free()
	await process_frame
	main.free()

func _combat_order() -> void:
	var encounter: CombatEncounter = preload("res://scenes/battle/combat_encounter.tscn").instantiate()
	encounter.party_display_order = [&"seraphine", &"mira", &"lysandra"]
	view.add_child(encounter)
	await _settle()
	_check(encounter.reusable_hud.dock.active_ids == encounter.party_display_order, "Next combat presents saved Party order")
	_check(encounter.battle_flow_controller.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST).is_empty(), "Combat starts normally with reordered display")
	var engine: CombatEngine = encounter.combat_engine
	var runtime: BattleRuntimeState = engine.battle_runtime
	var battle: BattleState = runtime.battle_state
	var before_order: Array[StringName] = engine.stable_battler_order.duplicate()
	var before_states: Dictionary = engine.battler_states.duplicate()
	var before_positions: Dictionary = engine.battlefield_state.battler_positions.duplicate(true)
	var before_inventory: Dictionary = engine.backpack.snapshot()
	var before_turn: Array = [runtime.selected_battler_id, battle.round_number, battle.phase, battle.phase_index, battle.party_order_total, battle.enemy_order_value, battle.first_side, battle.second_side]
	var actions: Dictionary = {}
	for id: StringName in engine.battler_states:
		actions[id] = engine.battler_states[id].current_actions
	encounter.reusable_hud.dock.preferred_party_order = HEROES.duplicate()
	encounter.reusable_hud.set_active_party_ids(encounter.party_display_order)
	await _settle()
	_check(encounter.reusable_hud.dock.active_ids == HEROES, "Dock presentation can reorder existing cards")
	_check(engine.stable_battler_order == before_order and engine.battler_states == before_states and engine.battlefield_state.battler_positions == before_positions, "Presentation preserves battler identity, order and battlefield positions")
	_check([runtime.selected_battler_id, battle.round_number, battle.phase, battle.phase_index, battle.party_order_total, battle.enemy_order_value, battle.first_side, battle.second_side] == before_turn, "Presentation preserves actor, initiative, round and phase")
	var unchanged: bool = true
	for id: StringName in engine.battler_states:
		unchanged = unchanged and actions[id] == engine.battler_states[id].current_actions
	_check(unchanged and engine.backpack.snapshot() == before_inventory, "Presentation spends no Actions and changes no item/equipment ownership")
	encounter.queue_free()
	await process_frame
