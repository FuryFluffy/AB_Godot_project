class_name RunLootController
extends RunBackpackController
## References source dictionaries owned by RunState or EventRoomInstanceState.
## A preview validates capacity before any claim (and future trap commitment).
var sources: Array[Dictionary] = []
var party_states: Dictionary = {}

func snapshot() -> Dictionary:
	var value: Dictionary = super.snapshot()
	value["loot"] = sources.duplicate(true)
	return value

func bind_sources(records: Array[Dictionary]) -> void:
	sources = records
	changed.emit()

func payload(location: Dictionary) -> Dictionary:
	if String(location.get("domain", "")) != "loot":
		return super.payload(location)
	var index: int = int(location.get("index", -1))
	if index < 0 or index >= sources.size():
		return {}
	var record: Dictionary = sources[index]
	return {"item_id": record.get("item_id", ""), "quantity": LootClaim.remaining(record)}

func transfer(transaction: Dictionary, target: Dictionary, quantity: int, preview: bool = false) -> Dictionary:
	if String(transaction.get("source", {}).get("domain", "")) == "loot":
		return collect(transaction, target, quantity, preview)
	return super.transfer(transaction, target, quantity, preview)

func collect(transaction: Dictionary, target: Dictionary, quantity: int, preview: bool = false) -> Dictionary:
	var error: String = _validate_request(transaction)
	if not error.is_empty():
		return _error(error)
	if combat != null:
		return _error("Finish combat before collecting Loot.")
	var index: int = int(transaction.get("source", {}).get("index", -1))
	if index < 0 or index >= sources.size():
		return _error("Loot source is unavailable.")
	var record: Dictionary = sources[index]
	error = LootClaim.validate(record)
	if not error.is_empty():
		return _error(error)
	var left: int = LootClaim.remaining(record)
	if quantity < 1 or quantity > left:
		return _error("Choose an available Loot quantity.")
	var owner := StringName(target.get("heroine", ""))
	if String(target.get("domain", "")) != "backpack" or not heroine_ids.has(owner) or not inventory.backpacks_by_heroine.has(owner):
		return _error("Collect into a current heroine's Backpack first.")
	var staged: RunInventoryState = _stage_inventory()
	var item: ItemDefinition = inventory.catalog.get_item(StringName(record.get("item_id", "")))
	var incoming: Dictionary = {"item_id": record.get("item_id", ""), "quantity": quantity}
	var registries: Dictionary = {}
	if record.has("equipment_snapshot"):
		if equipment == null or quantity != 1:
			return _error("Equipment source is unavailable.")
		var instance := EquipmentInstance.new()
		error = instance.restore_from_snapshot(record.equipment_snapshot, equipment.definitions_by_id)
		if not error.is_empty():
			return _error(error)
		for loadout: PersonalEquipmentLoadoutState in equipment.loadouts_by_heroine.values():
			if loadout.get_instance(instance.instance_id) != null:
				return _error("This equipment instance is already owned.")
		incoming = BackpackPayload.equipment_slot(0, instance.instance_id)
		registries[owner] = equipment.get_loadout(owner).instances_by_id.duplicate()
		registries[owner][instance.instance_id] = instance
	elif item == null:
		return _error("Loot item is no longer defined.")
	var moved: int = 0
	if item != null and item.content_category in [ItemDefinition.ContentCategory.KEY, ItemDefinition.ContentCategory.MATERIAL]:
		error = staged.route_reward(item.item_id, quantity)
		if not error.is_empty():
			return _error(error)
		moved = quantity
	else:
		error = RefugeInventoryTransfer._eligible_item(inventory.catalog, incoming, "backpack")
		if not error.is_empty():
			return _error(error)
		var bag: Array = _slots(staged, target)
		var slot: int = int(target.get("index", -1))
		if slot < -1 or slot >= bag.size():
			return _error("Choose a valid Backpack slot.")
		var order: Array[int] = []
		if slot >= 0:
			order.append(slot)
		else:
			for i: int in range(bag.size()):
				if RefugeInventoryTransfer._matches(incoming, bag[i]):
					order.append(i)
			for i: int in range(bag.size()):
				if BackpackPayload.is_empty(bag[i]):
					order.append(i)
		for i: int in order:
			if not BackpackPayload.is_empty(bag[i]) and not RefugeInventoryTransfer._matches(incoming, bag[i]):
				return _error("Choose an empty slot or compatible stack; Loot cannot receive carried items.")
			var count: int = int(bag[i].quantity)
			var accepted: int = mini(quantity - moved, RefugeInventoryTransfer._item_limit(inventory.catalog, incoming) - count)
			if accepted > 0:
				bag[i] = RefugeInventoryTransfer._at(incoming, count + accepted, i, "backpack")
				moved += accepted
	var result: Dictionary = RefugeInventoryTransfer._result(moved, left - moved)
	if moved == 0:
		return result
	var checked: Dictionary = _commit(staged, {}, result, true, registries)
	if not String(checked.error).is_empty() or preview:
		return checked
	# Validation is complete. Publish source + destination before any observer.
	LootClaim.accept(record, moved)
	return _commit(staged, {}, result, false, registries)

