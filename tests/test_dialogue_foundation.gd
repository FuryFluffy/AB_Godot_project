extends SceneTree


const TEST_DIALOGUE: DialogueDefinition = preload(
	"res://data/dialogue/dialogue_foundation_test.tres"
)


var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_shared_exploration_hud_scene()
	_test_definition_and_branching()
	_test_party_dependent_choice()
	_test_condition_composition()
	_test_entry_outcomes_and_automatic_transitions()
	_test_session_and_narrative_persistence()
	_test_pending_story_request_restoration()
	if failures.is_empty():
		print("Dialogue foundation regression tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _test_shared_exploration_hud_scene() -> void:
	var packed := load(
		"res://scenes/exploration/event_room_screen.tscn"
	) as PackedScene
	_expect(packed != null, "Event-room screen should load with the shared HUD.")
	if packed == null:
		return
	var screen := packed.instantiate() as EventRoomScreen
	root.add_child(screen)
	await process_frame
	var hud := screen.get_node_or_null("ExplorationHUD") as ExplorationHUD
	_expect(hud != null, "Event-room screen should instance ExplorationHUD.")
	_expect(
		hud != null
		and hud.item_bar is ItemBarView
		and hud.dialogue_panel is DialoguePanel
		and hud.command_bar is ExplorationCommandBarView,
		"Shared HUD should own items, dialogue, and exploration commands."
	)
	if hud != null and hud.dialogue_panel != null:
		var frame := hud.dialogue_panel.get_node_or_null(
			"Frame"
		) as PanelContainer
		_expect(
			frame != null
			and is_equal_approx(frame.anchor_top, 1.0)
			and is_equal_approx(frame.anchor_bottom, 1.0)
			and frame.offset_top >= -260.0
			and frame.offset_bottom <= -20.0,
			"Dialogue text and choices must stay inside a compact bottom frame."
		)
		_expect(
			hud.dialogue_panel.left_actor is TextureRect
			and hud.dialogue_panel.right_actor is TextureRect,
			"Dialogue presentation should provide two independent actor stages."
		)
	screen.queue_free()
	await process_frame


func _test_definition_and_branching() -> void:
	_expect(
		TEST_DIALOGUE.validate_definition().is_empty(),
		"The authored dialogue test graph should validate."
	)
	var context := _make_context([&"lysandra"])
	var runner := DialogueRunner.new()
	_expect(
		runner.start(TEST_DIALOGUE, context).is_empty(),
		"Dialogue runner should start the authored graph."
	)
	var choices: Array[Dictionary] = runner.get_presented_choices()
	_expect(choices.size() == 2, "Unavailable disabled choice should remain visible.")
	_expect(bool(choices[0].get("available", false)), "Unconditional choice should be available.")
	_expect(not bool(choices[1].get("available", true)), "Mira choice should be disabled when absent.")

	var choice_result: DialogueResult = runner.choose(&"dialogue_test_calm")
	_expect(choice_result.current_node_id == &"item_gate", "Choice should enter the item gate.")
	_expect(context.choice_ids.has(&"dialogue_test_calm"), "Choice should update the live context.")
	var wrong_item: DialogueResult = runner.select_item(&"l01_bandage_roll")
	_expect(wrong_item.selected_item_id == &"", "Ineligible item should not advance dialogue.")
	var item_result: DialogueResult = runner.select_item(&"l01_warm_wine_flask")
	_expect(item_result.selected_item_id == &"l01_warm_wine_flask", "Eligible item should resolve the gate.")
	_expect(item_result.current_node_id == &"rejoin", "Item route should reach the shared rejoin node.")
	_expect(context.get_item_quantity(&"l01_warm_wine_flask") == 1, "Item outcome should consume one flask in context.")
	_expect(context.get_flag(&"run", &"dialogue_test_wine_offered"), "Item outcome should set its run flag.")
	runner.advance()
	_expect(runner.session.current_node_id == &"end", "Rejoin node should advance to the ending.")
	var completed: DialogueResult = runner.advance()
	_expect(completed.completed, "Ending should complete the dialogue.")


func _test_party_dependent_choice() -> void:
	var context := _make_context([&"lysandra", &"mira"])
	var runner := DialogueRunner.new()
	runner.start(TEST_DIALOGUE, context)
	var choices: Array[Dictionary] = runner.get_presented_choices()
	_expect(bool(choices[1].get("available", false)), "Mira choice should unlock when Mira is in the current party.")
	var result: DialogueResult = runner.choose(&"dialogue_test_mira")
	_expect(result.current_node_id == &"item_gate", "Mira branch should rejoin at the same item gate.")


func _test_condition_composition() -> void:
	var context := _make_context([&"lysandra"])
	context.present_actor_ids = [&"lysandra", &"mira"]
	var party_condition := DialogueConditionDefinition.new()
	party_condition.kind = DialogueConditionDefinition.Kind.PARTY_CONTAINS
	party_condition.subject_id = &"lysandra"
	var actor_condition := DialogueConditionDefinition.new()
	actor_condition.kind = DialogueConditionDefinition.Kind.ACTOR_PRESENT
	actor_condition.subject_id = &"mira"
	var all_group := DialogueConditionGroup.new()
	all_group.conditions.append(party_condition)
	all_group.conditions.append(actor_condition)
	_expect(all_group.evaluate(context), "ALL group should require both true conditions.")
	var not_group := DialogueConditionGroup.new()
	not_group.mode = DialogueConditionGroup.Mode.NOT
	not_group.conditions.append(actor_condition)
	_expect(not not_group.evaluate(context), "NOT group should invert its single child.")


func _test_entry_outcomes_and_automatic_transitions() -> void:
	var entry_flag := DialogueOutcomeDefinition.new()
	entry_flag.kind = DialogueOutcomeDefinition.Kind.SET_FLAG
	entry_flag.scope = &"run"
	entry_flag.subject_id = &"automatic_route_ready"

	var flag_condition := DialogueConditionDefinition.new()
	flag_condition.kind = DialogueConditionDefinition.Kind.FLAG_SET
	flag_condition.scope = &"run"
	flag_condition.subject_id = &"automatic_route_ready"
	var flag_group := DialogueConditionGroup.new()
	flag_group.conditions.append(flag_condition)

	var conditional_transition := (
		DialogueAutomaticTransitionDefinition.new()
	)
	conditional_transition.transition_id = &"take_flagged_route"
	conditional_transition.conditions = flag_group
	conditional_transition.next_node_id = &"flagged"

	var fallback_transition := DialogueAutomaticTransitionDefinition.new()
	fallback_transition.transition_id = &"take_fallback_route"
	fallback_transition.next_node_id = &"fallback"

	var routing_node := DialogueNodeDefinition.new()
	routing_node.node_id = &"route"
	routing_node.text = "Choose a route automatically."
	routing_node.entry_outcomes.append(entry_flag)
	routing_node.automatic_transitions.append(conditional_transition)
	routing_node.automatic_transitions.append(fallback_transition)

	var flagged_node := DialogueNodeDefinition.new()
	flagged_node.node_id = &"flagged"
	flagged_node.text = "The entry flag selected this line."
	var fallback_node := DialogueNodeDefinition.new()
	fallback_node.node_id = &"fallback"
	fallback_node.text = "The fallback line was selected."

	var definition := DialogueDefinition.new()
	definition.dialogue_id = &"automatic_transition_test"
	definition.start_node_id = &"route"
	definition.nodes = [routing_node, flagged_node, fallback_node]
	_expect(
		definition.validate_definition().is_empty(),
		"Entry outcomes and automatic-transition routes should validate."
	)

	var context := _make_context([&"lysandra"])
	var runner := DialogueRunner.new()
	_expect(
		runner.start(definition, context).is_empty(),
		"Automatic-transition dialogue should start without an error."
	)
	var start_result: DialogueResult = (
		runner.consume_pending_transition_result()
	)
	_expect(
		context.get_flag(&"run", &"automatic_route_ready")
		and runner.session.current_node_id == &"flagged"
		and start_result.outcomes.size() == 1
		and start_result.automatic_transition_ids
		== [&"take_flagged_route"],
		(
			"Node-entry outcomes must apply before the first matching "
			+ "automatic transition is selected."
		)
	)

	var restored := DialogueSessionState.from_snapshot(
		runner.session.to_snapshot()
	)
	restored.current_node_id = &"route"
	restored.completed = false
	var restored_context := _make_context([&"lysandra"])
	var restored_runner := DialogueRunner.new()
	_expect(
		restored_runner.start(
			definition,
			restored_context,
			restored
		).is_empty(),
		"A restored automatic-transition session should remain valid."
	)
	var restored_result: DialogueResult = (
		restored_runner.consume_pending_transition_result()
	)
	_expect(
		not restored_context.get_flag(
			&"run",
			&"automatic_route_ready"
		)
		and restored_runner.session.current_node_id == &"fallback"
		and restored_result.outcomes.is_empty()
		and restored_result.automatic_transition_ids
		== [&"take_fallback_route"],
		(
			"Once-per-session entry outcomes must not replay after a "
			+ "session restore."
		)
	)


func _test_session_and_narrative_persistence() -> void:
	var context := _make_context([&"lysandra"])
	var runner := DialogueRunner.new()
	runner.start(TEST_DIALOGUE, context)
	var choice_result: DialogueResult = runner.choose(&"dialogue_test_calm")
	var state_snapshot: Dictionary = runner.session.to_snapshot()
	var restored := DialogueSessionState.from_snapshot(state_snapshot)
	_expect(restored.current_node_id == &"item_gate", "Session should restore its stable current node ID.")

	var narrative := NarrativeState.new()
	var apply_error: String = narrative.apply_dialogue_result_snapshot(
		choice_result.to_snapshot()
	)
	_expect(apply_error.is_empty(), "Narrative state should accept a dialogue result snapshot.")
	_expect(narrative.choice_ids.has(&"dialogue_test_calm"), "Narrative state should persist selected choice IDs.")
	var restored_narrative := NarrativeState.from_snapshot(narrative.to_snapshot())
	_expect(restored_narrative.recruited_heroine_ids.has(&"lysandra"), "Narrative snapshot should retain recruitment state.")


func _test_pending_story_request_restoration() -> void:
	var narrative := NarrativeState.new()
	narrative.pending_story_requests.append({
		"kind": DialogueOutcomeDefinition.Kind.REQUEST_SCENE,
		"subject_id": "existing_request",
	})
	var empty_snapshot: Dictionary = narrative.to_snapshot()
	empty_snapshot["pending_story_requests"] = []
	var empty_error: String = narrative.restore_from_snapshot(empty_snapshot)
	_expect(
		empty_error.is_empty()
		and narrative.pending_story_requests.is_empty(),
		"An empty pending-story-request array should restore successfully."
	)

	var valid_requests: Array = [
		{
			"kind": DialogueOutcomeDefinition.Kind.REQUEST_SCENE,
			"subject_id": "first_request",
			"payload": {"room_id": "first_room"},
		},
		{
			"kind": DialogueOutcomeDefinition.Kind.START_BATTLE,
			"subject_id": "second_request",
		},
	]
	var valid_snapshot: Dictionary = narrative.to_snapshot()
	valid_snapshot["pending_story_requests"] = valid_requests
	var valid_error: String = narrative.restore_from_snapshot(valid_snapshot)
	(valid_requests[0] as Dictionary)["subject_id"] = "mutated_request"
	var source_payload: Dictionary = (
		(valid_requests[0] as Dictionary).get("payload", {}) as Dictionary
	)
	source_payload["room_id"] = "mutated_room"
	var restored_payload: Dictionary = narrative.pending_story_requests[0].get(
		"payload",
		{}
	) as Dictionary
	_expect(
		valid_error.is_empty()
		and narrative.pending_story_requests.size() == 2
		and String(narrative.pending_story_requests[0].get(
			"subject_id",
			""
		)) == "first_request"
		and String(restored_payload.get("room_id", "")) == "first_room",
		"Valid pending story requests should restore as deep-owned dictionaries."
	)

	narrative.choice_ids.append(&"preserved_choice")
	var state_before_error: Dictionary = narrative.to_snapshot()
	var malformed_snapshot: Dictionary = state_before_error.duplicate(true)
	malformed_snapshot["choice_ids"] = ["replacement_choice"]
	malformed_snapshot["pending_story_requests"] = [
		{"subject_id": "valid_before_error"},
		42,
	]
	var malformed_error: String = narrative.restore_from_snapshot(
		malformed_snapshot
	)
	_expect(
		malformed_error
		== "Narrative snapshot contains an invalid story request.",
		"A non-Dictionary pending story request should be rejected."
	)
	_expect(
		narrative.to_snapshot() == state_before_error,
		"Rejected story-request restoration must leave narrative state unchanged."
	)


func _make_context(party: Array[StringName]) -> DialogueContext:
	var context := DialogueContext.new()
	context.current_party_ids = party.duplicate()
	context.present_actor_ids = party.duplicate()
	context.recruited_heroine_ids = party.duplicate()
	context.inventory_quantities = {
		&"l01_warm_wine_flask": 2,
		&"l01_bandage_roll": 3,
	}
	return context


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
