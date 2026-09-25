extends SceneTree


const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)
const SOURCE_CATALOG: RewardSourceCatalogDefinition = preload(
	"res://data/rewards/reward_source_catalog.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)


var failures: int = 0


func _init() -> void:
	_test_catalog_channels_and_fixed_rewards()
	_test_event_room_assignment_uses_shared_resolution()
	_test_material_rewards_route_once_to_material_pouch()
	_test_deterministic_current_layer_weighting()
	_test_deferred_claim_round_trip_and_no_duplicate()
	_test_invalid_sources_and_destinations()
	_test_malformed_snapshot_is_transactional_and_m8_compatible()
	if failures == 0:
		print("Deterministic reward-source and routing tests passed.")
	else:
		push_error("%d reward-source test(s) failed." % failures)
	quit(failures)


func _test_catalog_channels_and_fixed_rewards() -> void:
	_expect(
		SOURCE_CATALOG.validate_catalog(ITEM_CATALOG).is_empty(),
		"The production reward-source catalog must validate."
	)
	var expected_fixed: Dictionary = {
		&"wine_cellar_specific": &"l01_warm_wine_flask",
		&"butlers_office_specific": &"l01_ledger_seal",
		&"layer_1_rusty_key_01": &"shared_rusty_key",
		&"l02_kept_watch_chain_oil": &"l02_chain_oil",
		&"l01_wax_prep_red_wax_material": &"mat_l01_red_wax",
		&"l01_linen_sorting_servant_cloth": &"mat_l01_servant_cloth",
		&"l02_polished_gallery_chain_links": &"mat_l02_chain_links",
		&"l02_punishment_room_prison_iron": &"mat_l02_prison_iron",
	}
	for source_value: Variant in expected_fixed.keys():
		var source_id := StringName(source_value)
		var source: RoomLootSourceDefinition = SOURCE_CATALOG.get_source(source_id)
		var expected_item: ItemDefinition = ITEM_CATALOG.get_item(
			expected_fixed[source_value]
		)
		var current_layer: int = expected_item.layer
		var result: Dictionary = RewardSourceResolver.resolve(
			source,
			ITEM_CATALOG,
			current_layer,
			27072026,
			StringName("test_%s" % source_id)
		)
		var record: Dictionary = result.get("record", {}) as Dictionary
		_expect(
			String(result.get("error", "")).is_empty()
			and StringName(record.get("item_id", "")) == expected_fixed[source_value],
			"Fixed reward source '%s' must retain its authored item." % source_id
		)
	var inventory := RunInventoryState.new()
	inventory.initialize(ITEM_CATALOG, [&"lysandra", &"mira", &"seraphine"], true)
	var rusty_result: Dictionary = RewardSourceResolver.resolve(
		SOURCE_CATALOG.get_source(&"layer_1_rusty_key_01"),
		ITEM_CATALOG,
		1,
		27072026,
		&"rusty_key_host"
	)
	var rusty_record: Dictionary = rusty_result.get("record", {}) as Dictionary
	var route_error: String = inventory.route_reward(
		StringName(rusty_record.get("item_id", "")),
		int(rusty_record.get("quantity", 0))
	)
	_expect(
		route_error.is_empty()
		and inventory.get_key_quantity(&"shared_rusty_key") == 1
		and SOURCE_CATALOG.get_source(&"demo_map_item_cache").source_channel
		== RoomLootSourceDefinition.SourceChannel.MAP_ITEM_CACHE
		and SOURCE_CATALOG.get_source(&"l02_kept_watch_chain_oil").source_channel
		== RoomLootSourceDefinition.SourceChannel.ENCOUNTER_COMPLETION
		and SOURCE_CATALOG.get_source(&"wine_cellar_specific").source_channel
		== RoomLootSourceDefinition.SourceChannel.EVENT_ROOM_HOTSPOT,
		"Executable source channels must resolve canonically and route Keys to the Key Chain."
	)
	var generator := LayerMapGenerator.new()
	var generated_run := RunState.new()
	var generated_error: String = generated_run.initialize(
		27072026,
		generator.generate_layer_1(27072026),
		generator.make_layer_1_generated_room_item_rules(),
		_full_party_snapshot()
	)
	var generated_request: Dictionary = {}
	for requests_value: Variant in generated_run.generated_room_item_requests.values():
		if requests_value is Array and not (requests_value as Array).is_empty():
			generated_request = ((requests_value as Array)[0] as Dictionary)
			break
	_expect(
		generated_error.is_empty()
		and StringName(generated_request.get("source_id", ""))
		== &"layer_1_rusty_key_01"
		and StringName(generated_request.get("item_id", ""))
		== &"shared_rusty_key"
		and int(generated_request.get("quantity", 0)) == 1
		and int(generated_request.get("resolution_seed", 0)) > 0,
		"Generated Rusty Key placement must persist its fixed reward resolution against one host node."
	)


func _test_event_room_assignment_uses_shared_resolution() -> void:
	var room_screen := EventRoomScreen.new()
	room_screen.definition = load(
		"res://data/exploration/rooms/layer1/wine_cellar_warm_bottles.tres"
	) as EventRoomDefinition
	room_screen.instance_state = EventRoomInstanceState.new()
	room_screen.instance_state.source_node_id = &"event_room_test_node"
	room_screen.instance_state.generation_seed = 443322
	room_screen.available_item_catalog = ITEM_CATALOG
	room_screen.current_layer_number = 1
	var anchor := RoomItemSpawnAnchor.new()
	anchor.anchor_id = &"warm_bottle_anchor"
	anchor.anchor_tags = [&"bottle"]
	var anchors: Array[RoomItemSpawnAnchor] = [anchor]
	var assignments: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = room_screen.instance_state.generation_seed
	var assignment_error: String = room_screen._append_loot_source_assignments(
		assignments,
		anchors,
		SOURCE_CATALOG.get_source(&"wine_cellar_specific"),
		rng
	)
	var assignment: Dictionary = (
		assignments[0] as Dictionary if assignments.size() == 1 else {}
	)
	_expect(
		assignment_error.is_empty()
		and assignments.size() == 1
		and StringName(assignment.get("source_id", ""))
		== &"wine_cellar_specific"
		and StringName(assignment.get("item_id", ""))
		== &"l01_warm_wine_flask"
		and StringName(assignment.get("binding_id", ""))
		== &"event_room_test_node:wine_cellar_specific:draw_0"
		and int(assignment.get("resolution_seed", 0))
		== RewardSourceResolver.make_seed(
			443322,
			&"wine_cellar_specific",
			&"event_room_test_node:wine_cellar_specific:draw_0"
		),
		"Event-room loot assignment must retain the shared deterministic reward record."
	)
	room_screen.free()
	anchor.free()


func _test_material_rewards_route_once_to_material_pouch() -> void:
	var source_items: Dictionary = {
		&"l01_wax_prep_red_wax_material": &"mat_l01_red_wax",
		&"l01_linen_sorting_servant_cloth": &"mat_l01_servant_cloth",
		&"l02_polished_gallery_chain_links": &"mat_l02_chain_links",
		&"l02_punishment_room_prison_iron": &"mat_l02_prison_iron",
	}
	var inventory := RunInventoryState.new()
	inventory.initialize(ITEM_CATALOG, [&"lysandra", &"mira", &"seraphine"], true)
	var routed_all := true
	for source_value: Variant in source_items.keys():
		var source_id := StringName(source_value)
		var item_id := StringName(source_items[source_value])
		var item: ItemDefinition = ITEM_CATALOG.get_item(item_id)
		var resolution: Dictionary = RewardSourceResolver.resolve(
			SOURCE_CATALOG.get_source(source_id),
			ITEM_CATALOG,
			item.layer,
			27072026,
			StringName("material_test_%s" % source_id)
		)
		var record: Dictionary = resolution.get("record", {}) as Dictionary
		var route_error: String = inventory.route_reward(
			StringName(record.get("item_id", "")),
			int(record.get("quantity", 0))
		)
		routed_all = (
			routed_all
			and String(resolution.get("error", "")).is_empty()
			and route_error.is_empty()
			and int(inventory.material_pouch.get(String(item_id), 0)) == 1
		)

	var generator := LayerMapGenerator.new()
	var binding_rooms: Dictionary = {
		&"wax_prep_room": &"l01_wax_prep_red_wax_material",
		&"linen_sorting_room": &"l01_linen_sorting_servant_cloth",
		&"polished_shackle_gallery": &"l02_polished_gallery_chain_links",
		&"punishment_mechanism_room": &"l02_punishment_room_prison_iron",
	}
	var bindings_valid := true
	for room_value: Variant in binding_rooms.keys():
		var room_id := StringName(room_value)
		var node := MapNodeState.new()
		generator._configure_registered_room_content(
			node,
			generator.room_catalog.get_room(room_id)
		)
		bindings_valid = (
			bindings_valid
			and node.room_definition_id == room_id
			and node.reward_source_id == binding_rooms[room_value]
		)

	var run := RunState.new()
	var initialize_error: String = run.initialize(
		27072026,
		generator.generate_layer_1(27072026),
		generator.make_layer_1_generated_room_item_rules(),
		_full_party_snapshot()
	)
	var wax_node: MapNodeState = _get_authored_node(
		run.graph,
		&"wax_prep_room"
	)
	var first_claim: Dictionary = run._resolve_and_route_node_reward(wax_node)
	var second_claim: Dictionary = run._resolve_and_route_node_reward(wax_node)
	_expect(
		routed_all
		and bindings_valid
		and initialize_error.is_empty()
		and bool(first_claim.get("claimed", false))
		and bool(second_claim.get("claimed", false))
		and int(run.run_inventory.material_pouch.get("mat_l01_red_wax", 0)) == 1,
		"Authored Material rewards must route to the shared Material Pouch exactly once."
	)


func _test_deterministic_current_layer_weighting() -> void:
	var source: RoomLootSourceDefinition = SOURCE_CATALOG.get_source(
		&"demo_map_item_cache"
	)
	var l1_entry: RoomItemPoolEntryDefinition = source.pool.get_entry(
		&"l01_bandage_cache"
	)
	var l2_entry: RoomItemPoolEntryDefinition = source.pool.get_entry(
		&"l02_poultice_cache"
	)
	var first: Dictionary = RewardSourceResolver.resolve(
		source, ITEM_CATALOG, 1, 99173, &"stable_map_node"
	)
	var second: Dictionary = RewardSourceResolver.resolve(
		source, ITEM_CATALOG, 1, 99173, &"stable_map_node"
	)
	_expect(
		RewardSourceResolver.get_effective_weight(l1_entry, 1) == 3
		and RewardSourceResolver.get_effective_weight(l2_entry, 1) == 1
		and RewardSourceResolver.get_effective_weight(l1_entry, 2) == 1
		and RewardSourceResolver.get_effective_weight(l2_entry, 2) == 3
		and first == second,
		"Current-layer entries must receive exactly ×3 base weight and fixed inputs must resolve identically."
	)


func _test_deferred_claim_round_trip_and_no_duplicate() -> void:
	var run: RunState = _make_layer_2_run(8128)
	var full_ids: Array[StringName] = [
		&"l01_bandage_roll",
		&"l01_smelling_salts",
		&"l01_warm_wine_flask",
		&"l01_servants_tonic",
		&"l01_red_wax_ampoule",
		&"l01_kitchen_knife",
	]
	var quantities: Array[int] = [1, 1, 1, 1, 1, 1]
	run.run_inventory.restore_item_bar_snapshot(
		_make_item_bar_snapshot(full_ids, quantities)
	)
	run.select_node(&"l2_c1_n0")
	var travel_error: String = run.travel_to(&"l2_c1_n0")
	var outcome := EncounterOutcome.new()
	outcome.result = EncounterOutcome.Result.VICTORY
	outcome.encounter_id = LayerMapGenerator.LAYER_2_FIRST_SLICE_ENCOUNTER_ID
	outcome.source_node_id = &"l2_c1_n0"
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.bloom_reward = 4
	var apply_error: String = run.apply_encounter_outcome(outcome)
	var node: MapNodeState = run.graph.get_map_node(&"l2_c1_n0")
	var record_key: String = RewardSourceResolver.make_record_key(
		&"l02_kept_watch_chain_oil",
		&"l2_c1_n0"
	)
	var deferred_record: Dictionary = run.reward_resolutions.get(
		record_key,
		{}
	) as Dictionary
	var active_snapshot: Dictionary = run.make_active_run_snapshot(
		"post_node",
		KnowledgeState.new()
	)
	var restored := RunState.new()
	var restore_error: String = restored.restore_active_run_snapshot(
		active_snapshot,
		BATTLER_CATALOG
	)
	var remove_error: String = restored.run_inventory.remove_from_item_bar(
		&"l01_kitchen_knife",
		1
	)
	var retry: Dictionary = restored.retry_deferred_reward(&"l2_c1_n0")
	var retry_again: Dictionary = restored.retry_deferred_reward(&"l2_c1_n0")
	_expect(
		travel_error.is_empty()
		and apply_error.is_empty()
		and node.cleared
		and not node.reward_claimed
		and run.bloom == 4
		and bool(deferred_record.get("deferred", false))
		and not bool(deferred_record.get("claimed", true))
		and restore_error.is_empty()
		and remove_error.is_empty()
		and String(retry.get("error", "")).is_empty()
		and bool(retry.get("claimed", false))
		and bool(retry_again.get("already_claimed", false))
		and _item_bar_quantity(restored, &"l02_chain_oil") == 1
		and restored.bloom == 4,
		"A full Item Bar must defer one fixed resolution, round-trip it, and claim exactly once without duplicating Bloom."
	)


func _test_invalid_sources_and_destinations() -> void:
	var rejected_items: Array[ItemDefinition] = [
		ITEM_CATALOG.get_item(&"quiet_cell_blanket"),
		ITEM_CATALOG.get_item(&"l01_torn_cuff"),
		ITEM_CATALOG.get_item(&"l01_courtesy_collar"),
	]
	for item: ItemDefinition in rejected_items:
		var source: RoomLootSourceDefinition = _make_test_source(item)
		var result: Dictionary = RewardSourceResolver.resolve(
			source, ITEM_CATALOG, 1, 1234, &"invalid_entry"
		)
		_expect(
			not String(result.get("error", "")).is_empty(),
			"Unavailable/legacy/unowned item '%s' must be rejected." % item.item_id
		)
	var wrong_layer: Dictionary = RewardSourceResolver.resolve(
		SOURCE_CATALOG.get_source(&"wine_cellar_specific"),
		ITEM_CATALOG,
		2,
		1234,
		&"wrong_layer"
	)
	var duplicate_catalog := RewardSourceCatalogDefinition.new()
	var duplicate_source: RoomLootSourceDefinition = SOURCE_CATALOG.get_source(
		&"wine_cellar_specific"
	)
	duplicate_catalog.sources = [duplicate_source, duplicate_source]
	var malformed_entry := RoomItemPoolEntryDefinition.new()
	malformed_entry.entry_id = &"bad_quantity"
	malformed_entry.item = ITEM_CATALOG.get_item(&"l01_bandage_roll")
	malformed_entry.world_texture = malformed_entry.item.icon
	malformed_entry.quantity = 0
	var malformed_pool := RoomItemPoolDefinition.new()
	malformed_pool.pool_id = &"malformed_pool"
	malformed_pool.entries = [malformed_entry]
	var malformed_source := RoomLootSourceDefinition.new()
	malformed_source.source_id = &"malformed_source"
	malformed_source.source_channel = RoomLootSourceDefinition.SourceChannel.MAP_ITEM_CACHE
	malformed_source.eligible_layers = [1]
	malformed_source.pool = malformed_pool
	_expect(
		not String(wrong_layer.get("error", "")).is_empty()
		and not duplicate_catalog.validate_catalog(ITEM_CATALOG).is_empty()
		and not malformed_source.validate_definition().is_empty(),
		"Wrong layers, duplicate source IDs, and malformed quantities must reject structurally."
	)


func _test_malformed_snapshot_is_transactional_and_m8_compatible() -> void:
	var source_run: RunState = _make_layer_2_run(9911)
	source_run.select_node(&"l2_c1_n0")
	source_run.travel_to(&"l2_c1_n0")
	var resolution: Dictionary = source_run.resolve_pending_node_reward()
	source_run.complete_pending_node(4, bool(resolution.get("claimed", false)))
	var snapshot: Dictionary = source_run.make_active_run_snapshot(
		"post_node",
		KnowledgeState.new()
	)
	var malformed: Dictionary = snapshot.duplicate(true)
	var malformed_run: Dictionary = malformed.get("run_snapshot", {}) as Dictionary
	var malformed_records: Dictionary = malformed_run.get(
		"reward_resolutions",
		{}
	) as Dictionary
	var record_key: Variant = malformed_records.keys()[0]
	var bad_record: Dictionary = malformed_records[record_key] as Dictionary
	bad_record["item_id"] = "not_a_canonical_item"
	var target: RunState = _make_layer_2_run(9912)
	target.bloom = 77
	var before_graph: Dictionary = target.graph.to_snapshot()
	var before_inventory: Dictionary = target.run_inventory.get_snapshot()
	var malformed_error: String = target.restore_active_run_snapshot(
		malformed,
		BATTLER_CATALOG
	)
	var m8_snapshot: Dictionary = snapshot.duplicate(true)
	var m8_run: Dictionary = m8_snapshot.get("run_snapshot", {}) as Dictionary
	m8_run.erase("reward_resolutions")
	var map_snapshot: Dictionary = m8_snapshot.get("map_snapshot", {}) as Dictionary
	var graph_snapshot: Dictionary = map_snapshot.get("graph", {}) as Dictionary
	var node_snapshots: Array = graph_snapshot.get("nodes", []) as Array
	for node_value: Variant in node_snapshots:
		if not (node_value is Dictionary):
			continue
		var node_snapshot: Dictionary = node_value as Dictionary
		node_snapshot.erase("reward_source_id")
		if StringName(node_snapshot.get("node_id", "")) == &"l2_c1_n0":
			node_snapshot["first_clear_item_id"] = "l02_chain_oil"
			node_snapshot["first_clear_item_quantity"] = 1
			node_snapshot["first_clear_item_stack_limit"] = 3
	var compatible := RunState.new()
	var compatibility_error: String = compatible.restore_active_run_snapshot(
		m8_snapshot,
		BATTLER_CATALOG
	)
	var legacy_item_node := MapNodeState.new()
	legacy_item_node.node_id = &"legacy_item_node"
	legacy_item_node.node_type = MapNodeState.NodeType.ITEM
	legacy_item_node.display_name = "Legacy Item"
	legacy_item_node.reward_source_id = &"demo_map_item_cache"
	var legacy_item_snapshot: Dictionary = legacy_item_node.to_snapshot()
	legacy_item_snapshot.erase("reward_source_id")
	var legacy_item_restore: Dictionary = MapNodeState.from_snapshot(
		legacy_item_snapshot
	)
	var restored_legacy_item: MapNodeState = legacy_item_restore.get(
		"node"
	) as MapNodeState
	_expect(
		not malformed_error.is_empty()
		and target.bloom == 77
		and target.graph.to_snapshot() == before_graph
		and target.run_inventory.get_snapshot() == before_inventory
		and compatibility_error.is_empty()
		and compatible.reward_resolutions.is_empty()
		and compatible.graph.get_map_node(&"l2_c1_n0").reward_source_id
		== &"l02_kept_watch_chain_oil",
		"Malformed reward records must restore transactionally while Milestone 8 snapshots migrate narrowly."
	)
	_expect(
		String(legacy_item_restore.get("error", "")).is_empty()
		and restored_legacy_item != null
		and restored_legacy_item.reward_source_id == &"m8_compat_bandage_cache",
		"An unresolved Milestone 8 Item node must retain its fixed Bandage source."
	)


func _make_layer_2_run(seed: int) -> RunState:
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		seed,
		LayerMapGenerator.new().generate_layer_2_run(seed),
		[],
		_full_party_snapshot()
	)
	_expect(initialize_error.is_empty(), "Reward-source test run must initialize.")
	run.opening_completed = true
	return run


