extends "res://tests/test_inventory_transfers.gd"
var checks: int = 0
var generator := LayerMapGenerator.new()

func check(ok: bool, message: String) -> void:
	checks += 1
	_expect(ok, message)

func _run() -> void:
	_test_entitlements()
	_test_unused_and_permanent_departures()
	_test_memory()
	for layer: int in [1, 2]:
		for defeat: bool in [false, true]:
			_test_expedition(layer, defeat)
	_test_current_locks_and_thresholds()
	_test_compatibility()
	print("Stage 23 Castle Memory / Passage: %d checks, %d failures." % [checks, failures])
	quit(failures)

func _test_entitlements() -> void:
	_fixture()
	run.bloom = 50000
	run.campaign_lifecycle.defeated_boss_ids.clear()
	check(not run.is_passage_eligible(1) and not run.is_passage_eligible(2), "Floor access alone never qualifies")
	check(not String(controller.purchase_intel(&"conquerors_passage", false, 100, 1).error).is_empty(), "Undefeated boss rejects purchase")
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	run.campaign_lifecycle.mark_boss_defeated(RunState.JAILER_BOSS_ID)
	check(not run.is_passage_eligible(3), "Later floors remain unavailable")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	fail_save = true
	check(not String(controller.purchase_intel(&"conquerors_passage", false, 100, 1).error).is_empty() and run.bloom == 50000 and run.refuge_ownership.to_snapshot() == before, "Failed save rolls back layer purchase and selection")
	fail_save = false
	check(not String(controller.purchase_intel(&"conquerors_passage", false, 100, 2).error).is_empty(), "Layer price must match selected layer")
	check(String(controller.purchase_intel(&"conquerors_passage", false, 100, 1).error).is_empty(), "Buy Layer 1 for 100")
	check(String(controller.purchase_intel(&"conquerors_passage", false, 200, 2).error).is_empty() and run.bloom == 49700, "Buy Layer 2 for 200")
	check(String(controller.purchase_intel(&"conquerors_passage", false, 100, 1).error).is_empty() and run.bloom == 49700, "Identical entitlement never recharges")
	check(String(controller.select_passage(0).error).is_empty() and run.refuge_ownership.pending_passage_layers.size() == 2, "Normal departure selection retains both paid shortcuts")
	check(String(controller.purchase_intel(&"conquerors_passage", true, 10000, 1).error).is_empty() and run.bloom == 39700, "Permanent layer price is 100x")
	check(run.refuge_ownership.permanent_passage_layers == [1], "Permanent Layer 1 never unlocks Layer 2")
	check(String(controller.purchase_intel(&"conquerors_passage", false, 100, 1).error).is_empty() and run.bloom == 39700, "Permanent prevents repurchase")
	check(String(controller.purchase_intel(&"castle_memory", false, 10).error).is_empty(), "Memory approved temporary price")
	check(String(controller.purchase_intel(&"castle_memory", true, 1000).error).is_empty(), "Memory approved permanent price")
	check(String(controller.select_passage(2).error).is_empty(), "Select paid Layer 2")
	var restored := RefugeOwnershipState.new()
	check(restored.restore_from_snapshot(JSON.parse_string(JSON.stringify(run.refuge_ownership.to_snapshot())), ITEMS, BATTLERS, HEROES).is_empty() and restored.selected_passage_layer == 2 and restored.pending_passage_layers == [1, 2], "Layer entitlements and selection survive JSON")
	var transfer: Dictionary = restored.make_run_start_transfer()
	check(transfer.error.is_empty() and transfer.refuge_state.pending_passage_layers == [1] and transfer.refuge_state.permanent_passage_layers == [1], "Departure consumes only corresponding temporary layer")

