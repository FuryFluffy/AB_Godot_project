extends SceneTree
const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
const HEROES: Array[StringName] = [&"lysandra",&"mira",&"seraphine"]
var checks: int = 0
var failures: int = 0

func _init() -> void:
	_generation()
	_offers()
	_staging()
	print("Stage 20 Rest room state: %d checks, %d failures." % [checks,failures])
	quit(failures)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _generation() -> void:
	var generator := LayerMapGenerator.new()
	var absent: int = 0
	var present: int = 0
	var repeats: int = 0
	var seen: Dictionary = {}
	for seed: int in range(1,101):
		var layer_offers: Array[int] = []
		for layer: int in [1,2]:
			var graph: LayerMapGraph = generator.generate_layer_1(seed) if layer == 1 else generator.generate_layer_2_run(seed)
			_check(generator.validate_generated_layer(graph).is_empty() and generator.validate_special_room_quotas(graph).is_empty(),"Rest activation preserves topology and all special quotas")
			var count: int = 0
			for node: MapNodeState in graph.nodes.values():
				if node.node_type == MapNodeState.NodeType.REST:
					count += 1
					seen[node.rest_offer_id] = true
					layer_offers.append(node.rest_offer_id)
					_check(node.requires_event_room() and not node.has_encounter_content() and node.reward_source_id == &"" and not node.rest_used,"Rest is an unused authored room without combat/reward inheritance")
					_check(node.rest_offer_id == RoomRestRules.assigned_offer(node.content_seed,node.node_id),"Offer is assigned once from stable room/run seed")
				else:
					_check(node.rest_offer_id == 0,"Other node types receive no Rest offer")
			_check(count <= 1,"Each layer has zero or one Rest room")
			present += count
			absent += int(count == 0)
			var loaded: Dictionary = LayerMapGraph.from_snapshot(JSON.parse_string(JSON.stringify(graph.to_snapshot())))
			_check(loaded.error.is_empty() and JSON.parse_string(JSON.stringify(loaded.graph.to_snapshot())) == JSON.parse_string(JSON.stringify(graph.to_snapshot())),"Room offer survives JSON map roundtrip without regeneration")
		if layer_offers.size() == 2 and layer_offers[0] == layer_offers[1]:
			repeats += 1
	_check(absent > 0 and present > 0 and seen.size() == 6 and repeats > 0,"Optional room generation covers all six offers and allows later-layer repeats")
	var node: MapNodeState = generator.generate_layer_1(1).get_map_node(&"l1_c0_n0")
	if node == null:
		node = generator.generate_layer_1(1).nodes.values()[0]
	var old: Dictionary = node.to_snapshot()
	old.erase("rest_offer_id")
	_check(MapNodeState.from_snapshot(old).node.rest_offer_id == 0,"Legacy absence does not invent an offer")
	for invalid: Variant in [-1,7,1.5,"1",null,true]:
		var bad: Dictionary = old.duplicate(true)
		bad.rest_offer_id = invalid
		_check(not MapNodeState.from_snapshot(bad).error.is_empty(),"Malformed explicit offer rejects")

func _states() -> Dictionary:
	var states: Dictionary = {}
	for id: StringName in HEROES:
		var actor := BattlerState.new(BATTLERS.get_battler(id))
		actor.current_hp = 1
		actor.current_mp = 1
		actor.current_resolve = 90
		actor.current_corruption = 75
		states[id] = actor
	return states

