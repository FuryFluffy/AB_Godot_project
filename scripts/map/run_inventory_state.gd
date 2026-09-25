class_name RunInventoryState
extends RefCounted


signal inventory_changed


const ITEM_BAR_SLOT_COUNT: int = 6
const BACKPACK_SLOT_COUNT: int = 15

const DOMAIN_ITEM_BAR: StringName = &"item_bar"
const DOMAIN_BACKPACK: StringName = &"backpack"
const DOMAIN_KEY_CHAIN: StringName = &"key_chain"
const DOMAIN_MATERIAL_POUCH: StringName = &"material_pouch"
const DOMAIN_MEMENTO: StringName = &"memento"


var catalog: ItemCatalogDefinition
var item_bar_slots: Array[Dictionary] = []
var backpacks_by_heroine: Dictionary = {}
var key_chain: Dictionary = {}
var material_pouch: Dictionary = {}
var memento_slots_by_heroine: Dictionary = {}


func initialize(
	new_catalog: ItemCatalogDefinition,
	active_heroine_ids: Array[StringName],
	include_authored_item_bar_loadout: bool = false
) -> String:
	if new_catalog == null:
		return "Run inventory requires the item catalog."
	var catalog_error: String = new_catalog.validate_catalog()
	if not catalog_error.is_empty():
		return catalog_error
	var normalized_heroine_ids: Array[StringName] = []
	for heroine_id: StringName in active_heroine_ids:
		if heroine_id == &"":
			return "Run inventory received an empty heroine ID."
		if normalized_heroine_ids.has(heroine_id):
			return "Run inventory received duplicate heroine '%s'." % heroine_id
		normalized_heroine_ids.append(heroine_id)
	if normalized_heroine_ids.is_empty():
		return "Run inventory requires at least one active heroine."

	catalog = new_catalog
	item_bar_slots = _make_empty_slots(ITEM_BAR_SLOT_COUNT)
	backpacks_by_heroine.clear()
	memento_slots_by_heroine.clear()
	for heroine_id: StringName in normalized_heroine_ids:
		backpacks_by_heroine[heroine_id] = _make_empty_slots(
			BACKPACK_SLOT_COUNT
		)
		memento_slots_by_heroine[heroine_id] = null
	key_chain.clear()
	material_pouch.clear()

	if include_authored_item_bar_loadout:
		var loadout_error: String = restore_item_bar_snapshot(
			_make_authored_item_bar_loadout()
		)
		if not loadout_error.is_empty():
			return loadout_error
	inventory_changed.emit()
	return ""


func get_snapshot() -> Dictionary:
	var backpacks: Dictionary = {}
	for heroine_key: Variant in backpacks_by_heroine.keys():
		backpacks[String(heroine_key)] = (
			(backpacks_by_heroine[heroine_key] as Array).duplicate(true)
		)
	var mementos: Dictionary = {}
	for heroine_key: Variant in memento_slots_by_heroine.keys():
		var stored_value: Variant = memento_slots_by_heroine[heroine_key]
		mementos[String(heroine_key)] = (
			null if stored_value == null else String(stored_value)
		)
	return {
		"item_bar_slots": item_bar_slots.duplicate(true),
		"backpacks_by_heroine": backpacks,
		"key_chain": key_chain.duplicate(true),
		"material_pouch": material_pouch.duplicate(true),
		"memento_slots_by_heroine": mementos,
	}


