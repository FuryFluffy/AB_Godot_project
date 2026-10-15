class_name RefugeInventoryTransfer
extends RefCounted
## Stateless planner over the existing Refuge ownership containers. The controller
## stages, validates and persists the complete result; no second inventory exists.

static func address(domain: StringName, index: int = -1, heroine: StringName = &"", instance: StringName = &"") -> Dictionary:
	return {"domain": domain, "index": index, "heroine": heroine, "instance": instance}

static func slots(state: RefugeOwnershipState, location: Dictionary) -> Array:
	match String(location.get("domain", "")):
		"backpack": return state.preparation_slots_by_heroine.get(StringName(location.get("heroine", "")), [])
		"item_bar": return state.prepared_item_bar_slots
		"stash": return state.stash_item_stacks
	return []

static func payload(state: RefugeOwnershipState, location: Dictionary) -> Dictionary:
	if String(location.get("domain", "")) == "stash_equipment":
		var id := StringName(location.get("instance", ""))
		if state.stash_equipment_instances.has(id) or state.stash_equipment_instances.has(String(id)):
			return {"item_id": "", "quantity": 1, "equipment_instance_id": String(id)}
		return {}
	var values: Array = slots(state, location)
	var index: int = int(location.get("index", -1))
	return values[index].duplicate(true) if index >= 0 and index < values.size() else {}

static func apply(state: RefugeOwnershipState, source: Dictionary, target: Dictionary, quantity: int, quick: bool = false) -> Dictionary:
	var item: Dictionary = payload(state, source)
	if item.is_empty() or BackpackPayload.is_empty(item):
		return _error("The source is empty or no longer available.")
	var available: int = int(item.quantity)
	if quantity <= 0 or quantity > available:
		return _error("Choose a quantity from 1 to the source quantity.")
	var domain := String(target.get("domain", ""))
	if domain not in ["backpack", "item_bar", "stash"]:
		return _error("Unsupported inventory destination.")
	if domain == "backpack" and not state.preparation_slots_by_heroine.has(StringName(target.get("heroine", ""))):
		return _error("Choose a known Backpack owner.")
	var eligibility: String = _eligible(state, item, domain)
	if not eligibility.is_empty():
		return _error(eligibility)
	if quick and _same_container(source, target):
		return _result(0, available)
	if item.has("equipment_instance_id") and quick:
		return _quick_equipment(state, source, target, item)
	if String(source.get("domain", "")) == "stash_equipment":
		return _error("Use Move to Backpack for stored equipment.")
	var from: Array = slots(state, source)
	var to: Array = slots(state, target)
	var from_index: int = int(source.get("index", -1))
	if quick:
		var remaining: int = quantity
		for index: int in range(to.size()):
			if _matches(item, to[index]):
				var accepted: int = mini(remaining, _limit(state, item) - int(to[index].quantity))
				to[index].quantity += accepted
				remaining -= accepted
		for index: int in range(to.size()):
			if remaining == 0:
				break
			if BackpackPayload.is_empty(to[index]):
				var accepted: int = mini(remaining, _limit(state, item))
				to[index] = _at(item, accepted, index, domain)
				remaining -= accepted
		while remaining > 0 and domain == "stash":
			var accepted: int = mini(remaining, _limit(state, item))
			to.append(_at(item, accepted, to.size(), domain))
			remaining -= accepted
		var moved: int = quantity - remaining
		if moved > 0:
			from[from_index] = _at(item, available - moved, from_index, String(source.domain))
			_cleanup_stash(state)
		return _result(moved, available - moved)
	if domain == "stash" or String(source.domain) == "stash":
		return _error("Use named quick transfers between Stash and Backpacks.")
	if domain == "backpack" and String(source.domain) == "backpack" and String(source.heroine) != String(target.heroine):
		return _error("Use Stash for transfers between named Backpacks.")
	var target_index: int = int(target.get("index", -1))
	if target_index < 0 or target_index >= to.size():
		return _error("Choose a valid destination slot.")
	if _same_container(source, target) and from_index == target_index:
		return _result(0, available)
	var displaced: Dictionary = to[target_index].duplicate(true)
	if _matches(item, displaced) or BackpackPayload.is_empty(displaced):
		var count: int = 0 if BackpackPayload.is_empty(displaced) else int(displaced.quantity)
		var accepted: int = mini(quantity, _limit(state, item) - count)
		if accepted > 0:
			to[target_index] = _at(item, count + accepted, target_index, domain)
			from[from_index] = _at(item, available - accepted, from_index, String(source.domain))
		return _result(accepted, available - accepted)
	if quantity != available:
		return _error("A partial stack cannot swap with a different occupied item.")
	eligibility = _eligible(state, displaced, String(source.domain))
	if not eligibility.is_empty():
		return _error(eligibility)
	to[target_index] = _at(item, available, target_index, domain)
	from[from_index] = _at(displaced, int(displaced.quantity), from_index, String(source.domain))
	return _result(quantity, 0)

