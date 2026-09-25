extends SceneTree


const ROOM_CATALOG: LayerRoomCatalogDefinition = preload(
	"res://data/rooms/layer_1_2_room_catalog.tres"
)
const EVENT_ROOM_CATALOG: EventRoomCatalogDefinition = preload(
	"res://data/exploration/rooms/event_room_catalog.tres"
)
const DIALOGUE_CATALOG: DialogueCatalogDefinition = preload(
	"res://data/dialogue/production_dialogue_catalog.tres"
)
const STAGE_CATALOG: CombatStageCatalog = preload(
	"res://data/presentation/combat_stage_catalog.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const ROOM_ENCOUNTER_HOTSPOT_SCRIPT: Script = preload(
	"res://scripts/exploration/interactions/room_encounter_hotspot.gd"
)
const DINING_ROOM_ID: StringName = &"dining_service_hall"
const BELL_ROOM_ID: StringName = &"bell_pull_gallery"


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_optional_registered_generation()
	await _test_presentations_and_authored_battlefield()
	_test_dining_encounter_lifecycle()
	_test_bell_gallery_lifecycle()
	_test_malformed_binding_is_transactional()
	if failures == 0:
		print("Milestone 15 Pilot A integration tests passed.")
	else:
		push_error("%d Pilot A integration test(s) failed." % failures)
	quit(failures)


func _test_optional_registered_generation() -> void:
	var dining_registered := ROOM_CATALOG.get_room(DINING_ROOM_ID)
	var bell_registered := ROOM_CATALOG.get_room(BELL_ROOM_ID)
	_expect(
		dining_registered != null
		and dining_registered.exploration_definition != null
		and dining_registered.production_battlefields.size() == 1
		and bell_registered != null
		and bell_registered.exploration_definition != null
		and EVENT_ROOM_CATALOG.get_room(DINING_ROOM_ID) != null
		and EVENT_ROOM_CATALOG.get_room(BELL_ROOM_ID) != null,
		"Both Pilot A rooms must resolve through the real room registries."
	)

	var generator := LayerMapGenerator.new()
	var dining_seen := false
	var dining_absent := false
	var bell_seen := false
	var bell_absent := false
	var deterministic := true
	var valid_optional_nodes := true
	var presentation_only_fillers_remain_noncombat := true
	var cold_pantry_seen := false
	for seed: int in range(1, 257):
		var first: LayerMapGraph = generator.generate_layer_1(seed)
		var second: LayerMapGraph = generator.generate_layer_1(seed)
		if first == null or second == null:
			deterministic = false
			continue
		deterministic = deterministic and (
			JSON.stringify(first.to_snapshot())
			== JSON.stringify(second.to_snapshot())
		)
		var first_special: MapNodeState = first.get_nodes_in_column(1)[0]
		valid_optional_nodes = valid_optional_nodes and (
			first_special.authored_room_id != DINING_ROOM_ID
		)
		var dining: MapNodeState = _get_authored_node(first, DINING_ROOM_ID)
		var bell: MapNodeState = _get_authored_node(first, BELL_ROOM_ID)
		for value: Variant in first.nodes.values():
			var node: MapNodeState = value as MapNodeState
			if node.authored_room_id == &"cold_pantry":
				cold_pantry_seen = true
			if node.node_id in [&"l1_c1_n0", &"l1_c5_n0", &"l1_c6_n0"]:
				continue
			if node.authored_room_id == DINING_ROOM_ID:
				continue
			presentation_only_fillers_remain_noncombat = (
				presentation_only_fillers_remain_noncombat
				and node.node_type != MapNodeState.NodeType.BATTLE
				and node.node_type != MapNodeState.NodeType.BOSS
				and not node.has_encounter_content()
			)
		dining_seen = dining_seen or dining != null
		dining_absent = dining_absent or dining == null
		bell_seen = bell_seen or bell != null
		bell_absent = bell_absent or bell == null
		if dining != null:
			valid_optional_nodes = valid_optional_nodes and (
				dining.node_type == MapNodeState.NodeType.ROOM
				and dining.room_definition_id == DINING_ROOM_ID
				and dining.encounter_id == RunState.DINING_SERVICE_HALL_ENCOUNTER_ID
				and dining.encounter_template_id == &"dining_service_hall_regular"
				and dining.reward_source_id == &""
			)
		if bell != null:
			valid_optional_nodes = valid_optional_nodes and (
				bell.node_type == MapNodeState.NodeType.ROOM
				and bell.room_definition_id == BELL_ROOM_ID
				and not bell.has_encounter_content()
				and bell.reward_source_id == &""
			)
	_expect(
		deterministic
		and dining_seen and dining_absent
		and bell_seen and bell_absent
		and valid_optional_nodes
		and cold_pantry_seen
		and presentation_only_fillers_remain_noncombat,
		(
			"Both Pilot A rooms must be deterministic optional filler content, "
			+ "never universal or substituted into the Corrupted Butler route; "
			+ "presentation-only fillers such as Cold Pantry must remain noncombat."
		)
	)


