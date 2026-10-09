extends SceneTree

var failures: int = 0
var selection_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var definition := EncounterDefinition.new()
	definition.encounter_id = &"dining_dock_test"
	definition.authored_room_id = &"dining_service_hall"
	definition.combat_stage_id = &"dining_service_hall_stage"
	definition.enemy_ids.assign([&"hollow_servant"])
	definition.template = load("res://data/encounters/dining_service_hall_template.tres")
	var encounter: CombatEncounter = load("res://scenes/battle/combat_encounter.tscn").instantiate()
	var inventory: Array[Dictionary] = []
	encounter.prepare_run_encounter(definition, {}, inventory)
	root.add_child(encounter)
	await _layout()
	var hud := encounter.reusable_hud as BottomDockHUD
	_expect(hud != null, "Dining stage must compose the native bottom HUD.")
	if hud == null:
		quit(1)
		return
	var hud_count: int = 0
	for child: Node in encounter.get_children():
		if child is ReusableCombatHUD:
			hud_count += 1
	_expect(hud_count == 1, "Exactly one HUD may own intentions.")
	_expect(hud.item_bar.slot_buttons.size() == 6, "The shared bar must contain six slots.")
	_expect(hud.command_bar.log_button.is_set_as_top_level(), "Log must not participate in CommandBar container layout.")
	hud.heroine_selected.connect(func(_id: StringName) -> void: selection_count += 1)
	var ids: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
	for count: int in [1, 2, 3]:
		var party: Array[StringName] = []
		party.assign(ids.slice(0, count))
		hud.set_active_party_ids(party)
		await _layout()
		var visible_count: int = 0
		for card: HeroineCardView in [hud.lysandra_card, hud.mira_card, hud.seraphine_card]:
			if not card.visible:
				continue
			visible_count += 1
			_expect(card.get_global_rect().end.y <= 1080, "The entire heroine card must fit above the window bottom.")
			_expect(is_equal_approx(card.size.x, 288.0), "Party cards must keep a readable fixed width.")
			var before: int = selection_count
			_click(card.get_global_rect().get_center())
			await process_frame
			_expect(selection_count == before + 1, "One pointer click emits one heroine selection.")
			_expect(encounter.battle_runtime.selected_battler_id == card.battler_id, "Pointer card selects the real battler.")
		_expect(visible_count == count, "No empty party cards should remain.")
		_expect(hud.party_strip.get_global_rect().end.x < hud.item_bar.position.x, "Party and items must not overlap.")
		_expect(hud.item_bar.get_global_rect().end.x < hud.command_bar.position.x, "Items and commands must not overlap.")
		_expect(hud.command_bar.get_global_rect().end.x <= 1920, "All commands must fit the design canvas.")
	var slot := hud.item_bar.slot_buttons[0] as CombatItemSlotView
	hud.display_item_slot(0, "misleading label 77", true, "Structured count", true, null, 123)
	await _layout()
	_expect(slot.quantity_badge.text == "123", "Quantity must come from the structured field, never parsed label text.")
	_expect(slot.size.x == hud.command_bar.attack_button.size.x, "Items and normal commands share slot width.")
	_expect(slot.size.y == hud.command_bar.attack_button.size.y, "Items and normal commands share slot height.")
	_expect(slot.button_pressed, "Selected item needs a selected state.")
	var width: float = slot.size.x
	hud.display_item_slot(0, "999", false, "Empty", false, null, 0)
	hud.item_bar.set_locked(true)
	hud.item_bar.set_locked(false)
	await _layout()
	_expect(slot.disabled and slot.quantity_badge.text.is_empty() and slot.size.x == width,
		"Empty slots remain disabled and fixed width after unlock.")
	encounter.battle_flow_controller.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST)
	encounter._refresh_battle_flow_ui()
	# Pointer events must reach authored Positions behind faded battler controls,
	# even with a non-identity canvas camera transform.
	encounter._on_battler_selected(&"lysandra")
	encounter._on_move_pressed()
	var board: BattlefieldInteractionOverlay = encounter.battlefield_input_overlay
	var lane: AnchorDefinition = encounter.battlefield_definition.get_anchor(&"west_lane")
	var camera: Camera2D = encounter.presentation_director.camera
	camera.zoom = Vector2(1.08, 1.08)
	camera.force_update_scroll()
	await _layout()
	_click(board.get_global_transform_with_canvas() * lane.get_position_point(2))
	await process_frame
	_expect(board.move_path.has(&"west_lane"), "Pointer area selection must cross faded sprites in camera space.")
	var path_before: Array[StringName] = board.move_path.duplicate()
	_click(hud.command_bar.log_button.get_global_rect().get_center())
	await process_frame
	_expect(hud.log_is_open and board.move_path == path_before, "Log pointer input must not consume or alter Move selection.")
	hud.close_log()
	_click(board.get_global_transform_with_canvas() * lane.get_position_point(2))
	await create_timer(0.9).timeout
	_expect(encounter.battlefield_state.get_battler_position(&"lysandra").position_index == 2,
		"Second pointer click must confirm the real authored Position.")
	camera.zoom = Vector2.ONE
	camera.force_update_scroll()
	encounter._on_battler_selected(&"seraphine")
	await _layout()
	_click(hud.command_bar.ability_button.get_global_rect().get_center())
	await create_timer(0.25).timeout
	_expect(hud.ability_panel.visible, "Pointer routing opens Ability on its first click.")
	_expect(hud.ability_panel.get_global_rect().end.y < 944, "First-open Ability content must clear the dock.")
	_click(hud.command_bar.log_button.get_global_rect().get_center())
	await process_frame
	_expect(hud.log_is_open, "Log remains clickable with Ability open.")
	_expect(hud.combat_log.size.x >= 500 and hud.combat_log.size.y >= 280, "Log must retain a usable scrollable drawer, not collapse to its header.")
	_expect(not hud.combat_log.get_global_rect().intersects(hud.ability_panel.get_global_rect()), "Log and Ability must not cover one another.")
	encounter._cancel_current_interaction()
	await process_frame
	_expect(not hud.ability_panel.visible, "Cancel closes the Ability popup.")
	_click(hud.command_bar.ability_button.get_global_rect().get_center())
	await create_timer(0.25).timeout
	_expect(hud.ability_panel.visible and hud.ability_panel.get_global_rect().end.y < 944, "Reopening retains popup clearance.")
	encounter._cancel_current_interaction()
	encounter._set_commands_locked(true)
	_click(hud.command_bar.log_button.get_global_rect().get_center())
	await process_frame
	_expect(not hud.log_is_open and not hud.command_bar.log_button.disabled, "Locked resolution still allows the Log tab.")
	encounter._set_commands_locked(false)
	hud.reaction_exchange.set_anchor_position(Vector2(1600, 1080))
	hud.reaction_exchange.open_exchange()
	await _layout()
	_expect(hud.reaction_exchange.get_global_rect().end.y < 944, "Reaction choices must clear the dock.")
	hud.reaction_exchange.show_equipment_break_choice("Test equipment", 3)
	await _layout()
	_expect(hud.reaction_exchange.get_global_rect().end.y < 944, "Equipment break choices must clear the dock.")
	hud.close_reaction_exchange()
	# Real controller initiation; no UI-only context swap is treated as Grapple evidence.
	encounter.battlefield_state.place_battler(&"lysandra", &"rear_center", 1)
	var attempt: GrappleAttemptResult = encounter.grapple_controller.prepare_initiation(&"hollow_servant", &"lysandra")
	_expect(attempt.error_message.is_empty(), "The existing controller should permit the contact Grapple fixture: " + attempt.error_message)
	if attempt.error_message.is_empty():
		attempt = encounter.grapple_controller.resolve_initiation(false)
		_expect(attempt.succeeded, "The genuine initiation should attach a track.")
		if attempt.succeeded:
			encounter._on_battler_selected(&"lysandra")
			encounter._refresh_battle_flow_ui()
			await _layout()
			_expect(hud.command_bar.struggle_button.visible and hud.command_bar.submit_button.disabled, "Real Grapple shows Struggle and gated Submit.")
			_click(hud.command_bar.struggle_button.get_global_rect().get_center())
			await create_timer(0.3).timeout
			_expect(hud.struggle_panel.visible and hud.struggle_panel.get_global_rect().end.y < 944, "Real Grapple Struggle popup must clear the dock.")
			encounter._cancel_current_interaction()
	# Verify every authored destination and attached foot clearance under camera focus.
	var director: CombatPresentationDirector = encounter.presentation_director
	var marker: BattleMarker = encounter._get_battler_marker(&"lysandra")
	var old_position: Vector2 = marker.position
	for anchor: AnchorDefinition in encounter.battlefield_definition.anchors:
		for index: int in range(anchor.capacity):
			marker.position = anchor.get_position_point(index)
			for cluster_offset: Vector2 in [Vector2.ZERO, Vector2(0, 45)]:
				marker.cluster_display_offset = cluster_offset
				var focus: Vector2 = director._safe_focus(Vector2(960, 540), 1.12)
				var screen_foot: float = (marker.position.y + cluster_offset.y + 13 * marker.battlefield_presentation_scale - focus.y) * 1.12 + 540
				_expect(screen_foot <= 936.01, "Every authored foot/shadow and Grapple cluster must fit the reserved area.")
	marker.position = old_position
	marker.cluster_display_offset = Vector2.ZERO
	encounter.queue_free()
	await process_frame
	var ordinary: CombatEncounter = load("res://scenes/battle/combat_encounter.tscn").instantiate()
	root.add_child(ordinary)
	await process_frame
	_expect(not ordinary.reusable_hud is BottomDockHUD and ordinary.presentation_director == null,
		"A non-Dining encounter must keep its original HUD and presentation.")
	ordinary.queue_free()
	await process_frame
	if failures == 0:
		print("Dining bottom dock integration tests passed.")
	quit(failures)

func _layout() -> void:
	for _frame: int in range(4):
		await process_frame

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
