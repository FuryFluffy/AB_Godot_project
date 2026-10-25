extends SceneTree
const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
const HEROES: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
var checks: int = 0
var failures: int = 0
func _init() -> void:
	_run.call_deferred()
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var generator := LayerMapGenerator.new()
	var run := RunState.new()
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp": 10, "mp": 4, "resolve": 75, "corruption": 0}
	run.initialize(813, generator.generate_layer_1(813), generator.make_layer_1_generated_room_item_rules(), party)
	run.opening_completed = true
	var knowledge := KnowledgeState.new()
	var original: Dictionary = run.make_active_run_snapshot("post_node", knowledge)
	var before_party: Dictionary = run.party_snapshot.duplicate(true)
	var before_bags: Dictionary = run.run_inventory.get_snapshot()
	var before_gear: Dictionary = run.run_equipment.get_snapshot()
	var reversed: Array[StringName] = [&"seraphine", &"mira", &"lysandra"]
	_check(run.set_party_display_order(reversed, HEROES).is_empty(), "Immediate permutation succeeds")
	_check(run.get_party_display_order() == reversed and run._make_current_party_ids() == HEROES, "Display order does not alter encounter roster order")
	_check(run.party_snapshot == before_party and run.run_inventory.get_snapshot() == before_bags and run.run_equipment.get_snapshot() == before_gear, "Reordering preserves stats and all ownership")
	_check(not run.set_party_display_order(HEROES, HEROES).is_empty() and run.get_party_display_order() == reversed, "Stale order rejects without mutation")
	for invalid: Variant in [[], ["lysandra"], ["lysandra", "lysandra", "mira"], ["lysandra", "mira", "unknown"], null, [1, 2, 3]]:
		_check(not RunPartyOrder.validate(invalid, HEROES).is_empty(), "Malformed permutations reject")
	var saved: Dictionary = run.make_active_run_snapshot("post_node", knowledge)
	var restored := RunState.new()
	_check(restored.restore_active_run_snapshot(saved, BATTLERS).is_empty() and restored.get_party_display_order() == reversed, "Post-node roundtrip retains presentation permutation")
	_check(restored.restore_active_run_snapshot(original, BATTLERS).is_empty() and restored.get_party_display_order() == HEROES, "Pre-change safe point retains original order")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.run_snapshot.erase("party_display_order")
	_check(restored.restore_active_run_snapshot(legacy, BATTLERS).is_empty() and restored.get_party_display_order() == HEROES, "Legacy saves default to current roster order")
	var stable: Dictionary = restored.make_active_run_snapshot("post_node", knowledge)
	for invalid: Variant in [[], ["lysandra", "mira", "mira"], "lysandra", ["lysandra", "mira", "unknown"]]:
		var bad: Dictionary = saved.duplicate(true)
		bad.run_snapshot.party_display_order = invalid
		_check(not restored.restore_active_run_snapshot(bad, BATTLERS).is_empty() and restored.make_active_run_snapshot("post_node", knowledge) == stable, "Malformed save rejects transactionally")
	CampaignSaveSlotStore.set_test_save_directory("user://stage13_party")
	CampaignSaveSlotStore.delete_slot(1)
	_check(CampaignSaveSlotStore.save_active_run_slot(1, run, knowledge, "post_node").is_empty(), "Production store writes order")
	var document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	_check(restored.restore_active_run_snapshot(document.active_run_snapshot, BATTLERS).is_empty() and restored.get_party_display_order() == reversed, "JSON roundtrip preserves order")
	_check(run.set_party_display_order(HEROES, reversed).is_empty() and CampaignSaveSlotStore.read_document_for_load(1).document == document, "Changing order does not write a mid-node save")
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	_check(RunPartyOrder.resolve(reversed, [&"lysandra"]) == [&"lysandra"], "Solo roster cannot display inactive members")
	_check(RunPartyOrder.resolve([&"mira"], HEROES) == [&"mira", &"lysandra", &"seraphine"], "Recruitment appends only new current members")
	print("Stage 13 Party state: %d checks, %d failures." % [checks, failures])
	quit(failures)