func restore_from_snapshot(
	snapshot: Dictionary,
	allow_retained_legacy_item_bar_item: bool = false
) -> String:
	if catalog == null:
		return "Run inventory requires initialization before restoration."
	var item_bar_value: Variant = snapshot.get("item_bar_slots", null)
	var backpacks_value: Variant = snapshot.get(
		"backpacks_by_heroine",
		null
	)
	var key_chain_value: Variant = snapshot.get("key_chain", null)
	var material_value: Variant = snapshot.get("material_pouch", null)
	var memento_value: Variant = snapshot.get(
		"memento_slots_by_heroine",
		null
	)
	if not (item_bar_value is Array):
		return "Run inventory snapshot has an invalid Item Bar."
	if not (backpacks_value is Dictionary):
		return "Run inventory snapshot has invalid backpacks."
	if not (key_chain_value is Dictionary):
		return "Run inventory snapshot has an invalid Key Chain."
	if not (material_value is Dictionary):
		return "Run inventory snapshot has an invalid Material Pouch."
	if not (memento_value is Dictionary):
		return "Run inventory snapshot has invalid Memento slots."

	var staged_item_bar: Array[Dictionary] = []
	var item_bar_error: String = _normalize_ordered_slots(
		item_bar_value as Array,
		ITEM_BAR_SLOT_COUNT,
		DOMAIN_ITEM_BAR,
		staged_item_bar,
		allow_retained_legacy_item_bar_item
	)
	if not item_bar_error.is_empty():
		return item_bar_error

	var staged_backpacks: Dictionary = {}
	var stored_backpacks: Dictionary = backpacks_value as Dictionary
	if stored_backpacks.size() != backpacks_by_heroine.size():
		return "Run inventory snapshot does not match the active heroine set."
	for heroine_key: Variant in backpacks_by_heroine.keys():
		var heroine_id := StringName(heroine_key)
		var backpack_value: Variant = stored_backpacks.get(
			heroine_id,
			stored_backpacks.get(String(heroine_id), null)
		)
		if not (backpack_value is Array):
			return "Run inventory snapshot is missing %s's backpack." % heroine_id
		var staged_slots: Array[Dictionary] = []
		var backpack_error: String = _normalize_ordered_slots(
			backpack_value as Array,
			BACKPACK_SLOT_COUNT,
			DOMAIN_BACKPACK,
			staged_slots
		)
		if not backpack_error.is_empty():
			return backpack_error
		staged_backpacks[heroine_id] = staged_slots

	var staged_key_chain: Dictionary = {}
	var key_error: String = _normalize_quantity_dictionary(
		key_chain_value as Dictionary,
		DOMAIN_KEY_CHAIN,
		staged_key_chain
	)
	if not key_error.is_empty():
		return key_error
	var staged_material_pouch: Dictionary = {}
	var material_error: String = _normalize_quantity_dictionary(
		material_value as Dictionary,
		DOMAIN_MATERIAL_POUCH,
		staged_material_pouch
	)
	if not material_error.is_empty():
		return material_error

	var stored_mementos: Dictionary = memento_value as Dictionary
	if stored_mementos.size() != memento_slots_by_heroine.size():
		return "Run inventory snapshot does not match the heroine Memento slots."
	var staged_mementos: Dictionary = {}
	for heroine_key: Variant in memento_slots_by_heroine.keys():
		var heroine_id := StringName(heroine_key)
		var stored_value: Variant = stored_mementos.get(
			heroine_id,
			stored_mementos.get(String(heroine_id), null)
		)
		if stored_value == null or StringName(stored_value) == &"":
			staged_mementos[heroine_id] = null
			continue
		var memento_id := StringName(stored_value)
		var memento_error: String = _validate_item_for_domain(
			memento_id,
			DOMAIN_MEMENTO
		)
		if not memento_error.is_empty():
			return memento_error
		staged_mementos[heroine_id] = memento_id

	item_bar_slots = staged_item_bar
	backpacks_by_heroine = staged_backpacks
	key_chain = staged_key_chain
	material_pouch = staged_material_pouch
	memento_slots_by_heroine = staged_mementos
	inventory_changed.emit()
	return ""


func get_item_bar_snapshot() -> Array[Dictionary]:
	return item_bar_slots.duplicate(true)


func restore_item_bar_snapshot(
	snapshot: Array,
	allow_retained_legacy_item: bool = false
) -> String:
	if catalog == null:
		return "Run inventory requires initialization before Item Bar restoration."
	var staged_slots: Array[Dictionary] = []
	var restore_error: String = _normalize_ordered_slots(
		snapshot,
		ITEM_BAR_SLOT_COUNT,
		DOMAIN_ITEM_BAR,
		staged_slots,
		allow_retained_legacy_item
	)
	if not restore_error.is_empty():
		return restore_error
	item_bar_slots = staged_slots
	inventory_changed.emit()
	return ""


