extends SceneTree
const ITEMS = preload("res://data/items/layer_1_2_item_catalog.tres")
const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
const HEROES: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
const A = "l01_bandage_roll"
const B = "l01_smelling_salts"
var failures: int = 0
var checks: int = 0
var engine: CombatEngine
var service: RunBackpackController
var bags: RunInventoryState
var bar: SixSlotInventoryState
var gear: RunEquipmentState
var actor: BattlerState

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_fixture()
	_test_transfers()
	_test_permissions()
	_test_equipment()
	_test_exploration()
	_test_atomic_observers()
	engine.free()
	print("Stage 11 run Backpack: %d checks, %d failures." % [checks, failures])
	quit(failures)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _fixture() -> void:
	bags = RunInventoryState.new()
	_check(bags.initialize(ITEMS, HEROES, false).is_empty(), "Run inventory initializes")
	gear = RunEquipmentState.new()
	_check(gear.initialize(BATTLERS, HEROES, bags).is_empty(), "Existing equipment owner initializes")
	bar = SixSlotInventoryState.new()
	bar.initialize(ITEMS)
	engine = CombatEngine.new()
	engine.battle_runtime = BattleRuntimeState.new()
	engine.battle_flow_controller = BattleFlowController.new()
	for id: StringName in HEROES:
		engine.battler_states[id] = BattlerState.new(BATTLERS.get_battler(id), null, gear.get_loadout(id))
	engine.battle_flow_controller.initialize(engine.battler_states, engine.battle_runtime.battle_state, DiceResolver.new(), 111)
	_check(engine.battle_flow_controller.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST).is_empty(), "Real turn rules initialize")
	engine.item_inventory = bar
	engine.configure_backpack(gear, HEROES)
	service = engine.backpack
	actor = engine.get_battler_state(&"lysandra")

func _bag(index: int, id: StringName = &"lysandra") -> Dictionary:
	return RefugeInventoryTransfer.address(&"backpack", index, id)
func _bar(index: int) -> Dictionary:
	return RefugeInventoryTransfer.address(&"item_bar", index)
func _slot(index: int, id: String = "", quantity: int = 0) -> Dictionary:
	return {"slot_index": index, "item_id": id, "quantity": quantity}
func _move(source: Dictionary, target: Dictionary, quantity: int) -> Dictionary:
	return service.transfer(service.request(source), target, quantity)
func _reset() -> void:
	bags.initialize(ITEMS, HEROES, false)
	bar.load_items([])
	actor.current_actions = 3
	engine.battle_runtime.selected_battler_id = &"lysandra"

func _test_transfers() -> void:
	_reset()
	bags.backpacks_by_heroine[&"lysandra"][4] = _slot(4, A, 4)
	var result: Dictionary = _move(_bag(4), _bar(2), 4)
	_check(result.moved == 4 and actor.current_actions == 2 and BackpackPayload.is_empty(bags.get_backpack_snapshot(&"lysandra")[4]), "Whole-stack transfer costs one Action")
	bags.backpacks_by_heroine[&"lysandra"][4] = _slot(4, B, 2)
	result = _move(_bag(4), _bar(2), 2)
	_check(result.moved == 2 and actor.current_actions == 1 and bags.get_backpack_snapshot(&"lysandra")[4].item_id == A, "Swap returns exact source and costs once")
	var before: Dictionary = service.snapshot()
	result = _move(_bag(4), _bar(2), 1)
	_check(not result.error.is_empty() and before == service.snapshot(), "Partial occupied swap rejects atomically")
	result = _move(_bag(4), _bar(0), 2)
	_check(result.moved == 2 and actor.current_actions == 0 and bags.get_backpack_snapshot(&"lysandra")[4].quantity == 2, "Split is a separate paid change")
	before = service.snapshot()
	_check(not _move(_bar(0), _bag(1), 1).error.is_empty() and before == service.snapshot(), "Insufficient Actions cannot mutate")
	actor.current_actions = 3
	bar.slots[0].quantity = 3
	result = _move(_bag(4), _bar(0), 2)
	_check(result.moved == 1 and result.remaining == 1 and actor.current_actions == 2, "Partial merge costs once and retains excess")
	before = service.snapshot()
	result = _move(_bag(4), _bar(0), 1)
	_check(result.moved == 0 and before == service.snapshot(), "Full matching target is free no-op")
	var stale: Dictionary = service.request(_bag(4))
	actor.current_actions -= 1
	before = service.snapshot()
	_check(not service.transfer(stale, _bar(1), 1).error.is_empty() and before == service.snapshot(), "Stale Action snapshot rejects")
	stale = service.request(_bag(4))
	bar.consume(0, 1)
	before = service.snapshot()
	_check(not service.transfer(stale, _bar(1), 1).error.is_empty() and before == service.snapshot(), "Stale consumed Item Bar rejects")

