extends "res://tests/test_inventory_transfers.gd"
var checks: int = 0
func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)
func _run() -> void:
	_rest()
	_rest_safe_points()
	_return()
	print("Stage 14 Recovery: %d checks, %d failures." % [checks, failures])
	quit(failures)
func _rest() -> void:
	var generator := LayerMapGenerator.new()
	run = RunState.new()
	var states: Dictionary = {}
	var party: Dictionary = {}
	for id: StringName in HEROES:
		var state := BattlerState.new(BATTLERS.get_battler(id))
		state.current_hp = 0
		state.current_mp = 0
		state.current_corruption = 96
		state.current_actions = 0
		state.is_defeated = true
		states[id] = state
		party[id] = {"hp": 0, "mp": 0, "resolve": 70, "corruption": 96}
	run.initialize(814, generator.generate_layer_1(814), generator.make_layer_1_generated_room_item_rules(), party)
	run.opening_completed = true
	var before: Dictionary = run.make_active_run_snapshot("post_node", KnowledgeState.new())
	var request: Dictionary = run.ordinary_rest_request(states)
	_expect(run.ordinary_rest_uses == 0 and before == run.make_active_run_snapshot("post_node", KnowledgeState.new()), "Opening/cancelling preview never spends or mutates")
	states[&"mira"].current_mp = 1
	_expect(not run.apply_ordinary_rest(states, request).is_empty() and run.ordinary_rest_uses == 0 and states[&"lysandra"].current_hp == 0, "Stale preview rejects all changes atomically")
	states[&"mira"].current_mp = 0
	request = run.ordinary_rest_request(states)
	var bag_before: Dictionary = run.run_inventory.get_snapshot()
	var gear_before: Dictionary = run.run_equipment.get_snapshot()
	_expect(run.apply_ordinary_rest(states, request).is_empty() and run.ordinary_rest_uses == 1, "First confirmed Rest succeeds once")
	for id: StringName in HEROES:
		var state: BattlerState = states[id]
		_expect(state.current_hp == ceili(state.get_max_hp() / 2.0) and state.current_mp == ceili(state.get_max_mp() / 2.0) and not state.is_defeated and state.current_corruption == 100 and state.current_actions == 0, "Every heroine revives with rounded-up half maxima, capped Corruption and unchanged Actions")
	_expect(not run.apply_ordinary_rest(states, request).is_empty() and run.ordinary_rest_uses == 1, "Repeated confirmation cannot spend twice")
	_expect(run.apply_ordinary_rest(states, run.ordinary_rest_request(states)).is_empty() and run.ordinary_rest_uses == 2, "Second successful Rest uses final charge")
	for state: BattlerState in states.values():
		_expect(state.current_hp == state.get_max_hp() and state.current_mp == state.get_max_mp(), "Recovery caps at maxima")
	_expect(not run.apply_ordinary_rest(states, run.ordinary_rest_request(states)).is_empty() and run.ordinary_rest_uses == 2, "Third use rejects")
	_expect(bag_before == run.run_inventory.get_snapshot() and gear_before == run.run_equipment.get_snapshot(), "Rest changes no items, materials or equipment")
	var snapshot: Dictionary = run.make_active_run_snapshot("post_node", KnowledgeState.new())
	var restored := RunState.new()
	_expect(restored.restore_active_run_snapshot(JSON.parse_string(JSON.stringify(snapshot)), BATTLERS).is_empty() and restored.ordinary_rest_uses == 2 and JSON.parse_string(JSON.stringify(restored.party_snapshot)) == JSON.parse_string(JSON.stringify(run.party_snapshot)), "JSON safe point restores stats and spent count together")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.run_snapshot.erase("ordinary_rest_uses")
	_expect(restored.restore_active_run_snapshot(legacy, BATTLERS).is_empty() and restored.ordinary_rest_uses == 0, "Legacy saves default to zero uses")
	for invalid: Variant in [-1, 3, 0.5, "1", null, true]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.run_snapshot.ordinary_rest_uses = invalid
		var stable: Dictionary = restored.make_active_run_snapshot("post_node", KnowledgeState.new())
		_expect(not restored.restore_active_run_snapshot(bad, BATTLERS).is_empty() and stable == restored.make_active_run_snapshot("post_node", KnowledgeState.new()), "Malformed explicit Rest count rejects transactionally")
	_expect(restored.restore_active_run_snapshot(before, BATTLERS).is_empty() and restored.ordinary_rest_uses == 0 and restored.party_snapshot[&"lysandra"].hp == 0, "Interrupted node's prior safe point retains both pre-Rest stats and count")
	run.initialize(815, generator.generate_layer_1(815), [], party)
	_expect(run.ordinary_rest_uses == 0, "New run resets ordinary Rest budget")
