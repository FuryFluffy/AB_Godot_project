extends SceneTree
const ITEMS = preload("res://data/items/layer_1_2_item_catalog.tres")
const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
const HEROES: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
var checks: int = 0
var failures: int = 0
var service: RunLootController
var bags: RunInventoryState
var bar: SixSlotInventoryState
var gear: RunEquipmentState

func _init() -> void:
	_run.call_deferred()
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	_setup()
	_capacity()
	_lifetime()
	_use_discard()
	_equipment()
	_persistence()
	_room_persistence()
	print("Stage 12 Loot transactions: %d checks, %d failures." % [checks, failures])
	quit(failures)
func _setup() -> void:
	bags = RunInventoryState.new()
	bags.initialize(ITEMS, HEROES, false)
	bar = SixSlotInventoryState.new()
	bar.initialize(ITEMS)
	gear = RunEquipmentState.new()
	gear.initialize(BATTLERS, HEROES, bags)
	service = RunLootController.new()
	service.configure(bags, bar, gear, HEROES)
	for id: StringName in HEROES:
		service.party_states[id] = BattlerState.new(BATTLERS.get_battler(id), null, gear.get_loadout(id))
func _source(quantity: int = 7, fight: bool = false, item: String = "l01_bandage_roll") -> Dictionary:
	var record: Dictionary = {"source_id": "fixture", "binding_id": "fixture_room", "quantity": quantity, "item_id": item, "claimed": false, "deferred": false, "source_channel": 1 if fight else 2}
	if not fight:
		record.spawn_id = "fixture_anchor"
		record.collected = false
	return record
func _bag(index: int = -1, owner: StringName = &"lysandra") -> Dictionary:
	return RefugeInventoryTransfer.address(&"backpack", index, owner)
func _request(index: int = 0) -> Dictionary:
	return service.request(RefugeInventoryTransfer.address(&"loot", index))
func _take(quantity: int, target: Dictionary = _bag()) -> Dictionary:
	return service.collect(_request(), target, quantity)
func _quantity(owner: StringName, item: String) -> int:
	var total: int = 0
	for slot: Dictionary in bags.backpacks_by_heroine[owner]:
		if slot.item_id == item:
			total += int(slot.quantity)
	return total
func _capacity() -> void:
	var record: Dictionary = _source()
	service.bind_sources([record])
	for i: int in range(15):
		bags.backpacks_by_heroine[&"lysandra"][i] = {"slot_index": i, "item_id": "l01_smelling_salts", "quantity": ITEMS.get_item(&"l01_smelling_salts").stack_limit}
	bags.backpacks_by_heroine[&"lysandra"][4] = {"slot_index": 4, "item_id": "l01_bandage_roll", "quantity": 3}
	var before: Dictionary = service.snapshot()
	var result: Dictionary = service.collect(_request(), _bag(), 7, true)
	_check(result.moved == 1 and service.snapshot() == before, "Capacity preview accepts partial merge at 15/15 without claiming (future trap boundary)")
	result = _take(7)
	_check(result.moved == 1 and LootClaim.remaining(record) == 6 and record.quantity == 7 and _quantity(&"lysandra", "l01_bandage_roll") == 4, "Quick collection merges before free slots and preserves authored quantity")
	before = service.snapshot()
	_check(_take(6, _bag(4)).moved == 0 and service.snapshot() == before, "Full matching stack preserves source and destination")
	_check(_take(6).moved == 0 and service.snapshot() == before, "Full bag pickup preserves source for future trap transaction")
	_check(not _take(1, _bag(0)).error.is_empty() and service.snapshot() == before, "Loot never evicts unrelated carried items")
	_check(not _take(1, RefugeInventoryTransfer.address(&"item_bar", 0)).error.is_empty() and service.snapshot() == before, "Loot must enter a bag before bar/equip")
	_check(not _take(1, _bag(-1, &"unknown")).error.is_empty(), "Unknown heroine is rejected")
	var stale: Dictionary = _request()
	result = _take(2, _bag(-1, &"mira"))
	_check(result.moved == 2 and LootClaim.remaining(record) == 4 and _quantity(&"mira", "l01_bandage_roll") == 2, "Alternative heroine accepts quantity and conserves source")
	before = service.snapshot()
	_check(not service.collect(stale, _bag(-1, &"mira"), 1).error.is_empty() and service.snapshot() == before, "Stale claim cannot duplicate contents")
	result = _take(4, _bag(-1, &"mira"))
	_check(result.moved == 4 and record.claimed and record.collected and _quantity(&"mira", "l01_bandage_roll") == 6, "Quick collection merges then uses first empty bag slot")
	before = service.snapshot()
	_check(not _take(1).error.is_empty() and before == service.snapshot(), "Exhausted source cannot be reclaimed")
	_check(LootClaim.validate(record).is_empty(), "Completed partial claim validates")
	for item: String in ["shared_rusty_key", "mat_l01_red_wax"]:
		record = _source(1, false, item)
		service.bind_sources([record])
		_check(_take(1).moved == 1 and record.claimed, "Keys/Materials collect despite full Backpack")
	_check(bags.get_key_quantity(&"shared_rusty_key") == 1 and bags.material_pouch.get("mat_l01_red_wax", 0) == 1, "Shared collections receive exactly one reward")
