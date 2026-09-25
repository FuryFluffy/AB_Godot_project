extends RefCounted


const JAILER_VICTORY: DialogueDefinition = preload(
	"res://data/dialogue/layer2_jailer_victory_aftermath.tres"
)
const FARTHEST_CELL: DialogueDefinition = preload(
	"res://data/dialogue/layer2_farthest_cell_refuge_establishment.tres"
)


static func make_jailer_victory_outcome(
	run: RunState,
	combat_outcome: EncounterOutcome
) -> StoryDialogueOutcome:
	var context: DialogueContext = _make_context(run)
	context.present_actor_ids.append(&"jailer")
	var results: Array[Dictionary] = _complete_linear_dialogue(
		JAILER_VICTORY,
		context
	)
	return _make_story_outcome(
		RunState.JAILER_VICTORY_STORY_ID,
		combat_outcome.source_node_id,
		combat_outcome.inventory_snapshot,
		combat_outcome.party_snapshot,
		run.get_run_inventory_snapshot(),
		results
	)


static func make_farthest_cell_outcome(run: RunState) -> StoryDialogueOutcome:
	var runner := DialogueRunner.new()
	var results: Array[Dictionary] = []
	if not runner.start(FARTHEST_CELL, _make_context(run)).is_empty():
		return null
	for _step: int in range(2):
		results.append(runner.advance().to_snapshot())
	var completion: DialogueResult = runner.choose(
		&"layer_2_farthest_cell_enter_refuge"
	)
	results.append(completion.to_snapshot())
	if not completion.completed:
		return null
	return _make_story_outcome(
		RunState.FARTHEST_CELL_REFUGE_STORY_ID,
		RunState.LAYER_2_FARTHEST_CELL_NODE_ID,
		run.inventory_snapshot,
		run.party_snapshot,
		run.get_run_inventory_snapshot(),
		results
	)


static func _complete_linear_dialogue(
	dialogue: DialogueDefinition,
	context: DialogueContext
) -> Array[Dictionary]:
	var runner := DialogueRunner.new()
	var results: Array[Dictionary] = []
	if not runner.start(dialogue, context).is_empty():
		return results
	for _step: int in range(dialogue.nodes.size() + 1):
		var result: DialogueResult = runner.advance()
		results.append(result.to_snapshot())
		if result.completed:
			return results
	return []


static func _make_context(run: RunState) -> DialogueContext:
	var context := DialogueContext.new()
	context.current_party_ids = [&"lysandra", &"mira", &"seraphine"]
	context.present_actor_ids = context.current_party_ids.duplicate()
	context.recruited_heroine_ids = context.current_party_ids.duplicate()
	context.flags_by_scope = run.narrative_state.flags_by_scope.duplicate(true)
	context.choice_ids = run.narrative_state.choice_ids.duplicate()
	context.resolved_interaction_ids = (
		run.narrative_state.resolved_interaction_ids.duplicate()
	)
	return context


static func _make_story_outcome(
	story_id: StringName,
	source_node_id: StringName,
	inventory_snapshot: Array[Dictionary],
	party_snapshot: Dictionary,
	run_inventory_snapshot: Dictionary,
	results: Array[Dictionary]
) -> StoryDialogueOutcome:
	if results.is_empty():
		return null
	var outcome := StoryDialogueOutcome.new()
	outcome.story_id = story_id
	outcome.source_node_id = source_node_id
	outcome.inventory_snapshot = inventory_snapshot.duplicate(true)
	outcome.run_inventory_snapshot = run_inventory_snapshot.duplicate(true)
	outcome.party_snapshot = party_snapshot.duplicate(true)
	outcome.dialogue_result_snapshots = results.duplicate(true)
	return outcome