func has_fight_sources() -> bool:
	for record: Dictionary in sources:
		if LootClaim.is_fight(record):
			return true
	return false

func has_fight_surplus() -> bool:
	for record: Dictionary in sources:
		if LootClaim.is_fight(record) and LootClaim.remaining(record) > 0:
			return true
	return false

func abandon_fight_surplus(expected: Dictionary) -> Dictionary:
	if combat != null or expected != snapshot() or not access_error().is_empty():
		return _error("Loot changed. Review the remaining items again.")
	for record: Dictionary in sources:
		if LootClaim.is_fight(record):
			LootClaim.abandon(record)
	changed.emit()
	return {"error": ""}

func manage_carried(transaction: Dictionary, quantity: int, target_id: StringName = &"", use: bool = false) -> Dictionary:
	var error: String = _validate_request(transaction)
	if not error.is_empty():
		return _error(error)
	if combat != null or sources.is_empty():
		return _error("Use/Discard is available only during out-of-combat Loot management.")
	var location: Dictionary = transaction.get("source", {})
	if String(location.get("domain", "")) not in ["backpack", "item_bar"]:
		return _error("Collect an item before using or discarding it.")
	if String(location.domain) == "backpack" and not heroine_ids.has(StringName(location.get("heroine", ""))):
		return _error("Choose a current heroine's Backpack.")
	var carried: Dictionary = payload(location)
	if BackpackPayload.is_empty(carried) or quantity < 1 or quantity > int(carried.get("quantity", 0)):
		return _error("Choose an available carried quantity.")
	var target: BattlerState = party_states.get(target_id)
	var item: ItemDefinition = inventory.catalog.get_item(StringName(carried.get("item_id", "")))
	if use:
		if not heroine_ids.has(target_id) or quantity != 1:
			return _error("Choose a current heroine for one item use.")
		error = RunItemUse._validate_exploration_item_use(item, target)
		if not error.is_empty():
			return _error(error)
	var staged: RunInventoryState = _stage_inventory()
	var slots: Array = _slots(staged, location)
	var index: int = int(location.index)
	if not use or item.consumes_on_use:
		slots[index] = RefugeInventoryTransfer._at(carried, int(carried.quantity) - quantity, index, String(location.domain))
	var registries: Dictionary = {}
	if carried.has("equipment_instance_id"):
		var owner := StringName(location.heroine)
		if equipment == null or equipment.get_loadout(owner) == null:
			return _error("Equipment owner is unavailable.")
		var loadout: PersonalEquipmentLoadoutState = equipment.get_loadout(owner)
		if loadout.get_instance(StringName(carried.equipment_instance_id)) == null or loadout.slot_instance_ids.values().has(StringName(carried.equipment_instance_id)):
			return _error("Only owned, unequipped carried equipment can be discarded.")
		registries[owner] = loadout.instances_by_id.duplicate()
		registries[owner].erase(StringName(carried.equipment_instance_id))
		registries[owner].erase(String(carried.equipment_instance_id))
	var result: Dictionary = RefugeInventoryTransfer._result(quantity, int(carried.quantity) - quantity)
	var checked: Dictionary = _commit(staged, {}, result, true, registries)
	if not String(checked.error).is_empty():
		return checked
	var effects: Callable
	if use:
		effects = func() -> void:
			for effect: ItemEffectDefinition in item.effects:
				RunItemUse._apply_exploration_item_effect(target, effect)
	return _commit(staged, {}, result, false, registries, effects)
