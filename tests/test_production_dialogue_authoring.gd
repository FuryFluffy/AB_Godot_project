extends SceneTree


const CATALOG: DialogueCatalogDefinition = preload(
	"res://data/dialogue/production_dialogue_catalog.tres"
)
const WINE_ROOM: EventRoomDefinition = preload(
	"res://data/exploration/rooms/layer1/wine_cellar_warm_bottles.tres"
)
const OFFICE_ROOM: EventRoomDefinition = preload(
	"res://data/exploration/rooms/layer1/butlers_office.tres"
)
const BELL_GALLERY_ROOM: EventRoomDefinition = preload(
	"res://data/exploration/rooms/layer1/bell_pull_gallery.tres"
)
const LEDGER_ROOM: LayerRoomDefinition = preload(
	"res://data/rooms/layer_1/02_servant_ledger_alcove.tres"
)
const CONFESSIONAL_ROOM: LayerRoomDefinition = preload(
	"res://data/rooms/layer_1/05_ruined_confessional.tres"
)
const COAT_ROOM: LayerRoomDefinition = preload(
	"res://data/rooms/layer_1/06_coat_beside_service_door.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)


var failures: int = 0


func _init() -> void:
	_test_catalog_and_real_graph_completion()
	_test_trigger_bindings_and_deferred_opening()
	_test_room_and_background_bindings()
	_test_curated_production_character_art()
	_test_active_run_dialogue_session_round_trip()
	_test_malformed_results_are_transactional()
	if failures == 0:
		print("Production dialogue authoring tests passed.")
	else:
		push_error("%d production dialogue test(s) failed." % failures)
	quit(failures)


func _test_catalog_and_real_graph_completion() -> void:
	_expect(
		CATALOG.validate_definition().is_empty(),
		"The production catalog must validate."
	)
	_expect(
		CATALOG.dialogues.size() == 14,
		"The production catalog must contain fourteen bound graphs."
	)
	for dialogue: DialogueDefinition in CATALOG.dialogues:
		var context: DialogueContext = _full_context()
		var runner := DialogueRunner.new()
		var start_error: String = runner.start(dialogue, context)
		var results: Array[Dictionary] = []
		if start_error.is_empty():
			for _step: int in range(dialogue.nodes.size() + 2):
				var node: DialogueNodeDefinition = runner.get_current_node()
				var result: DialogueResult
				if node != null and not node.choices.is_empty():
					var choices: Array[Dictionary] = runner.get_presented_choices()
					var choice := choices[0].get("choice") as DialogueChoiceDefinition
					result = runner.choose(choice.choice_id)
				else:
					result = runner.advance()
				results.append(result.to_snapshot())
				if result.completed:
					break
		_expect(
			start_error.is_empty()
			and runner.session != null
			and runner.session.completed
			and dialogue.is_completed(context),
			(
				"Production graph '%s' must start and complete through its real data."
				% dialogue.dialogue_id
			)
		)
		var narrative := NarrativeState.new()
		for result_snapshot: Dictionary in results:
			var apply_error: String = narrative.apply_dialogue_result_snapshot(
				result_snapshot,
				CATALOG
			)
			_expect(
				apply_error.is_empty(),
				"Completed graph results must enter NarrativeState."
			)


func _test_trigger_bindings_and_deferred_opening() -> void:
	var expected: Dictionary = {
		&"layer_1_mira_recruitment_aftermath": [&"encounter_aftermath", &"layer_1_corrupted_butler_opening"],
		&"layer_1_seraphine_recruitment_prelude": [&"encounter_prelude", &"layer_1_seraphine_ruined_chapel"],
		&"layer_1_seraphine_recruitment_aftermath": [&"encounter_aftermath", &"layer_1_seraphine_ruined_chapel"],
		&"layer_1_blood_nun_aftermath": [&"encounter_aftermath", &"layer_1_blood_nun"],
		&"layer_2_refuge_origin": [&"refugeless_defeat", &"layer_2_jailer_first_containment"],
		&"layer_2_refuge_origin_from_upper_route": [&"refugeless_defeat", &"refugeless_ascent_non_jailer"],
		&"layer_2_jailer_victory_aftermath": [&"encounter_victory", &"layer_2_jailer_first_containment"],
		&"layer_2_farthest_cell_refuge_establishment": [&"map_arrival", &"l2_refuge_farthest_cell"],
		&"layer_1_wine_cellar_observation": [&"event_room_entry", &"wine_cellar_warm_bottles"],
		&"layer_1_butlers_office_observation": [&"event_room_entry", &"butlers_office"],
		&"layer_1_bell_pull_gallery_observation": [&"event_room_entry", &"bell_pull_gallery"],
		&"layer_1_servant_ledger_observation": [&"event_room_entry", &"servant_ledger_alcove"],
		&"layer_1_ruined_confessional": [&"event_room_entry", &"ruined_confessional"],
		&"layer_1_coat_torn_cuff": [&"event_room_entry", &"coat_beside_service_door"],
	}
	for dialogue_id: StringName in expected:
		var binding: Array = expected[dialogue_id]
		var dialogue: DialogueDefinition = CATALOG.get_dialogue(dialogue_id)
		_expect(
			dialogue != null and dialogue.matches_trigger(binding[0], binding[1]),
			"Production graph '%s' must retain its canonical trigger." % dialogue_id
		)
	_expect(
		CATALOG.get_triggered_dialogue(
			&"encounter_prelude",
			&"layer_1_opening_hollow_servant"
		) == null,
		"The locked silent solo opening must remain direct combat, not speculative dialogue."
	)


func _test_room_and_background_bindings() -> void:
	var mira_aftermath: DialogueDefinition = CATALOG.get_dialogue(
		&"layer_1_mira_recruitment_aftermath"
	)
	var mira_first_line: DialogueNodeDefinition = (
		mira_aftermath.get_node_definition(&"first_line")
		if mira_aftermath != null
		else null
	)
	var mira_portrait := (
		mira_first_line.portrait as AtlasTexture
		if mira_first_line != null
		else null
	)
	_expect(
		WINE_ROOM.entry_dialogue == CATALOG.get_dialogue(
			&"layer_1_wine_cellar_observation"
		)
		and OFFICE_ROOM.entry_dialogue == CATALOG.get_dialogue(
			&"layer_1_butlers_office_observation"
		)
		and BELL_GALLERY_ROOM.entry_dialogue == CATALOG.get_dialogue(
			&"layer_1_bell_pull_gallery_observation"
		)
		and LEDGER_ROOM.exploration_definition.entry_dialogue == CATALOG.get_dialogue(
			&"layer_1_servant_ledger_observation"
		)
		and CONFESSIONAL_ROOM.exploration_definition.entry_dialogue == CATALOG.get_dialogue(
			&"layer_1_ruined_confessional"
		)
		and COAT_ROOM.exploration_definition.entry_dialogue == CATALOG.get_dialogue(
			&"layer_1_coat_torn_cuff"
		),
		"Executable room observations must bind through EventRoomDefinition."
	)
	_expect(
		WINE_ROOM.entry_dialogue.background_override == null
		and OFFICE_ROOM.entry_dialogue.background_override == null
		and BELL_GALLERY_ROOM.entry_dialogue.background_override == null
		and CATALOG.get_dialogue(
			&"layer_2_farthest_cell_refuge_establishment"
		).background_override != null,
		"Ordinary rooms must inherit their visuals while Farthest Cell uses its authored asset."
	)
	_expect(
		mira_first_line != null
		and mira_first_line.left_actor_sprite.resource_path.ends_with(
			"assets/characters/curated/lysandra/core_idle_front.png"
		)
		and mira_first_line.right_actor_sprite.resource_path.ends_with(
			"assets/characters/curated/mira/core_move_front.png"
		)
		and mira_portrait != null
		and mira_portrait.atlas.resource_path.ends_with(
			"assets/characters/curated/mira/core_move_front.png"
		),
		"Mira's recruitment aftermath must use the current curated heroine art."
	)


func _test_curated_production_character_art() -> void:
	var affected_dialogue_ids: Array[StringName] = [
		&"layer_1_seraphine_recruitment_prelude",
		&"layer_1_seraphine_recruitment_aftermath",
		&"layer_1_blood_nun_aftermath",
		&"layer_2_refuge_origin",
		&"layer_2_refuge_origin_from_upper_route",
	]
	var checked_actor_sprites: int = 0
	var checked_portraits: int = 0
	for dialogue_id: StringName in affected_dialogue_ids:
		var dialogue: DialogueDefinition = CATALOG.get_dialogue(dialogue_id)
		_expect(dialogue != null, "Affected production dialogue should load.")
		if dialogue == null:
			continue
		for node: DialogueNodeDefinition in dialogue.nodes:
			for actor_sprite: Texture2D in [
				node.left_actor_sprite,
				node.right_actor_sprite,
			]:
				if actor_sprite == null:
					continue
				checked_actor_sprites += 1
				_expect(
					_texture_source_path(actor_sprite).contains(
						"assets/characters/curated/"
					),
					"Production dialogue actors must use curated heroine art."
				)
			if node.portrait != null:
				checked_portraits += 1
				_expect(
					node.portrait is AtlasTexture
					and _texture_source_path(node.portrait).contains(
						"assets/characters/curated/"
					),
					"Production dialogue portraits must crop curated heroine art."
				)
	_expect(
		checked_actor_sprites == 20 and checked_portraits == 2,
		"The five affected production graphs should cover 20 actors and two portraits."
	)


func _texture_source_path(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		return atlas.atlas.resource_path if atlas.atlas != null else ""
	return texture.resource_path if texture != null else ""


func _test_active_run_dialogue_session_round_trip() -> void:
	var generator := LayerMapGenerator.new()
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		27072026,
		generator.generate_layer_1(27072026),
		generator.make_layer_1_generated_room_item_rules(),
		{
			&"lysandra": {
				"hp": 10,
				"mp": 4,
				"resolve": 50,
				"corruption": 0,
			}
		}
	)
	var dialogue: DialogueDefinition = BELL_GALLERY_ROOM.entry_dialogue
	var runner := DialogueRunner.new()
	var start_error: String = runner.start(dialogue, _full_context())
	var entry_result: DialogueResult = runner.consume_pending_transition_result()
	var apply_error: String = run.narrative_state.apply_dialogue_result_snapshot(
		entry_result.to_snapshot(),
		CATALOG
	)
	var snapshot: Dictionary = run.make_active_run_snapshot(
		"post_node",
		KnowledgeState.new()
	)
	var restored := RunState.new()
	var restore_error: String = restored.restore_active_run_snapshot(
		snapshot,
		BATTLER_CATALOG
	)
	var restored_session: DialogueSessionState = (
		restored.narrative_state.get_dialogue_session(dialogue.dialogue_id)
		if restore_error.is_empty()
		else null
	)
	var resumed := DialogueRunner.new()
	var restored_session_was_active: bool = (
		restored_session != null and not restored_session.completed
	)
	var resume_error: String = resumed.start(
		dialogue,
		_full_context(),
		restored_session
	)
	var completion: DialogueResult = resumed.advance()
	var completion_error: String = (
		restored.narrative_state.apply_dialogue_result_snapshot(
			completion.to_snapshot(),
			CATALOG
		)
	)
	var replay_error: String = (
		restored.narrative_state.apply_dialogue_result_snapshot(
			completion.to_snapshot(),
			CATALOG
		)
	)
	_expect(
		initialize_error.is_empty()
		and start_error.is_empty()
		and apply_error.is_empty()
		and not snapshot.is_empty()
		and restore_error.is_empty()
		and restored_session != null
		and restored_session_was_active
		and resume_error.is_empty()
		and completion.completed
		and completion_error.is_empty()
		and replay_error.is_empty()
		and restored.narrative_state.resolved_interaction_ids.count(
			dialogue.completion_id
		) == 1,
		"Active-run snapshots must resume dialogue once without duplicating completion."
	)


func _test_malformed_results_are_transactional() -> void:
	var narrative := NarrativeState.new()
	narrative.choice_ids = [&"existing_choice"]
	var before: Dictionary = narrative.to_snapshot()
	var unknown_error: String = narrative.apply_dialogue_result_snapshot({
		"dialogue_id": "unknown_dialogue",
		"outcomes": [],
		"session_snapshot": {},
	}, CATALOG)
	var malformed_error: String = narrative.restore_from_snapshot({
		"recruited_heroine_ids": ["lysandra"],
		"choice_ids": [],
		"resolved_interaction_ids": [],
		"flags_by_scope": {"run": {}, "save": {}, "persistent": {}},
		"dialogue_sessions": {"unknown_dialogue": {}},
		"pending_story_requests": [],
	}, CATALOG)
	_expect(
		not unknown_error.is_empty()
		and not malformed_error.is_empty()
		and narrative.to_snapshot() == before,
		"Malformed or unknown dialogue references must leave narrative state unchanged."
	)


func _full_context() -> DialogueContext:
	var context := DialogueContext.new()
	context.current_party_ids = [&"lysandra", &"mira", &"seraphine"]
	context.present_actor_ids = [&"lysandra", &"mira", &"seraphine", &"blood_nun", &"jailer"]
	context.recruited_heroine_ids = context.current_party_ids.duplicate()
	context.flags_by_scope = {&"run": {}, &"save": {}, &"persistent": {}}
	return context


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
