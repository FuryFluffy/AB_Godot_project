class_name ArchiveReplaySession
extends RefCounted
## Discard-only dialogue playback. No RunState, persistence or result consumers.

var runner: DialogueRunner


static func unavailable_reason(entry: LoreEntryDefinition) -> String:
	if entry == null or entry.archive_replay == null:
		return "No scene is attached to this entry."
	var definition: DialogueDefinition = entry.archive_replay
	if not definition.validate_definition().is_empty():
		return "This scene is not available for replay."
	if not _valid_context(entry.archive_replay_context):
		return "Replay starting context has not been authored."
	for node: DialogueNodeDefinition in definition.nodes:
		# These need gameplay services that this read-only viewer cannot supply.
		if node.item_policy != DialogueNodeDefinition.ItemPolicy.DISABLED:
			return "This scene requires item interactions unavailable in replay."
		var outcomes: Array[DialogueOutcomeDefinition] = node.entry_outcomes.duplicate()
		for choice: DialogueChoiceDefinition in node.choices:
			outcomes.append_array(choice.outcomes)
		for transition: DialogueAutomaticTransitionDefinition in node.automatic_transitions:
			outcomes.append_array(transition.outcomes)
		for outcome: DialogueOutcomeDefinition in outcomes:
			if outcome.kind in [DialogueOutcomeDefinition.Kind.START_BATTLE, DialogueOutcomeDefinition.Kind.REQUEST_SCENE, DialogueOutcomeDefinition.Kind.CONSUME_ROOM_ITEM]:
				return "This scene requires gameplay transitions unavailable in replay."
	return ""


static func _valid_context(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	for key: String in ["current_party_ids", "present_actor_ids", "recruited_heroine_ids", "knowledge_ids", "choice_ids", "resolved_interaction_ids", "campaign_item_ids"]:
		if not (snapshot.get(key, []) is Array):
			return false
		for value: Variant in snapshot.get(key, []):
			if not (value is String or value is StringName):
				return false
	for key: String in ["heroine_states", "inventory_quantities", "flags_by_scope"]:
		if not (snapshot.get(key, {}) is Dictionary):
			return false
	for value: Variant in snapshot.get("heroine_states", {}).values():
		if not (value is Dictionary):
			return false
		for stat: Variant in value.values():
			if not (stat is int or stat is float or stat is bool):
				return false
	for value: Variant in snapshot.get("inventory_quantities", {}).values():
		if not (value is int or value is float):
			return false
	for value: Variant in snapshot.get("flags_by_scope", {}).values():
		if not (value is Dictionary):
			return false
	return snapshot.get("pending_bloom", 0) is int or snapshot.get("pending_bloom", 0) is float


func start(entry: LoreEntryDefinition) -> String:
	close()
	var error: String = unavailable_reason(entry)
	if not error.is_empty():
		return error
	var candidate := DialogueRunner.new()
	# Snapshot reconstruction deep-copies every mutable context collection.
	error = candidate.start(entry.archive_replay, DialogueContext.from_snapshot(entry.archive_replay_context))
	if not error.is_empty():
		return error
	runner = candidate
	# Outcomes affect only this private context, allowing authored branches to work.
	runner.consume_pending_transition_result()
	return ""


func advance() -> void:
	if runner != null:
		runner.advance() # Deliberately never publish the DialogueResult.


func choose(choice_id: StringName) -> void:
	if runner != null:
		runner.choose(choice_id)


func close() -> void:
	runner = null
