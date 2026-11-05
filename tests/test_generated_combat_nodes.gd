extends SceneTree

const STAGES = preload("res://data/presentation/combat_stage_catalog.tres")
const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
var checks: int = 0
var failures: int = 0

func _init() -> void:
	var generator := LayerMapGenerator.new()
	var formations: Dictionary = {}
	for seed: int in range(1, 51):
		for layer: int in [1, 2]:
			var graph: LayerMapGraph = generator.generate_layer_1(seed) if layer == 1 else generator.generate_layer_2_run(seed)
			_check(generator.validate_generated_layer(graph).is_empty(), "Elite activation preserves graph/story constraints")
			var elites: int = 0
			for node: MapNodeState in graph.nodes.values():
				if node.node_type != MapNodeState.NodeType.ELITE:
					_check(node.requires_event_room() if node.node_type in [MapNodeState.NodeType.ALCHEMY, MapNodeState.NodeType.WORKSHOP] else true, "Stage 21 field stations are exploration rooms")
					continue
				elites += 1
				_check(node.has_encounter_content() and node.requires_battle() and not node.requires_event_room() and node.room_definition_id == &"" and node.reward_source_id == &"", "Elite contains only combat and no inherited exploration reward")
				for party_count: int in [1, 2, 3]:
					var run := RunState.new()
					var party: Dictionary = {}
					for id: StringName in [&"lysandra", &"mira", &"seraphine"].slice(0, party_count):
						party[id] = {"hp": 5, "mp": 3, "resolve": 70, "corruption": 0}
					run.initialize(seed, graph, [], party)
					run.opening_completed = true
					run.current_node_id = node.node_id
					run.pending_node_id = node.node_id
					var definition: EncounterDefinition = run.make_encounter_definition()
					_check(definition != null, "Generated Elite resolves an executable definition")
					if definition == null:
						continue
					_check(definition.party_ids.size() == party_count and definition.spawn_assignments.size() == definition.get_all_battler_ids().size() and definition.template.validate_capacity(party_count, definition.enemy_ids.size()).is_empty(), "Every supported party and enemy has an authored spawn; party size is preserved")
					var binding: CombatStageBindingDefinition = STAGES.get_binding(definition.encounter_id, definition.authored_room_id, definition.template.template_id)
					_check(binding != null and binding.trigger_type == &"route" and binding.return_target == &"node_map", "Generated encounter has an immediate reusable map-return binding")
					_check(definition.enemy_ids == [&"red_wax_acolyte", &"hollow_servant"] or definition.enemy_ids == [&"hollow_servant", &"knife_footman", &"prayer_rag_novice"], "Only established Elite formations are used")
					if layer == 1:
						formations[definition.enemy_ids.size()] = true
					else:
						_check(definition.enemy_ids.size() == 2, "Dungeon's existing two-position battlefield uses the supported pair")
			_check(elites >= 1 and elites <= 2, "Each full layer activates one or two Elites within its room budget")
	_check(formations.has(2) and formations.has(3), "Both Layer 1 Elite variants appear across real generated seeds")
	_check(STAGES.validate_definition().is_empty(), "Catalog validates exact and template bindings")
	var story: CombatStageBindingDefinition = STAGES.get_binding(RunState.SERAPHINE_RECRUITMENT_ENCOUNTER_ID, &"ruined_chapel", &"ruined_chapel_regular")
	_check(story.trigger_type == &"dialogue_result" and story.return_target == &"seraphine_recruitment_aftermath", "Exact story binding wins over generic template fallback")
	_check(STAGES.get_binding(&"unknown", &"room", &"unregistered") == null, "Missing templates remain a launch error")
	var duplicate: CombatStageCatalog = STAGES.duplicate(true)
	var extra: CombatStageBindingDefinition = duplicate.bindings[-1].duplicate(true)
	extra.binding_id = &"duplicate_template_test"
	duplicate.bindings.append(extra)
	_check(not duplicate.validate_definition().is_empty(), "Ambiguous template fallbacks reject at catalog validation")
	var legacy: LayerMapGraph = generator.generate_layer_1(333)
	for id: String in legacy.reserved_node_types:
		var node: MapNodeState = legacy.get_map_node(StringName(id))
		if node.node_type == MapNodeState.NodeType.ELITE:
			node.node_type = MapNodeState.NodeType.ROOM
			node.encounter_id = &""
			node.encounter_template_id = &""
	var restored: LayerMapGraph = LayerMapGraph.from_snapshot(legacy.to_snapshot()).graph
	_check(restored != null and restored.to_snapshot() == legacy.to_snapshot(), "Loading a pre-activation graph retains its stored room types without regenerating Elites")
	_revisit(generator)
	print("Stage 17 generated combat: %d checks, %d failures." % [checks, failures])
	quit(failures)

func _revisit(generator: LayerMapGenerator) -> void:
	var graph: LayerMapGraph = generator.generate_layer_1(333)
	var run := RunState.new()
	run.initialize(333, graph, [], {&"lysandra": {"hp": 5, "mp": 3}})
	run.opening_completed = true
	var elite: MapNodeState
	for node: MapNodeState in graph.nodes.values():
		if node.node_type == MapNodeState.NodeType.ELITE:
			elite = node
	var origin: MapNodeState = graph.get_map_node(elite.incoming_ids[0])
	origin.visited = true
	origin.cleared = true
	origin.exit_completed = true
	run.current_node_id = origin.node_id
	graph.reveal_adjacency(origin.node_id)
	_check(run.travel_to(elite.node_id).is_empty(), "Known route enters generated Elite")
	var definition: EncounterDefinition = run.make_encounter_definition()
	var outcome := EncounterOutcome.new()
	outcome.source_node_id = elite.node_id
	outcome.encounter_id = definition.encounter_id
	outcome.result = EncounterOutcome.Result.VICTORY
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.bloom_reward = 11 # Fixture value tests exactly-once accounting, not authored economy.
	_check(run.apply_encounter_outcome(outcome).is_empty() and elite.encounter_cleared and elite.solved and elite.exit_completed and run.pending_node_id == &"", "Victory resolves/Solves combat-only node")
	var bloom: int = run.bloom
	_check(run.travel_to(origin.node_id).is_empty() and run.travel_to(elite.node_id).is_empty() and run.make_encounter_definition() == null and run.pending_node_id == &"" and run.bloom == bloom, "Revisit produces neither enemies nor repeat rewards")
	_check(not run.apply_encounter_outcome(outcome).is_empty() and run.bloom == bloom, "Duplicate outcome cannot grant rewards")
	var saved: Dictionary = run.make_active_run_snapshot("post_node", KnowledgeState.new())
	var loaded := RunState.new()
	_check(loaded.restore_active_run_snapshot(saved, BATTLERS).is_empty() and loaded.graph.get_map_node(elite.node_id).solved, "Continue retains generated combat completion")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
