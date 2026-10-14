class_name InventorySlotPresenter
extends RefCounted
## Read-only adapter for the same slot view in Refuge and run contexts.
## Equipment condition is resolved from its existing registry, never copied into a slot.

static func entries(
	slots: Array,
	domain: StringName,
	items: ItemCatalogDefinition,
	equipment: EquipmentCatalogDefinition,
	instances: Dictionary = {}
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(slots.size()):
		var slot: Dictionary = slots[index]
		var entry: Dictionary = slot.duplicate(true)
		var item_id := StringName(slot.get("item_id", ""))
		var definition: ItemDefinition = items.get_item(item_id)
		var is_memento: bool = (
			definition != null
			and definition.content_category == ItemDefinition.ContentCategory.MEMENTO
		)
		entry.merge({
			"slot_index": int(slot.get("slot_index", index)),
			"domain": domain,
			"display_name": definition.display_name if definition != null else "Empty",
			"icon": definition.icon if definition != null else null,
			"combat_usable": definition.combat_usable if definition != null else false,
			"kind": "Memento" if is_memento else "Item",
		}, true)
		if slot.has("equipment_instance_id"):
			var id := StringName(slot.equipment_instance_id)
			var record: Dictionary = instances.get(id, instances.get(String(id), {}))
			var gear: EquipmentDefinition = equipment.get_equipment(
				StringName(record.get("definition_id", ""))
			)
			entry.merge({
				"kind": "Equipment",
				"display_name": gear.display_name if gear != null else String(id),
				"instance_id": id,
				"condition": int(record.get("current_condition", 0)),
				"condition_maximum": gear.condition_maximum if gear != null else 0,
			}, true)
		entry["empty"] = BackpackPayload.is_empty(slot)
		entry["details"] = _details(entry)
		result.append(entry)
	return result


static func _details(entry: Dictionary) -> String:
	if entry.empty:
		return "Empty slot"
	var state: String = (
		"Condition: %d/%d" % [entry.condition, entry.condition_maximum]
		if entry.kind == "Equipment"
		else "Quantity: %d" % int(entry.get("quantity", 0))
	)
	return "%s · %s\n%s" % [entry.display_name, entry.kind, state]


static func run_backpack(
	inventory: RunInventoryState,
	equipment: RunEquipmentState,
	heroine_id: StringName
) -> Array[Dictionary]:
	var registry: Dictionary = {}
	if equipment != null:
		var snapshot: Dictionary = equipment.get_snapshot()
		var loadouts: Dictionary = snapshot.get("loadouts_by_heroine", {})
		var loadout: Dictionary = loadouts.get(heroine_id, loadouts.get(String(heroine_id), {}))
		registry = loadout.get("instances", {})
	return entries(
		inventory.get_backpack_snapshot(heroine_id), &"backpack",
		inventory.catalog, RefugeManagementController.EQUIPMENT_CATALOG, registry
	)
