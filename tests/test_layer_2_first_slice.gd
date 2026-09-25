extends SceneTree


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)


var failures: int = 0


func _init() -> void:
	_test_first_route_node_and_encounter()
	_test_first_clear_rewards_are_non_farmable()
	if failures == 0:
		print("Layer 2 first playable slice tests passed.")
	else:
		push_error("%d Layer 2 first-slice test(s) failed." % failures)
	quit(failures)


func _test_first_route_node_and_encounter() -> void:
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph = generator.generate_layer_2_run(27072026)
	var first_node: MapNodeState = graph.get_map_node(&"l2_c1_n0")
	var chain_thrall: BattlerDefinition = BATTLER_CATALOG.get_battler(
		&"chain_thrall"
	)
	var iron_guard: BattlerDefinition = BATTLER_CATALOG.get_battler(
		&"iron_masked_guard"
	)
	var deeper_nodes: Array[MapNodeState] = graph.get_nodes_in_column(2)
	var deeper_traversable: bool = not deeper_nodes.is_empty()
	for node: MapNodeState in deeper_nodes:
		deeper_traversable = deeper_traversable and node.travel_enabled

	var run := RunState.new()
	var initialize_error: String = run.initialize(
		27072026,
		graph,
		[],
		_full_party_snapshot()
	)
	run.opening_completed = true
	var select_error: String = run.select_node(&"l2_c1_n0")
	var travel_error: String = run.travel_to(&"l2_c1_n0")
	var encounter: EncounterDefinition = run.make_encounter_definition()
	_expect(
		initialize_error.is_empty()
		and select_error.is_empty()
		and travel_error.is_empty()
		and first_node != null
		and first_node.travel_enabled
		and first_node.encounter_id == (
			LayerMapGenerator.LAYER_2_FIRST_SLICE_ENCOUNTER_ID
		)
		and first_node.reward_source_id == &"l02_kept_watch_chain_oil"
		and deeper_traversable
		and encounter != null
		and encounter.enemy_ids.size() == 2
		and encounter.enemy_ids[0] == &"iron_masked_guard"
		and encounter.enemy_ids[1] == &"chain_thrall"
		and encounter.template != null
		and encounter.template.template_id == (
			&"layer_2_chain_maintenance_regular"
		)
		and chain_thrall != null
		and chain_thrall.grapple_template != null
		and iron_guard != null
		and iron_guard.default_loadout != null
		and iron_guard.default_loadout.armor != null,
		"The first Layer 2 route node must launch the authored Kept Watch composition into the traversable generated route."
	)


func _test_first_clear_rewards_are_non_farmable() -> void:
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph = generator.generate_layer_2_run(8128)
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		8128,
		graph,
		[],
		_full_party_snapshot()
	)
	_expect(
		initialize_error.is_empty(),
		"Layer 2 reward fixture should initialize: %s" % initialize_error
	)
	if not initialize_error.is_empty():
		return
	run.opening_completed = true
	run.inventory_snapshot = _empty_inventory_snapshot()
	var select_error: String = run.select_node(&"l2_c1_n0")
	var travel_error: String = run.travel_to(&"l2_c1_n0")
	_expect(
		select_error.is_empty() and travel_error.is_empty(),
		"Layer 2 reward fixture should reach Kept Watch: %s %s"
		% [select_error, travel_error]
	)
	if not select_error.is_empty() or not travel_error.is_empty():
		return
	var outcome := EncounterOutcome.new()
	outcome.result = EncounterOutcome.Result.VICTORY
	outcome.encounter_id = LayerMapGenerator.LAYER_2_FIRST_SLICE_ENCOUNTER_ID
	outcome.source_node_id = &"l2_c1_n0"
	outcome.party_snapshot = _full_party_snapshot()
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.bloom_reward = 4
	var apply_error: String = run.apply_encounter_outcome(outcome)
	var chain_oil_quantity: int = 0
	for slot: Dictionary in run.inventory_snapshot:
		if StringName(slot.get("item_id", "")) == &"l02_chain_oil":
			chain_oil_quantity += int(slot.get("quantity", 0))
	var cleared_node: MapNodeState = graph.get_map_node(&"l2_c1_n0")
	var duplicate_error: String = run.apply_encounter_outcome(outcome)
	_expect(
		apply_error.is_empty()
		and cleared_node.cleared
		and cleared_node.reward_claimed
		and run.bloom == 4
		and chain_oil_quantity == 1
		and not duplicate_error.is_empty()
		and run.bloom == 4,
		"Kept Watch must grant exactly 4 Bloom and one Chain Oil on first clear only."
	)


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


func _empty_inventory_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for slot_index: int in range(6):
		snapshot.append({
			"slot_index": slot_index,
			"item_id": "",
			"quantity": 0,
		})
	return snapshot


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