func _test_permissions() -> void:
	_reset()
	bags.backpacks_by_heroine[&"mira"][0] = _slot(0, B, 2)
	bags.backpacks_by_heroine[&"lysandra"][0] = _slot(0, A, 2)
	var before: Dictionary = service.snapshot()
	for target: Dictionary in [_bag(1, &"mira"), _bag(1), RefugeInventoryTransfer.address(&"stash"), RefugeInventoryTransfer.address(&"memento")]:
		_check(not _move(_bag(0), target, 2).error.is_empty() and before == service.snapshot(), "Unapproved combat destination rejects")
	_check(not _move(_bag(0, &"mira"), _bar(0), 2).error.is_empty() and before == service.snapshot(), "Other heroine bag never spends actor or other Actions")
	actor.add_grapple_track(&"fixture_track")
	before = service.snapshot()
	_check(not service.access_error().is_empty() and not _move(_bag(0), _bar(0), 2).error.is_empty() and before == service.snapshot(), "Grapple rejects access and direct transaction")
	actor.remove_grapple_track(&"fixture_track")
	actor.active_statuses.append(StatusInstance.new(preload("res://data/statuses/stunned.tres")))
	_check(not service.access_error().is_empty(), "Stunned actor cannot bypass Active Action rules")
	actor.active_statuses.clear()
	engine.backpack_commands_locked = true
	_check(not service.access_error().is_empty(), "Resolution lock rejects entry")
	engine.backpack_commands_locked = false
	engine.battle_runtime.begin_move_targeting(&"lysandra")
	_check(not service.access_error().is_empty(), "Pending Move rejects Backpack")
	engine.battle_runtime.cancel_move_targeting()
	actor.current_actions = 0
	_check(service.access_error().is_empty() and not service.mutation_error(&"lysandra").is_empty(), "Browsing with zero Actions remains free")
	actor.current_actions = 3
	engine.battle_flow_controller.end_current_phase()
	_check(not service.access_error().is_empty(), "Enemy phase rejects mutations and entry")
	engine.battle_flow_controller.end_current_phase()

func _test_equipment() -> void:
	_reset()
	var loadout: PersonalEquipmentLoadoutState = gear.get_loadout(&"lysandra")
	var old: EquipmentInstance = loadout.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND)
	var incoming := EquipmentInstance.new()
	incoming.initialize(&"stage11_fixture_weapon", old.definition)
	incoming.set_condition_clamped(0)
	loadout.register_instance(incoming)
	bags.backpacks_by_heroine[&"lysandra"][7] = BackpackPayload.equipment_slot(7, incoming.instance_id)
	var before: Dictionary = service.snapshot()
	var preview: Dictionary = service.equip(service.request(_bag(7)), EquipmentDefinition.Slot.MAIN_HAND, true)
	_check(preview.error.is_empty() and before == service.snapshot(), "Equipment preview is free")
	var result: Dictionary = service.equip(service.request(_bag(7)), EquipmentDefinition.Slot.MAIN_HAND)
	_check(result.changed and actor.current_actions == 2, "Equipment exchange charges once")
	_check(loadout.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND) == incoming and actor.weapon_state.instance == incoming, "Existing instance and runtime adapter switch together")
	_check(String(bags.get_backpack_snapshot(&"lysandra")[7].equipment_instance_id) == String(old.instance_id) and incoming.current_condition == 0, "Displaced gear returns to exact source; broken condition preserved")
	before = service.snapshot()
	_check(not service.equip(service.request(_bag(7)), EquipmentDefinition.Slot.OFF_HAND).error.is_empty() and before == service.snapshot(), "Unapproved Shield/offhand replacement rejects")
	_check(not _move(_bag(7), _bar(0), 1).error.is_empty() and before == service.snapshot(), "Equipment cannot enter Item Bar")
	result = service.equip(service.request(_bag(7)), EquipmentDefinition.Slot.MAIN_HAND)
	_check(result.changed and loadout.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND) == old and actor.current_actions == 1, "Second replacement spends a separate Action")
	var restored := RunInventoryState.new()
	restored.initialize(ITEMS, HEROES, false)
	_check(restored.restore_from_snapshot(JSON.parse_string(JSON.stringify(service.snapshot().inventory))).is_empty(), "Inventory uses existing JSON save representation")
	var restored_gear := RunEquipmentState.new()
	_check(restored_gear.initialize_from_snapshot(BATTLERS, HEROES, restored, JSON.parse_string(JSON.stringify(gear.get_snapshot()))).is_empty(), "Equipment identity and condition survive existing snapshot reload")

func _test_exploration() -> void:
	service.combat = null
	var actions: int = actor.current_actions
	bags.backpacks_by_heroine[&"mira"][0] = _slot(0, A, 2)
	_check(_move(_bag(0, &"mira"), _bar(1), 2).changed and actor.current_actions == actions, "Exploration current-party transfers are free")
	_check(_move(_bar(1), _bag(1, &"mira"), 1).changed, "Exploration can split back into selected bag")
	_check(_move(_bag(1, &"mira"), _bag(2, &"mira"), 1).changed, "Exploration allows same-bag rearrangement")
	var before: Dictionary = service.snapshot()
	_check(not _move(_bag(2, &"mira"), RefugeInventoryTransfer.address(&"stash"), 1).error.is_empty() and before == service.snapshot(), "No remote Stash")
	service.exploration_guard = func() -> String: return "Dialogue in progress"
	_check(not service.access_error().is_empty(), "Dialogue lock uses existing context")
	service.exploration_guard = Callable()
	service.combat = engine

func _test_atomic_observers() -> void:
	actor.current_actions = 2
	bags.backpacks_by_heroine[&"lysandra"][0] = _slot(0, A, 1)
	var observe: Callable = func() -> void:
		_check(actor.current_actions == 1 and bar.get_slot(4).quantity == 1 and BackpackPayload.is_empty(bags.get_backpack_snapshot(&"lysandra")[0]), "Observers see both inventory and Action committed")
	bags.inventory_changed.connect(observe)
	_check(_move(_bag(0), _bar(4), 1).changed, "Atomic observed operation succeeds")
	bags.inventory_changed.disconnect(observe)