func _lifetime() -> void:
	var room: Dictionary = _source(5)
	var fight: Dictionary = _source(4, true)
	service.bind_sources([room, fight])
	var before: Dictionary = service.snapshot()
	var result: Dictionary = service.abandon_fight_surplus(before)
	_check(result.error.is_empty() and LootClaim.remaining(room) == 5 and LootClaim.remaining(fight) == 0 and fight.abandoned_quantity == 4, "Confirmed loss affects only fight surplus even in mixed sources")
	_check(LootClaim.validate(fight).is_empty() and LootClaim.validate(room).is_empty(), "Closed sources validate")
	_check(not service.abandon_fight_surplus(before).error.is_empty(), "Stale abandonment rejects")
	for value: Variant in [-1, 6, 1.5, "2", null]:
		var malformed: Dictionary = room.duplicate(true)
		malformed.remaining_quantity = value
		malformed.abandoned_quantity = 0
		_check(not LootClaim.validate(malformed).is_empty(), "Malformed remainder rejected: %s" % str(value))
	var malformed: Dictionary = room.duplicate(true)
	malformed.remaining_quantity = 0
	malformed.abandoned_quantity = 5
	malformed.claimed = true
	malformed.collected = true
	_check(not LootClaim.validate(malformed).is_empty(), "Persistent room source cannot be abandoned")
	var legacy: Dictionary = _source(2)
	_check(LootClaim.remaining(legacy) == 2, "Legacy unclaimed defaults to full quantity")
	legacy.claimed = true
	legacy.collected = true
	_check(LootClaim.remaining(legacy) == 0, "Legacy claimed defaults to empty")
func _use_discard() -> void:
	service.bind_sources([_source()])
	var actor: BattlerState = service.party_states[&"mira"]
	actor.current_hp = 1
	var before_hp: int = actor.current_hp
	var result: Dictionary = service.manage_carried(service.request(_bag(0, &"mira")), 1, &"mira", true)
	_check(result.error.is_empty() and actor.current_hp > before_hp and _quantity(&"mira", "l01_bandage_roll") == 5, "Use consumes one carried item and applies existing field effect")
	actor.current_hp = actor.get_max_hp()
	var before: Dictionary = service.snapshot()
	_check(not service.manage_carried(service.request(_bag(0, &"mira")), 1, &"mira", true).error.is_empty() and service.snapshot() == before, "No-effect Use consumes nothing")
	result = service.manage_carried(service.request(_bag(0, &"mira")), 2)
	_check(result.moved == 2 and _quantity(&"mira", "l01_bandage_roll") == 3, "Discard removes exact carried quantity")
	before = service.snapshot()
	_check(not service.manage_carried(_request(), 1).error.is_empty() and service.snapshot() == before, "Loot itself cannot be used or discarded")
	service.sources = []
	_check(not service.manage_carried(service.request(_bag(0, &"mira")), 1).error.is_empty(), "Use/Discard is not a new general Backpack permission")