func get_backpack_snapshot(heroine_id: StringName) -> Array[Dictionary]:
	var stored_value: Variant = backpacks_by_heroine.get(heroine_id, null)
	if not (stored_value is Array):
		return []
	var result: Array[Dictionary] = []
	for slot_value: Variant in (stored_value as Array):
		result.append((slot_value as Dictionary).duplicate(true))
	return result


func add_to_item_bar(item_id: StringName, quantity: int = 1) -> String:
	return _add_to_owned_slots(
		item_bar_slots,
		item_id,
		quantity,
		DOMAIN_ITEM_BAR,
		func(updated_slots: Array[Dictionary]) -> void:
			item_bar_slots = updated_slots
	)


func remove_from_item_bar(item_id: StringName, quantity: int = 1) -> String:
	return _remove_from_owned_slots(
		item_bar_slots,
		item_id,
		quantity,
		func(updated_slots: Array[Dictionary]) -> void:
			item_bar_slots = updated_slots
	)


func add_to_backpack(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int = 1
) -> String:
	var backpack_value: Variant = backpacks_by_heroine.get(heroine_id, null)
	if not (backpack_value is Array):
		return "No active heroine owns backpack '%s'." % heroine_id
	var current_slots: Array[Dictionary] = []
	for slot_value: Variant in (backpack_value as Array):
		current_slots.append((slot_value as Dictionary).duplicate(true))
	return _add_to_owned_slots(
		current_slots,
		item_id,
		quantity,
		DOMAIN_BACKPACK,
		func(updated_slots: Array[Dictionary]) -> void:
			backpacks_by_heroine[heroine_id] = updated_slots
	)


func remove_from_backpack(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int = 1
) -> String:
	var backpack_value: Variant = backpacks_by_heroine.get(heroine_id, null)
	if not (backpack_value is Array):
		return "No active heroine owns backpack '%s'." % heroine_id
	var current_slots: Array[Dictionary] = []
	for slot_value: Variant in (backpack_value as Array):
		current_slots.append((slot_value as Dictionary).duplicate(true))
	return _remove_from_owned_slots(
		current_slots,
		item_id,
		quantity,
		func(updated_slots: Array[Dictionary]) -> void:
			backpacks_by_heroine[heroine_id] = updated_slots
	)


func move_backpack_to_item_bar(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int
) -> String:
	return _move_between_ordered_domains(
		heroine_id,
		item_id,
		quantity,
		true
	)


func move_item_bar_to_backpack(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int
) -> String:
	return _move_between_ordered_domains(
		heroine_id,
		item_id,
		quantity,
		false
	)


func add_to_key_chain(item_id: StringName, quantity: int = 1) -> String:
	return _add_to_quantity_domain(
		key_chain,
		item_id,
		quantity,
		DOMAIN_KEY_CHAIN
	)


func consume_key(item_id: StringName, quantity: int = 1) -> String:
	return _remove_from_quantity_domain(
		key_chain,
		item_id,
		quantity,
		"Key Chain"
	)


func get_key_quantity(item_id: StringName) -> int:
	return int(key_chain.get(String(item_id), key_chain.get(item_id, 0)))


func add_to_material_pouch(item_id: StringName, quantity: int = 1) -> String:
	return _add_to_quantity_domain(
		material_pouch,
		item_id,
		quantity,
		DOMAIN_MATERIAL_POUCH
	)


func consume_material(item_id: StringName, quantity: int = 1) -> String:
	return _remove_from_quantity_domain(
		material_pouch,
		item_id,
		quantity,
		"Material Pouch"
	)


