class_name DialogueRunner
extends RefCounted


var definition: DialogueDefinition
var context: DialogueContext
var session: DialogueSessionState
var last_error: String = ""

var _pending_outcomes: Array[DialogueOutcomeDefinition] = []
var _pending_entered_node_ids: Array[StringName] = []
var _pending_automatic_transition_ids: Array[StringName] = []


func start(
	new_definition: DialogueDefinition,
	new_context: DialogueContext,
	restored_session: DialogueSessionState = null
) -> String:
	if new_definition == null:
		return "DialogueRunner received no dialogue definition."
	var definition_error: String = new_definition.validate_definition()
	if not definition_error.is_empty():
		return definition_error
	if new_context == null:
		return "DialogueRunner received no dialogue context."

	definition = new_definition
	context = new_context
	session = restored_session
	last_error = ""
	_clear_pending_transition_data()
	if session == null:
		session = DialogueSessionState.new()
		session.dialogue_id = definition.dialogue_id
		session.current_node_id = definition.start_node_id
	else:
		if session.dialogue_id != definition.dialogue_id:
			return "Restored dialogue session has the wrong dialogue_id."
		if definition.get_node_definition(session.current_node_id) == null:
			return "Restored dialogue session points to a missing node."

	_enter_current_node_and_resolve_automatic_transitions()
	return last_error


func get_current_node() -> DialogueNodeDefinition:
	if definition == null or session == null or session.completed:
		return null
	return definition.get_node_definition(session.current_node_id)


func get_presented_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var node: DialogueNodeDefinition = get_current_node()
	if node == null:
		return result

	for choice: DialogueChoiceDefinition in node.choices:
		var available: bool = choice.is_available(context)
		if (
			not available
			and choice.failed_condition_presentation
			== DialogueChoiceDefinition.FailedConditionPresentation.HIDE
		):
			continue
		result.append({
			"choice": choice,
			"available": available,
			"reason": "" if available else choice.unavailable_reason,
		})

	return result


func consume_pending_transition_result() -> DialogueResult:
	var result := _make_result()
	_append_pending_transition_data(result)
	_sync_result(result)
	return result


func advance() -> DialogueResult:
	var result := _make_result()
	var node: DialogueNodeDefinition = get_current_node()
	if node == null:
		result.completed = true
		_append_pending_transition_data(result)
		_sync_result(result)
		return result
	if not node.choices.is_empty():
		_append_pending_transition_data(result)
		_sync_result(result)
		return result
	if node.item_policy == DialogueNodeDefinition.ItemPolicy.REQUIRED_ITEM:
		_append_pending_transition_data(result)
		_sync_result(result)
		return result
	_transition_to(node.default_next_node_id)
	_append_pending_transition_data(result)
	_sync_result(result)
	return result


func choose(choice_id: StringName) -> DialogueResult:
	var result := _make_result()
	var node: DialogueNodeDefinition = get_current_node()
	if node == null:
		result.completed = true
		_append_pending_transition_data(result)
		_sync_result(result)
		return result

	for entry: Dictionary in get_presented_choices():
		var choice := entry.get("choice") as DialogueChoiceDefinition
		if choice == null or choice.choice_id != choice_id:
			continue
		if not bool(entry.get("available", false)):
			_append_pending_transition_data(result)
			_sync_result(result)
			return result
		result.selected_choice_id = choice.choice_id
		result.append_outcomes(choice.outcomes)
		_apply_outcomes(choice.outcomes)
		_record_choice(choice.choice_id)
		_transition_to(choice.next_node_id)
		_append_pending_transition_data(result)
		_sync_result(result)
		return result

	_append_pending_transition_data(result)
	_sync_result(result)
	return result


