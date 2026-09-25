class_name SixSlotInventoryState
extends RefCounted


signal inventory_changed


const SLOT_COUNT: int = 6


var catalog: ItemCatalogDefinition
var slots: Array[InventorySlotState] = []
var checkpoint_item_ids: Array[StringName] = []
var checkpoint_quantities: Array[int] = []


func initialize(
	new_catalog: ItemCatalogDefinition
) -> String:
	catalog = new_catalog
	slots.clear()
	for _slot_index: int in range(SLOT_COUNT):
		slots.append(InventorySlotState.new())

	if catalog == null:
		return "The six-slot inventory has no item catalog."
	var catalog_error: String = catalog.validate_catalog()
	if not catalog_error.is_empty():
		return catalog_error
	inventory_changed.emit()
	return ""


func get_slot(
	slot_index: int
) -> InventorySlotState:
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index]


func load_items(
	item_ids: Array[StringName],
	quantities: Array[int] = []
) -> String:
	if catalog == null:
		return "The item catalog is missing."
	if item_ids.size() > SLOT_COUNT:
		return "A six-slot loadout cannot contain more than six items."

	var resolved_items: Array[ItemDefinition] = []
	var resolved_quantities: Array[int] = []
	for slot_index: int in range(item_ids.size()):
		var item_id: StringName = item_ids[slot_index]
		if item_id == &"":
			resolved_items.append(null)
			resolved_quantities.append(0)
			continue
		var item: ItemDefinition = catalog.get_item(item_id)
		if item == null:
			return "Unknown item_id: %s." % item_id
		var eligibility_error: String = _validate_item_bar_item(item)
		if not eligibility_error.is_empty():
			return eligibility_error
		var quantity: int = 1
		if slot_index < quantities.size():
			quantity = quantities[slot_index]
		if quantity <= 0 or quantity > item.stack_limit:
			return "Item Bar quantity for '%s' exceeds its authored stack rules." % item_id
		resolved_items.append(item)
		resolved_quantities.append(quantity)

	for slot: InventorySlotState in slots:
		slot.clear()

	for slot_index: int in range(resolved_items.size()):
		var item: ItemDefinition = resolved_items[slot_index]
		if item == null:
			continue
		slots[slot_index].item = item
		slots[slot_index].quantity = resolved_quantities[slot_index]

	inventory_changed.emit()
	return ""


func add_item(
	item_id: StringName,
	quantity: int = 1
) -> String:
	if catalog == null:
		return "The item catalog is missing."
	if quantity <= 0:
		return "Item quantity must be positive."
	var item: ItemDefinition = catalog.get_item(item_id)
	if item == null:
		return "Unknown item_id: %s." % item_id
	var eligibility_error: String = _validate_item_bar_item(item)
	if not eligibility_error.is_empty():
		return eligibility_error

	var available_capacity: int = 0
	for slot: InventorySlotState in slots:
		if slot.item == item:
			available_capacity += item.stack_limit - slot.quantity
		elif slot.is_empty():
			available_capacity += item.stack_limit
	if available_capacity < quantity:
		return "The six-slot Item Bar has no room for %d more %s." % [
			quantity - available_capacity,
			item.display_name,
		]

	var remaining: int = quantity
	for slot: InventorySlotState in slots:
		if (
			slot.item == item
			and slot.quantity < item.stack_limit
		):
			var added: int = mini(
				remaining,
				item.stack_limit - slot.quantity
			)
			slot.quantity += added
			remaining -= added
			if remaining <= 0:
				inventory_changed.emit()
				return ""

	for slot: InventorySlotState in slots:
		if not slot.is_empty():
			continue
		var added: int = mini(remaining, item.stack_limit)
		slot.item = item
		slot.quantity = added
		remaining -= added
		if remaining <= 0:
			inventory_changed.emit()
			return ""

	return "The six-slot Item Bar could not store %s." % item.display_name


func consume(
	slot_index: int,
	quantity: int = 1
) -> String:
	var slot: InventorySlotState = get_slot(slot_index)
	if slot == null or slot.is_empty():
		return "The selected item slot is empty."
	if quantity <= 0:
		return "Consumption quantity must be positive."
	if slot.quantity < quantity:
		return "The selected item stack is too small."

	slot.quantity -= quantity
	if slot.quantity <= 0:
		slot.clear()
	inventory_changed.emit()
	return ""


func capture_checkpoint() -> void:
	checkpoint_item_ids.clear()
	checkpoint_quantities.clear()
	for slot: InventorySlotState in slots:
		checkpoint_item_ids.append(
			slot.item.item_id
			if not slot.is_empty()
			else &""
		)
		checkpoint_quantities.append(slot.quantity)


func restore_checkpoint() -> String:
	if checkpoint_item_ids.size() != SLOT_COUNT:
		return "No complete six-slot inventory checkpoint exists."

	var restored_ids: Array[StringName] = []
	var restored_quantities: Array[int] = []
	for slot_index: int in range(SLOT_COUNT):
		restored_ids.append(checkpoint_item_ids[slot_index])
		restored_quantities.append(
			checkpoint_quantities[slot_index]
		)
	return load_items(restored_ids, restored_quantities)


func get_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for slot_index: int in range(slots.size()):
		var slot: InventorySlotState = slots[slot_index]
		snapshot.append({
			"slot_index": slot_index,
			"item_id": (
				String(slot.item.item_id)
				if not slot.is_empty()
				else ""
			),
			"quantity": slot.quantity,
		})
	return snapshot


func _validate_item_bar_item(item: ItemDefinition) -> String:
	if not item.canonical_workbook_item:
		return "Item '%s' is not a canonical carried-item Stable ID." % item.item_id
	if (
		item.content_category != ItemDefinition.ContentCategory.ACTIVE
		or not item.combat_usable
		or not item.is_active_item()
	):
		return "Item '%s' cannot enter the combat Item Bar." % item.item_id
	return ""
