class_name RunBackpackController
extends RefCounted
## Transaction boundary over the existing run owners. No mid-node saves: the
## encounter/room outcome is persisted by the production safe-point lifecycle.

signal changed
var inventory: RunInventoryState
var item_bar: SixSlotInventoryState
var equipment: RunEquipmentState
var heroine_ids: Array[StringName] = []
var combat: CombatEngine
var exploration_guard: Callable

func configure(bags: RunInventoryState, bar: SixSlotInventoryState, gear: RunEquipmentState, ids: Array[StringName], engine: CombatEngine = null) -> void:
	inventory = bags
	item_bar = bar
	equipment = gear
	heroine_ids = ids.duplicate()
	combat = engine

func access_error() -> String:
	if inventory == null or item_bar == null:
		return "Run Backpack is unavailable."
	if combat != null:
		if not heroine_ids.has(actor_id()):
			return "This combatant has no expedition Backpack."
		return combat.backpack_access_error()
	return String(exploration_guard.call()) if exploration_guard.is_valid() else ""

func actor_id() -> StringName:
	return combat.battle_runtime.selected_battler_id if combat != null else &""

func mutation_error(owner: StringName) -> String:
	var error: String = access_error()
	if not error.is_empty():
		return error
	if not heroine_ids.has(owner):
		return "Choose a current expedition heroine."
	if combat != null:
		if owner != actor_id():
			return "Read only: only the acting heroine's Backpack can change."
		return combat.backpack_mutation_error()
	return ""

func snapshot() -> Dictionary:
	var state: Dictionary = inventory.get_snapshot()
	# Item use is owned by the native six-slot state during a node.
	state.item_bar_slots = item_bar.get_snapshot()
	return {"inventory": state, "equipment": equipment.get_snapshot() if equipment != null else {},
		"actor": actor_id(), "actions": combat.get_battler_state(actor_id()).current_actions if combat != null and combat.get_battler_state(actor_id()) != null else -1,
		"round": combat.battle_runtime.battle_state.round_number if combat != null else 0,
		"phase": combat.battle_runtime.battle_state.phase if combat != null else 0}

func request(source: Dictionary) -> Dictionary:
	return {"source": source.duplicate(true), "snapshot": snapshot()}

func payload(location: Dictionary) -> Dictionary:
	var values: Array = _slots(inventory, location)
	if String(location.get("domain", "")) == "item_bar":
		values = item_bar.get_snapshot()
	var index: int = int(location.get("index", -1))
	return values[index].duplicate(true) if index >= 0 and index < values.size() else {}

func transfer(transaction: Dictionary, target: Dictionary, quantity: int, preview: bool = false) -> Dictionary:
	var source: Dictionary = transaction.get("source", {})
	var error: String = _validate_request(transaction)
	if not error.is_empty():
		return _error(error)
	for location: Dictionary in [source, target]:
		if String(location.get("domain", "")) not in ["backpack", "item_bar"]:
			return _error("Only current Backpacks and the shared Item Bar are available.")
		if String(location.domain) == "backpack":
			error = mutation_error(StringName(location.get("heroine", "")))
			if not error.is_empty():
				return _error(error)
	if combat != null and String(source.domain) == String(target.domain):
		return _error("Combat permits Backpack ↔ Item Bar changes only.")
	var staged: RunInventoryState = _stage_inventory()
	var result: Dictionary = RefugeInventoryTransfer.apply_ordered(inventory.catalog, source, target, quantity, _slots(staged, source), _slots(staged, target))
	if not String(result.error).is_empty() or not result.changed:
		return result
	return _commit(staged, {}, result, preview)

func equip(transaction: Dictionary, slot: EquipmentDefinition.Slot, preview: bool = false) -> Dictionary:
	var error: String = _validate_request(transaction)
	if not error.is_empty():
		return _error(error)
	if combat == null:
		return _error("Equipment changes are not available in this Backpack context.")
	var source: Dictionary = transaction.get("source", {})
	var owner := StringName(source.get("heroine", ""))
	error = mutation_error(owner)
	if not error.is_empty():
		return _error(error)
	if String(source.get("domain", "")) != "backpack" or equipment == null:
		return _error("Choose carried equipment from the actor's Backpack.")
	var loadout: PersonalEquipmentLoadoutState = equipment.get_loadout(owner)
	if loadout == null:
		return _error("Equipment owner is unavailable.")
	var item: Dictionary = payload(source)
	var incoming: EquipmentInstance = loadout.get_instance(StringName(item.get("equipment_instance_id", "")))
	if incoming == null or not ((slot == EquipmentDefinition.Slot.MAIN_HAND and incoming.definition is WeaponDefinition) or (slot == EquipmentDefinition.Slot.ARMOR and incoming.definition is ArmorDefinition)):
		return _error("Only carried Main Hand weapons and Armor can replace combat equipment.")
	if not incoming.definition.allows_slot(slot):
		return _error("This equipment is incompatible with that slot.")
	var displaced: EquipmentInstance = loadout.get_equipped_instance(slot)
	if displaced == incoming:
		return RefugeInventoryTransfer._result(0, 1)
	var staged: RunInventoryState = _stage_inventory()
	var index: int = int(source.get("index", -1))
	var bag: Array = _slots(staged, source)
	if index < 0 or index >= bag.size():
		return _error("Choose a valid Backpack slot.")
	bag[index] = BackpackPayload.equipment_slot(index, displaced.instance_id) if displaced != null else {"slot_index": index, "item_id": "", "quantity": 0}
	var assignments: Dictionary = loadout.slot_instance_ids.duplicate(true)
	assignments[EquipmentDefinition.get_slot_key(slot)] = incoming.instance_id
	return _commit(staged, assignments, RefugeInventoryTransfer._result(1, 0), preview)

