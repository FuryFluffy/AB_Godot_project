extends SceneTree


var failures: int = 0
var reaction_choice: StringName = &""
var defence_choice: StringName = &""
var equipment_break_choice: StringName = &""
var equipment_break_choice_count: int = 0
var grapple_dodge_choice: bool = false
var move_reaction_choice: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_reaction_exchange_contract()
	await _test_command_bar_grapple_context()
	_test_dodge_step_controller()
	_test_encounter_architecture()

	if failures == 0:
		print("Reusable merge tests passed.")
	else:
		push_error(
			"%d reusable merge test(s) failed." % failures
		)
	quit(failures)


func _test_reaction_exchange_contract() -> void:
	var packed := load(
		"res://scenes/battle/ui/reusable/components/reaction_exchange.tscn"
	) as PackedScene
	_expect(packed != null, "Reaction Exchange scene should load.")
	if packed == null:
		return
	var exchange := packed.instantiate() as ReactionExchange
	root.add_child(exchange)
	await process_frame
	exchange.reaction_selected.connect(_on_reaction_selected)
	exchange.defence_selected.connect(_on_defence_selected)
	exchange.equipment_break_selected.connect(
		_on_equipment_break_selected
	)
	exchange.grapple_response_selected.connect(
		_on_grapple_response_selected
	)
	exchange.move_reaction_selected.connect(
		_on_move_reaction_selected
	)
	exchange.open_exchange()
	exchange.set_context("Butler", "Lysandra", 3)
	exchange.set_reactor("Lysandra", 2)
	exchange.set_availability(true, true, true, false, true)

	_expect(exchange.visible, "Reaction Exchange should open.")
	_expect(
		not (exchange.get_node("%Attack") as Button).disabled,
		"Attack reaction should be enabled when legal."
	)
	_expect(
		(exchange.get_node("%Shield") as Button).disabled,
		"Illegal Shield defense should be disabled."
	)
	(exchange.get_node("%Defend") as Button).pressed.emit()
	_expect(
		(exchange.get_node("%DefendChoices") as HBoxContainer).visible,
		"Defend should switch the same window to Armor/Shield/Back."
	)
	(exchange.get_node("%Back") as Button).pressed.emit()
	_expect(
		(exchange.get_node("%Reactions") as HBoxContainer).visible,
		"Back should restore the five-reaction row."
	)
	(exchange.get_node("%Parry") as Button).pressed.emit()
	_expect(
		reaction_choice == &"parry",
		"Parry should emit the passive UI intention."
	)
	(exchange.get_node("%Armor") as Button).pressed.emit()
	_expect(
		defence_choice == &"armor",
		"Armor should emit the passive UI intention."
	)
	exchange.show_equipment_break_choice(
		"Lysandra's Chain",
		2
	)
	(exchange.get_node("%Destroy") as Button).pressed.emit()
	(exchange.get_node("%Destroy") as Button).pressed.emit()
	_expect(
		equipment_break_choice == &"destroy"
		and equipment_break_choice_count == 1,
		"Equipment break choices must submit exactly once."
	)
	_expect(
		not exchange.visible,
		"Submitting an equipment choice must immediately hide the exchange."
	)
	exchange.open_exchange()
	exchange.set_availability(true, true, true, true, true)
	exchange.set_player_controlled(false, "Butler")
	for button_name: StringName in [
		&"Attack",
		&"Dodge",
		&"Defend",
		&"Parry",
		&"Skip",
	]:
		var button := (
			exchange.get_node("%%%s" % button_name)
			as Button
		)
		_expect(
			button.disabled,
			"Enemy-owned reactions must disable %s." % button_name
		)
	exchange.open_grapple_exchange()
	exchange.set_grapple_availability(true)
	_expect(
		not (exchange.get_node("%Attack") as Button).visible
		and not (exchange.get_node("%Defend") as Button).visible
		and not (exchange.get_node("%Parry") as Button).visible,
		"Grapple initiation should hide ordinary reaction choices."
	)
	(exchange.get_node("%Dodge") as Button).pressed.emit()
	_expect(
		grapple_dodge_choice,
		"Grapple Dodge should emit the dedicated Grapple response."
	)
	exchange.open_move_reaction("Lysandra", "Butler", 2)
	_expect(
		(exchange.get_node("%Attack") as Button).visible
		and not (exchange.get_node("%Dodge") as Button).visible
		and (exchange.get_node("%Skip") as Button).text == "WAIT",
		"Move Reactions should use the persistent exchange window."
	)
	(exchange.get_node("%Attack") as Button).pressed.emit()
	_expect(
		move_reaction_choice,
		"Move Reaction Attack should emit the dedicated intention."
	)
	exchange.queue_free()
	await process_frame