func _test_memory() -> void:
	for layer: int in [1, 2]:
		for seed_value: int in range(1, 11):
			var old: LayerMapGraph = CastleLayoutMemory.generate(generator, layer, seed_value, [])
			var known_id: StringName = old.get_nodes_in_column(3)[0].node_id
			for node: MapNodeState in old.nodes.values():
				node.type_known = node.node_id == known_id
				node.visited = true
				node.cleared = true
				node.exit_completed = true
				node.solved = true
				node.encounter_cleared = true
				node.rest_used = true
				node.reward_claimed = true
			for edge: Dictionary in old.edge_states.values():
				edge.known = true
				edge.unlocked = false
				edge.hidden = true
			var previous: Dictionary = old.to_snapshot()
			var boss_id: StringName = RunState.BLOOD_NUN_BOSS_ID if layer == 1 else RunState.JAILER_BOSS_ID
			var fresh: LayerMapGraph = CastleLayoutMemory.generate(generator, layer, seed_value + 500, [boss_id], previous)
			check(fresh != null and old.to_snapshot() == previous, "Memory generation leaves archived snapshot untouched")
			if fresh == null: continue
			check(fresh.layout_seed == seed_value and fresh.run_seed != old.run_seed and fresh.reserved_node_types == old.reserved_node_types, "Layout identity and content seed are independent")
			for node: MapNodeState in fresh.nodes.values():
				var prior: MapNodeState = old.get_map_node(node.node_id)
				check(node.column == prior.column and node.row == prior.row and node.node_type == prior.node_type and node.outgoing_ids == prior.outgoing_ids and node.incoming_ids == prior.incoming_ids and node.authored_room_id == prior.authored_room_id, "Placements/types/room identities/topology retained")
				check(node.type_known == prior.type_known and node.content_seed != prior.content_seed, "Only discovered types remembered; content randomness refreshed")
				if node.node_id not in [fresh.start_node_id, fresh.boss_node_id]:
					check(not node.visited and not node.solved and not node.cleared and not node.encounter_cleared and not node.exit_completed and not node.reward_claimed and not node.rest_used, "New rooms retain no completion or resource-use state")
				if node.node_type == MapNodeState.NodeType.REST:
					check(node.rest_offer_id == RoomRestRules.assigned_offer(node.content_seed, node.node_id), "Rest offer uses fresh content seed")
			var boss: MapNodeState = fresh.get_map_node(fresh.boss_node_id)
			check(boss.cleared and boss.solved and not boss.has_encounter_content(), "Permanent boss remains dead")
			for edge: Dictionary in fresh.edge_states.values():
				check(edge.known and edge.unlocked and not edge.hidden, "Known routes retained with current authored accessibility")
			var again: LayerMapGraph = CastleLayoutMemory.generate(generator, layer, fresh.run_seed, [boss_id], fresh.to_snapshot())
			check(again.run_seed != fresh.run_seed and again.layout_seed == fresh.layout_seed, "Repeated entered seed still refreshes content without layout drift")
			check(LayerMapGraph.from_snapshot(JSON.parse_string(JSON.stringify(fresh.to_snapshot()))).graph.to_snapshot() == fresh.to_snapshot(), "Remembered graph JSON round-trip exact")

