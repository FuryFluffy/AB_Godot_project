class_name BackpackPayload
extends RefCounted
## Backpack equipment slots reference the existing registry; condition lives there.
## Old item_id/quantity slots remain byte-compatible. Mementos retain Item IDs.

static func is_empty(slot: Dictionary) -> bool:
	return String(slot.get("equipment_instance_id", "")).is_empty() and String(slot.get("item_id", "")).is_empty() and int(slot.get("quantity", 0)) == 0


static func equipment_slot(index: int, instance_id: StringName) -> Dictionary:
	return {"slot_index": index, "item_id": "", "quantity": 1, "equipment_instance_id": String(instance_id)}


static func validate_reference(slot: Dictionary) -> String:
	var id: Variant = slot.get("equipment_instance_id")
	if not (id is String or id is StringName) or String(id).is_empty():
		return "Backpack equipment requires a non-empty instance ID."
	var quantity: Variant = slot.get("quantity")
	if not (quantity is int or quantity is float) or float(quantity) != 1.0 or String(slot.get("item_id", "")) != "":
		return "Equipment occupies one Backpack slot and cannot also contain an item stack."
	return ""


static func validate_locations(backpacks: Dictionary, loadouts: Dictionary) -> String:
	var seen: Dictionary = {}
	for heroine: Variant in backpacks:
		var loadout: Dictionary = loadouts.get(heroine, loadouts.get(String(heroine), {}))
		var instances: Dictionary = loadout.get("instances", {})
		var equipped: Dictionary = loadout.get("slots", {})
		for slot: Dictionary in backpacks[heroine]:
			if not slot.has("equipment_instance_id"):
				continue
			var id := StringName(slot.equipment_instance_id)
			if seen.has(id):
				return "Equipment instance '%s' occupies multiple Backpacks/slots." % id
			if not instances.has(id) and not instances.has(String(id)):
				return "Backpack references unregistered equipment '%s' for '%s'." % [id, heroine]
			for assigned: Variant in equipped.values():
				if String(assigned) == String(id):
					return "Equipment '%s' cannot be equipped and carried simultaneously." % id
			seen[id] = true
	return ""