func _test_command_bar_grapple_context() -> void:
	var packed := load(
		"res://scenes/battle/ui/reusable/components/command_bar_view.tscn"
	) as PackedScene
	_expect(packed != null, "Reusable Command Bar scene should load.")
	if packed == null:
		return
	var command_bar := packed.instantiate() as CommandBarView
	root.add_child(command_bar)
	await process_frame
	_expect(
		command_bar.find_child("Inspect", true, false) == null,
		"The obsolete reusable Inspect button must be removed."
	)
	command_bar.set_grapple_context(true, true, false)
	_expect(
		(command_bar.get_node("%Struggle") as Button).visible
		and not (command_bar.get_node("%Struggle") as Button).disabled,
		"A grappled heroine with Actions should receive Struggle."
	)
	_expect(
		(command_bar.get_node("%GrappleWait") as Button).visible
		and not (command_bar.get_node("%GrappleWait") as Button).disabled,
		"A grappled heroine with Actions should receive Wait."
	)
	_expect(
		not (command_bar.get_node("%Attack") as Button).visible,
		"Ordinary Attack must leave the command row during Grapple."
	)
	command_bar.queue_free()
	await process_frame


func _test_dodge_step_controller() -> void:
	var definitions: Array[BattlerDefinition] = [
		load(
			"res://data/battlers/heroines/lysandra.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/hollow_servant.tres"
		) as BattlerDefinition,
	]
	var battlers := BattleBootstrap.new().create_battler_states(
		definitions
	)
	var battlefield := BattlefieldState.new()
	var definition := load(
		"res://data/battlefields/ruined_chapel_spatial_test.tres"
	) as BattlefieldDefinition
	var error := battlefield.initialize(definition, battlers)
	_expect(error.is_empty(), "Dodge-step fixture should initialize.")
	if not error.is_empty():
		return

	var controller := DodgeStepController.new()
	controller.initialize(battlers, battlefield)
	var destinations := controller.get_legal_destinations(
		&"lysandra",
		&"hollow_servant"
	)
	_expect(
		not destinations.is_empty(),
		"Dodge should expose at least one connected free destination."
	)
	if destinations.is_empty():
		return
	var first: Dictionary = controller.choose_ai_destination(
		&"lysandra",
		&"hollow_servant"
	)
	_expect(
		not first.is_empty(),
		"AI-controlled Dodge should choose its own legal destination."
	)
	var anchor_id := StringName(first.get("anchor_id", &""))
	var position_index := int(first.get("position_index", -1))
	_expect(
		controller.apply_step(
			&"lysandra",
			&"hollow_servant",
			anchor_id,
			position_index
		).is_empty(),
		"Legal Dodge destination should apply without an Action cost."
	)
	var position := battlefield.get_battler_position(&"lysandra")
	_expect(
		position != null
		and position.anchor_id == anchor_id
		and position.position_index == position_index,
		"Dodge should move exactly to the chosen Anchor Position."
	)


func _test_encounter_architecture() -> void:
	var encounter_scene := load(
		"res://scenes/battle/combat_encounter.tscn"
	) as PackedScene
	_expect(
		encounter_scene != null,
		"Production CombatEncounter scene should load independently."
	)
	if encounter_scene != null:
		var encounter := encounter_scene.instantiate()
		_expect(
			encounter is CombatEncounter,
			"Production combat root should be CombatEncounter."
		)
		encounter.queue_free()


func _on_reaction_selected(choice: StringName) -> void:
	reaction_choice = choice


func _on_defence_selected(choice: StringName) -> void:
	defence_choice = choice


func _on_equipment_break_selected(choice: StringName) -> void:
	equipment_break_choice = choice
	equipment_break_choice_count += 1


func _on_grapple_response_selected(dodge: bool) -> void:
	grapple_dodge_choice = dodge


func _on_move_reaction_selected(react: bool) -> void:
	move_reaction_choice = react


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