func _return() -> void:
	_fixture()
	var generator := LayerMapGenerator.new()
	_expect(run.begin_next_layer_2_run(generator.generate_layer_2_run(814)).is_empty(), "Return fixture departs established Refuge")
	var knowledge := KnowledgeState.new()
	run.run_inventory.material_pouch["mat_l01_red_wax"] = 3
	run.party_snapshot[&"mira"].hp = 1
	var before: Dictionary = run.make_active_run_snapshot("post_node", knowledge)
	var prepared: Dictionary = run.prepare_refuge_return(null, generator.generate_bloom_refuge_holding_state(814), BATTLERS, knowledge)
	_expect(prepared.error.is_empty() and before == run.make_active_run_snapshot("post_node", knowledge), "Preparing Return preserves live run")
	if not prepared.error.is_empty():
		return
	var staged: RunState = prepared.state
	_expect(staged.graph.layer_id == &"bloom_refuge" and staged.party_snapshot[&"mira"].hp == BATTLERS.get_battler(&"mira").max_hp and staged.refuge_ownership.banked_materials.get("mat_l01_red_wax", 0) == 3, "Existing Return heals and banks exactly remaining materials")
	_expect(not staged.ordinary_rest_access_error({}).is_empty(), "Ordinary Rest unavailable after Refuge")
	CampaignSaveSlotStore.set_test_save_directory("user://stage14_recovery")
	CampaignSaveSlotStore.delete_slot(1)
	_expect(CampaignSaveSlotStore.save_active_run_slot(1, run, knowledge, "post_node").is_empty(), "Production store writes previous safe point")
	var original: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	CampaignSaveSlotStore.force_test_write_failure = true
	_expect(not CampaignSaveSlotStore.save_refuge_slot(1, staged, knowledge).is_empty() and CampaignSaveSlotStore.read_document_for_load(1).document == original and run.make_active_run_snapshot("post_node", knowledge) == before, "Failed Return write preserves durable boundary and live run")
	CampaignSaveSlotStore.force_test_write_failure = false
	_expect(CampaignSaveSlotStore.save_refuge_slot(1, staged, knowledge).is_empty(), "Return save retries successfully")
	var document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	_expect(document.get("active_run_snapshot") == null, "Successful Return removes resumable active-run snapshot")
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()

func _rest_safe_points() -> void:
	var generator := LayerMapGenerator.new()
	var knowledge := KnowledgeState.new()
	var party: Dictionary = {}
	var states: Dictionary = {}
	for id: StringName in HEROES:
		var state := BattlerState.new(BATTLERS.get_battler(id))
		state.current_hp = 1
		state.current_mp = 0
		state.current_corruption = 0
		states[id] = state
		party[id] = {"hp": 1, "mp": 0, "resolve": 70, "corruption": 0}
	run = RunState.new()
	run.initialize(814, generator.generate_layer_1(814), generator.make_layer_1_generated_room_item_rules(), party)
	run.opening_completed = true
	var node: MapNodeState
	for candidate: MapNodeState in run.graph.nodes.values():
		if candidate.requires_event_room():
			node = candidate
			break
	_expect(node != null, "Rest fixture has a generated room")
	if node == null:
		return
	run.pending_origin_node_id = run.current_node_id
	run.current_node_id = node.node_id
	run.selected_node_id = node.node_id
	run.pending_node_id = node.node_id
	node.visited = true
	run.prepare_pending_node_seed()
	CampaignSaveSlotStore.set_test_save_directory("user://stage14_rest_safe_points")
	CampaignSaveSlotStore.delete_slot(1)
	_expect(CampaignSaveSlotStore.save_active_run_slot(1, run, knowledge, "pre_node").is_empty(), "Production pre-node Rest boundary saved")
	var original: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	_expect(run.apply_ordinary_rest(states, run.ordinary_rest_request(states)).is_empty() and CampaignSaveSlotStore.read_document_for_load(1).document == original, "Rest does not write a mid-node save")
	var interrupted := RunState.new()
	_expect(interrupted.restore_active_run_snapshot(original.active_run_snapshot, BATTLERS).is_empty() and interrupted.ordinary_rest_uses == 0 and interrupted.party_snapshot[&"lysandra"].hp == 1 and interrupted.pending_node_seed == run.pending_node_seed, "Interrupted Rest resumes previous stats/count and same content seed")
	var outcome := EventRoomOutcome.new()
	outcome.source_node_id = node.node_id
	outcome.clear_node = true
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	outcome.run_inventory_snapshot = run.run_inventory.get_snapshot()
	outcome.room_state_snapshot = run.get_event_room_state(node.node_id, node.room_definition_id).to_snapshot()
	_expect(run.apply_event_room_outcome(outcome).is_empty(), "Rest room exit uses existing outcome resolution")
	CampaignSaveSlotStore.force_test_write_failure = true
	_expect(not CampaignSaveSlotStore.save_active_run_slot(1, run, knowledge, "post_node").is_empty() and CampaignSaveSlotStore.read_document_for_load(1).document == original, "Failed post-node save cannot save only count or only healed stats")
	CampaignSaveSlotStore.force_test_write_failure = false
	_expect(CampaignSaveSlotStore.save_active_run_slot(1, run, knowledge, "post_node").is_empty(), "Resolved Rest safe point retries")
	var resumed := RunState.new()
	var saved_run: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document.active_run_snapshot
	_expect(resumed.restore_active_run_snapshot(saved_run, BATTLERS).is_empty() and resumed.ordinary_rest_uses == 1 and resumed.party_snapshot[&"lysandra"].hp == states[&"lysandra"].current_hp and resumed.party_snapshot[&"lysandra"].corruption == 10, "Continue restores resolved recovery and use count together")
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