func select_item(
	item_id: StringName,
	target_heroine_id: StringName = &""
) -> DialogueResult:
	var result := _make_result()
	var node: DialogueNodeDefinition = get_current_node()
	if node == null:
		result.completed = true
		_append_pending_transition_data(result)
		_sync_result(result)
		return result
	if node.item_policy not in [
		DialogueNodeDefinition.ItemPolicy.DIALOGUE_ITEMS,
		DialogueNodeDefinition.ItemPolicy.REQUIRED_ITEM,
	]:
		_append_pending_transition_data(result)
		_sync_result(result)
		return result
	if context.get_item_quantity(item_id) <= 0:
		_append_pending_transition_data(result)
		_sync_result(result)
		return result

	for option: DialogueItemOptionDefinition in node.item_options:
		if option.item_id != item_id:
			continue
		if (
			option.target_heroine_id != &""
			and option.target_heroine_id != target_heroine_id
		):
			continue
		result.selected_item_id = item_id
		result.selected_target_id = target_heroine_id
		result.append_outcomes(option.outcomes)
		_apply_outcomes(option.outcomes)
		_transition_to(option.next_node_id)
		_append_pending_transition_data(result)
		_sync_result(result)
		return result

	_append_pending_transition_data(result)
	_sync_result(result)
	return result


func _make_result() -> DialogueResult:
	var result := DialogueResult.new()
	if definition != null:
		result.dialogue_id = definition.dialogue_id
	if session != null:
		result.current_node_id = session.current_node_id
		result.completed = session.completed
	result.error_message = last_error
	return result


func _sync_result(result: DialogueResult) -> void:
	if result == null or session == null:
		return
	result.current_node_id = session.current_node_id
	result.completed = session.completed
	result.session_snapshot = session.to_snapshot()
	result.error_message = last_error


func _record_choice(choice_id: StringName) -> void:
	if not session.selected_choice_ids.has(choice_id):
		session.selected_choice_ids.append(choice_id)
	if not context.choice_ids.has(choice_id):
		context.choice_ids.append(choice_id)


func _transition_to(next_node_id: StringName) -> void:
	if next_node_id == &"":
		session.current_node_id = &""
		session.completed = true
		return
	session.current_node_id = next_node_id
	_enter_current_node_and_resolve_automatic_transitions()


func _enter_current_node_and_resolve_automatic_transitions() -> void:
	var automatic_chain_node_ids: Dictionary = {}
	while session.current_node_id != &"" and not session.completed:
		if automatic_chain_node_ids.has(session.current_node_id):
			last_error = (
				"Dialogue '%s' entered an automatic-transition cycle at '%s'."
				% [definition.dialogue_id, session.current_node_id]
			)
			return
		automatic_chain_node_ids[session.current_node_id] = true

		var node: DialogueNodeDefinition = definition.get_node_definition(
			session.current_node_id
		)
		if node == null:
			last_error = (
				"Dialogue '%s' cannot enter missing node '%s'."
				% [definition.dialogue_id, session.current_node_id]
			)
			return

		_record_node_visit(node.node_id)
		_apply_node_entry_outcomes(node)
		var transition: DialogueAutomaticTransitionDefinition = (
			node.get_first_available_automatic_transition(context)
		)
		if transition == null:
			return

		if not session.triggered_automatic_transition_ids.has(
			transition.transition_id
		):
			session.triggered_automatic_transition_ids.append(
				transition.transition_id
			)
		_pending_automatic_transition_ids.append(
			transition.transition_id
		)
		_queue_outcomes(transition.outcomes)

		if transition.next_node_id == &"":
			session.current_node_id = &""
			session.completed = true
			return
		session.current_node_id = transition.next_node_id


func _record_node_visit(node_id: StringName) -> void:
	if not session.visited_node_ids.has(node_id):
		session.visited_node_ids.append(node_id)
	_pending_entered_node_ids.append(node_id)


func _apply_node_entry_outcomes(node: DialogueNodeDefinition) -> void:
	if node.entry_outcomes.is_empty():
		return
	if (
		node.apply_entry_outcomes_once_per_session
		and session.applied_entry_outcome_node_ids.has(node.node_id)
	):
		return
	_queue_outcomes(node.entry_outcomes)
	if (
		node.apply_entry_outcomes_once_per_session
		and not session.applied_entry_outcome_node_ids.has(node.node_id)
	):
		session.applied_entry_outcome_node_ids.append(node.node_id)


