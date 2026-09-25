@tool
class_name DialogueDefinition
extends Resource


@export var dialogue_id: StringName
@export var start_node_id: StringName
@export_group("Production Binding")
@export var trigger_kind: StringName
@export var trigger_id: StringName
@export var completion_kind: StringName
@export var completion_id: StringName
@export var completion_scope: StringName = &"run"
@export_group("Presentation")
@export var background_override: Texture2D
@export_group("Graph")
@export var nodes: Array[DialogueNodeDefinition] = []


func get_node_definition(node_id: StringName) -> DialogueNodeDefinition:
	for node: DialogueNodeDefinition in nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


func validate_definition() -> String:
	if dialogue_id == &"":
		return "A DialogueDefinition has no dialogue_id."
	if start_node_id == &"":
		return "Dialogue '%s' has no start_node_id." % dialogue_id
	if nodes.is_empty():
		return "Dialogue '%s' has no nodes." % dialogue_id
	var has_production_binding: bool = (
		trigger_kind != &""
		or trigger_id != &""
		or completion_kind != &""
		or completion_id != &""
	)
	if has_production_binding and trigger_kind not in [
		&"development",
		&"encounter_prelude",
		&"encounter_aftermath",
		&"encounter_victory",
		&"refugeless_defeat",
		&"map_arrival",
		&"event_room_entry",
	]:
		return "Dialogue '%s' has an invalid trigger_kind." % dialogue_id
	if has_production_binding and trigger_id == &"":
		return "Dialogue '%s' has no trigger_id." % dialogue_id
	if has_production_binding and completion_kind not in [
		&"development",
		&"resolved_interaction",
		&"flag",
		&"recruited",
		&"choice",
	]:
		return "Dialogue '%s' has an invalid completion_kind." % dialogue_id
	if has_production_binding and completion_id == &"":
		return "Dialogue '%s' has no completion_id." % dialogue_id
	if has_production_binding and completion_kind == &"flag" and completion_scope not in [
		&"run",
		&"save",
		&"persistent",
	]:
		return "Dialogue '%s' has an invalid completion scope." % dialogue_id

	var ids: Dictionary = {}
	for node: DialogueNodeDefinition in nodes:
		if node == null:
			return "Dialogue '%s' contains a null node." % dialogue_id
		var node_error: String = node.validate_definition()
		if not node_error.is_empty():
			return node_error
		if ids.has(node.node_id):
			return "Dialogue '%s' repeats node '%s'." % [
				dialogue_id,
				node.node_id,
			]
		ids[node.node_id] = true

	if not ids.has(start_node_id):
		return "Dialogue '%s' cannot find its start node." % dialogue_id

	for node: DialogueNodeDefinition in nodes:
		var destinations: Array[StringName] = []
		if node.default_next_node_id != &"":
			destinations.append(node.default_next_node_id)
		for choice: DialogueChoiceDefinition in node.choices:
			if choice.next_node_id != &"":
				destinations.append(choice.next_node_id)
		for option: DialogueItemOptionDefinition in node.item_options:
			if option.next_node_id != &"":
				destinations.append(option.next_node_id)
		for transition: DialogueAutomaticTransitionDefinition in (
			node.automatic_transitions
		):
			if transition.next_node_id != &"":
				destinations.append(transition.next_node_id)
		for destination: StringName in destinations:
			if not ids.has(destination):
				return "Dialogue node '%s' points to missing node '%s'." % [
					node.node_id,
					destination,
				]

	if (
		has_production_binding
		and completion_kind != &"development"
		and not _authors_completion()
	):
		return (
			"Dialogue '%s' does not author its declared completion '%s'."
			% [dialogue_id, completion_id]
		)

	return ""


func matches_trigger(
	expected_kind: StringName,
	expected_id: StringName
) -> bool:
	return trigger_kind == expected_kind and trigger_id == expected_id


func is_completed(context: DialogueContext) -> bool:
	if context == null:
		return false
	match completion_kind:
		&"resolved_interaction":
			return context.resolved_interaction_ids.has(completion_id)
		&"flag":
			return context.get_flag(completion_scope, completion_id)
		&"recruited":
			return context.recruited_heroine_ids.has(completion_id)
		&"choice":
			return context.choice_ids.has(completion_id)
		&"development":
			return false
	return false


func _authors_completion() -> bool:
	for node: DialogueNodeDefinition in nodes:
		if node == null:
			continue
		if _outcomes_author_completion(node.entry_outcomes):
			return true
		for transition: DialogueAutomaticTransitionDefinition in node.automatic_transitions:
			if transition != null and _outcomes_author_completion(transition.outcomes):
				return true
		for choice: DialogueChoiceDefinition in node.choices:
			if choice == null:
				continue
			if completion_kind == &"choice" and choice.choice_id == completion_id:
				return true
			if _outcomes_author_completion(choice.outcomes):
				return true
		for option: DialogueItemOptionDefinition in node.item_options:
			if option != null and _outcomes_author_completion(option.outcomes):
				return true
	return false


func _outcomes_author_completion(
	outcomes: Array[DialogueOutcomeDefinition]
) -> bool:
	for outcome: DialogueOutcomeDefinition in outcomes:
		if outcome == null or outcome.subject_id != completion_id:
			continue
		match completion_kind:
			&"resolved_interaction":
				if outcome.kind == DialogueOutcomeDefinition.Kind.RESOLVE_INTERACTION:
					return true
			&"flag":
				if (
					outcome.kind == DialogueOutcomeDefinition.Kind.SET_FLAG
					and outcome.scope == completion_scope
					and outcome.boolean_value
				):
					return true
			&"recruited":
				if outcome.kind == DialogueOutcomeDefinition.Kind.RECRUIT_HEROINE:
					return true
	return false
