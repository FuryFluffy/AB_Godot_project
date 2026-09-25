@tool
class_name DialogueNodeDefinition
extends Resource


enum ItemPolicy {
	DISABLED,
	NORMAL_USE,
	DIALOGUE_ITEMS,
	REQUIRED_ITEM,
}


@export var node_id: StringName
@export var speaker_id: StringName
@export var speaker_name: String
@export var expression_id: StringName = &"neutral"
@export var portrait: Texture2D
@export_group("Staged Actors")
@export var left_actor_sprite: Texture2D
@export var left_actor_flip_h: bool = false
@export var right_actor_sprite: Texture2D
@export var right_actor_flip_h: bool = true
@export_group("Dialogue Flow")
@export_multiline var text: String
@export var entry_outcomes: Array[DialogueOutcomeDefinition] = []
@export var apply_entry_outcomes_once_per_session: bool = true
@export var automatic_transitions: Array[DialogueAutomaticTransitionDefinition] = []
@export var choices: Array[DialogueChoiceDefinition] = []
@export var default_next_node_id: StringName
@export var item_policy: ItemPolicy = ItemPolicy.DISABLED
@export var item_options: Array[DialogueItemOptionDefinition] = []
@export var mandatory: bool = true


func validate_definition() -> String:
	if node_id == &"":
		return "A dialogue node has no node_id."
	if text.strip_edges().is_empty():
		return "Dialogue node '%s' has no text." % node_id
	if not choices.is_empty() and default_next_node_id != &"":
		return (
			"Dialogue node '%s' has choices and a default next node."
			% node_id
		)
	if item_policy in [ItemPolicy.DIALOGUE_ITEMS, ItemPolicy.REQUIRED_ITEM]:
		if item_options.is_empty():
			return "Dialogue node '%s' has no item options." % node_id
	elif not item_options.is_empty():
		return "Dialogue node '%s' defines unused item options." % node_id

	for outcome: DialogueOutcomeDefinition in entry_outcomes:
		if outcome == null:
			return "Dialogue node '%s' contains a null entry outcome." % node_id
		var outcome_error: String = outcome.validate_definition()
		if not outcome_error.is_empty():
			return outcome_error

	var transition_ids: Dictionary = {}
	var found_unconditional_transition: bool = false
	for transition: DialogueAutomaticTransitionDefinition in (
		automatic_transitions
	):
		if transition == null:
			return (
				"Dialogue node '%s' contains a null automatic transition."
				% node_id
			)
		var transition_error: String = transition.validate_definition()
		if not transition_error.is_empty():
			return transition_error
		if found_unconditional_transition:
			return (
				"Dialogue node '%s' places automatic transition '%s' after "
				+ "an unconditional route."
			) % [node_id, transition.transition_id]
		if transition_ids.has(transition.transition_id):
			return (
				"Dialogue node '%s' repeats automatic transition '%s'."
				% [node_id, transition.transition_id]
			)
		transition_ids[transition.transition_id] = true
		found_unconditional_transition = transition.conditions == null

	var choice_ids: Dictionary = {}
	for choice: DialogueChoiceDefinition in choices:
		if choice == null:
			return "Dialogue node '%s' contains a null choice." % node_id
		var error: String = choice.validate_definition()
		if not error.is_empty():
			return error
		if choice_ids.has(choice.choice_id):
			return "Dialogue node '%s' repeats choice '%s'." % [
				node_id,
				choice.choice_id,
			]
		choice_ids[choice.choice_id] = true

	var item_ids: Dictionary = {}
	for option: DialogueItemOptionDefinition in item_options:
		if option == null:
			return "Dialogue node '%s' contains a null item option." % node_id
		var error: String = option.validate_definition()
		if not error.is_empty():
			return error
		var stable_key: String = "%s|%s" % [
			option.item_id,
			option.target_heroine_id,
		]
		if item_ids.has(stable_key):
			return "Dialogue node '%s' repeats item route '%s'." % [
				node_id,
				stable_key,
			]
		item_ids[stable_key] = true

	return ""


func get_first_available_automatic_transition(
	context: DialogueContext
) -> DialogueAutomaticTransitionDefinition:
	for transition: DialogueAutomaticTransitionDefinition in (
		automatic_transitions
	):
		if transition != null and transition.is_available(context):
			return transition
	return null