func _test_presentations_and_authored_battlefield() -> void:
	var dining_scene := load(
		"res://scenes/exploration/rooms/layer1/dining_service_hall.tscn"
	) as PackedScene
	var bell_scene := load(
		"res://scenes/exploration/rooms/layer1/bell_pull_gallery.tscn"
	) as PackedScene
	var dining_presentation: Node = dining_scene.instantiate()
	var bell_presentation: Node = bell_scene.instantiate()
	root.add_child(dining_presentation)
	root.add_child(bell_presentation)
	await process_frame
	var dining_trigger: Variant = dining_presentation.find_child(
		"RoomEncounterHotspot", true, false
	)
	var dining_exit := dining_presentation.find_child(
		"RoomExitHotspot", true, false
	) as RoomExitHotspot
	var bell_exit := bell_presentation.find_child(
		"RoomExitHotspot", true, false
	) as RoomExitHotspot
	var dining_background := dining_presentation.get_node_or_null(
		"Background"
	) as Sprite2D
	var bell_background := bell_presentation.get_node_or_null(
		"Background"
	) as Sprite2D
	_expect(
		dining_trigger != null
		and dining_trigger.validate_hotspot().is_empty()
		and dining_trigger.trigger_id == &"dining_service_hall_battle_route"
		and dining_exit != null
		and bell_exit != null
		and dining_background != null
		and dining_background.texture.resource_path.ends_with(
			"l01_room_dining_service_hall.png"
		)
		and bell_background != null
		and bell_background.texture.resource_path.ends_with(
			"l01_room_bell_pull_gallery.png"
		),
		"Pilot A exploration scenes need reviewed art and clear authored exits/triggers."
	)

	var template: EncounterTemplateDefinition = RunState.DINING_SERVICE_HALL_TEMPLATE
	var battlefield := template.battlefield_scene.instantiate() as AuthoredBattlefield
	root.add_child(battlefield)
	await process_frame
	var dining_binding: CombatStageBindingDefinition = STAGE_CATALOG.get_binding(
		RunState.DINING_SERVICE_HALL_ENCOUNTER_ID,
		DINING_ROOM_ID
	)
	_expect(
		battlefield != null
		and battlefield.validate_authoring().is_empty()
		and template.preview_enemy_ids == [&"hollow_servant", &"knife_footman"]
		and template.enemy_group_rulebook != null
		and dining_binding != null
		and dining_binding.trigger_type == &"interaction"
		and STAGE_CATALOG.get_stage(
			dining_binding.combat_stage_id
		).background_texture.resource_path.ends_with(
			"l01_room_dining_service_hall.png"
		),
		"Dining must bind its legal authored battlefield and reviewed combat stage."
	)
	dining_presentation.queue_free()
	bell_presentation.queue_free()
	battlefield.queue_free()
	await process_frame