func _test_expedition(layer: int, defeat: bool) -> void:
	_fixture()
	run.bloom = 50000
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	run.campaign_lifecycle.mark_boss_defeated(RunState.JAILER_BOSS_ID)
	check(String(controller.purchase_intel(&"conquerors_passage", false, 100, 1).error).is_empty(), "Buy L1")
	check(String(controller.purchase_intel(&"conquerors_passage", false, 200, 2).error).is_empty(), "Buy L2")
	check(String(controller.select_passage(layer).error).is_empty(), "Select expedition")
	check(String(controller.purchase_intel(&"castle_memory", false, 10).error).is_empty(), "Buy memory")
	var old: LayerMapGraph = CastleLayoutMemory.generate(generator, layer, 412, run.get_defeated_boss_ids())
	old.get_nodes_in_column(3)[0].type_known = true
	CastleLayoutMemory.remember(run.refuge_ownership.castle_layouts, old)
	var inventory: Dictionary = run.refuge_ownership.make_run_start_transfer().run_inventory.get_snapshot()
	check(String(controller.apply_party_order([&"lysandra"], run.refuge_ownership.selected_party_ids).error).is_empty(), "Apply solo party")
	inventory = run.refuge_ownership.make_run_start_transfer().run_inventory.get_snapshot()
	var progress: Dictionary = run.heroine_progression_snapshot.duplicate(true)
	var next: LayerMapGraph = run.generate_prepared_expedition(generator, 999)
	var item_rules: Array[GeneratedRoomItemPlacementRule] = []
	if layer == 1:
		item_rules = generator.make_layer_1_generated_room_item_rules()
	check(run.begin_next_layer_2_run(next, item_rules).is_empty(), "Boss departure succeeds")
	check(run.current_node_id == next.boss_node_id and run.bloom == 0 and run.heroine_progression_snapshot == progress and run.run_inventory.get_snapshot() == inventory, "Boss entry grants no rewards/XP/resources and uses normal selected preparation")
	check(run.event_room_snapshots.is_empty() and run.reward_resolutions.is_empty(), "All room contents and traps will be newly instantiated")
	check(not run.generated_room_item_requests.is_empty() if layer == 1 else run.generated_room_item_requests.is_empty(), "Layer 1 key placement is freshly authored, never pre-collected")
	for node: MapNodeState in next.nodes.values():
		if node.node_id != next.boss_node_id:
			check(not node.visited and not node.solved and not node.reward_claimed, "Skipped node remains unvisited, unsolved and unrewarded")
	var preceding: StringName = next.connected_ids(next.boss_node_id)[0]
	check(run.can_travel_to(preceding), "Can backtrack from boss to actual adjacent room")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(run.make_active_run_snapshot("post_node", KnowledgeState.new())))
	var restored := RunState.new()
	var restore_error: String = restored.restore_active_run_snapshot(snapshot, BATTLERS)
	check(restore_error.is_empty(), "Continue boss start: " + restore_error)
	if not restore_error.is_empty(): return
	check(JSON.parse_string(JSON.stringify(restored.generated_room_item_requests)) == JSON.parse_string(JSON.stringify(run.generated_room_item_requests)), "Continue retains every generated key placement field through JSON")
	check(restored.current_node_id == next.boss_node_id and restored.refuge_ownership.pending_passage_layers == [3-layer] and restored.graph.to_snapshot() == next.to_snapshot(), "Continue keeps same map/knowledge and only unused entitlement")
	if layer == 1:
		restored.pending_node_id = &"l1_c5_n0"
		var encounter: EncounterDefinition = restored.make_encounter_definition()
		check(encounter != null and encounter.party_ids == [&"lysandra"], "Skipped recruitment never injects inactive heroine")
		restored.pending_node_id = &""
		restored.pending_node_seed = 0
	var error: String
	if defeat:
		var outcome := EncounterOutcome.new()
		outcome.result = EncounterOutcome.Result.DEFEAT
		outcome.encounter_id = &"fixture:memory_defeat"
		outcome.source_node_id = restored.current_node_id
		outcome.party_snapshot = restored.party_snapshot.duplicate(true)
		outcome.inventory_snapshot = restored.inventory_snapshot.duplicate(true)
		for id: Variant in outcome.party_snapshot: outcome.party_snapshot[id].hp = 0
		error = restored.apply_post_refuge_defeat(outcome, generator.generate_bloom_refuge_holding_state(999), BATTLERS)
	else:
		error = restored.return_current_run_to_refuge(generator.generate_bloom_refuge_holding_state(999), BATTLERS)
	check(error.is_empty(), "Return/defeat retains memory: " + error)
	check(restored.refuge_ownership.castle_layouts[String(next.layer_id)].run_seed == next.run_seed and restored.refuge_ownership.pending_passage_layers == [3-layer] and not restored.get_run_intel_ids().has(&"castle_memory"), "End preserves latest layout and unused Passage while temporary Memory expires")

