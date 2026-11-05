extends "res://tests/test_inventory_transfers.gd"
const INTEL = preload("res://data/intel/intel_catalog.tres")
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	_expect(ok,message)

func _run() -> void:
	CampaignSaveSlotStore.set_test_save_directory("user://stage22_state")
	_test_purchases()
	_test_intel_maps()
	for defeated: bool in [false,true]:
		_test_lifecycle(defeated)
	CampaignSaveSlotStore.force_test_write_failure = false
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 22 Intel state: %d checks, %d failures." % [checks,failures])
	quit(failures)

func _test_purchases() -> void:
	_fixture()
	run.bloom = 5000
	controller.bind(run,BATTLERS,func() -> String: return CampaignSaveSlotStore.save_refuge_slot(1,run,KnowledgeState.new()))
	check(CampaignSaveSlotStore.save_refuge_slot(1,run,KnowledgeState.new()).is_empty(),"Initial Refuge saved")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	var document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	CampaignSaveSlotStore.force_test_write_failure = true
	check(not String(controller.purchase_intel(&"scouting",false,10).error).is_empty() and run.bloom == 5000 and run.refuge_ownership.to_snapshot() == before,"Failed purchase write rolls back wallet and ownership")
	check(CampaignSaveSlotStore.read_document_for_load(1).document == document,"Failed purchase preserves durable document")
	CampaignSaveSlotStore.force_test_write_failure = false
	for option: IntelOptionDefinition in INTEL.options:
		if option.effect in [IntelOptionDefinition.Effect.CASTLE_MEMORY, IntelOptionDefinition.Effect.CONQUEROR_PASSAGE]:
			continue
		if not option.available:
			check(not String(controller.purchase_intel(option.option_id,false,0).error).is_empty(),"Unsupported Stage 23 shell cannot charge")
			continue
		if option.permanent_only:
			check(not String(controller.purchase_intel(option.option_id,false,100).error).is_empty(),"Submit has no temporary purchase")
			continue
		check(option.price(true) == option.price(false)*100 and option.provisional_price,"Permanent counterpart uses configured 100x price")
		check(String(controller.purchase_intel(option.option_id,false,10).error).is_empty(),"Supported option buys immediately")
	check(run.bloom == 4930 and run.refuge_ownership.pending_intel.size() == 7,"Exactly seven one-run charges")
	check(String(controller.purchase_intel(&"scouting",false,10).error).is_empty() and run.bloom == 4930,"Duplicate purchase is free no-op")
	check(not String(controller.purchase_intel(&"scouting",true,999).error).is_empty() and run.bloom == 4930,"Stale price rejects")
	check(String(controller.purchase_intel(&"scouting",true,1000).error).is_empty() and run.bloom == 3930,"Permanent purchase paid exactly once")
	check(String(controller.purchase_intel(&"submit",true,100).error).is_empty() and run.bloom == 3830,"Separate permanent Submit price")
	check(String(controller.purchase_intel(&"scouting",false,10).error).is_empty() and run.bloom == 3830,"Permanent ownership prevents repurchase")
	run.bloom = 9
	before = run.refuge_ownership.to_snapshot()
	check(not String(controller.purchase_intel(&"battle_sense",true,1000).error).is_empty() and run.bloom == 9 and run.refuge_ownership.to_snapshot() == before,"Insufficient Bloom is atomic")
	var restored := RefugeOwnershipState.new()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(before))
	check(restored.restore_from_snapshot(snapshot,ITEMS,BATTLERS,HEROES).is_empty() and restored.pending_intel.size() == 7 and restored.permanent_intel.size() == 2,"Purchased ownership survives JSON")
	for field: String in ["pending_intel","permanent_intel"]:
		for bad: Variant in [null,{},[1],["missing"],["scouting","scouting"],["conquerors_passage"]]:
			var invalid: Dictionary = snapshot.duplicate(true)
			invalid[field] = bad
			var intact: Dictionary = restored.to_snapshot()
			check(not restored.restore_from_snapshot(invalid,ITEMS,BATTLERS,HEROES).is_empty() and restored.to_snapshot() == intact,"Malformed Intel ownership rejects without mutation")
	snapshot.erase("pending_intel")
	snapshot.erase("permanent_intel")
	check(restored.restore_from_snapshot(snapshot,ITEMS,BATTLERS,HEROES).is_empty() and restored.pending_intel.is_empty() and restored.permanent_intel.is_empty(),"Legacy absence defaults unowned")

func _fresh_map(seed: int) -> LayerMapGraph:
	var graph: LayerMapGraph = LayerMapGenerator.new().generate_layer_1(seed)
	for node: MapNodeState in graph.nodes.values():
		node.type_known = false
	for edge: Dictionary in graph.edge_states.values():
		edge.known = false
	return graph

