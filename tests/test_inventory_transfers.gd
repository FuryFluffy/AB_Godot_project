extends SceneTree

const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
const ITEMS = preload("res://data/items/layer_1_2_item_catalog.tres")
const A = "l01_bandage_roll"
const B = "l01_smelling_salts"
const M = "l01_hollow_livery_pin"
const HEROES: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
var failures: int = 0
var saves: int = 0
var fail_save: bool = false
var saved: Dictionary = {}
var controller: RefugeManagementController
var run: RunState

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_slots()
	_test_quick()
	_test_equipment()
	_test_rollback()
	_test_conservation()
	await _test_ui()
	print("Stage 03 inventory transfers: %d failures." % failures)
	quit(failures)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _fixture() -> void:
	run = RunState.new()
	var party: Dictionary = {}
	for id: StringName in HEROES:
		var hero: BattlerDefinition = BATTLERS.get_battler(id)
		party[id] = {"hp": hero.max_hp, "mp": hero.max_mp, "resolve": hero.starting_resolve, "corruption": hero.starting_corruption}
	run.initialize(27072026, LayerMapGenerator.new().generate_bloom_refuge_holding_state(27072026), [], party)
	run.opening_completed = true
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	run.campaign_lifecycle.restore_legacy_refuge(27072026)
	var flags: Dictionary = run.narrative_state.flags_by_scope.get(&"save", {})
	flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	controller = RefugeManagementController.new()
	_expect(controller.bind(run, BATTLERS, _persist).is_empty(), "Bind established Refuge.")
	for i: int in range(6):
		run.refuge_ownership.prepared_item_bar_slots[i] = _slot(i)
	saves = 0
	fail_save = false

func _persist() -> String:
	saves += 1
	if fail_save:
		return "Injected save failure"
	saved = run.refuge_ownership.to_snapshot().duplicate(true)
	return ""

func _slot(index: int, id: String = "", quantity: int = 0) -> Dictionary:
	return {"slot_index": index, "item_id": id, "quantity": quantity}

func _bag(index: int, hero: StringName = &"lysandra") -> Dictionary:
	return RefugeInventoryTransfer.address(&"backpack", index, hero)

func _bar(index: int) -> Dictionary:
	return RefugeInventoryTransfer.address(&"item_bar", index)

func _move(source: Dictionary, target: Dictionary, quantity: int, quick: bool = false) -> Dictionary:
	return controller.transfer_inventory(controller.inventory_request(source), target, quantity, quick)

func _test_slots() -> void:
	_fixture()
	var state: RefugeOwnershipState = run.refuge_ownership
	state.preparation_slots_by_heroine[&"lysandra"][4] = _slot(4, A, 4)
	var result: Dictionary = _move(_bag(4), _bar(2), 4)
	_expect(result.moved == 4 and BackpackPayload.is_empty(run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][4]), "Whole stack moves into the exact empty bar slot.")
	_expect(run.refuge_ownership.prepared_item_bar_slots[2].quantity == 4 and saves == 1, "Move commits once.")
	run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][4] = _slot(4, B, 2)
	result = _move(_bag(4), _bar(2), 2)
	_expect(result.moved == 2 and run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][4].item_id == A and run.refuge_ownership.prepared_item_bar_slots[2].item_id == B, "Different-item swap returns to exact source, with one save.")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	var count: int = saves
	result = _move(_bag(4), _bar(2), 1)
	_expect(not String(result.error).is_empty() and run.refuge_ownership.to_snapshot() == before and saves == count, "Partial different-item swap rejects without saving.")
	result = _move(_bag(4), _bar(0), 2)
	_expect(result.moved == 2 and run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][4].quantity == 2, "Split leaves remainder in exact source.")
	run.refuge_ownership.prepared_item_bar_slots[0].quantity = 3
	result = _move(_bag(4), _bar(0), 2)
	_expect(result.moved == 1 and result.remaining == 1, "Matching merge accepts only capacity.")
	before = run.refuge_ownership.to_snapshot()
	count = saves
	result = _move(_bag(4), _bar(0), 1)
	_expect(result.moved == 0 and saves == count and run.refuge_ownership.to_snapshot() == before, "Full matching target is a no-op, never a swap or save.")
	_move(_bar(2), _bag(7), 2)
	_expect(run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][7].item_id == B, "Reverse move uses selected Backpack slot.")
	run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][9] = _slot(9, M, 1)
	before = run.refuge_ownership.to_snapshot()
	_expect(not String(_move(_bar(0), _bag(9), 4).error).is_empty() and run.refuge_ownership.to_snapshot() == before, "Validate displaced Memento eligibility before either side changes.")
	for quantity: int in [0, -1, 99]:
		_expect(not String(_move(_bar(0), _bag(1), quantity).error).is_empty() and run.refuge_ownership.to_snapshot() == before, "Invalid quantity has no effects.")