func assign_memento(
	heroine_id: StringName,
	item_id: StringName
) -> String:
	if not memento_slots_by_heroine.has(heroine_id):
		return "No active heroine owns Memento slot '%s'." % heroine_id
	var item_error: String = _validate_item_for_domain(item_id, DOMAIN_MEMENTO)
	if not item_error.is_empty():
		return item_error
	if memento_slots_by_heroine[heroine_id] != null:
		return "%s's Memento slot is already occupied." % heroine_id
	memento_slots_by_heroine[heroine_id] = item_id
	inventory_changed.emit()
	return ""


func clear_memento(heroine_id: StringName) -> String:
	if not memento_slots_by_heroine.has(heroine_id):
		return "No active heroine owns Memento slot '%s'." % heroine_id
	memento_slots_by_heroine[heroine_id] = null
	inventory_changed.emit()
	return ""


func get_memento_id(heroine_id: StringName) -> StringName:
	var stored_value: Variant = memento_slots_by_heroine.get(heroine_id, null)
	return &"" if stored_value == null else StringName(stored_value)


func route_reward(
	item_id: StringName,
	quantity: int,
	owner_heroine_id: StringName = &""
) -> String:
	if quantity <= 0:
		return "Item reward quantity must be positive."
	var item: ItemDefinition = catalog.get_item(item_id) if catalog != null else null
	var canonical_error: String = _validate_canonical_item(item_id, item)
	if not canonical_error.is_empty():
		return canonical_error
	match item.content_category:
		ItemDefinition.ContentCategory.ACTIVE:
			if item.combat_usable:
				return add_to_item_bar(item_id, quantity)
			if owner_heroine_id == &"":
				return "Exploration item '%s' requires an authored heroine owner." % item_id
			return add_to_backpack(owner_heroine_id, item_id, quantity)
		ItemDefinition.ContentCategory.KEY:
			return add_to_key_chain(item_id, quantity)
		ItemDefinition.ContentCategory.MATERIAL:
			return add_to_material_pouch(item_id, quantity)
		ItemDefinition.ContentCategory.MEMENTO:
			if quantity != 1:
				return "A Memento reward must have quantity one."
			if owner_heroine_id == &"":
				return "Memento '%s' requires an authored heroine owner." % item_id
			return assign_memento(owner_heroine_id, item_id)
	return "Item '%s' has no carried runtime domain." % item_id


func get_runtime_domain(item_id: StringName) -> StringName:
	var item: ItemDefinition = catalog.get_item(item_id) if catalog != null else null
	if not _validate_canonical_item(item_id, item).is_empty():
		return &""
	match item.content_category:
		ItemDefinition.ContentCategory.ACTIVE:
			return DOMAIN_ITEM_BAR if item.combat_usable else DOMAIN_BACKPACK
		ItemDefinition.ContentCategory.KEY:
			return DOMAIN_KEY_CHAIN
		ItemDefinition.ContentCategory.MATERIAL:
			return DOMAIN_MATERIAL_POUCH
		ItemDefinition.ContentCategory.MEMENTO:
			return DOMAIN_MEMENTO
	return &""


func _move_between_ordered_domains(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int,
	backpack_to_item_bar: bool
) -> String:
	if quantity <= 0:
		return "Move quantity must be positive."
	var backpack_value: Variant = backpacks_by_heroine.get(heroine_id, null)
	if not (backpack_value is Array):
		return "No active heroine owns backpack '%s'." % heroine_id
	var staged_backpack: Array[Dictionary] = []
	for slot_value: Variant in (backpack_value as Array):
		staged_backpack.append((slot_value as Dictionary).duplicate(true))
	var staged_item_bar: Array[Dictionary] = item_bar_slots.duplicate(true)
	var source_slots: Array[Dictionary] = (
		staged_backpack if backpack_to_item_bar else staged_item_bar
	)
	var destination_slots: Array[Dictionary] = (
		staged_item_bar if backpack_to_item_bar else staged_backpack
	)
	var destination_domain: StringName = (
		DOMAIN_ITEM_BAR if backpack_to_item_bar else DOMAIN_BACKPACK
	)
	var item_error: String = _validate_item_for_domain(
		item_id,
		destination_domain
	)
	if not item_error.is_empty():
		return item_error
	var remove_error: String = _remove_from_slots(
		source_slots,
		item_id,
		quantity
	)
	if not remove_error.is_empty():
		return remove_error
	var item: ItemDefinition = catalog.get_item(item_id)
	var add_error: String = _add_to_slots(
		destination_slots,
		item_id,
		quantity,
		item.stack_limit
	)
	if not add_error.is_empty():
		return add_error
	backpacks_by_heroine[heroine_id] = staged_backpack
	item_bar_slots = staged_item_bar
	inventory_changed.emit()
	return ""