static func _quick_equipment(state: RefugeOwnershipState, source: Dictionary, target: Dictionary, item: Dictionary) -> Dictionary:
	var id := StringName(item.equipment_instance_id)
	var error: String
	if String(source.domain) == "stash_equipment" and String(target.domain) == "backpack":
		var bag: Array = slots(state, target)
		var free: bool = false
		for slot: Dictionary in bag:
			free = free or BackpackPayload.is_empty(slot)
		if not free:
			return _result(0, 1)
		error = state.move_stash_equipment_to_heroine(id, StringName(target.heroine))
	elif String(source.domain) == "backpack" and String(target.domain) == "stash":
		error = state.move_unequipped_equipment_to_stash(StringName(source.heroine), id)
	else:
		return _error("Equipment quick transfers use Stash and a named Backpack.")
	return _result(1, 0) if error.is_empty() else _error(error)

static func _eligible(state: RefugeOwnershipState, item: Dictionary, domain: String) -> String:
	if item.has("equipment_instance_id"):
		return "Equipment cannot enter the Item Bar." if domain == "item_bar" else ""
	var definition: ItemDefinition = state.item_catalog.get_item(StringName(item.get("item_id", "")))
	if definition == null or not definition.canonical_workbook_item:
		return "Unknown inventory item."
	if domain == "item_bar":
		if definition.content_category != ItemDefinition.ContentCategory.ACTIVE or not definition.combat_usable:
			return "Only authored combat items can enter the Item Bar."
	elif definition.content_category not in [ItemDefinition.ContentCategory.ACTIVE, ItemDefinition.ContentCategory.MEMENTO]:
		return "Keys and Materials use their shared collections."
	return ""

static func _limit(state: RefugeOwnershipState, item: Dictionary) -> int:
	return 1 if item.has("equipment_instance_id") else state.item_catalog.get_item(StringName(item.item_id)).stack_limit

static func _matches(a: Dictionary, b: Dictionary) -> bool:
	# Canonical definitions currently carry no per-stack modifiers. Stable ID is
	# their compatibility key; equipment instances never merge.
	return not a.has("equipment_instance_id") and not b.has("equipment_instance_id") and not BackpackPayload.is_empty(b) and String(a.item_id) == String(b.item_id)

static func _same_container(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("domain", "")) == String(b.get("domain", "")) and (String(a.get("domain", "")) != "backpack" or String(a.get("heroine", "")) == String(b.get("heroine", "")))

static func _at(item: Dictionary, quantity: int, index: int, domain: String) -> Dictionary:
	var result: Dictionary = {"item_id": "", "quantity": 0}
	if quantity > 0:
		result = item.duplicate(true)
		result.quantity = quantity
	result.erase("stack_index")
	result.erase("slot_index")
	result["stack_index" if domain == "stash" else "slot_index"] = index
	return result

static func _cleanup_stash(state: RefugeOwnershipState) -> void:
	for index: int in range(state.stash_item_stacks.size() - 1, -1, -1):
		if int(state.stash_item_stacks[index].quantity) == 0:
			state.stash_item_stacks.remove_at(index)
	for index: int in range(state.stash_item_stacks.size()):
		state.stash_item_stacks[index].stack_index = index

static func _result(moved: int, remaining: int) -> Dictionary:
	return {"error": "", "moved": moved, "remaining": remaining, "changed": moved > 0}

static func _error(message: String) -> Dictionary:
	return {"error": message, "moved": 0, "changed": false}