func _test_intel_maps() -> void:
	for seed: int in range(1,21):
		for option: IntelOptionDefinition in INTEL.options:
			if not option.available or option.permanent_only:
				continue
			var graph: LayerMapGraph = _fresh_map(seed)
			var before: Dictionary = graph.to_snapshot()
			IntelMapEffects.apply(graph,[option.option_id],graph.start_node_id)
			for node: MapNodeState in graph.nodes.values():
				if option.effect in [IntelOptionDefinition.Effect.BATTLE_SENSE,IntelOptionDefinition.Effect.SANCTUARY,IntelOptionDefinition.Effect.DANGER,IntelOptionDefinition.Effect.ARTISAN]:
					var types: Dictionary = {1:[MapNodeState.NodeType.BATTLE,MapNodeState.NodeType.ELITE],4:[MapNodeState.NodeType.REST],5:[MapNodeState.NodeType.TRAP],6:[MapNodeState.NodeType.ALCHEMY,MapNodeState.NodeType.WORKSHOP]}
					check(node.type_known == (node.node_type in types[option.effect]),"Type benefit identifies exactly its room types")
					check(graph.edge_states == before.edge_states,"Type knowledge never discloses routes")
				if option.effect == IntelOptionDefinition.Effect.PATHFINDING:
					check(not node.type_known,"Pathfinding never identifies room types")
			var first: Dictionary = graph.to_snapshot()
			IntelMapEffects.apply(graph,[option.option_id],graph.start_node_id)
			check(graph.to_snapshot() == first,"Knowledge grants are idempotent and Treasury choice stable")
			var roundtrip: Dictionary = LayerMapGraph.from_snapshot(JSON.parse_string(JSON.stringify(first)))
			check(roundtrip.error.is_empty() and roundtrip.graph.to_snapshot() == first,"Intel map knowledge and normalized reservation IDs round-trip exactly")
	# Exercise every combination, preserving discovery and physical route restrictions.
	var ids: Array[StringName] = [&"scouting",&"battle_sense",&"smell_of_a_coin",&"pathfinding",&"sanctuary_sense",&"danger_sense",&"artisans_eye"]
	for bits: int in range(128):
		var graph: LayerMapGraph = _fresh_map(42)
		var chosen: Array[StringName] = []
		for i: int in range(7):
			if bits & (1 << i): chosen.append(ids[i])
		var a: StringName = graph.start_node_id
		var b: StringName = graph.connected_ids(a)[0]
		graph.edge_states[graph.edge_id(a,b)].unlocked = false
		graph.edge_states[graph.edge_id(a,b)].hidden = true
		graph.get_map_node(a).type_known = true
		IntelMapEffects.apply(graph,chosen,a)
		check(graph.get_map_node(a).type_known and not graph.is_connection_accessible(a,b),"Combined knowledge never erases discoveries or bypasses hidden/locked passages")
		if chosen.has(&"pathfinding"):
			check(graph.is_connection_known(a,b),"Pathfinding can show a blocked connection without granting passage")
		check(LayerMapGraph.from_snapshot(graph.to_snapshot()).error.is_empty(),"Known blocked edges serialize")
	# A single deterministic path to one Treasury uses only real edges and changes no completion state.
	var graph: LayerMapGraph = _fresh_map(42)
	IntelMapEffects.apply(graph,[&"smell_of_a_coin"],graph.start_node_id)
	var known: Array[StringName] = []
	for node: MapNodeState in graph.nodes.values():
		if node.type_known: known.append(node.node_id)
	check(known.size() == 1 and graph.get_map_node(known[0]).node_type == MapNodeState.NodeType.TREASURY,"Coin identifies exactly one Treasury")
	var seen: Array[StringName] = [graph.start_node_id]
	var queue: Array[StringName] = seen.duplicate()
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for next: StringName in graph.connected_ids(current):
			if graph.is_connection_known(current,next) and not seen.has(next):
				seen.append(next)
				queue.append(next)
	check(seen.has(known[0]),"Coin route connects start to target through actual topology")

func _test_lifecycle(defeated: bool) -> void:
	_fixture()
	run.bloom = 1500
	check(String(controller.purchase_intel(&"battle_sense",false,10).error).is_empty(),"Pending benefit purchased")
	check(String(controller.purchase_intel(&"scouting",true,1000).error).is_empty(),"Permanent benefit purchased")
	var generator := LayerMapGenerator.new()
	check(run.begin_next_layer_2_run(generator.generate_layer_2_run(2202)).is_empty(),"Actual expedition begins")
	check(run.bloom == 0 and run.refuge_ownership.pending_intel.is_empty() and run.get_run_intel_ids().has(&"battle_sense") and run.get_run_intel_ids().has(&"scouting"),"Start consumes pending ownership without recharging; active benefits retained")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(run.make_active_run_snapshot("post_node",KnowledgeState.new())))
	var restored := RunState.new()
	check(restored.restore_active_run_snapshot(snapshot,BATTLERS).is_empty() and restored.get_run_intel_ids() == run.get_run_intel_ids() and restored.refuge_ownership.pending_intel.is_empty(),"Continue reconstructs active benefits without replenishing pending purchases")
	var error: String
	if defeated:
		var outcome := EncounterOutcome.new()
		outcome.result = EncounterOutcome.Result.DEFEAT
		outcome.encounter_id = &"fixture:intel_defeat"
		outcome.source_node_id = restored.current_node_id
		outcome.party_snapshot = restored.party_snapshot.duplicate(true)
		outcome.inventory_snapshot = restored.inventory_snapshot.duplicate(true)
		for id: Variant in outcome.party_snapshot: outcome.party_snapshot[id].hp = 0
		error = restored.apply_post_refuge_defeat(outcome,generator.generate_bloom_refuge_holding_state(2202),BATTLERS)
	else:
		error = restored.return_current_run_to_refuge(generator.generate_bloom_refuge_holding_state(2202),BATTLERS)
	check(error.is_empty(),"Return/defeat succeeds: " + error)
	check(restored.refuge_ownership.pending_intel.is_empty() and restored.refuge_ownership.permanent_intel.has(&"scouting") and not restored.get_run_intel_ids().has(&"battle_sense"),"Temporary benefit expires; permanent survives")
	check(restored.begin_next_layer_2_run(generator.generate_layer_2_run(2203)).is_empty() and not restored.get_run_intel_ids().has(&"battle_sense") and restored.get_run_intel_ids().has(&"scouting"),"Next expedition receives only permanent benefits")