func _validate_request(transaction: Dictionary) -> String:
	var error: String = access_error()
	if not error.is_empty():
		return error
	if transaction.get("snapshot", {}) != snapshot():
		return "Inventory or turn changed. Select the source again."
	if combat != null:
		return mutation_error(actor_id())
	return ""

func _stage_inventory() -> RunInventoryState:
	var staged := RunInventoryState.new()
	staged.catalog = inventory.catalog
	staged.backpacks_by_heroine = inventory.backpacks_by_heroine.duplicate(true)
	staged.memento_slots_by_heroine = inventory.memento_slots_by_heroine.duplicate(true)
	var error: String = staged.restore_from_snapshot(snapshot().inventory, true)
	assert(error.is_empty(), error)
	return staged

func _commit(staged: RunInventoryState, assignments: Dictionary, result: Dictionary, preview: bool, registries: Dictionary = {}, final_effect: Callable = Callable()) -> Dictionary:
	# Validate every destination before publishing any change or spending Actions.
	var checked: RunInventoryState = _stage_inventory()
	var error: String = checked.restore_from_snapshot(staged.get_snapshot(), true)
	if not error.is_empty():
		return _error(error)
	var loadout: PersonalEquipmentLoadoutState
	if equipment != null:
		var loadouts: Dictionary = equipment.get_snapshot().loadouts_by_heroine
		for owner: Variant in registries:
			var snapshots: Dictionary = {}
			for id: Variant in registries[owner]:
				snapshots[String(id)] = registries[owner][id].to_snapshot()
			loadouts[String(owner)].instances = snapshots
		if not assignments.is_empty():
			loadout = equipment.get_loadout(actor_id())
			loadouts[String(actor_id())].slots = assignments.duplicate(true)
		error = BackpackPayload.validate_locations(staged.backpacks_by_heroine, loadouts)
		if not error.is_empty():
			return _error(error)
	var ids: Array[StringName] = []
	var quantities: Array[int] = []
	for slot: Dictionary in staged.item_bar_slots:
		ids.append(StringName(slot.item_id))
		quantities.append(int(slot.quantity))
	var checked_bar := SixSlotInventoryState.new()
	checked_bar.initialize(inventory.catalog)
	error = checked_bar.load_items(ids, quantities)
	if not error.is_empty():
		return _error(error)
	if preview:
		return result
	var actor: BattlerState = combat.get_battler_state(actor_id()) if combat != null else null
	# No fallible operation follows this point. Observers see ownership + Action
	# together; original instance objects and condition adapters are retained.
	for owner: Variant in registries:
		equipment.get_loadout(StringName(owner)).instances_by_id = registries[owner]
	inventory.key_chain = staged.key_chain
	inventory.material_pouch = staged.material_pouch
	inventory.item_bar_slots = staged.item_bar_slots
	inventory.backpacks_by_heroine = staged.backpacks_by_heroine
	item_bar.slots = checked_bar.slots
	if loadout != null:
		loadout.slot_instance_ids = assignments
	if actor != null:
		actor.current_actions -= 1
	if final_effect.is_valid():
		final_effect.call()
	if loadout != null:
		loadout.loadout_changed.emit()
	inventory.inventory_changed.emit()
	item_bar.inventory_changed.emit()
	if actor != null:
		actor.state_changed.emit()
	changed.emit()
	return result

func _slots(state: RunInventoryState, location: Dictionary) -> Array:
	match String(location.get("domain", "")):
		"backpack": return state.backpacks_by_heroine.get(StringName(location.get("heroine", "")), [])
		"item_bar": return state.item_bar_slots
	return []

func _error(message: String) -> Dictionary:
	return RefugeInventoryTransfer._error(message)
