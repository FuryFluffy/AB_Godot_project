class_name RefugeLoadoutExchange
extends RefCounted
## Stateless source-return exchanges over existing Refuge ownership snapshots.
## Only one equipped slot is changed. No automatic multi-slot displacement.

const KEYS: Array[StringName] = [&"main_hand", &"off_hand", &"armor", &"memento"]

static func candidates(state: RefugeOwnershipState, heroine: StringName, slot: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not state.known_heroine_ids.has(heroine) or not KEYS.has(slot):
		return result
	result.append({"source": {"domain": &"nothing"}, "display_name": "Nothing", "source_label": "Return current item to Stash", "condition_text": ""})
	if slot == &"memento":
		for index: int in range(state.stash_item_stacks.size()):
			_add_memento(result, state, heroine, state.stash_item_stacks[index], RefugeInventoryTransfer.address(&"stash", index), "Stash")
	else:
		var ids: Array = state.stash_equipment_instances.keys()
		ids.sort()
		for id: Variant in ids:
			_add_equipment(result, state, heroine, slot, state.stash_equipment_instances[id], RefugeInventoryTransfer.address(&"stash_equipment", -1, &"", StringName(id)), "Stash")
	for owner: StringName in state.known_heroine_ids:
		var name_text: String = state.battler_catalog.get_battler(owner).display_name
		var bag: Array = state.preparation_slots_by_heroine[owner]
		for index: int in range(bag.size()):
			var source: Dictionary = RefugeInventoryTransfer.address(&"backpack", index, owner)
			var label: String = "Backpack · %s · slot %d" % [name_text, index + 1]
			if slot == &"memento":
				_add_memento(result, state, heroine, bag[index], source, label)
			elif bag[index].has("equipment_instance_id"):
				var instances: Dictionary = state.equipment_loadouts_by_heroine[owner].instances
				_add_equipment(result, state, heroine, slot, instances.get(String(bag[index].equipment_instance_id), {}), source, label)
	return result

static func _add_equipment(result: Array[Dictionary], state: RefugeOwnershipState, heroine: StringName, slot: StringName, record: Dictionary, source: Dictionary, label: String) -> void:
	var definition: EquipmentDefinition = state.equipment_definitions_by_id.get(StringName(record.get("definition_id", "")))
	if definition == null or not definition.player_refuge_available or not definition.allows_slot(KEYS.find(slot)):
		return
	if not _hand_error(state, heroine, slot, definition).is_empty():
		return
	result.append({"source": source, "display_name": definition.display_name, "source_label": label, "instance_id": String(record.instance_id), "condition_text": "Condition %d/%d%s" % [int(record.current_condition), definition.condition_maximum, " · Broken" if int(record.current_condition) == 0 else ""]})

static func _add_memento(result: Array[Dictionary], state: RefugeOwnershipState, heroine: StringName, item: Dictionary, source: Dictionary, label: String) -> void:
	var id := StringName(item.get("item_id", ""))
	var definition: ItemDefinition = state.item_catalog.get_item(id)
	if definition == null or not definition.canonical_workbook_item or definition.content_category != ItemDefinition.ContentCategory.MEMENTO or int(item.get("quantity", 0)) != 1:
		return
	for owner: StringName in state.known_heroine_ids:
		var equipped: Variant = state.memento_slots_by_heroine.get(owner, null)
		if owner != heroine and equipped != null and String(equipped) == String(id):
			return # Preserve the existing one-equipped-owner-per-Memento-ID rule.
	result.append({"source": source, "display_name": definition.display_name, "source_label": label, "item_id": id, "icon": definition.icon, "condition_text": "", "description": definition.description})

static func apply(state: RefugeOwnershipState, heroine: StringName, slot: StringName, source: Dictionary) -> Dictionary:
	var valid: bool = false
	for candidate: Dictionary in candidates(state, heroine, slot):
		if candidate.source == source:
			valid = true
			break
	if not valid:
		return _error("That source is no longer a compatible stored item for this slot.")
	if slot == &"memento":
		return _memento(state, heroine, source)
	var recipient: Dictionary = state.equipment_loadouts_by_heroine[heroine]
	var old_id := StringName(recipient.slots.get(slot, ""))
	var old_record: Dictionary = recipient.instances.get(String(old_id), {}).duplicate(true)
	var nothing: bool = String(source.domain) == "nothing"
	if nothing and old_id == &"":
		return {"error": "", "changed": false}
	var incoming: Dictionary = {}
	if not nothing:
		if String(source.domain) == "stash_equipment":
			incoming = state.stash_equipment_instances[StringName(source.instance)].duplicate(true)
			state.stash_equipment_instances.erase(StringName(source.instance))
		else:
			var bag: Array = state.preparation_slots_by_heroine[StringName(source.heroine)]
			var id: String = String(bag[int(source.index)].equipment_instance_id)
			var owner: Dictionary = state.equipment_loadouts_by_heroine[StringName(source.heroine)]
			incoming = owner.instances[id].duplicate(true)
			owner.instances.erase(id)
			bag[int(source.index)] = RefugeInventoryTransfer._at({}, 0, int(source.index), "backpack")
	# Remove the outgoing registry record before placing it in the exact source.
	recipient.slots[String(slot)] = ""
	if not old_record.is_empty():
		recipient.instances.erase(String(old_id))
		if nothing or String(source.domain) == "stash_equipment":
			state.stash_equipment_instances[old_id] = old_record
		else:
			var source_owner := StringName(source.heroine)
			state.equipment_loadouts_by_heroine[source_owner].instances[String(old_id)] = old_record
			state.preparation_slots_by_heroine[source_owner][int(source.index)] = BackpackPayload.equipment_slot(int(source.index), old_id)
	if not incoming.is_empty():
		recipient.instances[String(incoming.instance_id)] = incoming
		recipient.slots[String(slot)] = String(incoming.instance_id)
	return {"error": "", "changed": true}

static func _memento(state: RefugeOwnershipState, heroine: StringName, source: Dictionary) -> Dictionary:
	var old_value: Variant = state.memento_slots_by_heroine.get(heroine, null)
	var old_id: StringName = &"" if old_value == null else StringName(old_value)
	var nothing: bool = String(source.domain) == "nothing"
	var incoming: Dictionary = {} if nothing else RefugeInventoryTransfer.payload(state, source)
	var next_id := StringName(incoming.get("item_id", ""))
	if old_id == next_id:
		return {"error": "", "changed": false}
	if not nothing:
		var contents: Array = RefugeInventoryTransfer.slots(state, source)
		contents[int(source.index)] = RefugeInventoryTransfer._at({}, 0, int(source.index), String(source.domain))
	state.memento_slots_by_heroine[heroine] = null if nothing else next_id
	if old_id != &"":
		if nothing or String(source.domain) == "stash":
			var error: String = state.add_stash_item(old_id, 1)
			if not error.is_empty():
				return _error(error)
		else:
			state.preparation_slots_by_heroine[StringName(source.heroine)][int(source.index)] = {"slot_index": int(source.index), "item_id": String(old_id), "quantity": 1}
	RefugeInventoryTransfer._cleanup_stash(state)
	return {"error": "", "changed": true}

static func _hand_error(state: RefugeOwnershipState, heroine: StringName, slot: StringName, definition: EquipmentDefinition) -> String:
	var loadout: Dictionary = state.equipment_loadouts_by_heroine[heroine]
	if slot == &"main_hand" and definition is WeaponDefinition and (definition as WeaponDefinition).is_two_handed and String(loadout.slots.off_hand) != "":
		return "Clear Off Hand first; automatic multi-slot displacement is unsupported."
	if slot == &"off_hand" and String(loadout.slots.main_hand) != "":
		var record: Dictionary = loadout.instances.get(String(loadout.slots.main_hand), {})
		var main: EquipmentDefinition = state.equipment_definitions_by_id.get(StringName(record.get("definition_id", "")))
		if main is WeaponDefinition and (main as WeaponDefinition).is_two_handed:
			return "Clear the two-handed Main Hand first."
	return ""

static func equipped_entries(state: RefugeOwnershipState, heroine: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not state.known_heroine_ids.has(heroine):
		return result
	var loadout: Dictionary = state.equipment_loadouts_by_heroine[heroine]
	for slot: StringName in KEYS:
		var entry: Dictionary = {"slot": slot, "label": "Memento" if slot == &"memento" else EquipmentDefinition.get_slot_label(KEYS.find(slot)), "display_name": "Empty", "condition_text": "", "icon": null}
		if slot == &"memento":
			var value: Variant = state.memento_slots_by_heroine.get(heroine, null)
			var definition: ItemDefinition = null if value == null else state.item_catalog.get_item(StringName(value))
			if definition != null:
				entry.display_name = definition.display_name
				entry.icon = definition.icon
				entry["description"] = definition.description
		else:
			var record: Dictionary = loadout.instances.get(String(loadout.slots.get(slot, "")), {})
			var definition: EquipmentDefinition = state.equipment_definitions_by_id.get(StringName(record.get("definition_id", "")))
			if definition != null:
				entry.display_name = definition.display_name
				entry.condition_text = "Condition %d/%d%s" % [int(record.current_condition), definition.condition_maximum, " · Broken" if int(record.current_condition) == 0 else ""]
		result.append(entry)
	return result

static func _error(message: String) -> Dictionary:
	return {"error": message, "changed": false}