func _equipment() -> void:
	var loadout: PersonalEquipmentLoadoutState = gear.get_loadout(&"mira")
	var definition: EquipmentDefinition = loadout.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND).definition
	var instance := EquipmentInstance.new(&"stage12_unique", definition, 0)
	var record: Dictionary = _source(1)
	record.item_id = ""
	record.equipment_snapshot = instance.to_snapshot()
	service.bind_sources([record])
	var equipped: Dictionary = loadout.slot_instance_ids.duplicate()
	var result: Dictionary = _take(1, _bag(-1, &"mira"))
	_check(result.error.is_empty() and record.claimed and loadout.slot_instance_ids == equipped, "Equipment Loot enters a bag, never equips directly")
	var owned: EquipmentInstance = loadout.get_instance(&"stage12_unique")
	_check(owned != null and owned.current_condition == 0 and owned.definition_id == instance.definition_id, "Equipment preserves unique identity and broken condition")
	var slot_index: int = -1
	for slot: Dictionary in bags.backpacks_by_heroine[&"mira"]:
		if slot.get("equipment_instance_id", "") == "stage12_unique":
			slot_index = int(slot.slot_index)
	_check(slot_index >= 0, "Equipment reference occupies one bag slot")
	if slot_index >= 0:
		result = service.manage_carried(service.request(_bag(slot_index, &"mira")), 1)
		_check(result.error.is_empty() and loadout.get_instance(&"stage12_unique") == null, "Discard removes carried equipment registry ownership")
func _persistence() -> void:
	var run := RunState.new()
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp": 10, "mp": 4, "resolve": 75, "corruption": 0}
	_check(run.initialize(8128, LayerMapGenerator.new().generate_layer_2_run(8128), [], party).is_empty(), "Production run initializes")
	run.opening_completed = true
	run.travel_to(&"l2_c1_n0")
	run.prepare_pending_node_seed()
	var pre: Dictionary = run.make_active_run_snapshot("pre_node", KnowledgeState.new())
	var node: MapNodeState = run.graph.get_map_node(&"l2_c1_n0")
	var record: Dictionary = run.prepare_node_reward(node).record
	var battle_bar := SixSlotInventoryState.new()
	battle_bar.initialize(ITEMS)
	var loot := RunLootController.new()
	loot.configure(run.run_inventory, battle_bar, run.run_equipment, HEROES)
	loot.bind_sources([record])
	_check(loot.abandon_fight_surplus(loot.snapshot()).error.is_empty(), "Production fight source confirms abandonment")
	var interrupted := RunState.new()
	_check(interrupted.restore_active_run_snapshot(pre, BATTLERS).is_empty() and interrupted.prepare_node_reward(interrupted.graph.get_map_node(node.node_id)).record.resolution_seed == record.resolution_seed and not interrupted.graph.get_map_node(node.node_id).cleared, "Interruption restores pre-node contents and identical reward seed")
	var outcome := EncounterOutcome.new()
	outcome.source_node_id = node.node_id
	outcome.encounter_id = node.encounter_id
	outcome.result = EncounterOutcome.Result.VICTORY
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.inventory_snapshot = battle_bar.get_snapshot()
	outcome.bloom_reward = 4
	_check(run.apply_encounter_outcome(outcome).is_empty() and node.reward_claimed and run.bloom == 4, "Fight outcome completes abandoned source without granting it")
	var post: Dictionary = run.make_active_run_snapshot("post_node", KnowledgeState.new())
	var restored := RunState.new()
	_check(restored.restore_active_run_snapshot(post, BATTLERS).is_empty(), "Abandonment survives production snapshot round trip")
	_check(restored.retry_deferred_reward(node.node_id).get("already_claimed", false) and restored.bloom == 4, "Revisit cannot reclaim abandoned fight rewards or duplicate Bloom")
	var bad: Dictionary = post.duplicate(true)
	var key: Variant = bad.run_snapshot.reward_resolutions.keys()[0]
	bad.run_snapshot.reward_resolutions[key].remaining_quantity = 999
	var stable: Dictionary = restored.make_active_run_snapshot("post_node", KnowledgeState.new())
	_check(not restored.restore_active_run_snapshot(bad, BATTLERS).is_empty() and stable == restored.make_active_run_snapshot("post_node", KnowledgeState.new()), "Malformed saved remainder rejects transactionally")