func _get_authored_node(
	graph: LayerMapGraph,
	room_id: StringName
) -> MapNodeState:
	if graph == null:
		return null
	for value: Variant in graph.nodes.values():
		var node: MapNodeState = value as MapNodeState
		if node.authored_room_id == room_id:
			return node
	return null


func _make_test_source(item: ItemDefinition) -> RoomLootSourceDefinition:
	var entry := RoomItemPoolEntryDefinition.new()
	entry.entry_id = &"test_entry"
	entry.item = item
	entry.world_texture = item.icon
	entry.required_anchor_tag = &"small_item"
	var pool := RoomItemPoolDefinition.new()
	pool.pool_id = &"test_pool"
	pool.entries = [entry]
	var source := RoomLootSourceDefinition.new()
	source.source_id = &"test_source"
	source.source_channel = RoomLootSourceDefinition.SourceChannel.MAP_ITEM_CACHE
	source.eligible_layers = [1, 2]
	source.pool = pool
	source.minimum_draws = 1
	source.maximum_draws = 1
	return source


func _full_party_snapshot() -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(10, 4, 75, 8),
		&"mira": _heroine_snapshot(9, 6, 72, 12),
		&"seraphine": _heroine_snapshot(8, 8, 80, 4),
	}


func _heroine_snapshot(hp: int, mp: int, resolve: int, corruption: int) -> Dictionary:
	return {
		"hp": hp, "mp": mp, "resolve": resolve, "corruption": corruption,
		"item_guard": 0, "weapon_damage": 0, "weapon_broken": false,
		"armor_damage": 0, "armor_broken": false,
		"shield_damage": 0, "shield_broken": false,
	}


func _make_item_bar_snapshot(
	item_ids: Array[StringName],
	quantities: Array[int]
) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for slot_index: int in range(RunInventoryState.ITEM_BAR_SLOT_COUNT):
		snapshot.append({
			"slot_index": slot_index,
			"item_id": String(item_ids[slot_index]),
			"quantity": quantities[slot_index],
		})
	return snapshot


func _item_bar_quantity(run: RunState, item_id: StringName) -> int:
	var quantity: int = 0
	for slot: Dictionary in run.inventory_snapshot:
		if StringName(slot.get("item_id", "")) == item_id:
			quantity += int(slot.get("quantity", 0))
	return quantity


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