func _test_quick() -> void:
	_fixture()
	var state: RefugeOwnershipState = run.refuge_ownership
	state.add_stash_item(StringName(A), 4)
	for i: int in range(15):
		state.preparation_slots_by_heroine[&"mira"][i] = _slot(i, B, 2)
	state.preparation_slots_by_heroine[&"mira"][1] = _slot(1, A, 4)
	state.preparation_slots_by_heroine[&"mira"][9] = _slot(9, A, 2)
	var source: Dictionary = RefugeInventoryTransfer.address(&"stash", state.stash_item_stacks.size() - 1)
	var result: Dictionary = _move(source, _bag(-1, &"mira"), 4, true)
	_expect(result.moved == 2 and result.remaining == 2, "Full bag accepts a matching merge; overflow stays at source.")
	_expect(run.refuge_ownership.preparation_slots_by_heroine[&"mira"][0].item_id == B, "Quick transfer never evicts unrelated items.")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	var count: int = saves
	result = _move(source, _bag(-1, &"mira"), 2, true)
	_expect(result.moved == 0 and saves == count and run.refuge_ownership.to_snapshot() == before, "No-capacity quick transfer has no effects.")
	run.refuge_ownership.preparation_slots_by_heroine[&"mira"][3] = _slot(3)
	run.refuge_ownership.preparation_slots_by_heroine[&"mira"][9].quantity = 3
	result = _move(source, _bag(-1, &"mira"), 2, true)
	_expect(result.moved == 2 and run.refuge_ownership.preparation_slots_by_heroine[&"mira"][9].quantity == 4 and run.refuge_ownership.preparation_slots_by_heroine[&"mira"][3].quantity == 1, "Merge before earlier free slot, then place remainder first-free.")
	result = _move(_bag(9, &"mira"), RefugeInventoryTransfer.address(&"stash"), 4, true)
	_expect(result.moved == 4 and BackpackPayload.is_empty(run.refuge_ownership.preparation_slots_by_heroine[&"mira"][9]), "Reverse quick transfer stores whole stack atomically.")
	_expect(run.refuge_ownership.selected_party_ids == HEROES, "Named destinations do not reorder the expedition.")

func _test_equipment() -> void:
	_fixture()
	var state: RefugeOwnershipState = run.refuge_ownership
	var id := StringName(state.equipment_loadouts_by_heroine[&"lysandra"].slots.main_hand)
	state.unequip_owned_slot(&"lysandra", EquipmentDefinition.Slot.MAIN_HAND)
	state.move_unequipped_equipment_to_stash(&"lysandra", id)
	state.stash_equipment_instances[id].current_condition = 0
	var original: Dictionary = state.stash_equipment_instances[id].duplicate(true)
	var result: Dictionary = _move(RefugeInventoryTransfer.address(&"stash_equipment", -1, &"", id), _bag(-1, &"mira"), 1, true)
	_expect(result.moved == 1 and run.refuge_ownership.equipment_loadouts_by_heroine[&"mira"].instances[String(id)] == original, "Named equipment transfer preserves broken condition and identity.")
	result = _move(_bag(0, &"mira"), _bag(8, &"mira"), 1)
	_expect(result.moved == 1 and run.refuge_ownership.preparation_slots_by_heroine[&"mira"][8].equipment_instance_id == String(id), "Carried instance moves without a duplicate registry entry.")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	_expect(not String(_move(_bag(8, &"mira"), _bar(0), 1).error).is_empty() and run.refuge_ownership.to_snapshot() == before, "Gear cannot enter Item Bar.")
	result = _move(_bag(8, &"mira"), RefugeInventoryTransfer.address(&"stash"), 1, true)
	_expect(result.moved == 1 and run.refuge_ownership.stash_equipment_instances[id] == original, "Reverse equipment transfer preserves condition.")
	var restored := RefugeOwnershipState.new()
	var file := FileAccess.open("user://stage03_inventory.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	var decoded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://stage03_inventory.json"))
	_expect(restored.restore_from_snapshot(decoded, ITEMS, BATTLERS, HEROES).is_empty(), "Committed mixed ownership reloads from JSON.")
	_expect(restored.stash_equipment_instances[id] == original, "Reload retains exact equipment instance and condition.")