func _add_to_owned_slots(
	current_slots: Array[Dictionary],
	item_id: StringName,
	quantity: int,
	domain: StringName,
	commit: Callable
) -> String:
	if quantity <= 0:
		return "Item quantity must be positive."
	var item_error: String = _validate_item_for_domain(item_id, domain)
	if not item_error.is_empty():
		return item_error
	var staged_slots: Array[Dictionary] = current_slots.duplicate(true)
	var item: ItemDefinition = catalog.get_item(item_id)
	var add_error: String = _add_to_slots(
		staged_slots,
		item_id,
		quantity,
		item.stack_limit
	)
	if not add_error.is_empty():
		return add_error
	commit.call(staged_slots)
	inventory_changed.emit()
	return ""


func _remove_from_owned_slots(
	current_slots: Array[Dictionary],
	item_id: StringName,
	quantity: int,
	commit: Callable
) -> String:
	if quantity <= 0:
		return "Item quantity must be positive."
	var staged_slots: Array[Dictionary] = current_slots.duplicate(true)
	var remove_error: String = _remove_from_slots(
		staged_slots,
		item_id,
		quantity
	)
	if not remove_error.is_empty():
		return remove_error
	commit.call(staged_slots)
	inventory_changed.emit()
	return ""


func _add_to_quantity_domain(
	domain_state: Dictionary,
	item_id: StringName,
	quantity: int,
	domain: StringName
) -> String:
	if quantity <= 0:
		return "Item quantity must be positive."
	var item_error: String = _validate_item_for_domain(item_id, domain)
	if not item_error.is_empty():
		return item_error
	var staged: Dictionary = domain_state.duplicate(true)
	var key: String = String(item_id)
	var next_quantity: int = int(staged.get(key, 0)) + quantity
	var item: ItemDefinition = catalog.get_item(item_id)
	if next_quantity > item.stack_limit:
		return "%s stack '%s' exceeds its authored limit." % [
			_get_domain_label(domain),
			item_id,
		]
	staged[key] = next_quantity
	if domain == DOMAIN_KEY_CHAIN:
		key_chain = staged
	else:
		material_pouch = staged
	inventory_changed.emit()
	return ""


func _remove_from_quantity_domain(
	domain_state: Dictionary,
	item_id: StringName,
	quantity: int,
	domain_label: String
) -> String:
	if quantity <= 0:
		return "Item quantity must be positive."
	var key: String = String(item_id)
	var current_quantity: int = int(
		domain_state.get(key, domain_state.get(item_id, 0))
	)
	if current_quantity < quantity:
		return "%s does not contain enough '%s'." % [domain_label, item_id]
	var staged: Dictionary = domain_state.duplicate(true)
	var remaining: int = current_quantity - quantity
	if remaining <= 0:
		staged.erase(key)
		staged.erase(item_id)
	else:
		staged[key] = remaining
	if domain_label == "Key Chain":
		key_chain = staged
	else:
		material_pouch = staged
	inventory_changed.emit()
	return ""


