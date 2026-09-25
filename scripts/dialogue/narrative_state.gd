class_name NarrativeState
extends RefCounted


var recruited_heroine_ids: Array[StringName] = [&"lysandra"]
var choice_ids: Array[StringName] = []
var resolved_interaction_ids: Array[StringName] = []
var flags_by_scope: Dictionary = {
	&"run": {},
	&"save": {},
	&"persistent": {},
}
var dialogue_sessions: Dictionary = {}
var pending_story_requests: Array[Dictionary] = []
var campaign_item_ids: Array[StringName] = []


func apply_dialogue_result_snapshot(
	snapshot: Dictionary,
	dialogue_catalog: DialogueCatalogDefinition = null
) -> String:
	var dialogue_id := StringName(snapshot.get("dialogue_id", ""))
	if dialogue_id == &"":
		return "Dialogue result has no dialogue_id."
	if (
		dialogue_catalog != null
		and dialogue_catalog.get_dialogue(dialogue_id) == null
	):
		return "Dialogue result references an unknown production graph."
	var outcome_values: Variant = snapshot.get("outcomes", [])
	if not (outcome_values is Array):
		return "Dialogue result outcomes are invalid."
	var session_value: Variant = snapshot.get("session_snapshot", {})
	if not (session_value is Dictionary):
		return "Dialogue result session snapshot is invalid."
	if not (session_value as Dictionary).is_empty():
		var session_error: String = DialogueSessionState.validate_snapshot(
			session_value as Dictionary,
			dialogue_id
		)
		if not session_error.is_empty():
			return session_error

	for outcome_value: Variant in (outcome_values as Array):
		if not (outcome_value is Dictionary):
			return "Dialogue result contains an invalid outcome."
		var outcome := outcome_value as Dictionary
		var kind := int(outcome.get("kind", -1))
		var subject_id := StringName(outcome.get("subject_id", ""))
		if kind < 0 or kind > DialogueOutcomeDefinition.Kind.GRANT_CAMPAIGN_ITEM:
			return "Dialogue result contains an unknown outcome kind."
		if (
			kind not in [
				DialogueOutcomeDefinition.Kind.GRANT_BLOOM,
				DialogueOutcomeDefinition.Kind.RETURN_TO_EXPLORATION,
			]
			and subject_id == &""
		):
			return "Dialogue result contains an outcome without a subject_id."
		if kind == DialogueOutcomeDefinition.Kind.SET_FLAG:
			var scope := StringName(outcome.get("scope", "run"))
			if scope not in [&"run", &"save", &"persistent"]:
				return "Dialogue result contains an invalid flag scope."

	var staged_recruited_ids: Array[StringName] = recruited_heroine_ids.duplicate()
	var staged_choice_ids: Array[StringName] = choice_ids.duplicate()
	var staged_interaction_ids: Array[StringName] = (
		resolved_interaction_ids.duplicate()
	)
	var staged_flags: Dictionary = flags_by_scope.duplicate(true)
	var staged_sessions: Dictionary = dialogue_sessions.duplicate(true)
	var staged_requests: Array[Dictionary] = []
	for request: Dictionary in pending_story_requests:
		staged_requests.append(request.duplicate(true))
	var staged_campaign_items: Array[StringName] = campaign_item_ids.duplicate()

	for outcome_value: Variant in (outcome_values as Array):
		var outcome := outcome_value as Dictionary
		var kind := int(outcome.get("kind", -1))
		var subject_id := StringName(outcome.get("subject_id", ""))
		match kind:
			DialogueOutcomeDefinition.Kind.SET_FLAG:
				var scope := StringName(outcome.get("scope", "run"))
				var flags: Dictionary = (
					staged_flags.get(scope, {}) as Dictionary
				).duplicate(true)
				flags[subject_id] = bool(
					outcome.get("boolean_value", true)
				)
				staged_flags[scope] = flags
			DialogueOutcomeDefinition.Kind.RECORD_CHOICE:
				_append_unique(staged_choice_ids, subject_id)
			DialogueOutcomeDefinition.Kind.RESOLVE_INTERACTION:
				_append_unique(staged_interaction_ids, subject_id)
			DialogueOutcomeDefinition.Kind.RECRUIT_HEROINE:
				_append_unique(staged_recruited_ids, subject_id)
			DialogueOutcomeDefinition.Kind.START_BATTLE, DialogueOutcomeDefinition.Kind.REQUEST_SCENE:
				staged_requests.append(outcome.duplicate(true))
			DialogueOutcomeDefinition.Kind.GRANT_CAMPAIGN_ITEM:
				_append_unique(staged_campaign_items, subject_id)

	var selected_choice_id := StringName(
		snapshot.get("selected_choice_id", "")
	)
	if selected_choice_id != &"":
		_append_unique(staged_choice_ids, selected_choice_id)

	var session_snapshot: Dictionary = session_value as Dictionary
	if not session_snapshot.is_empty():
		staged_sessions[dialogue_id] = session_snapshot.duplicate(true)

	# Commit only after the complete result, including its session snapshot,
	# has validated. A malformed result cannot partially change campaign state.
	recruited_heroine_ids = staged_recruited_ids
	choice_ids = staged_choice_ids
	resolved_interaction_ids = staged_interaction_ids
	flags_by_scope = staged_flags
	dialogue_sessions = staged_sessions
	pending_story_requests = staged_requests
	campaign_item_ids = staged_campaign_items

	return ""


func store_dialogue_session(state: DialogueSessionState) -> void:
	if state == null or state.dialogue_id == &"":
		return
	dialogue_sessions[state.dialogue_id] = state.to_snapshot()