func _test_compatibility() -> void:
	_fixture()
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	var restored := RefugeOwnershipState.new()
	for field: String in ["pending_passage_layers", "permanent_passage_layers", "selected_passage_layer", "castle_layouts"]:
		for value: Variant in [null, "bad", [3], [1,1], {"layer_3":{}}]:
			var bad: Dictionary = before.duplicate(true)
			bad[field] = value
			check(not restored.restore_from_snapshot(bad, ITEMS, BATTLERS, HEROES).is_empty(), "Malformed expedition fields reject")
		before.erase(field)
	check(restored.restore_from_snapshot(before, ITEMS, BATTLERS, HEROES).is_empty() and restored.castle_layouts.is_empty() and restored.pending_passage_layers.is_empty(), "Old saves load with no invented memory or purchases")


func _test_current_locks_and_thresholds() -> void:
	_fixture()
	var layouts: Dictionary = {}
	CastleLayoutMemory.remember(layouts, generator.generate_layer_2_entry(77))
	check(layouts.is_empty(), "Transient story threshold never replaces a full castle layout")
	run.bloom = 5000
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	check(String(controller.purchase_intel(&"conquerors_passage", false, 100, 1).error).is_empty(), "Lock fixture Passage")
	check(String(controller.purchase_intel(&"castle_memory", true, 1000).error).is_empty(), "Permanent memory fixture")
	var old: LayerMapGraph = generator.generate_layer_1(99, run.get_defeated_boss_ids())
	for edge: Dictionary in old.edge_states.values():
		edge.known = true
		edge.unlocked = true
	CastleLayoutMemory.remember(run.refuge_ownership.castle_layouts, old)
	var fresh: LayerMapGraph = run.generate_prepared_expedition(generator, 100)
	var found_lock: bool = false
	for node: MapNodeState in fresh.nodes.values():
		if node.room_definition_id != &"wine_cellar_warm_bottles": continue
		for target: StringName in node.outgoing_ids:
			var edge: Dictionary = fresh.edge_states[fresh.edge_id(node.node_id, target)]
			check(edge.known and not edge.unlocked and not fresh.is_connection_accessible(node.node_id, target), "Remembered open door is known but relocked by current authoring")
			found_lock = true
	check(found_lock, "Authored Wine Cellar door lock exercised")


func _test_unused_and_permanent_departures() -> void:
	_fixture()
	run.bloom = 30000
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	run.campaign_lifecycle.mark_boss_defeated(RunState.JAILER_BOSS_ID)
	check(String(controller.purchase_intel(&"conquerors_passage", false, 100, 1).error).is_empty(), "Prepare unused Layer 1 Passage")
	check(String(controller.purchase_intel(&"conquerors_passage", true, 20000, 2).error).is_empty(), "Buy permanent Layer 2 for 20,000")
	check(String(controller.select_passage(0).error).is_empty(), "Choose normal departure after purchases")
	check(run.begin_next_layer_2_run(run.generate_prepared_expedition(generator, 180)).is_empty(), "Ordinary expedition still begins at Farthest Cell")
	check(run.current_node_id == &"l2_refuge_farthest_cell" and run.refuge_ownership.pending_passage_layers == [1] and run.refuge_ownership.permanent_passage_layers == [2], "Ordinary departure consumes no unused Passage")
	check(run.return_current_run_to_refuge(generator.generate_bloom_refuge_holding_state(180), BATTLERS).is_empty(), "Return from ordinary expedition")
	check(run.refuge_ownership.pending_passage_layers == [1] and run.refuge_ownership.permanent_passage_layers == [2], "Unused paid Passage outlives unrelated expedition")
	for seed_value: int in [181, 182]:
		check(String(controller.select_passage(2).error).is_empty(), "Select permanent boss departure again")
		check(run.begin_next_layer_2_run(run.generate_prepared_expedition(generator, seed_value)).is_empty() and run.current_node_id == run.graph.boss_node_id, "Permanent Passage works repeatedly with no new payment")
		check(run.return_current_run_to_refuge(generator.generate_bloom_refuge_holding_state(seed_value), BATTLERS).is_empty(), "Return from permanent Passage")
		check(run.refuge_ownership.permanent_passage_layers == [2] and run.refuge_ownership.pending_passage_layers == [1], "Permanent and unused temporary rights remain distinct")