func _normalize_ordered_slots(
	stored_slots: Array,
	expected_size: int,
	domain: StringName,
	result: Array[Dictionary],
	allow_retained_legacy_item: bool = false
) -> String:
	if stored_slots.size() != expected_size:
		return "%s must contain exactly %d ordered slots." % [
			_get_domain_label(domain),
			expected_size,
		]
	for slot_index: int in range(expected_size):
		var slot_value: Variant = stored_slots[slot_index]
		if not (slot_value is Dictionary):
			return "%s slot %d is invalid." % [
				_get_domain_label(domain),
				slot_index,
			]
		var slot: Dictionary = slot_value as Dictionary
		if int(slot.get("slot_index", -1)) != slot_index:
			return "%s slot indices must be deterministic." % _get_domain_label(domain)
		var item_id := StringName(slot.get("item_id", ""))
		var quantity: int = int(slot.get("quantity", 0))
		if item_id == &"":
			if quantity != 0:
				return "An empty %s slot must have quantity zero." % _get_domain_label(domain)
			result.append(_make_empty_slot(slot_index))
			continue
		if quantity <= 0:
			return "An occupied %s slot must have positive quantity." % _get_domain_label(domain)
		var item: ItemDefinition = catalog.get_item(item_id)
		var item_error: String = _validate_item_for_domain(item_id, domain)
		var retained_legacy_item: bool = (
			allow_retained_legacy_item
			and item != null
			and item.content_category
			== ItemDefinition.ContentCategory.LEGACY_DEVELOPMENT
		)
		if (
			not item_error.is_empty()
			and not retained_legacy_item
		):
			return item_error
		if (
			item == null
			or (not retained_legacy_item and quantity > item.stack_limit)
		):
			return "%s stack '%s' exceeds its authored limit." % [
				_get_domain_label(domain),
				item_id,
			]
		result.append({
			"slot_index": slot_index,
			"item_id": String(item_id),
			"quantity": quantity,
		})
	return ""


func _normalize_quantity_dictionary(
	stored: Dictionary,
	domain: StringName,
	result: Dictionary
) -> String:
	for item_key: Variant in stored.keys():
		var item_id := StringName(item_key)
		var quantity_value: Variant = stored[item_key]
		if (
			typeof(quantity_value) not in [TYPE_INT, TYPE_FLOAT]
			or float(quantity_value) != floorf(float(quantity_value))
			or int(quantity_value) <= 0
		):
			return "%s quantities must be positive integers." % _get_domain_label(domain)
		var item_error: String = _validate_item_for_domain(item_id, domain)
		if not item_error.is_empty():
			return item_error
		var item: ItemDefinition = catalog.get_item(item_id)
		if int(quantity_value) > item.stack_limit:
			return "%s stack '%s' exceeds its authored limit." % [
				_get_domain_label(domain),
				item_id,
			]
		result[String(item_id)] = int(quantity_value)
	return ""


func _validate_item_for_domain(
	item_id: StringName,
	domain: StringName
) -> String:
	var item: ItemDefinition = catalog.get_item(item_id) if catalog != null else null
	var canonical_error: String = _validate_canonical_item(item_id, item)
	if not canonical_error.is_empty():
		return canonical_error
	match domain:
		DOMAIN_ITEM_BAR:
			if (
				item.content_category != ItemDefinition.ContentCategory.ACTIVE
				or not item.combat_usable
				or not item.is_active_item()
			):
				return "Item '%s' is not eligible for the combat Item Bar." % item_id
		DOMAIN_BACKPACK:
			if item.content_category != ItemDefinition.ContentCategory.ACTIVE:
				return "Item '%s' is not an ordinary backpack item." % item_id
		DOMAIN_KEY_CHAIN:
			if item.content_category != ItemDefinition.ContentCategory.KEY:
				return "Item '%s' is not a Key Chain item." % item_id
		DOMAIN_MATERIAL_POUCH:
			if item.content_category != ItemDefinition.ContentCategory.MATERIAL:
				return "Item '%s' is not a Material Pouch item." % item_id
		DOMAIN_MEMENTO:
			if item.content_category != ItemDefinition.ContentCategory.MEMENTO:
				return "Item '%s' is not a Memento." % item_id
	return ""


func _validate_canonical_item(
	item_id: StringName,
	item: ItemDefinition
) -> String:
	if item_id == &"":
		return "A carried item requires a Stable ID."
	if item == null:
		return "Unknown carried item Stable ID: %s." % item_id
	if not item.canonical_workbook_item:
		return "Carried item '%s' is not a canonical workbook Stable ID." % item_id
	return ""