func _offers() -> void:
	for offer: int in range(1,7):
		var states: Dictionary = _states()
		var request: Dictionary = RoomRestRules.preview(offer,states,HEROES)
		_check(request.error.is_empty() and request.offer_id == offer and request.before.size() == 3 and request.after.size() == 3,"Single offer previews every active heroine")
		for id: StringName in HEROES:
			var actor: BattlerState = states[id]
			var after: Dictionary = request.after[id]
			var hp: int = actor.get_max_hp() if offer == 6 else mini(actor.get_max_hp(),1+ceili(actor.get_max_hp()/2.0)) if offer in [1,3] else 1
			var mp: int = actor.get_max_mp() if offer == 6 else mini(actor.get_max_mp(),1+ceili(actor.get_max_mp()/2.0)) if offer in [2,3] else 1
			_check(after == {"hp":hp,"mp":mp,"resolve":100 if offer in [4,6] else 90,"corruption":55 if offer == 5 else 100 if offer == 6 else 75},"Assigned effect adds the authored amount, with ceiling and bounds")
			_check(actor.current_hp == 1 and actor.current_mp == 1 and actor.current_corruption == 75,"Preview/cancel is pure")
			_check(request.text.contains(actor.definition.display_name),"Preview names every recipient")
		states[&"mira"].current_corruption = 5
		states[&"mira"].current_hp = states[&"mira"].get_max_hp()
		states[&"mira"].current_mp = states[&"mira"].get_max_mp()
		request = RoomRestRules.preview(offer,states,HEROES)
		_check(request.after[&"mira"].hp == states[&"mira"].get_max_hp() and request.after[&"mira"].mp == states[&"mira"].get_max_mp(),"Recovery never exceeds maxima")
		_check(request.after[&"mira"].corruption == (0 if offer == 5 else 55 if offer == 6 else 5),"Corruption reduction and full recovery cost use valid bounds")
	_check(not RoomRestRules.preview(0,_states(),HEROES).error.is_empty(),"Missing offer cannot be selected from UI")

func _staging() -> void:
	var generator := LayerMapGenerator.new()
	var graph: LayerMapGraph
	var node: MapNodeState
	for seed: int in range(1,20):
		graph = generator.generate_layer_1(seed)
		for candidate: MapNodeState in graph.nodes.values():
			if candidate.node_type == MapNodeState.NodeType.REST:
				node = candidate
				break
		if node != null:
			break
	var states: Dictionary = _states()
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp":1,"mp":1,"resolve":90,"corruption":75}
	var run := RunState.new()
	run.initialize(1,graph,[],party)
	run.opening_completed = true
	run.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	var origin: MapNodeState = graph.get_map_node(node.incoming_ids[0])
	origin.visited = true
	origin.cleared = true
	origin.exit_completed = true
	origin.encounter_cleared = origin.has_encounter_content()
	run.current_node_id = origin.node_id
	graph.reveal_adjacency(origin.node_id)
	_check(run.travel_to(node.node_id).is_empty(),"State fixture enters actual generated Rest node")
	run.prepare_pending_node_seed()
	run.ordinary_rest_uses = 1
	run.bloom = 31
	run.run_inventory.material_pouch["mat_l01_red_wax"] = 7
	var room_state: EventRoomInstanceState = run.get_event_room_state(node.node_id,node.room_definition_id)
	var outcome := EventRoomOutcome.new()
	outcome.source_node_id = node.node_id
	outcome.room_state_snapshot = room_state.to_snapshot()
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.run_inventory_snapshot = run.run_inventory.get_snapshot()
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	var knowledge := KnowledgeState.new()
	var before: Dictionary = run.make_active_run_snapshot("pre_node",knowledge)
	var request: Dictionary = run.room_rest_request(states)
	states[&"mira"].current_hp += 1
	_check(not run.prepare_room_rest(outcome,states,request,BATTLERS,knowledge).error.is_empty() and before == run.make_active_run_snapshot("pre_node",knowledge),"Stale party rejects without mutation")
	states[&"mira"].current_hp -= 1
	var result: Dictionary = run.prepare_room_rest(outcome,states,request,BATTLERS,knowledge)
	_check(result.error.is_empty(),"Rest stages complete recovery: " + String(result.error))
	if not result.error.is_empty():
		return
	var staged: RunState = result.state
	_check(before == run.make_active_run_snapshot("pre_node",knowledge) and not node.rest_used,"Staging does not consume live recovery")
	_check(staged.graph.get_map_node(node.node_id).rest_used and staged.ordinary_rest_uses == 1 and staged.bloom == 31 and staged.run_inventory.material_pouch["mat_l01_red_wax"] == 7,"Confirmed room recovery is independent of ordinary charges and all currencies")
	_check(not staged.room_rest_request(states).error.is_empty(),"Used offer cannot be repeated")
	var restored := RunState.new()
	_check(restored.restore_active_run_snapshot(staged.make_active_run_snapshot("pre_node",knowledge),BATTLERS).is_empty() and restored.graph.get_map_node(node.node_id).rest_used,"Consumed recovery survives production restore")