func _test_dining_encounter_lifecycle() -> void:
	var prepared: Dictionary = _make_run_at_room(DINING_ROOM_ID)
	var run: RunState = prepared.get("run") as RunState
	var node: MapNodeState = prepared.get("node") as MapNodeState
	_expect(
		run != null and node != null and String(prepared.get("error", "")).is_empty(),
		"A generated Dining Service Hall must be reachable as pending content."
	)
	if run == null or node == null:
		return
	var encounter: EncounterDefinition = run.make_encounter_definition()
	var pre_snapshot: Dictionary = run.make_active_run_snapshot(
		"pre_node", KnowledgeState.new()
	)
	var continued := RunState.new()
	var continue_error: String = continued.restore_active_run_snapshot(
		pre_snapshot,
		BATTLER_CATALOG
	)
	var continued_encounter: EncounterDefinition = (
		continued.make_encounter_definition()
		if continue_error.is_empty()
		else null
	)
	_expect(
		encounter != null
		and encounter.enemy_ids == [&"hollow_servant", &"knife_footman"]
		and encounter.template == RunState.DINING_SERVICE_HALL_TEMPLATE
		and encounter.ensure_spawn_assignments().is_empty()
		and not pre_snapshot.is_empty()
		and continue_error.is_empty()
		and continued.pending_node_seed == run.pending_node_seed
		and continued_encounter != null
		and continued_encounter.enemy_ids == encounter.enemy_ids,
		"Dining entry and pre-node Continue must preserve its encounter and seed."
	)

	var victory: EncounterOutcome = _make_encounter_outcome(
		run,
		encounter,
		EncounterOutcome.Result.VICTORY
	)
	var rewards_before: Dictionary = run.reward_resolutions.duplicate(true)
	var victory_error: String = run.apply_encounter_outcome(victory)
	var after_victory: Dictionary = run.make_active_run_snapshot(
		"post_node", KnowledgeState.new()
	)
	var before_duplicate: String = JSON.stringify(after_victory)
	var duplicate_error: String = run.apply_encounter_outcome(victory)
	var post_run := RunState.new()
	var post_error: String = post_run.restore_active_run_snapshot(
		after_victory,
		BATTLER_CATALOG
	)
	_expect(
		victory_error.is_empty()
		and node.cleared and node.reward_claimed
		and run.completed_encounters.has(encounter.encounter_id)
		and run.reward_resolutions == rewards_before
		and not duplicate_error.is_empty()
		and JSON.stringify(run.make_active_run_snapshot(
			"post_node", KnowledgeState.new()
		)) == before_duplicate
		and post_error.is_empty()
		and post_run.graph.get_map_node(node.node_id).cleared
		and post_run.pending_node_id == &"",
		"Dining victory, post-node Continue, and duplicate prevention must be exact."
	)

	var retry := RunState.new()
	var retry_restore_error: String = retry.restore_active_run_snapshot(
		pre_snapshot,
		BATTLER_CATALOG
	)
	var retry_encounter: EncounterDefinition = retry.make_encounter_definition()
	var defeat: EncounterOutcome = _make_encounter_outcome(
		retry,
		retry_encounter,
		EncounterOutcome.Result.DEFEAT
	)
	var defeat_error: String = retry.apply_encounter_outcome(defeat)
	_expect(
		retry_restore_error.is_empty()
		and defeat_error.is_empty()
		and not retry.graph.get_map_node(node.node_id).cleared
		and retry.pending_node_id == &"",
		"Dining defeat must not clear or reward the encounter; its pre-node snapshot remains retryable."
	)