func _add_to_slots(
	slots: Array[Dictionary],
	item_id: StringName,
	quantity: int,
	stack_limit: int
) -> String:
	var available_capacity: int = 0
	for slot: Dictionary in slots:
		var stored_id := StringName(slot.get("item_id", ""))
		var stored_quantity: int = int(slot.get("quantity", 0))
		if stored_id == item_id:
			available_capacity += maxi(stack_limit - stored_quantity, 0)
		elif stored_id == &"" and stored_quantity == 0:
			available_capacity += stack_limit
	if available_capacity < quantity:
		return "%s has insufficient capacity for '%s'." % [
			"Ordered inventory",
			item_id,
		]

	var remaining: int = quantity
	for slot_index: int in range(slots.size()):
		var stack_slot: Dictionary = slots[slot_index]
		if StringName(stack_slot.get("item_id", "")) != item_id:
			continue
		var current_quantity: int = int(stack_slot.get("quantity", 0))
		var added: int = mini(remaining, stack_limit - current_quantity)
		if added <= 0:
			continue
		stack_slot["quantity"] = current_quantity + added
		slots[slot_index] = stack_slot
		remaining -= added
		if remaining <= 0:
			return ""
	for slot_index: int in range(slots.size()):
		var empty_slot: Dictionary = slots[slot_index]
		if StringName(empty_slot.get("item_id", "")) != &"":
			continue
		var added: int = mini(remaining, stack_limit)
		slots[slot_index] = {
			"slot_index": slot_index,
			"item_id": String(item_id),
			"quantity": added,
		}
		remaining -= added
		if remaining <= 0:
			return ""
	return "Ordered inventory could not store '%s'." % item_id


func _remove_from_slots(
	slots: Array[Dictionary],
	item_id: StringName,
	quantity: int
) -> String:
	var available: int = 0
	for slot: Dictionary in slots:
		if StringName(slot.get("item_id", "")) == item_id:
			available += int(slot.get("quantity", 0))
	if available < quantity:
		return "Ordered inventory does not contain enough '%s'." % item_id
	var remaining: int = quantity
	for slot_index: int in range(slots.size()):
		var slot: Dictionary = slots[slot_index]
		if StringName(slot.get("item_id", "")) != item_id:
			continue
		var removed: int = mini(remaining, int(slot.get("quantity", 0)))
		var next_quantity: int = int(slot.get("quantity", 0)) - removed
		slots[slot_index] = (
			_make_empty_slot(slot_index)
			if next_quantity <= 0
			else {
				"slot_index": slot_index,
				"item_id": String(item_id),
				"quantity": next_quantity,
			}
		)
		remaining -= removed
		if remaining <= 0:
			return ""
	return "Ordered inventory could not remove '%s'." % item_id


func _make_authored_item_bar_loadout() -> Array[Dictionary]:
	return [
		{"slot_index": 0, "item_id": "l01_bandage_roll", "quantity": 3},
		{"slot_index": 1, "item_id": "l01_smelling_salts", "quantity": 2},
		{"slot_index": 2, "item_id": "l01_warm_wine_flask", "quantity": 2},
		_make_empty_slot(3),
		{"slot_index": 4, "item_id": "l01_red_wax_ampoule", "quantity": 2},
		_make_empty_slot(5),
	]


func _make_empty_slots(slot_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_index: int in range(slot_count):
		result.append(_make_empty_slot(slot_index))
	return result


func _make_empty_slot(slot_index: int) -> Dictionary:
	return {
		"slot_index": slot_index,
		"item_id": "",
		"quantity": 0,
	}


func _get_domain_label(domain: StringName) -> String:
	match domain:
		DOMAIN_ITEM_BAR:
			return "Item Bar"
		DOMAIN_BACKPACK:
			return "Backpack"
		DOMAIN_KEY_CHAIN:
			return "Key Chain"
		DOMAIN_MATERIAL_POUCH:
			return "Material Pouch"
		DOMAIN_MEMENTO:
			return "Memento slot"
	return "Run inventory"