func _test_rollback() -> void:
	_fixture()
	run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][4] = _slot(4, A, 4)
	run.refuge_ownership.prepared_item_bar_slots[3] = _slot(3, B, 2)
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	fail_save = true
	var result: Dictionary = _move(_bag(4), _bar(3), 4)
	_expect(String(result.error) == "Injected save failure" and run.refuge_ownership.to_snapshot() == before and saves == 1, "Save failure rolls back both sides of swap.")
	var request: Dictionary = controller.inventory_request(_bag(4))
	run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][4].quantity = 3
	before = run.refuge_ownership.to_snapshot()
	result = controller.transfer_inventory(request, _bar(0), 4)
	_expect(not String(result.error).is_empty() and run.refuge_ownership.to_snapshot() == before and saves == 1, "Stale drag cannot apply after ownership changes.")

func _counts() -> Dictionary:
	var result: Dictionary = {}
	var containers: Array = [run.refuge_ownership.prepared_item_bar_slots, run.refuge_ownership.stash_item_stacks]
	containers.append_array(run.refuge_ownership.preparation_slots_by_heroine.values())
	for container: Array in containers:
		for entry: Dictionary in container:
			var id: String = String(entry.get("item_id", ""))
			if not id.is_empty():
				result[id] = int(result.get(id, 0)) + int(entry.quantity)
	return result

func _test_conservation() -> void:
	_fixture()
	for i: int in range(15):
		run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][i] = _slot(i, A if i % 2 == 0 else B, 4 if i % 2 == 0 else 2)
	var expected: Dictionary = _counts()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31032026
	for attempt: int in range(100):
		var source: Dictionary = _bag(rng.randi_range(0, 14)) if attempt % 2 == 0 else _bar(rng.randi_range(0, 5))
		var target: Dictionary = _bar(rng.randi_range(0, 5)) if attempt % 2 == 0 else _bag(rng.randi_range(0, 14))
		var item: Dictionary = RefugeInventoryTransfer.payload(run.refuge_ownership, source)
		var quantity: int = int(item.get("quantity", 0))
		var before: Dictionary = run.refuge_ownership.to_snapshot()
		var previous_saves: int = saves
		fail_save = attempt % 7 == 0
		var result: Dictionary = _move(source, target, maxi(1, quantity if attempt % 3 == 0 else quantity / 2))
		_expect(_counts() == expected, "Seeded transfer sequence conserves every item quantity (%d)." % attempt)
		if not String(result.error).is_empty() or int(result.get("moved", 0)) == 0:
			_expect(before == run.refuge_ownership.to_snapshot(), "Rejected/no-op/failed transfer leaves complete snapshot unchanged (%d)." % attempt)
		else:
			_expect(saves == previous_saves + 1, "Successful exchange persists exactly once (%d)." % attempt)

func _test_ui() -> void:
	_fixture()
	run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][0] = _slot(0, A, 4)
	var screen := load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	await process_frame
	_expect(screen.present(run, BATTLERS, KnowledgeState.new(), false).is_empty(), "Present transfer UI.")
	screen.room_shell.open_station(&"stash")
	screen.room_shell.inventory_panel.show_backpacks(true)
	await process_frame
	var interaction: RefugeInventoryInteraction = screen.inventory_interaction
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	interaction.open_context(_bag(0), screen.preparation_grid.get_child(0))
	interaction.menu.hide()
	interaction._context_action(3)
	interaction.amount.value = 2
	interaction._split_confirmed()
	interaction.split.hide()
	_expect(run.refuge_ownership.to_snapshot() == before and not interaction.pending.is_empty(), "Split selection is presentation-only.")
	screen.handle_cancel()
	_expect(interaction.pending.is_empty() and screen.room_shell.modal.visible and run.refuge_ownership.to_snapshot() == before, "Cancel pending split retains parent inventory and all quantities.")
	interaction.open_context(_bag(0), screen.preparation_grid.get_child(0))
	interaction.menu.hide()
	interaction._context_action(2)
	screen.item_bar_grid.slot_buttons[4].pressed.emit()
	_expect(run.refuge_ownership.prepared_item_bar_slots[4].quantity == 4 and BackpackPayload.is_empty(run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][0]), "Controller select-source then empty destination moves the full stack.")
	_expect(not screen.item_bar_grid.slot_buttons[0].disabled, "Empty bar slots remain controller targets after refresh.")
	interaction.open_context(_bar(4), screen.item_bar_grid.slot_buttons[4])
	interaction.menu.hide()
	interaction._context_action(2)
	screen.set_actions_enabled(false)
	before = run.refuge_ownership.to_snapshot()
	interaction._select(_bag(2))
	_expect(run.refuge_ownership.to_snapshot() == before, "Disabled screen cannot mutate through controller path.")
	screen.queue_free()
	await process_frame