func _queue_outcomes(
	outcomes: Array[DialogueOutcomeDefinition]
) -> void:
	for outcome: DialogueOutcomeDefinition in outcomes:
		if outcome != null:
			_pending_outcomes.append(outcome)
	_apply_outcomes(outcomes)


func _append_pending_transition_data(result: DialogueResult) -> void:
	if result == null:
		return
	result.append_outcomes(_pending_outcomes)
	result.entered_node_ids.append_array(_pending_entered_node_ids)
	result.automatic_transition_ids.append_array(
		_pending_automatic_transition_ids
	)
	_clear_pending_transition_data()


func _clear_pending_transition_data() -> void:
	_pending_outcomes.clear()
	_pending_entered_node_ids.clear()
	_pending_automatic_transition_ids.clear()


func _apply_outcomes(
	outcomes: Array[DialogueOutcomeDefinition]
) -> void:
	for outcome: DialogueOutcomeDefinition in outcomes:
		match outcome.kind:
			DialogueOutcomeDefinition.Kind.SET_FLAG:
				context.set_flag(
					outcome.scope,
					outcome.subject_id,
					outcome.boolean_value
				)
			DialogueOutcomeDefinition.Kind.RECORD_CHOICE:
				if not context.choice_ids.has(outcome.subject_id):
					context.choice_ids.append(outcome.subject_id)
			DialogueOutcomeDefinition.Kind.ADD_ITEM:
				context.change_item_quantity(
					outcome.subject_id,
					outcome.integer_value
				)
			DialogueOutcomeDefinition.Kind.CONSUME_ITEM:
				context.change_item_quantity(
					outcome.subject_id,
					-outcome.integer_value
				)
			DialogueOutcomeDefinition.Kind.MODIFY_HEROINE_STAT:
				context.modify_heroine_stat(
					outcome.subject_id,
					outcome.key,
					outcome.integer_value
				)
			DialogueOutcomeDefinition.Kind.MODIFY_ACTIVE_PARTY_STAT:
				for heroine_id: StringName in context.current_party_ids:
					context.modify_heroine_stat(
						heroine_id,
						outcome.key,
						outcome.integer_value
					)
			DialogueOutcomeDefinition.Kind.RESTORE_ACTIVE_PARTY_FULL:
				for heroine_id: StringName in context.current_party_ids:
					var heroine_state: Dictionary = (
						context.heroine_states.get(heroine_id, {}) as Dictionary
					).duplicate(true)
					heroine_state["hp"] = int(
						heroine_state.get("max_hp", heroine_state.get("hp", 0))
					)
					heroine_state["mp"] = int(
						heroine_state.get("max_mp", heroine_state.get("mp", 0))
					)
					context.heroine_states[heroine_id] = heroine_state
			DialogueOutcomeDefinition.Kind.GRANT_BLOOM:
				context.pending_bloom += outcome.integer_value
			DialogueOutcomeDefinition.Kind.GRANT_KNOWLEDGE:
				if not context.knowledge_ids.has(outcome.subject_id):
					context.knowledge_ids.append(outcome.subject_id)
			DialogueOutcomeDefinition.Kind.RESOLVE_INTERACTION:
				if not context.resolved_interaction_ids.has(
					outcome.subject_id
				):
					context.resolved_interaction_ids.append(
						outcome.subject_id
					)
			DialogueOutcomeDefinition.Kind.RECRUIT_HEROINE:
				if not context.recruited_heroine_ids.has(
					outcome.subject_id
				):
					context.recruited_heroine_ids.append(
						outcome.subject_id
					)
				if (
					outcome.boolean_value
					and not context.current_party_ids.has(outcome.subject_id)
				):
					context.current_party_ids.append(outcome.subject_id)
			DialogueOutcomeDefinition.Kind.GRANT_CAMPAIGN_ITEM:
				if not context.campaign_item_ids.has(outcome.subject_id):
					context.campaign_item_ids.append(outcome.subject_id)
