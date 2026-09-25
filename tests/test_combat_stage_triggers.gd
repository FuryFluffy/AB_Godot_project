extends SceneTree


var failures: int = 0


func _init() -> void:
	var catalog := load(
		"res://data/presentation/combat_stage_catalog.tres"
	) as CombatStageCatalog
	_test_production_bindings(catalog)
	_test_interaction_once_only()
	_test_delayed_trigger_and_cancellation()
	_test_restored_resolution_does_not_replay()
	if failures == 0:
		print("Combat-stage trigger lifecycle tests passed.")
	else:
		push_error("%d combat-stage trigger test(s) failed." % failures)
	quit(failures)


func _test_production_bindings(catalog: CombatStageCatalog) -> void:
	_expect(catalog != null, "The production combat-stage catalog should load.")
	if catalog == null:
		return
	var opening: CombatStageBindingDefinition = catalog.get_binding(
		&"layer_1_lysandra_opening_hollow_servant",
		&"opening_servant_corridor"
	)
	var chapel: CombatStageBindingDefinition = catalog.get_binding(
		&"layer_1_seraphine_ruined_chapel",
		&"ruined_chapel"
	)
	var dining: CombatStageBindingDefinition = catalog.get_binding(
		&"layer_1_dining_service_hall",
		&"dining_service_hall"
	)
	_expect(
		opening != null
		and opening.trigger_type == &"route"
		and opening.return_target == &"layer_1_map",
		"Opening should retain its route-to-map lifecycle."
	)
	_expect(
		chapel != null
		and chapel.trigger_type == &"dialogue_result"
		and chapel.return_target == &"seraphine_recruitment_aftermath",
		"Ruined Chapel should preserve dialogue-result entry and aftermath return."
	)
	_expect(
		dining != null
		and dining.trigger_type == &"interaction"
		and dining.trigger_id == &"dining_service_hall_battle_route"
		and dining.return_target == &"layer_1_map",
		"Dining Service Hall should use its authored exploration interaction."
	)
	var butler: CombatStageBindingDefinition = catalog.get_binding(
			&"layer_1_corrupted_butler_opening",
			&"lower_kitchen"
		)
	_expect(
		butler != null
		and butler.exploration_room_id == &"lower_kitchen"
		and butler.battlefield_id == &"lower_kitchen"
		and butler.return_target == &"mira_recruitment_aftermath",
		"The Corrupted Butler should use the Lower Kitchen field and retain its Mira aftermath."
	)


func _test_interaction_once_only() -> void:
	var binding: CombatStageBindingDefinition = _make_binding(&"interaction")
	var state := ExplorationStageTriggerState.new()
	_expect(state.configure(binding).is_empty(), "Interaction trigger should configure.")
	_expect(
		state.activate(&"interaction"),
		"The matching interaction should fire the battle once."
	)
	_expect(
		not state.activate(&"interaction") and state.fired,
		"A fired interaction must not launch a duplicate battle."
	)


func _test_delayed_trigger_and_cancellation() -> void:
	var binding: CombatStageBindingDefinition = _make_binding(&"delayed_on_enter")
	binding.delay_seconds = 0.5
	var state := ExplorationStageTriggerState.new()
	state.configure(binding)
	_expect(
		not state.advance_delayed(0.2)
		and state.advance_delayed(0.3)
		and state.fired,
		"A delayed-on-enter trigger should fire once at its authored duration."
	)
	var cancellation_flags: Array[Array] = [
		[true, false, false, false],
		[false, true, false, false],
		[false, false, true, false],
		[false, false, false, true],
	]
	for flags: Array in cancellation_flags:
		var cancelled := ExplorationStageTriggerState.new()
		cancelled.configure(binding)
		_expect(
			not cancelled.advance_delayed(
				0.6,
				bool(flags[0]),
				bool(flags[1]),
				bool(flags[2]),
				bool(flags[3])
			)
			and cancelled.cancelled
			and not cancelled.fired,
			"Resolved, exited, dialogue, and mode-change cancellation must win over delay."
		)


func _test_restored_resolution_does_not_replay() -> void:
	var binding: CombatStageBindingDefinition = _make_binding(&"route")
	var restored := ExplorationStageTriggerState.new()
	_expect(
		restored.configure(binding, true).is_empty()
		and restored.fired
		and not restored.armed
		and not restored.activate(&"route"),
		"Restored fired state should never replay a completed encounter."
	)


func _make_binding(trigger_type: StringName) -> CombatStageBindingDefinition:
	var binding := CombatStageBindingDefinition.new()
	binding.binding_id = &"test_binding"
	binding.exploration_room_id = &"test_room"
	binding.trigger_id = &"test_trigger"
	binding.encounter_id = &"test_encounter"
	binding.combat_stage_id = &"test_stage"
	binding.battlefield_id = &"test_battlefield"
	binding.trigger_type = trigger_type
	binding.completion_state_id = &"test_complete"
	binding.return_target = &"test_room_aftermath"
	return binding


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