func _test_bell_gallery_lifecycle() -> void:
	var prepared: Dictionary = _make_run_at_room(BELL_ROOM_ID)
	var run: RunState = prepared.get("run") as RunState
	var node: MapNodeState = prepared.get("node") as MapNodeState
	_expect(
		run != null and node != null and String(prepared.get("error", "")).is_empty(),
		"A generated Bell-Pull Gallery must be reachable as pending content."
	)
	if run == null or node == null:
		return
	var dialogue: DialogueDefinition = EVENT_ROOM_CATALOG.get_room(
		BELL_ROOM_ID
	).entry_dialogue
	var context := DialogueContext.new()
	context.current_party_ids = [&"lysandra", &"mira", &"seraphine"]
	context.present_actor_ids = context.current_party_ids.duplicate()
	context.recruited_heroine_ids = context.current_party_ids.duplicate()
	context.flags_by_scope = {&"run": {}, &"save": {}, &"persistent": {}}
	var runner := DialogueRunner.new()
	var start_error: String = runner.start(dialogue, context)
	var entry_result: DialogueResult = runner.consume_pending_transition_result()
	var completion: DialogueResult = runner.advance()
	var pre_snapshot: Dictionary = run.make_active_run_snapshot(
		"pre_node", KnowledgeState.new()
	)
	var continued := RunState.new()
	var pre_continue_error: String = continued.restore_active_run_snapshot(
		pre_snapshot,
		BATTLER_CATALOG
	)

	var room_state: EventRoomInstanceState = run.get_event_room_state(
		node.node_id,
		BELL_ROOM_ID
	)
	room_state.visit_count = 1
	var outcome := EventRoomOutcome.new()
	outcome.source_node_id = node.node_id
	outcome.clear_node = true
	outcome.room_state_snapshot = room_state.to_snapshot()
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.run_inventory_snapshot = run.get_run_inventory_snapshot()
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.dialogue_result_snapshots = [
		entry_result.to_snapshot(),
		completion.to_snapshot(),
	]
	var bloom_before: int = run.bloom
	var rewards_before: Dictionary = run.reward_resolutions.duplicate(true)
	var materials_before: Dictionary = run.run_inventory.material_pouch.duplicate(true)
	var apply_error: String = run.apply_event_room_outcome(outcome)
	var post_snapshot: Dictionary = run.make_active_run_snapshot(
		"post_node", KnowledgeState.new()
	)
	var restored := RunState.new()
	var post_continue_error: String = restored.restore_active_run_snapshot(
		post_snapshot,
		BATTLER_CATALOG
	)
	var replay_error: String = restored.apply_event_room_outcome(outcome)
	_expect(
		start_error.is_empty()
		and completion.completed
		and pre_continue_error.is_empty()
		and continued.pending_node_id == node.node_id
		and apply_error.is_empty()
		and node.cleared and node.reward_claimed
		and run.bloom == bloom_before
		and run.reward_resolutions == rewards_before
		and run.run_inventory.material_pouch == materials_before
		and post_continue_error.is_empty()
		and restored.pending_node_id == &""
		and restored.narrative_state.resolved_interaction_ids.count(
			&"layer_1_bell_pull_gallery_observation"
		) == 1
		and replay_error.is_empty()
		and restored.narrative_state.resolved_interaction_ids.count(
			&"layer_1_bell_pull_gallery_observation"
		) == 1,
		"Bell Gallery must resolve once, grant nothing, and survive pre/post-node Continue and revisit."
	)


func _test_malformed_binding_is_transactional() -> void:
	var prepared: Dictionary = _make_run_at_room(DINING_ROOM_ID)
	var run: RunState = prepared.get("run") as RunState
	if run == null:
		_expect(false, "Transactional binding test requires a Dining run.")
		return
	var before: String = JSON.stringify(run.make_active_run_snapshot(
		"pre_node", KnowledgeState.new()
	))
	var malformed := CombatStageBindingDefinition.new()
	malformed.binding_id = &"malformed_dining_binding"
	malformed.exploration_room_id = DINING_ROOM_ID
	malformed.trigger_id = &"dining_service_hall_battle_route"
	malformed.encounter_id = RunState.DINING_SERVICE_HALL_ENCOUNTER_ID
	malformed.trigger_type = &"interaction"
	malformed.completion_state_id = &"malformed"
	malformed.return_target = &"layer_1_map"
	var trigger := ExplorationStageTriggerState.new()
	var binding_error: String = trigger.configure(malformed)
	var missing_hotspot: Variant = ROOM_ENCOUNTER_HOTSPOT_SCRIPT.new()
	var hotspot_error: String = missing_hotspot.validate_hotspot()
	_expect(
		not binding_error.is_empty()
		and not hotspot_error.is_empty()
		and JSON.stringify(run.make_active_run_snapshot(
			"pre_node", KnowledgeState.new()
		)) == before,
		"Malformed stage or hotspot bindings must fail without mutating the active run."
	)
	missing_hotspot.free()