func _room_persistence() -> void:
	CampaignSaveSlotStore.set_test_save_directory("user://stage12_loot_safe_points")
	CampaignSaveSlotStore.delete_slot(1)
	var generator := LayerMapGenerator.new()
	var run := RunState.new()
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp": 10, "mp": 4, "resolve": 75, "corruption": 0}
	run.initialize(8128, generator.generate_layer_1(8128), generator.make_layer_1_generated_room_item_rules(), party)
	run.opening_completed = true
	var node: MapNodeState
	for value: MapNodeState in run.graph.nodes.values():
		if value.requires_event_room():
			node = value
			break
	_check(node != null, "Generated map has an ordinary room")
	if node == null:
		CampaignSaveSlotStore.clear_test_save_directory()
		return
	# Isolate the room transaction; navigation is covered by existing route tests.
	run.pending_origin_node_id = run.current_node_id
	run.current_node_id = node.node_id
	run.selected_node_id = node.node_id
	run.pending_node_id = node.node_id
	node.visited = true
	run.prepare_pending_node_seed()
	var knowledge := KnowledgeState.new()
	_check(CampaignSaveSlotStore.save_active_run_slot(1, run, knowledge, "pre_node").is_empty(), "Production store writes pre-room safe point")
	var original: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	var room: EventRoomInstanceState = run.get_event_room_state(node.node_id, node.room_definition_id)
	var record: Dictionary = _source(7)
	record.binding_id = String(node.node_id)
	room.local_state.item_spawns = [record]
	var room_bar := SixSlotInventoryState.new()
	room_bar.initialize(ITEMS)
	var loot := RunLootController.new()
	loot.configure(run.run_inventory, room_bar, run.run_equipment, HEROES)
	loot.bind_sources([record])
	_check(loot.collect(loot.request(RefugeInventoryTransfer.address(&"loot", 0)), _bag(0), 7).moved == 4 and LootClaim.remaining(record) == 3, "Room accepts partial stack with exact remainder")
	_check(CampaignSaveSlotStore.read_document_for_load(1).document == original, "In-room collection does not write an ordinary mid-node save")
	var outcome := EventRoomOutcome.new()
	outcome.source_node_id = node.node_id
	outcome.room_state_snapshot = room.to_snapshot()
	outcome.inventory_snapshot = room_bar.get_snapshot()
	outcome.run_inventory_snapshot = run.run_inventory.get_snapshot()
	outcome.party_snapshot = run.party_snapshot.duplicate(true)
	outcome.clear_node = true
	_check(run.apply_event_room_outcome(outcome).is_empty(), "Room outcome resolves claim and inventory together")
	CampaignSaveSlotStore.force_test_write_failure = true
	_check(not CampaignSaveSlotStore.save_active_run_slot(1, run, knowledge, "post_node").is_empty(), "Injected atomic write failure reports failure")
	CampaignSaveSlotStore.force_test_write_failure = false
	_check(CampaignSaveSlotStore.read_document_for_load(1).document == original, "Failed post-room write preserves exact previous safe point")
	_check(CampaignSaveSlotStore.save_active_run_slot(1, run, knowledge, "post_node").is_empty(), "Retry saves room source and accepted inventory together")
	var restored := RunState.new()
	var saved: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document.active_run_snapshot
	_check(restored.restore_active_run_snapshot(saved, BATTLERS).is_empty(), "Production JSON save restores partial room contents")
	var revisit: EventRoomInstanceState = restored.get_event_room_state(node.node_id, node.room_definition_id)
	var remainder: Dictionary = revisit.local_state.item_spawns[0]
	_check(LootClaim.remaining(remainder) == 3 and not remainder.collected and restored.run_inventory.get_backpack_snapshot(&"lysandra")[0].quantity == 4, "Revisit keeps exact uncollected remainder and accepted stack")
	loot.configure(restored.run_inventory, room_bar, restored.run_equipment, HEROES)
	loot.bind_sources([remainder])
	_check(loot.collect(loot.request(RefugeInventoryTransfer.address(&"loot", 0)), _bag(), 3).moved == 3 and remainder.collected, "Revisited source collects only saved remainder")
	var total: int = 0
	for slot: Dictionary in restored.run_inventory.get_backpack_snapshot(&"lysandra"):
		if slot.item_id == "l01_bandage_roll":
			total += int(slot.quantity)
	_check(total == 7, "Save/revisit collection conserves all seven items without duplication")
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
