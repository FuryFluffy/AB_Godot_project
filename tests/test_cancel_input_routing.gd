extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_cancel_gestures()
	_test_item_targeting_uses_central_cancel_path()
	_test_attack_targeting_uses_central_cancel_path()
	_test_board_targeting_uses_central_cancel_path()
	_test_selection_panels_use_central_cancel_path()
	_test_committed_move_cannot_be_cancelled()
	_test_exploration_input_is_handled_before_teardown()

	if failures == 0:
		print("Central cancel-input routing tests passed.")
	else:
		push_error(
			"%d cancel-input routing test(s) failed."
			% failures
		)
	quit(failures)


func _test_cancel_gestures() -> void:
	var encounter := _make_encounter()
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	_expect(
		encounter._is_cancel_input(escape_event),
		"Escape should be recognized as a cancel input."
	)

	var echo_event := InputEventKey.new()
	echo_event.keycode = KEY_ESCAPE
	echo_event.pressed = true
	echo_event.echo = true
	_expect(
		not encounter._is_cancel_input(echo_event),
		"Held Escape key echoes must not repeat cancellation."
	)

	var right_mouse_event := InputEventMouseButton.new()
	right_mouse_event.button_index = MOUSE_BUTTON_RIGHT
	right_mouse_event.pressed = true
	_expect(
		encounter._is_cancel_input(right_mouse_event),
		"Right mouse press should be recognized as a cancel input."
	)

	var left_mouse_event := InputEventMouseButton.new()
	left_mouse_event.button_index = MOUSE_BUTTON_LEFT
	left_mouse_event.pressed = true
	_expect(
		not encounter._is_cancel_input(left_mouse_event),
		"Left mouse press must not be treated as cancellation."
	)


func _test_item_targeting_uses_central_cancel_path() -> void:
	var encounter := _make_encounter()
	encounter.battle_runtime.begin_item_targeting(&"mira", 2)
	encounter.commands_locked = true

	_expect(
		encounter._cancel_current_interaction(),
		"An active Item target selection should be cancellable."
	)
	_expect(
		not encounter.battle_runtime.is_selecting_item_target,
		"Cancelling must clear Item target selection."
	)
	_expect(
		encounter.battle_runtime.pending_item_user_id == &""
		and encounter.battle_runtime.pending_item_slot_index == -1,
		"Cancelling must clear the pending Item user and slot."
	)
	_expect(
		not encounter.commands_locked,
		"Cancelling Item targeting must restore combat commands."
	)


func _test_attack_targeting_uses_central_cancel_path() -> void:
	var encounter := _make_encounter()
	encounter.action_controller = BattleActionController.new()
	encounter.action_controller.runtime = encounter.battle_runtime
	encounter.battle_runtime.begin_attack_targeting(&"lysandra")

	_expect(
		encounter._cancel_current_interaction(),
		"An active Attack target selection should be cancellable."
	)
	_expect(
		not encounter.battle_runtime.is_selecting_attack_target
		and encounter.battle_runtime.pending_attacker_id == &"",
		"Cancelling must clear Attack target selection."
	)


func _test_board_targeting_uses_central_cancel_path() -> void:
	var encounter := _make_encounter()
	encounter.battlefield_input_overlay = (
		BattlefieldInteractionOverlay.new()
	)
	encounter.battlefield_overlay = BattlefieldOverlay.new()
	encounter.move_button = Button.new()
	encounter.aoe_button = Button.new()

	encounter.movement_controller = BattleMovementController.new()
	encounter.movement_controller.runtime = encounter.battle_runtime
	encounter.battle_runtime.begin_move_targeting(&"seraphine")
	_expect(
		encounter._cancel_current_interaction()
		and not encounter.battle_runtime.is_selecting_move,
		"Move selection should use the central cancel path."
	)

	encounter.aoe_controller = AoeActionController.new()
	encounter.aoe_controller.runtime = encounter.battle_runtime
	encounter.battle_runtime.begin_aoe_targeting(
		&"mira",
		AbilityDefinition.new()
	)
	_expect(
		encounter._cancel_current_interaction()
		and not encounter.battle_runtime.is_selecting_aoe,
		"AOE selection should use the central cancel path."
	)

	encounter.ability_controller = AbilityActionController.new()
	encounter.ability_controller.runtime = encounter.battle_runtime
	encounter.battle_runtime.begin_ability_targeting(
		&"lysandra",
		AbilityDefinition.new()
	)
	_expect(
		encounter._cancel_current_interaction()
		and not encounter.battle_runtime.is_selecting_ability_target,
		"Single-target Ability selection should use the central cancel path."
	)


func _test_committed_move_cannot_be_cancelled() -> void:
	var encounter := _make_encounter()
	var committed_move := CommittedMoveState.new()
	encounter.battle_runtime.store_active_move(committed_move)
	_expect(
		not encounter._cancel_current_interaction(),
		"A committed Move must not be interrupted by cancel input."
	)
	_expect(
		encounter.battle_runtime.active_move == committed_move,
		"Cancel input must preserve the committed Move state."
	)


func _test_selection_panels_use_central_cancel_path() -> void:
	var encounter := _make_encounter()
	encounter.ability_panel = AbilityPanel.new()
	encounter.ability_panel.show()
	_expect(
		encounter._cancel_current_interaction()
		and not encounter.ability_panel.visible,
		"The Ability popup should use the central cancel path."
	)

	encounter.struggle_panel = StrugglePanel.new()
	encounter.struggle_panel.show()
	_expect(
		encounter._cancel_current_interaction()
		and not encounter.struggle_panel.visible,
		"The Struggle popup should use the central cancel path."
	)


func _test_exploration_input_is_handled_before_teardown() -> void:
	var packed := load(
		"res://scenes/exploration/rooms/layer1/wax_prep_room.tscn"
	) as PackedScene
	_expect(packed != null, "Wax Preparation Room scene should load.")
	if packed == null:
		return

	var input_viewport := SubViewport.new()
	root.add_child(input_viewport)
	var room := packed.instantiate()
	input_viewport.add_child(room)
	var room_exit := room.find_child(
		"RoomExitHotspot",
		true,
		false
	) as RoomExitHotspot
	_expect(room_exit != null, "Wax Preparation Room should expose its exit.")
	if room_exit == null:
		room.free()
		input_viewport.free()
		return
	var handled_before_teardown: Array[bool] = [false]
	room_exit.exit_requested.connect(
		func() -> void:
			handled_before_teardown[0] = input_viewport.is_input_handled()
			input_viewport.remove_child(room)
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	room_exit._input_event(input_viewport, click, 0)
	_expect(
		handled_before_teardown[0]
		and room.get_parent() == null,
		(
			"Wax Preparation Room exit input must be handled before its "
			+ "interaction callback tears down the room."
		)
	)
	room.free()
	input_viewport.free()


func _make_encounter() -> CombatEncounter:
	var encounter := CombatEncounter.new()
	encounter.battle_runtime = BattleRuntimeState.new()
	encounter.log_presenter = BattleLogPresenter.new()
	return encounter


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