func get_dialogue_session(dialogue_id: StringName) -> DialogueSessionState:
	var snapshot: Dictionary = dialogue_sessions.get(
		dialogue_id,
		{}
	) as Dictionary
	if snapshot.is_empty():
		return null
	return DialogueSessionState.from_snapshot(snapshot)


func has_campaign_item(item_id: StringName) -> bool:
	return item_id != &"" and campaign_item_ids.has(item_id)


func to_snapshot() -> Dictionary:
	return {
		"recruited_heroine_ids": _strings(recruited_heroine_ids),
		"choice_ids": _strings(choice_ids),
		"resolved_interaction_ids": _strings(resolved_interaction_ids),
		"flags_by_scope": flags_by_scope.duplicate(true),
		"dialogue_sessions": dialogue_sessions.duplicate(true),
		"pending_story_requests": pending_story_requests.duplicate(true),
		"campaign_item_ids": _strings(campaign_item_ids),
	}


static func from_snapshot(
	snapshot: Dictionary,
	dialogue_catalog: DialogueCatalogDefinition = null
) -> NarrativeState:
	var state: NarrativeState = NarrativeState.new()
	var restore_error: String = state.restore_from_snapshot(
		snapshot,
		dialogue_catalog
	)
	if not restore_error.is_empty():
		push_error(restore_error)
	return state


func restore_from_snapshot(
	snapshot: Dictionary,
	dialogue_catalog: DialogueCatalogDefinition = null
) -> String:
	var recruited_values: Variant = snapshot.get(
		"recruited_heroine_ids",
		[&"lysandra"]
	)
	var choice_values: Variant = snapshot.get("choice_ids", [])
	var interaction_values: Variant = snapshot.get(
		"resolved_interaction_ids",
		[]
	)
	var scoped_flag_values: Variant = snapshot.get(
		"flags_by_scope",
		{}
	)
	var session_values: Variant = snapshot.get("dialogue_sessions", {})
	var request_values: Variant = snapshot.get(
		"pending_story_requests",
		[]
	)
	var campaign_item_values: Variant = snapshot.get("campaign_item_ids", [])

	if not (recruited_values is Array):
		return "Narrative snapshot recruited heroines are invalid."
	if not (choice_values is Array):
		return "Narrative snapshot choices are invalid."
	if not (interaction_values is Array):
		return "Narrative snapshot interactions are invalid."
	if not (scoped_flag_values is Dictionary):
		return "Narrative snapshot scoped flags are invalid."
	if not (session_values is Dictionary):
		return "Narrative snapshot dialogue sessions are invalid."
	if not (request_values is Array):
		return "Narrative snapshot story requests are invalid."
	if not (campaign_item_values is Array):
		return "Narrative snapshot campaign items are invalid."

	var restored_recruited_ids: Array[StringName] = _name_array(
		recruited_values as Array
	)
	if not restored_recruited_ids.has(&"lysandra"):
		return "Narrative snapshot must retain Lysandra."

	var stored_flags: Dictionary = (
		scoped_flag_values as Dictionary
	).duplicate(true)
	var restored_flags: Dictionary = {}
	for scope: StringName in [&"run", &"save", &"persistent"]:
		var scope_value: Variant = stored_flags.get(
			scope,
			stored_flags.get(String(scope), {})
		)
		if not (scope_value is Dictionary):
			return "Narrative snapshot contains invalid scoped flag data."
		var normalized_scope: Dictionary = {}
		for flag_key: Variant in (scope_value as Dictionary).keys():
			normalized_scope[StringName(flag_key)] = bool(
				(scope_value as Dictionary)[flag_key]
			)
		restored_flags[scope] = normalized_scope

	var restored_sessions: Dictionary = {}
	for session_key: Variant in (session_values as Dictionary).keys():
		var session_value: Variant = (session_values as Dictionary)[session_key]
		if not (session_value is Dictionary):
			return "Narrative snapshot contains invalid dialogue session data."
		var session_id := StringName(session_key)
		if dialogue_catalog != null and dialogue_catalog.get_dialogue(session_id) == null:
			return "Narrative snapshot references an unknown production dialogue."
		var session_error: String = DialogueSessionState.validate_snapshot(
			session_value as Dictionary,
			session_id
		)
		if not session_error.is_empty():
			return session_error
		restored_sessions[session_id] = (
			(session_value as Dictionary).duplicate(true)
		)

	var restored_requests: Array[Dictionary] = []
	for request_value: Variant in (request_values as Array):
		if not (request_value is Dictionary):
			return "Narrative snapshot contains an invalid story request."
		restored_requests.append(
			(request_value as Dictionary).duplicate(true)
		)
	var restored_campaign_items: Array[StringName] = []
	for campaign_item_value: Variant in (campaign_item_values as Array):
		if not (campaign_item_value is String or campaign_item_value is StringName):
			return "Narrative snapshot contains an invalid campaign item ID."
		var campaign_item_id := StringName(campaign_item_value)
		if campaign_item_id == &"":
			return "Narrative snapshot contains an empty campaign item ID."
		_append_unique(restored_campaign_items, campaign_item_id)

	# Commit only after the entire snapshot has been validated. The object
	# remains usable even when malformed recovery data is rejected.
	recruited_heroine_ids = restored_recruited_ids
	choice_ids = _name_array(choice_values as Array)
	resolved_interaction_ids = _name_array(interaction_values as Array)
	flags_by_scope = restored_flags
	dialogue_sessions = restored_sessions
	pending_story_requests = restored_requests
	campaign_item_ids = restored_campaign_items
	return ""


static func _append_unique(
	values: Array[StringName],
	value: StringName
) -> void:
	if value != &"" and not values.has(value):
		values.append(value)


static func _name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(value))
	return result


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