func _make_run_at_room(room_id: StringName) -> Dictionary:
	var generator := LayerMapGenerator.new()
	for seed: int in range(1, 1025):
		var graph: LayerMapGraph = generator.generate_layer_1(seed)
		var target: MapNodeState = _get_authored_node(graph, room_id)
		if target == null:
			continue
		var run := RunState.new()
		var initialize_error: String = run.initialize(
			seed,
			graph,
			generator.make_layer_1_generated_room_item_rules(),
			_full_party_snapshot()
		)
		if not initialize_error.is_empty():
			return {"error": initialize_error, "run": run, "node": target}
		run.opening_completed = true
		var route: Array[StringName] = _find_route(graph, target.node_id)
		if route.is_empty():
			return {"error": "Generated room has no route.", "run": run, "node": target}
		for route_node_id: StringName in route:
			var travel_error: String = run.travel_to(route_node_id)
			if not travel_error.is_empty():
				return {"error": travel_error, "run": run, "node": target}
			if route_node_id != target.node_id:
				var clear_error: String = run.complete_pending_node(0)
				if not clear_error.is_empty():
					return {"error": clear_error, "run": run, "node": target}
		var seed_error: String = run.prepare_pending_node_seed()
		return {"error": seed_error, "run": run, "node": target}
	return {"error": "No seed selected room '%s'." % room_id, "run": null, "node": null}


func _find_route(graph: LayerMapGraph, target_id: StringName) -> Array[StringName]:
	var frontier: Array[Dictionary] = [{
		"node_id": graph.start_node_id,
		"route": [],
	}]
	var visited: Dictionary = {}
	while not frontier.is_empty():
		var entry: Dictionary = frontier.pop_front()
		var node_id := StringName(entry.get("node_id", ""))
		if visited.has(node_id):
			continue
		visited[node_id] = true
		var route: Array[StringName] = []
		for value: Variant in entry.get("route", []) as Array:
			route.append(StringName(value))
		if node_id == target_id:
			return route
		var node: MapNodeState = graph.get_map_node(node_id)
		for next_id: StringName in node.outgoing_ids:
			var next_route: Array[StringName] = route.duplicate()
			next_route.append(next_id)
			frontier.append({"node_id": next_id, "route": next_route})
	return []


func _get_authored_node(
	graph: LayerMapGraph,
	room_id: StringName
) -> MapNodeState:
	if graph == null:
		return null
	for node_value: Variant in graph.nodes.values():
		var node := node_value as MapNodeState
		if node != null and node.authored_room_id == room_id:
			return node
	return null


func _make_encounter_outcome(
	run: RunState,
	encounter: EncounterDefinition,
	result: EncounterOutcome.Result
) -> EncounterOutcome:
	var outcome := EncounterOutcome.new()
	outcome.result = result
	outcome.encounter_id = encounter.encounter_id
	outcome.source_node_id = encounter.source_node_id
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	return outcome


func _full_party_snapshot() -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(10, 4, 75, 8),
		&"mira": _heroine_snapshot(9, 6, 72, 12),
		&"seraphine": _heroine_snapshot(8, 8, 80, 4),
	}


func _heroine_snapshot(
	hp: int,
	mp: int,
	resolve: int,
	corruption: int
) -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"resolve": resolve,
		"corruption": corruption,
		"item_guard": 0,
		"weapon_damage": 0,
		"weapon_broken": false,
		"armor_damage": 0,
		"armor_broken": false,
		"shield_damage": 0,
		"shield_broken": false,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
