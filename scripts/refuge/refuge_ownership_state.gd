class_name RefugeOwnershipState
extends RefCounted


signal ownership_changed


const PREPARATION_SLOT_COUNT: int = 15
const MATERIAL_CATALOG: MaterialCatalogDefinition = preload(
	"res://data/materials/layer_1_2_material_catalog.tres"
)
const EQUIPMENT_CATALOG: EquipmentCatalogDefinition = preload(
	"res://data/equipment/layer_1_2_equipment_catalog.tres"
)
const RECIPE_CATALOG: RefugeRecipeCatalogDefinition = preload(
	"res://data/refuge/refuge_recipe_catalog.tres"
)


var item_catalog: ItemCatalogDefinition
var battler_catalog: BattlerCatalogDefinition
var known_heroine_ids: Array[StringName] = []
var equipment_definitions_by_id: Dictionary = {}

var selected_party_ids: Array[StringName] = []
var prepared_item_bar_slots: Array[Dictionary] = []
var preparation_slots_by_heroine: Dictionary = {}
var equipment_loadouts_by_heroine: Dictionary = {}
var memento_slots_by_heroine: Dictionary = {}
var stash_item_stacks: Array[Dictionary] = []
var stash_equipment_instances: Dictionary = {}
var key_chain: Dictionary = {}
var banked_materials: Dictionary = {}


func initialize_default(
	new_item_catalog: ItemCatalogDefinition,
	new_battler_catalog: BattlerCatalogDefinition,
	heroine_ids: Array[StringName],
	legacy_party_snapshot: Dictionary = {},
	legacy_item_bar: Array = []
) -> String:
	var base_error: String = _initialize_base(
		new_item_catalog,
		new_battler_catalog,
		heroine_ids
	)
	if not base_error.is_empty():
		return base_error
	var temporary_inventory := RunInventoryState.new()
	var inventory_error: String = temporary_inventory.initialize(
		item_catalog,
		known_heroine_ids
	)
	if not inventory_error.is_empty():
		return inventory_error
	var authored_equipment := RunEquipmentState.new()
	var equipment_error: String = authored_equipment.initialize(
		battler_catalog,
		known_heroine_ids,
		temporary_inventory,
		legacy_party_snapshot
	)
	if not equipment_error.is_empty():
		return equipment_error
	var staged_definitions: Dictionary = EQUIPMENT_CATALOG.make_registry()
	for definition_value: Variant in authored_equipment.definitions_by_id.values():
		var definition := definition_value as EquipmentDefinition
		if definition == null:
			continue
		var existing: EquipmentDefinition = staged_definitions.get(
			definition.equipment_id
		) as EquipmentDefinition
		if existing != null and existing != definition:
			return "Equipment catalog disagrees with runtime definition '%s'." % (
				definition.equipment_id
			)
		staged_definitions[definition.equipment_id] = definition
	equipment_definitions_by_id = staged_definitions
	equipment_loadouts_by_heroine = (
		(authored_equipment.get_snapshot().get(
			"loadouts_by_heroine",
			{}
		) as Dictionary).duplicate(true)
	)
	selected_party_ids = known_heroine_ids.duplicate()
	var item_bar_error: String = _initialize_prepared_item_bar(
		legacy_item_bar
	)
	if not item_bar_error.is_empty():
		return item_bar_error
	preparation_slots_by_heroine = {}
	memento_slots_by_heroine = {}
	for heroine_id: StringName in known_heroine_ids:
		preparation_slots_by_heroine[heroine_id] = _make_empty_slots()
		memento_slots_by_heroine[heroine_id] = null
	stash_item_stacks = []
	stash_equipment_instances = {}
	key_chain = {}
	banked_materials = {}
	ownership_changed.emit()
	return ""


func restore_from_snapshot(
	snapshot: Dictionary,
	new_item_catalog: ItemCatalogDefinition,
	new_battler_catalog: BattlerCatalogDefinition,
	heroine_ids: Array[StringName],
	legacy_item_bar: Array = []
) -> String:
	var staged := RefugeOwnershipState.new()
	var base_error: String = staged.initialize_default(
		new_item_catalog,
		new_battler_catalog,
		heroine_ids
	)
	if not base_error.is_empty():
		return base_error
	var restore_error: String = staged._restore_snapshot_fields(
		snapshot.duplicate(true),
		legacy_item_bar.duplicate(true)
	)
	if not restore_error.is_empty():
		return restore_error
	_copy_from(staged)
	ownership_changed.emit()
	return ""


static func validate_snapshot(
	snapshot: Dictionary,
	new_item_catalog: ItemCatalogDefinition,
	new_battler_catalog: BattlerCatalogDefinition,
	heroine_ids: Array[StringName]
) -> String:
	var staged := RefugeOwnershipState.new()
	var base_error: String = staged.initialize_default(
		new_item_catalog,
		new_battler_catalog,
		heroine_ids
	)
	if not base_error.is_empty():
		return base_error
	return staged._restore_snapshot_fields(snapshot.duplicate(true))


func to_snapshot() -> Dictionary:
	var heroine_records: Dictionary = {}
	for heroine_id: StringName in known_heroine_ids:
		var memento_value: Variant = memento_slots_by_heroine.get(
			heroine_id,
			null
		)
		heroine_records[String(heroine_id)] = {
			"heroine_id": String(heroine_id),
			"preparation_slots": (
				(preparation_slots_by_heroine.get(heroine_id, []) as Array).duplicate(true)
			),
			"equipment_loadout": (
				(equipment_loadouts_by_heroine.get(heroine_id, {}) as Dictionary).duplicate(true)
			),
			"memento_id": (
				null if memento_value == null else String(memento_value)
			),
		}
	var selected_ids: Array[String] = []
	for heroine_id: StringName in selected_party_ids:
		selected_ids.append(String(heroine_id))
	var stash_equipment: Dictionary = {}
	var stash_ids: Array[StringName] = []
	for instance_key: Variant in stash_equipment_instances.keys():
		stash_ids.append(StringName(instance_key))
	stash_ids.sort()
	for instance_id: StringName in stash_ids:
		stash_equipment[String(instance_id)] = (
			(stash_equipment_instances.get(instance_id, {}) as Dictionary).duplicate(true)
		)
	return {
		"selected_party_ids": selected_ids,
		"prepared_item_bar_slots": prepared_item_bar_slots.duplicate(true),
		"heroine_records": heroine_records,
		"stash": {
			"item_stacks": stash_item_stacks.duplicate(true),
			"equipment_instances": stash_equipment,
		},
		"key_chain": key_chain.duplicate(true),
		"banked_materials": banked_materials.duplicate(true),
	}


func set_selected_party_order(heroine_ids: Array[StringName]) -> String:
	var validation_error: String = _validate_selected_party(heroine_ids)
	if not validation_error.is_empty():
		return validation_error
	selected_party_ids = heroine_ids.duplicate()
	ownership_changed.emit()
	return ""


func move_preparation_item_to_item_bar(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int
) -> String:
	var slots_value: Variant = preparation_slots_by_heroine.get(heroine_id, null)
	if not (slots_value is Array):
		return "Unknown Refuge heroine '%s'." % heroine_id
	var item_error: String = _validate_item_bar_item(item_id)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Item Bar transfer quantity must be positive."
	var staged_preparation: Array[Dictionary] = _duplicate_slots(slots_value as Array)
	var remove_error: String = _remove_from_slots(
		staged_preparation,
		item_id,
		quantity
	)
	if not remove_error.is_empty():
		return remove_error
	var item_bar_result: Dictionary = _stage_item_bar_change(
		item_id,
		quantity
	)
	var item_bar_error: String = String(item_bar_result.get("error", ""))
	if not item_bar_error.is_empty():
		return item_bar_error
	preparation_slots_by_heroine[heroine_id] = staged_preparation
	prepared_item_bar_slots = _duplicate_slots(
		item_bar_result.get("slots", []) as Array
	)
	ownership_changed.emit()
	return ""


func move_item_bar_item_to_preparation(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int
) -> String:
	var slots_value: Variant = preparation_slots_by_heroine.get(heroine_id, null)
	if not (slots_value is Array):
		return "Unknown Refuge heroine '%s'." % heroine_id
	var item_error: String = _validate_item_bar_item(item_id)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Item Bar transfer quantity must be positive."
	var staged_preparation: Array[Dictionary] = _duplicate_slots(slots_value as Array)
	var definition: ItemDefinition = item_catalog.get_item(item_id)
	var add_error: String = _add_to_slots(
		staged_preparation,
		item_id,
		quantity,
		definition.stack_limit
	)
	if not add_error.is_empty():
		return add_error
	var item_bar_result: Dictionary = _stage_item_bar_change(
		item_id,
		-quantity
	)
	var item_bar_error: String = String(item_bar_result.get("error", ""))
	if not item_bar_error.is_empty():
		return item_bar_error
	preparation_slots_by_heroine[heroine_id] = staged_preparation
	prepared_item_bar_slots = _duplicate_slots(
		item_bar_result.get("slots", []) as Array
	)
	ownership_changed.emit()
	return ""


func move_stash_item_to_item_bar(
	item_id: StringName,
	quantity: int
) -> String:
	var item_error: String = _validate_item_bar_item(item_id)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Item Bar transfer quantity must be positive."
	var staged_stash: Array[Dictionary] = stash_item_stacks.duplicate(true)
	var remove_error: String = _remove_from_stash_stacks(
		staged_stash,
		item_id,
		quantity
	)
	if not remove_error.is_empty():
		return remove_error
	var item_bar_result: Dictionary = _stage_item_bar_change(
		item_id,
		quantity
	)
	var item_bar_error: String = String(item_bar_result.get("error", ""))
	if not item_bar_error.is_empty():
		return item_bar_error
	stash_item_stacks = staged_stash
	prepared_item_bar_slots = _duplicate_slots(
		item_bar_result.get("slots", []) as Array
	)
	ownership_changed.emit()
	return ""


func move_item_bar_item_to_stash(
	item_id: StringName,
	quantity: int
) -> String:
	var item_error: String = _validate_item_bar_item(item_id)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Item Bar transfer quantity must be positive."
	var item_bar_result: Dictionary = _stage_item_bar_change(
		item_id,
		-quantity
	)
	var item_bar_error: String = String(item_bar_result.get("error", ""))
	if not item_bar_error.is_empty():
		return item_bar_error
	var staged_stash: Array[Dictionary] = stash_item_stacks.duplicate(true)
	_add_to_stash_stacks(
		staged_stash,
		item_id,
		quantity,
		item_catalog.get_item(item_id).stack_limit
	)
	prepared_item_bar_slots = _duplicate_slots(
		item_bar_result.get("slots", []) as Array
	)
	stash_item_stacks = staged_stash
	ownership_changed.emit()
	return ""


func assign_memento(heroine_id: StringName, item_id: StringName) -> String:
	if not memento_slots_by_heroine.has(heroine_id):
		return "Unknown Refuge heroine '%s'." % heroine_id
	var item_error: String = _validate_item_category(
		item_id,
		ItemDefinition.ContentCategory.MEMENTO,
		"Memento"
	)
	if not item_error.is_empty():
		return item_error
	if memento_slots_by_heroine.get(heroine_id, null) != null:
		return "Heroine '%s' already has a Memento." % heroine_id
	for stored_value: Variant in memento_slots_by_heroine.values():
		if stored_value != null and StringName(stored_value) == item_id:
			return "Memento '%s' already has a Refuge owner." % item_id
	memento_slots_by_heroine[heroine_id] = item_id
	ownership_changed.emit()
	return ""


func add_preparation_item(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int = 1
) -> String:
	var slots_value: Variant = preparation_slots_by_heroine.get(heroine_id, null)
	if not (slots_value is Array):
		return "Unknown Refuge heroine '%s'." % heroine_id
	var item_error: String = _validate_ordinary_item(item_id)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Preparation quantity must be positive."
	var staged_slots: Array[Dictionary] = _duplicate_slots(slots_value as Array)
	var definition: ItemDefinition = item_catalog.get_item(item_id)
	var add_error: String = _add_to_slots(
		staged_slots,
		item_id,
		quantity,
		definition.stack_limit
	)
	if not add_error.is_empty():
		return add_error
	preparation_slots_by_heroine[heroine_id] = staged_slots
	ownership_changed.emit()
	return ""


func add_stash_item(item_id: StringName, quantity: int = 1) -> String:
	var item_error: String = _validate_ordinary_item(item_id)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Stash quantity must be positive."
	var staged: Array[Dictionary] = stash_item_stacks.duplicate(true)
	_add_to_stash_stacks(
		staged,
		item_id,
		quantity,
		item_catalog.get_item(item_id).stack_limit
	)
	stash_item_stacks = staged
	ownership_changed.emit()
	return ""


func move_stash_item_to_preparation(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int
) -> String:
	var slots_value: Variant = preparation_slots_by_heroine.get(heroine_id, null)
	if not (slots_value is Array):
		return "Unknown Refuge heroine '%s'." % heroine_id
	var item_error: String = _validate_ordinary_item(item_id)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Stash transfer quantity must be positive."
	var staged_stash: Array[Dictionary] = stash_item_stacks.duplicate(true)
	var staged_slots: Array[Dictionary] = _duplicate_slots(slots_value as Array)
	var remove_error: String = _remove_from_stash_stacks(
		staged_stash,
		item_id,
		quantity
	)
	if not remove_error.is_empty():
		return remove_error
	var add_error: String = _add_to_slots(
		staged_slots,
		item_id,
		quantity,
		item_catalog.get_item(item_id).stack_limit
	)
	if not add_error.is_empty():
		return add_error
	stash_item_stacks = staged_stash
	preparation_slots_by_heroine[heroine_id] = staged_slots
	ownership_changed.emit()
	return ""


func move_preparation_item_to_stash(
	heroine_id: StringName,
	item_id: StringName,
	quantity: int
) -> String:
	var slots_value: Variant = preparation_slots_by_heroine.get(heroine_id, null)
	if not (slots_value is Array):
		return "Unknown Refuge heroine '%s'." % heroine_id
	var item_error: String = _validate_ordinary_item(item_id)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Preparation transfer quantity must be positive."
	var staged_slots: Array[Dictionary] = _duplicate_slots(slots_value as Array)
	var staged_stash: Array[Dictionary] = stash_item_stacks.duplicate(true)
	var remove_error: String = _remove_from_slots(
		staged_slots,
		item_id,
		quantity
	)
	if not remove_error.is_empty():
		return remove_error
	_add_to_stash_stacks(
		staged_stash,
		item_id,
		quantity,
		item_catalog.get_item(item_id).stack_limit
	)
	preparation_slots_by_heroine[heroine_id] = staged_slots
	stash_item_stacks = staged_stash
	ownership_changed.emit()
	return ""


func equip_owned_instance(
	heroine_id: StringName,
	slot: EquipmentDefinition.Slot,
	instance_id: StringName
) -> String:
	var loadout_result: Dictionary = _restore_heroine_loadout(heroine_id)
	var restore_error: String = String(loadout_result.get("error", ""))
	if not restore_error.is_empty():
		return restore_error
	var loadout: PersonalEquipmentLoadoutState = loadout_result.get(
		"loadout"
	) as PersonalEquipmentLoadoutState
	var equip_error: String = loadout.equip(slot, instance_id)
	if not equip_error.is_empty():
		return equip_error
	equipment_loadouts_by_heroine[heroine_id] = loadout.to_snapshot()
	ownership_changed.emit()
	return ""


func unequip_owned_slot(
	heroine_id: StringName,
	slot: EquipmentDefinition.Slot
) -> String:
	var loadout_result: Dictionary = _restore_heroine_loadout(heroine_id)
	var restore_error: String = String(loadout_result.get("error", ""))
	if not restore_error.is_empty():
		return restore_error
	var loadout: PersonalEquipmentLoadoutState = loadout_result.get(
		"loadout"
	) as PersonalEquipmentLoadoutState
	var unequip_error: String = loadout.unequip(slot)
	if not unequip_error.is_empty():
		return unequip_error
	equipment_loadouts_by_heroine[heroine_id] = loadout.to_snapshot()
	ownership_changed.emit()
	return ""


func move_unequipped_equipment_to_stash(
	heroine_id: StringName,
	instance_id: StringName
) -> String:
	if stash_equipment_instances.has(instance_id):
		return "Stash already contains equipment instance '%s'." % instance_id
	var loadout_result: Dictionary = _restore_heroine_loadout(heroine_id)
	var restore_error: String = String(loadout_result.get("error", ""))
	if not restore_error.is_empty():
		return restore_error
	var loadout: PersonalEquipmentLoadoutState = loadout_result.get(
		"loadout"
	) as PersonalEquipmentLoadoutState
	var instance: EquipmentInstance = loadout.get_instance(instance_id)
	if instance == null:
		return "Heroine '%s' does not own instance '%s'." % [heroine_id, instance_id]
	var remove_error: String = loadout.remove_unequipped_instance(instance_id)
	if not remove_error.is_empty():
		return remove_error
	var staged_stash: Dictionary = stash_equipment_instances.duplicate(true)
	staged_stash[instance_id] = instance.to_snapshot()
	equipment_loadouts_by_heroine[heroine_id] = loadout.to_snapshot()
	stash_equipment_instances = staged_stash
	ownership_changed.emit()
	return ""


func move_stash_equipment_to_heroine(
	instance_id: StringName,
	heroine_id: StringName
) -> String:
	var stored_value: Variant = stash_equipment_instances.get(
		instance_id,
		stash_equipment_instances.get(String(instance_id), null)
	)
	if not (stored_value is Dictionary):
		return "Stash does not contain equipment instance '%s'." % instance_id
	var loadout_result: Dictionary = _restore_heroine_loadout(heroine_id)
	var restore_error: String = String(loadout_result.get("error", ""))
	if not restore_error.is_empty():
		return restore_error
	var instance := EquipmentInstance.new()
	var instance_error: String = instance.restore_from_snapshot(
		(stored_value as Dictionary).duplicate(true),
		equipment_definitions_by_id
	)
	if not instance_error.is_empty():
		return instance_error
	var loadout: PersonalEquipmentLoadoutState = loadout_result.get(
		"loadout"
	) as PersonalEquipmentLoadoutState
	var register_error: String = loadout.register_instance(instance)
	if not register_error.is_empty():
		return register_error
	var staged_stash: Dictionary = stash_equipment_instances.duplicate(true)
	staged_stash.erase(instance_id)
	staged_stash.erase(String(instance_id))
	equipment_loadouts_by_heroine[heroine_id] = loadout.to_snapshot()
	stash_equipment_instances = staged_stash
	ownership_changed.emit()
	return ""


func get_banked_material_quantity(item_id: StringName) -> int:
	return int(banked_materials.get(String(item_id), 0))


func withdraw_banked_material_to_run(
	_item_id: StringName,
	_quantity: int
) -> String:
	return "Banked Materials cannot be withdrawn into a run."


func salvage_owned_equipment(instance_id: StringName) -> Dictionary:
	if instance_id == &"":
		return {"error": "Refuge salvage requires an equipment instance ID."}
	if equipment_loadouts_by_heroine.is_empty():
		return {
			"error": "Refuge salvage is unavailable while equipment is deployed into an active run."
		}
	var staged := RefugeOwnershipState.new()
	var stage_error: String = staged.restore_from_snapshot(
		to_snapshot(),
		item_catalog,
		battler_catalog,
		known_heroine_ids
	)
	if not stage_error.is_empty():
		return {"error": stage_error}
	var result: Dictionary = staged._apply_salvage(instance_id)
	if not String(result.get("error", "")).is_empty():
		return result
	_copy_from(staged)
	ownership_changed.emit()
	return result.duplicate(true)


func execute_refuge_recipe(
	recipe_id: StringName,
	target_instance_id: StringName
) -> Dictionary:
	if recipe_id == &"" or target_instance_id == &"":
		return {"error": "Refuge recipe execution requires recipe and target IDs."}
	if equipment_loadouts_by_heroine.is_empty():
		return {
			"error": "Refuge recipes are unavailable while equipment is deployed into an active run."
		}
	var staged := RefugeOwnershipState.new()
	var stage_error: String = staged.restore_from_snapshot(
		to_snapshot(),
		item_catalog,
		battler_catalog,
		known_heroine_ids
	)
	if not stage_error.is_empty():
		return {"error": stage_error}
	var result: Dictionary = staged._apply_recipe(
		recipe_id,
		target_instance_id
	)
	if not String(result.get("error", "")).is_empty():
		return result
	_copy_from(staged)
	ownership_changed.emit()
	return result.duplicate(true)


func make_run_start_transfer() -> Dictionary:
	var validation_error: String = validate_snapshot(
		to_snapshot(),
		item_catalog,
		battler_catalog,
		known_heroine_ids
	)
	if not validation_error.is_empty():
		return {"error": validation_error}
	var next_inventory := RunInventoryState.new()
	var inventory_error: String = next_inventory.initialize(
		item_catalog,
		selected_party_ids
	)
	if inventory_error.is_empty():
		inventory_error = next_inventory.restore_item_bar_snapshot(
			prepared_item_bar_slots,
			true
		)
	if not inventory_error.is_empty():
		return {"error": inventory_error}
	var inventory_snapshot: Dictionary = next_inventory.get_snapshot()
	var runtime_backpacks: Dictionary = inventory_snapshot.get(
		"backpacks_by_heroine",
		{}
	) as Dictionary
	var runtime_mementos: Dictionary = inventory_snapshot.get(
		"memento_slots_by_heroine",
		{}
	) as Dictionary
	for heroine_id: StringName in selected_party_ids:
		runtime_backpacks[String(heroine_id)] = (
			(preparation_slots_by_heroine.get(heroine_id, []) as Array).duplicate(true)
		)
		var memento_value: Variant = memento_slots_by_heroine.get(heroine_id, null)
		runtime_mementos[String(heroine_id)] = (
			null if memento_value == null else String(memento_value)
		)
	inventory_snapshot["key_chain"] = key_chain.duplicate(true)
	inventory_snapshot["backpacks_by_heroine"] = runtime_backpacks
	inventory_snapshot["memento_slots_by_heroine"] = runtime_mementos
	inventory_error = next_inventory.restore_from_snapshot(
		inventory_snapshot,
		true
	)
	if not inventory_error.is_empty():
		return {"error": inventory_error}
	var run_loadouts: Dictionary = {}
	for heroine_id: StringName in selected_party_ids:
		run_loadouts[String(heroine_id)] = (
			(equipment_loadouts_by_heroine.get(heroine_id, {}) as Dictionary).duplicate(true)
		)
	var next_equipment := RunEquipmentState.new()
	var equipment_error: String = next_equipment.initialize_from_snapshot(
		battler_catalog,
		selected_party_ids,
		next_inventory,
		{"loadouts_by_heroine": run_loadouts}
	)
	if not equipment_error.is_empty():
		return {"error": equipment_error}
	var staged_refuge := RefugeOwnershipState.new()
	staged_refuge._copy_runtime_context(self)
	staged_refuge.selected_party_ids = selected_party_ids.duplicate()
	staged_refuge.prepared_item_bar_slots = _make_slots(
		RunInventoryState.ITEM_BAR_SLOT_COUNT
	)
	staged_refuge.preparation_slots_by_heroine = {}
	staged_refuge.equipment_loadouts_by_heroine = {}
	staged_refuge.memento_slots_by_heroine = {}
	for heroine_id: StringName in known_heroine_ids:
		staged_refuge.preparation_slots_by_heroine[heroine_id] = _make_empty_slots()
		staged_refuge.memento_slots_by_heroine[heroine_id] = null
	staged_refuge.stash_item_stacks = stash_item_stacks.duplicate(true)
	staged_refuge.stash_equipment_instances = stash_equipment_instances.duplicate(true)
	staged_refuge.key_chain = {}
	staged_refuge.banked_materials = banked_materials.duplicate(true)
	return {
		"error": "",
		"refuge_state": staged_refuge,
		"run_inventory": next_inventory,
		"run_equipment": next_equipment,
	}


func make_run_return_transfer(
	run_inventory: RunInventoryState,
	run_equipment: RunEquipmentState,
	defeated: bool
) -> Dictionary:
	if run_inventory == null or run_equipment == null:
		return {"error": "Run resolution requires inventory and equipment state."}
	var run_loadouts: Dictionary = run_equipment.get_snapshot().get(
		"loadouts_by_heroine",
		{}
	) as Dictionary
	if run_loadouts.size() != selected_party_ids.size():
		return {"error": "Run resolution did not return every selected heroine loadout."}
	var staged_refuge := RefugeOwnershipState.new()
	var default_error: String = staged_refuge.initialize_default(
		item_catalog,
		battler_catalog,
		known_heroine_ids
	)
	if not default_error.is_empty():
		return {"error": default_error}
	staged_refuge.selected_party_ids = selected_party_ids.duplicate()
	staged_refuge.prepared_item_bar_slots = (
		_make_slots(RunInventoryState.ITEM_BAR_SLOT_COUNT)
		if defeated
		else run_inventory.get_item_bar_snapshot()
	)
	staged_refuge.preparation_slots_by_heroine = preparation_slots_by_heroine.duplicate(true)
	staged_refuge.equipment_loadouts_by_heroine = {}
	staged_refuge.memento_slots_by_heroine = {}
	for heroine_id: StringName in known_heroine_ids:
		var loadout_value: Variant = run_loadouts.get(
			heroine_id,
			run_loadouts.get(String(heroine_id), null)
		)
		if not (loadout_value is Dictionary):
			return {"error": "Run resolution is missing heroine '%s'." % heroine_id}
		staged_refuge.equipment_loadouts_by_heroine[heroine_id] = (
			(loadout_value as Dictionary).duplicate(true)
		)
		var memento_id: StringName = run_inventory.get_memento_id(heroine_id)
		staged_refuge.memento_slots_by_heroine[heroine_id] = (
			null if memento_id == &"" else memento_id
		)
		if not defeated:
			# Before Refuge ownership existed, voluntary return retained the
			# heroine backpacks for the next run. Preserve that behavior by
			# moving those ordered slots back into persistent preparation.
			staged_refuge.preparation_slots_by_heroine[heroine_id] = (
				run_inventory.get_backpack_snapshot(heroine_id)
			)
	staged_refuge.stash_item_stacks = stash_item_stacks.duplicate(true)
	staged_refuge.stash_equipment_instances = stash_equipment_instances.duplicate(true)
	staged_refuge.key_chain = {}
	for key_value: Variant in run_inventory.key_chain.keys():
		var key_id := StringName(key_value)
		var definition: ItemDefinition = item_catalog.get_item(key_id)
		if (
			defeated
			and definition.key_persistence_scope
			== ItemDefinition.KeyPersistenceScope.RUN_ONLY
		):
			continue
		staged_refuge.key_chain[String(key_id)] = int(
			run_inventory.key_chain[key_value]
		)
	staged_refuge.banked_materials = banked_materials.duplicate(true)
	for material_value: Variant in run_inventory.material_pouch.keys():
		var material_id := StringName(material_value)
		var bank_error: String = staged_refuge._bank_material(
			material_id,
			int(run_inventory.material_pouch[material_value])
		)
		if not bank_error.is_empty():
			return {"error": bank_error}
	var sanitized_snapshot: Dictionary = run_inventory.get_snapshot()
	sanitized_snapshot["key_chain"] = {}
	sanitized_snapshot["material_pouch"] = {}
	var cleared_mementos: Dictionary = {}
	var cleared_backpacks: Dictionary = {}
	for heroine_id: StringName in selected_party_ids:
		cleared_mementos[String(heroine_id)] = null
		cleared_backpacks[String(heroine_id)] = _make_empty_slots()
	sanitized_snapshot["memento_slots_by_heroine"] = cleared_mementos
	sanitized_snapshot["backpacks_by_heroine"] = cleared_backpacks
	if defeated:
		sanitized_snapshot["item_bar_slots"] = _make_slots(
			RunInventoryState.ITEM_BAR_SLOT_COUNT
		)
	var sanitized_inventory := RunInventoryState.new()
	var inventory_error: String = sanitized_inventory.initialize(
		item_catalog,
		selected_party_ids
	)
	if inventory_error.is_empty():
		inventory_error = sanitized_inventory.restore_from_snapshot(
			sanitized_snapshot
		)
	if not inventory_error.is_empty():
		return {"error": inventory_error}
	var empty_equipment := RunEquipmentState.new()
	var equipment_error: String = empty_equipment.initialize_empty(
		battler_catalog,
		sanitized_inventory
	)
	if not equipment_error.is_empty():
		return {"error": equipment_error}
	var validation_error: String = validate_snapshot(
		staged_refuge.to_snapshot(),
		item_catalog,
		battler_catalog,
		known_heroine_ids
	)
	if not validation_error.is_empty():
		return {"error": validation_error}
	return {
		"error": "",
		"refuge_state": staged_refuge,
		"run_inventory": sanitized_inventory,
		"run_equipment": empty_equipment,
	}


func _apply_salvage(instance_id: StringName) -> Dictionary:
	var location: Dictionary = _find_owned_equipment(instance_id)
	var location_error: String = String(location.get("error", ""))
	if not location_error.is_empty():
		return {"error": location_error}
	var instance: EquipmentInstance = location.get("instance") as EquipmentInstance
	if instance == null or instance.definition == null:
		return {"error": "Refuge salvage could not resolve the equipment definition."}
	var definition: EquipmentDefinition = EQUIPMENT_CATALOG.get_equipment(
		instance.definition_id
	)
	if definition == null or definition != instance.definition:
		return {"error": "Equipment '%s' is not canonical authored salvage content." % instance.definition_id}
	var definition_error: String = definition.validate_definition()
	if not definition_error.is_empty():
		return {"error": definition_error}
	if not definition.destructible:
		return {"error": "Equipment '%s' is non-destructible and cannot be salvaged." % definition.equipment_id}
	var material: MaterialDefinition = MATERIAL_CATALOG.get_material(
		definition.salvage_material_id
	)
	if (
		material == null
		or item_catalog.get_item(definition.salvage_material_id) != material
	):
		return {"error": "Equipment '%s' has no executable salvage Material." % definition.equipment_id}
	var salvage_yield: int = definition.get_salvage_yield()
	if salvage_yield <= 0:
		return {"error": "Equipment '%s' has an invalid salvage yield." % definition.equipment_id}
	var removal_result: Dictionary = _remove_owned_equipment(location)
	var removal_error: String = String(removal_result.get("error", ""))
	if not removal_error.is_empty():
		return {"error": removal_error}
	var bank_error: String = _bank_material(
		definition.salvage_material_id,
		salvage_yield
	)
	if not bank_error.is_empty():
		return {"error": bank_error}
	return {
		"error": "",
		"instance_id": String(instance_id),
		"definition_id": String(definition.equipment_id),
		"material_id": String(definition.salvage_material_id),
		"quantity": salvage_yield,
		"location": String(location.get("location", "")),
		"heroine_id": String(location.get("heroine_id", "")),
		"removed_slot": String(removal_result.get("removed_slot", "")),
	}


func _apply_recipe(
	recipe_id: StringName,
	target_instance_id: StringName
) -> Dictionary:
	var recipe: RefugeRecipeDefinition = RECIPE_CATALOG.get_recipe(recipe_id)
	if recipe == null:
		return {"error": "Unknown Refuge recipe '%s'." % recipe_id}
	var recipe_error: String = recipe.validate_definition(MATERIAL_CATALOG)
	if not recipe_error.is_empty():
		return {"error": recipe_error}
	var location: Dictionary = _find_owned_equipment(target_instance_id)
	var location_error: String = String(location.get("error", ""))
	if not location_error.is_empty():
		return {"error": location_error}
	var instance: EquipmentInstance = location.get("instance") as EquipmentInstance
	if instance == null or instance.definition == null:
		return {"error": "Refuge recipe could not resolve its equipment target."}
	if EQUIPMENT_CATALOG.get_equipment(instance.definition_id) != instance.definition:
		return {"error": "Refuge recipe target '%s' is not canonical authored equipment." % instance.definition_id}
	if not recipe.accepts_target(instance.definition):
		return {"error": "Refuge recipe '%s' rejects equipment '%s'." % [recipe_id, instance.definition_id]}
	if instance.current_condition >= instance.definition.condition_maximum:
		return {"error": "Equipment '%s' does not require repair." % target_instance_id}
	for material_value: Variant in recipe.material_inputs.keys():
		var material_id := StringName(material_value)
		var required: int = int(recipe.material_inputs[material_value])
		if get_banked_material_quantity(material_id) < required:
			return {"error": "Refuge recipe '%s' lacks banked Material '%s'." % [recipe_id, material_id]}

	var staged_materials: Dictionary = banked_materials.duplicate(true)
	for material_value: Variant in recipe.material_inputs.keys():
		var material_id := StringName(material_value)
		var key: String = String(material_id)
		var next_quantity: int = int(staged_materials.get(key, 0)) - int(
			recipe.material_inputs[material_value]
		)
		if next_quantity == 0:
			staged_materials.erase(key)
		else:
			staged_materials[key] = next_quantity
	var condition_before: int = instance.current_condition
	var repair_error: String = instance.repair_condition(
		recipe.condition_restore_amount
	)
	if not repair_error.is_empty():
		return {"error": repair_error}
	var store_error: String = _store_owned_equipment(location, instance)
	if not store_error.is_empty():
		return {"error": store_error}
	banked_materials = staged_materials
	return {
		"error": "",
		"recipe_id": String(recipe_id),
		"target_instance_id": String(target_instance_id),
		"condition_before": condition_before,
		"condition_after": instance.current_condition,
		"materials_consumed": recipe.material_inputs.duplicate(true),
	}


func _find_owned_equipment(instance_id: StringName) -> Dictionary:
	var stash_value: Variant = stash_equipment_instances.get(
		instance_id,
		stash_equipment_instances.get(String(instance_id), null)
	)
	if stash_value is Dictionary:
		var stash_instance := EquipmentInstance.new()
		var stash_error: String = stash_instance.restore_from_snapshot(
			(stash_value as Dictionary).duplicate(true),
			equipment_definitions_by_id
		)
		if not stash_error.is_empty():
			return {"error": stash_error}
		return {
			"error": "",
			"location": "stash",
			"instance": stash_instance,
		}
	for heroine_id: StringName in known_heroine_ids:
		var loadout_result: Dictionary = _restore_heroine_loadout(heroine_id)
		var loadout_error: String = String(loadout_result.get("error", ""))
		if not loadout_error.is_empty():
			return {"error": loadout_error}
		var loadout: PersonalEquipmentLoadoutState = loadout_result.get(
			"loadout"
		) as PersonalEquipmentLoadoutState
		var instance: EquipmentInstance = loadout.get_instance(instance_id)
		if instance != null:
			return {
				"error": "",
				"location": "loadout",
				"heroine_id": heroine_id,
				"loadout": loadout,
				"instance": instance,
			}
	return {"error": "Refuge does not own equipment instance '%s'." % instance_id}


func _remove_owned_equipment(location: Dictionary) -> Dictionary:
	var instance: EquipmentInstance = location.get("instance") as EquipmentInstance
	if instance == null:
		return {"error": "Refuge equipment removal requires an instance."}
	if String(location.get("location", "")) == "stash":
		var staged_stash: Dictionary = stash_equipment_instances.duplicate(true)
		staged_stash.erase(instance.instance_id)
		staged_stash.erase(String(instance.instance_id))
		stash_equipment_instances = staged_stash
		return {"error": "", "removed_slot": ""}
	var heroine_id := StringName(location.get("heroine_id", ""))
	var loadout: PersonalEquipmentLoadoutState = location.get(
		"loadout"
	) as PersonalEquipmentLoadoutState
	if heroine_id == &"" or loadout == null:
		return {"error": "Refuge equipment removal has an invalid owner."}
	var removed_slot: StringName = &""
	for slot: EquipmentDefinition.Slot in _equipment_slots():
		var equipped: EquipmentInstance = loadout.get_equipped_instance(slot)
		if equipped == null or equipped.instance_id != instance.instance_id:
			continue
		var unequip_error: String = loadout.unequip(slot)
		if not unequip_error.is_empty():
			return {"error": unequip_error}
		removed_slot = EquipmentDefinition.get_slot_key(slot)
		break
	var remove_error: String = loadout.remove_unequipped_instance(
		instance.instance_id
	)
	if not remove_error.is_empty():
		return {"error": remove_error}
	equipment_loadouts_by_heroine[heroine_id] = loadout.to_snapshot()
	return {"error": "", "removed_slot": String(removed_slot)}


func _store_owned_equipment(
	location: Dictionary,
	instance: EquipmentInstance
) -> String:
	if String(location.get("location", "")) == "stash":
		var staged_stash: Dictionary = stash_equipment_instances.duplicate(true)
		staged_stash[instance.instance_id] = instance.to_snapshot()
		stash_equipment_instances = staged_stash
		return ""
	var heroine_id := StringName(location.get("heroine_id", ""))
	var loadout: PersonalEquipmentLoadoutState = location.get(
		"loadout"
	) as PersonalEquipmentLoadoutState
	if heroine_id == &"" or loadout == null:
		return "Refuge equipment update has an invalid owner."
	equipment_loadouts_by_heroine[heroine_id] = loadout.to_snapshot()
	return ""


func _equipment_slots() -> Array[EquipmentDefinition.Slot]:
	return [
		EquipmentDefinition.Slot.MAIN_HAND,
		EquipmentDefinition.Slot.OFF_HAND,
		EquipmentDefinition.Slot.ARMOR,
	]


func _initialize_base(
	new_item_catalog: ItemCatalogDefinition,
	new_battler_catalog: BattlerCatalogDefinition,
	heroine_ids: Array[StringName]
) -> String:
	if new_item_catalog == null or new_battler_catalog == null:
		return "Refuge ownership requires item and battler catalogs."
	var item_error: String = new_item_catalog.validate_catalog()
	if not item_error.is_empty():
		return item_error
	var material_error: String = MATERIAL_CATALOG.validate_catalog()
	if not material_error.is_empty():
		return material_error
	var equipment_error: String = EQUIPMENT_CATALOG.validate_catalog(
		MATERIAL_CATALOG
	)
	if not equipment_error.is_empty():
		return equipment_error
	var recipe_error: String = RECIPE_CATALOG.validate_catalog(MATERIAL_CATALOG)
	if not recipe_error.is_empty():
		return recipe_error
	var reference_error: String = MATERIAL_CATALOG.validate_references(
		EQUIPMENT_CATALOG,
		RECIPE_CATALOG
	)
	if not reference_error.is_empty():
		return reference_error
	for material: MaterialDefinition in MATERIAL_CATALOG.materials:
		if new_item_catalog.get_item(material.item_id) != material:
			return "The canonical Item Catalog is missing Material '%s'." % (
				material.item_id
			)
	var normalized_ids: Array[StringName] = []
	for heroine_id: StringName in heroine_ids:
		var battler: BattlerDefinition = new_battler_catalog.get_battler(heroine_id)
		if (
			heroine_id == &""
			or normalized_ids.has(heroine_id)
			or battler == null
			or battler.faction != BattlerDefinition.Faction.HEROINE
		):
			return "Refuge ownership received an invalid heroine set."
		normalized_ids.append(heroine_id)
	if normalized_ids.is_empty():
		return "Refuge ownership requires recruited heroines."
	item_catalog = new_item_catalog
	battler_catalog = new_battler_catalog
	known_heroine_ids = normalized_ids
	return ""


func _restore_snapshot_fields(
	snapshot: Dictionary,
	legacy_item_bar: Array = []
) -> String:
	var selected_value: Variant = snapshot.get("selected_party_ids", null)
	var item_bar_value: Variant = snapshot.get(
		"prepared_item_bar_slots",
		null
	)
	var records_value: Variant = snapshot.get("heroine_records", null)
	var stash_value: Variant = snapshot.get("stash", null)
	var keys_value: Variant = snapshot.get("key_chain", null)
	var materials_value: Variant = snapshot.get("banked_materials", null)
	if not (selected_value is Array):
		return "Refuge snapshot requires selected_party_ids."
	if not (records_value is Dictionary):
		return "Refuge snapshot requires heroine_records."
	if not (stash_value is Dictionary):
		return "Refuge snapshot requires Stash data."
	if not (keys_value is Dictionary) or not (materials_value is Dictionary):
		return "Refuge snapshot requires Key Chain and banked Materials data."
	var staged_selected: Array[StringName] = []
	for value: Variant in selected_value as Array:
		if not (value is String or value is StringName):
			return "Refuge selected-party IDs must be strings."
		staged_selected.append(StringName(value))
	var selected_error: String = _validate_selected_party(staged_selected)
	if not selected_error.is_empty():
		return selected_error
	var staged_item_bar: Array[Dictionary] = []
	# Valid v3 Refuge snapshots written before Milestone 11 have no explicit
	# preparation Item Bar. The save loader may supply their former campaign
	# Item Bar once; direct/default restoration receives six safe empty slots.
	if item_bar_value == null:
		if legacy_item_bar.is_empty():
			staged_item_bar = _make_slots(RunInventoryState.ITEM_BAR_SLOT_COUNT)
		else:
			var legacy_result: Dictionary = _normalize_prepared_item_bar(
				legacy_item_bar
			)
			var legacy_error: String = String(legacy_result.get("error", ""))
			if not legacy_error.is_empty():
				return legacy_error
			staged_item_bar = _duplicate_slots(
				legacy_result.get("slots", []) as Array
			)
	elif item_bar_value is Array:
		var item_bar_result: Dictionary = _normalize_prepared_item_bar(
			item_bar_value as Array
		)
		var item_bar_error: String = String(item_bar_result.get("error", ""))
		if not item_bar_error.is_empty():
			return item_bar_error
		staged_item_bar = _duplicate_slots(
			item_bar_result.get("slots", []) as Array
		)
	else:
		return "Refuge prepared Item Bar must be an Array."
	var records: Dictionary = records_value as Dictionary
	if records.size() != known_heroine_ids.size():
		return "Refuge snapshot does not match the recruited heroine set."
	var staged_preparation: Dictionary = {}
	var staged_loadouts: Dictionary = {}
	var staged_mementos: Dictionary = {}
	var global_instance_ids: Dictionary = {}
	var used_memento_ids: Dictionary = {}
	for heroine_id: StringName in known_heroine_ids:
		var record_value: Variant = records.get(
			heroine_id,
			records.get(String(heroine_id), null)
		)
		if not (record_value is Dictionary):
			return "Refuge snapshot is missing heroine '%s'." % heroine_id
		var record: Dictionary = record_value as Dictionary
		if StringName(record.get("heroine_id", "")) != heroine_id:
			return "Refuge heroine record identity does not match '%s'." % heroine_id
		var slots_value: Variant = record.get("preparation_slots", null)
		var loadout_value: Variant = record.get("equipment_loadout", null)
		if not (slots_value is Array) or not (loadout_value is Dictionary):
			return "Refuge heroine '%s' has malformed preparation data." % heroine_id
		var normalized_slots: Array[Dictionary] = []
		var slots_error: String = _normalize_preparation_slots(
			slots_value as Array,
			normalized_slots
		)
		if not slots_error.is_empty():
			return slots_error
		var loadout := PersonalEquipmentLoadoutState.new()
		var loadout_error: String = loadout.restore_from_snapshot(
			(loadout_value as Dictionary).duplicate(true),
			equipment_definitions_by_id
		)
		if not loadout_error.is_empty():
			return loadout_error
		if loadout.owner_heroine_id != heroine_id:
			return "Refuge equipment owner does not match heroine '%s'." % heroine_id
		for instance_value: Variant in loadout.instances_by_id.keys():
			var instance_id := StringName(instance_value)
			if global_instance_ids.has(instance_id):
				return "Equipment instance '%s' has multiple Refuge owners." % instance_id
			global_instance_ids[instance_id] = true
		var memento_value: Variant = record.get("memento_id", null)
		if memento_value != null and not (
			memento_value is String or memento_value is StringName
		):
			return "Refuge Memento identity must be a string or null."
		var memento_id := StringName(memento_value) if memento_value != null else &""
		if memento_id != &"":
			var memento_error: String = _validate_item_category(
				memento_id,
				ItemDefinition.ContentCategory.MEMENTO,
				"Memento"
			)
			if not memento_error.is_empty():
				return memento_error
			if used_memento_ids.has(memento_id):
				return "Memento '%s' is assigned to multiple heroines." % memento_id
			used_memento_ids[memento_id] = true
		staged_preparation[heroine_id] = normalized_slots
		staged_loadouts[heroine_id] = loadout.to_snapshot()
		staged_mementos[heroine_id] = null if memento_id == &"" else memento_id
	var stash: Dictionary = stash_value as Dictionary
	var item_stacks_value: Variant = stash.get("item_stacks", null)
	var equipment_value: Variant = stash.get("equipment_instances", null)
	if not (item_stacks_value is Array) or not (equipment_value is Dictionary):
		return "Refuge Stash requires item and equipment collections."
	var staged_stash_items: Array[Dictionary] = []
	for stack_index: int in range((item_stacks_value as Array).size()):
		var stack_value: Variant = (item_stacks_value as Array)[stack_index]
		if not (stack_value is Dictionary):
			return "Refuge Stash contains a malformed item stack."
		var stack: Dictionary = stack_value as Dictionary
		if int(stack.get("stack_index", -1)) != stack_index:
			return "Refuge Stash item-stack indices must be deterministic."
		var item_id := StringName(stack.get("item_id", ""))
		var quantity_value: Variant = stack.get("quantity", null)
		var ordinary_error: String = _validate_ordinary_item(item_id)
		if not ordinary_error.is_empty():
			return ordinary_error
		if not _is_integer_value(quantity_value) or int(quantity_value) <= 0:
			return "Refuge Stash item quantities must be positive integers."
		if int(quantity_value) > item_catalog.get_item(item_id).stack_limit:
			return "Refuge Stash stack '%s' exceeds its authored limit." % item_id
		staged_stash_items.append({
			"stack_index": stack_index,
			"item_id": String(item_id),
			"quantity": int(quantity_value),
		})
	var staged_stash_equipment: Dictionary = {}
	for instance_key: Variant in (equipment_value as Dictionary).keys():
		var instance_value: Variant = (equipment_value as Dictionary)[instance_key]
		if not (instance_value is Dictionary):
			return "Refuge Stash contains malformed equipment."
		var instance := EquipmentInstance.new()
		var instance_error: String = instance.restore_from_snapshot(
			(instance_value as Dictionary).duplicate(true),
			equipment_definitions_by_id
		)
		if not instance_error.is_empty():
			return instance_error
		if String(instance.instance_id) != String(instance_key):
			return "Refuge Stash equipment key does not match instance_id."
		if global_instance_ids.has(instance.instance_id):
			return "Equipment instance '%s' has multiple Refuge owners." % instance.instance_id
		global_instance_ids[instance.instance_id] = true
		staged_stash_equipment[instance.instance_id] = instance.to_snapshot()
	var staged_keys: Dictionary = {}
	var key_error: String = _normalize_quantity_collection(
		keys_value as Dictionary,
		ItemDefinition.ContentCategory.KEY,
		"Refuge Key Chain",
		staged_keys,
		true
	)
	if not key_error.is_empty():
		return key_error
	var staged_materials: Dictionary = {}
	var material_error: String = _normalize_quantity_collection(
		materials_value as Dictionary,
		ItemDefinition.ContentCategory.MATERIAL,
		"Banked Materials",
		staged_materials,
		false
	)
	if not material_error.is_empty():
		return material_error
	selected_party_ids = staged_selected
	prepared_item_bar_slots = staged_item_bar
	preparation_slots_by_heroine = staged_preparation
	equipment_loadouts_by_heroine = staged_loadouts
	memento_slots_by_heroine = staged_mementos
	stash_item_stacks = staged_stash_items
	stash_equipment_instances = staged_stash_equipment
	key_chain = staged_keys
	banked_materials = staged_materials
	return ""


func _validate_selected_party(heroine_ids: Array[StringName]) -> String:
	if heroine_ids.size() != known_heroine_ids.size():
		return "The current demo requires every recruited heroine in the selected party."
	var seen: Dictionary = {}
	for heroine_id: StringName in heroine_ids:
		if heroine_id == &"" or not known_heroine_ids.has(heroine_id):
			return "Selected party contains an unknown heroine."
		if seen.has(heroine_id):
			return "Selected party repeats heroine '%s'." % heroine_id
		seen[heroine_id] = true
	return ""


func _normalize_preparation_slots(
	stored: Array,
	result: Array[Dictionary]
) -> String:
	if stored.size() != PREPARATION_SLOT_COUNT:
		return "Heroine preparation inventory must contain exactly 15 slots."
	for slot_index: int in range(PREPARATION_SLOT_COUNT):
		var slot_value: Variant = stored[slot_index]
		if not (slot_value is Dictionary):
			return "Heroine preparation slot %d is malformed." % slot_index
		var slot: Dictionary = slot_value as Dictionary
		if int(slot.get("slot_index", -1)) != slot_index:
			return "Heroine preparation slot indices must be deterministic."
		var item_id := StringName(slot.get("item_id", ""))
		var quantity_value: Variant = slot.get("quantity", null)
		if item_id == &"":
			if not _is_integer_value(quantity_value) or int(quantity_value) != 0:
				return "Empty preparation slots require quantity zero."
			result.append(_make_empty_slot(slot_index))
			continue
		var item_error: String = _validate_ordinary_item(item_id)
		if not item_error.is_empty():
			return item_error
		if not _is_integer_value(quantity_value) or int(quantity_value) <= 0:
			return "Occupied preparation slots require positive integer quantities."
		if int(quantity_value) > item_catalog.get_item(item_id).stack_limit:
			return "Preparation stack '%s' exceeds its authored limit." % item_id
		result.append({
			"slot_index": slot_index,
			"item_id": String(item_id),
			"quantity": int(quantity_value),
		})
	return ""


func _normalize_quantity_collection(
	stored: Dictionary,
	category: ItemDefinition.ContentCategory,
	label: String,
	result: Dictionary,
	enforce_stack_limit: bool
) -> String:
	for item_key: Variant in stored.keys():
		var item_id := StringName(item_key)
		var quantity_value: Variant = stored[item_key]
		var item_error: String = _validate_item_category(item_id, category, label)
		if not item_error.is_empty():
			return item_error
		if not _is_integer_value(quantity_value) or int(quantity_value) <= 0:
			return "%s quantities must be positive integers." % label
		if enforce_stack_limit and int(quantity_value) > item_catalog.get_item(item_id).stack_limit:
			return "%s '%s' exceeds its authored stack limit." % [label, item_id]
		result[String(item_id)] = int(quantity_value)
	return ""


func _validate_ordinary_item(item_id: StringName) -> String:
	return _validate_item_category(
		item_id,
		ItemDefinition.ContentCategory.ACTIVE,
		"ordinary Refuge item"
	)


func _validate_item_bar_item(item_id: StringName) -> String:
	var item_error: String = _validate_ordinary_item(item_id)
	if not item_error.is_empty():
		return item_error
	var definition: ItemDefinition = item_catalog.get_item(item_id)
	if definition == null or not definition.combat_usable:
		return "Item '%s' is not eligible for the combat Item Bar." % item_id
	return ""


func _validate_item_category(
	item_id: StringName,
	category: ItemDefinition.ContentCategory,
	label: String
) -> String:
	if item_id == &"":
		return "%s requires a Stable ID." % label
	var definition: ItemDefinition = item_catalog.get_item(item_id) if item_catalog != null else null
	if definition == null or not definition.canonical_workbook_item:
		return "Unknown canonical %s Stable ID: %s." % [label, item_id]
	if definition.content_category != category:
		return "Item '%s' is not eligible for %s." % [item_id, label]
	return ""


func _restore_heroine_loadout(heroine_id: StringName) -> Dictionary:
	var snapshot_value: Variant = equipment_loadouts_by_heroine.get(
		heroine_id,
		null
	)
	if not (snapshot_value is Dictionary):
		return {"error": "Unknown Refuge heroine '%s'." % heroine_id}
	var loadout := PersonalEquipmentLoadoutState.new()
	var error: String = loadout.restore_from_snapshot(
		(snapshot_value as Dictionary).duplicate(true),
		equipment_definitions_by_id
	)
	return {"error": error, "loadout": loadout}


func _is_integer_value(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_INT
		or (
			typeof(value) == TYPE_FLOAT
			and float(value) == floorf(float(value))
		)
	)


func _bank_material(item_id: StringName, quantity: int) -> String:
	var item_error: String = _validate_item_category(
		item_id,
		ItemDefinition.ContentCategory.MATERIAL,
		"banked Material"
	)
	if not item_error.is_empty():
		return item_error
	if quantity <= 0:
		return "Banked Material quantity must be positive."
	var key: String = String(item_id)
	banked_materials[key] = int(banked_materials.get(key, 0)) + quantity
	return ""


func _copy_from(source: RefugeOwnershipState) -> void:
	_copy_runtime_context(source)
	selected_party_ids = source.selected_party_ids.duplicate()
	prepared_item_bar_slots = source.prepared_item_bar_slots.duplicate(true)
	preparation_slots_by_heroine = source.preparation_slots_by_heroine.duplicate(true)
	equipment_loadouts_by_heroine = source.equipment_loadouts_by_heroine.duplicate(true)
	memento_slots_by_heroine = source.memento_slots_by_heroine.duplicate(true)
	stash_item_stacks = source.stash_item_stacks.duplicate(true)
	stash_equipment_instances = source.stash_equipment_instances.duplicate(true)
	key_chain = source.key_chain.duplicate(true)
	banked_materials = source.banked_materials.duplicate(true)


func _copy_runtime_context(source: RefugeOwnershipState) -> void:
	item_catalog = source.item_catalog
	battler_catalog = source.battler_catalog
	known_heroine_ids = source.known_heroine_ids.duplicate()
	equipment_definitions_by_id = source.equipment_definitions_by_id.duplicate()


func _duplicate_slots(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in source:
		result.append((value as Dictionary).duplicate(true))
	return result


func _initialize_prepared_item_bar(legacy_item_bar: Array) -> String:
	if legacy_item_bar.is_empty():
		prepared_item_bar_slots = _make_slots(
			RunInventoryState.ITEM_BAR_SLOT_COUNT
		)
		return ""
	var result: Dictionary = _normalize_prepared_item_bar(legacy_item_bar)
	var error: String = String(result.get("error", ""))
	if not error.is_empty():
		return error
	prepared_item_bar_slots = _duplicate_slots(
		result.get("slots", []) as Array
	)
	return ""


func _normalize_prepared_item_bar(stored: Array) -> Dictionary:
	var inventory := RunInventoryState.new()
	var initialize_error: String = inventory.initialize(
		item_catalog,
		known_heroine_ids
	)
	if not initialize_error.is_empty():
		return {"error": initialize_error, "slots": []}
	var restore_error: String = inventory.restore_item_bar_snapshot(stored, true)
	if not restore_error.is_empty():
		return {"error": restore_error, "slots": []}
	return {"error": "", "slots": inventory.get_item_bar_snapshot()}


func _stage_item_bar_change(
	item_id: StringName,
	quantity_delta: int
) -> Dictionary:
	var inventory := RunInventoryState.new()
	var error: String = inventory.initialize(item_catalog, known_heroine_ids)
	if error.is_empty():
		error = inventory.restore_item_bar_snapshot(prepared_item_bar_slots, true)
	if error.is_empty():
		error = (
			inventory.add_to_item_bar(item_id, quantity_delta)
			if quantity_delta > 0
			else inventory.remove_from_item_bar(item_id, -quantity_delta)
		)
	return {
		"error": error,
		"slots": (
			[] if not error.is_empty() else inventory.get_item_bar_snapshot()
		),
	}


func _make_empty_slots() -> Array[Dictionary]:
	return _make_slots(PREPARATION_SLOT_COUNT)


func _make_slots(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_index: int in range(count):
		result.append(_make_empty_slot(slot_index))
	return result


func _make_empty_slot(slot_index: int) -> Dictionary:
	return {"slot_index": slot_index, "item_id": "", "quantity": 0}


func _add_to_slots(
	slots: Array[Dictionary],
	item_id: StringName,
	quantity: int,
	stack_limit: int
) -> String:
	var capacity: int = 0
	for slot: Dictionary in slots:
		var stored_id := StringName(slot.get("item_id", ""))
		if stored_id == item_id:
			capacity += maxi(stack_limit - int(slot.get("quantity", 0)), 0)
		elif stored_id == &"":
			capacity += stack_limit
	if capacity < quantity:
		return "Preparation inventory has insufficient capacity for '%s'." % item_id
	var remaining: int = quantity
	for slot_index: int in range(slots.size()):
		var slot: Dictionary = slots[slot_index]
		if StringName(slot.get("item_id", "")) != item_id:
			continue
		var current: int = int(slot.get("quantity", 0))
		var added: int = mini(remaining, stack_limit - current)
		if added > 0:
			slot["quantity"] = current + added
			slots[slot_index] = slot
			remaining -= added
		if remaining == 0:
			return ""
	for slot_index: int in range(slots.size()):
		if StringName(slots[slot_index].get("item_id", "")) != &"":
			continue
		var added: int = mini(remaining, stack_limit)
		slots[slot_index] = {
			"slot_index": slot_index,
			"item_id": String(item_id),
			"quantity": added,
		}
		remaining -= added
		if remaining == 0:
			return ""
	return "Preparation inventory could not store '%s'." % item_id


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
		return "Preparation inventory does not contain enough '%s'." % item_id
	var remaining: int = quantity
	for slot_index: int in range(slots.size()):
		var slot: Dictionary = slots[slot_index]
		if StringName(slot.get("item_id", "")) != item_id:
			continue
		var removed: int = mini(remaining, int(slot.get("quantity", 0)))
		var next_quantity: int = int(slot.get("quantity", 0)) - removed
		slots[slot_index] = (
			_make_empty_slot(slot_index)
			if next_quantity == 0
			else {
				"slot_index": slot_index,
				"item_id": String(item_id),
				"quantity": next_quantity,
			}
		)
		remaining -= removed
		if remaining == 0:
			return ""
	return "Preparation inventory could not remove '%s'." % item_id


func _add_to_stash_stacks(
	stacks: Array[Dictionary],
	item_id: StringName,
	quantity: int,
	stack_limit: int
) -> void:
	var remaining: int = quantity
	for stack_index: int in range(stacks.size()):
		var stack: Dictionary = stacks[stack_index]
		if StringName(stack.get("item_id", "")) != item_id:
			continue
		var current: int = int(stack.get("quantity", 0))
		var added: int = mini(remaining, stack_limit - current)
		if added > 0:
			stack["quantity"] = current + added
			stacks[stack_index] = stack
			remaining -= added
		if remaining == 0:
			return
	while remaining > 0:
		var added: int = mini(remaining, stack_limit)
		stacks.append({
			"stack_index": stacks.size(),
			"item_id": String(item_id),
			"quantity": added,
		})
		remaining -= added


func _remove_from_stash_stacks(
	stacks: Array[Dictionary],
	item_id: StringName,
	quantity: int
) -> String:
	var available: int = 0
	for stack: Dictionary in stacks:
		if StringName(stack.get("item_id", "")) == item_id:
			available += int(stack.get("quantity", 0))
	if available < quantity:
		return "Stash does not contain enough '%s'." % item_id
	var remaining: int = quantity
	for stack_index: int in range(stacks.size() - 1, -1, -1):
		var stack: Dictionary = stacks[stack_index]
		if StringName(stack.get("item_id", "")) != item_id:
			continue
		var removed: int = mini(remaining, int(stack.get("quantity", 0)))
		var next_quantity: int = int(stack.get("quantity", 0)) - removed
		if next_quantity == 0:
			stacks.remove_at(stack_index)
		else:
			stack["quantity"] = next_quantity
			stacks[stack_index] = stack
		remaining -= removed
		if remaining == 0:
			break
	for stack_index: int in range(stacks.size()):
		stacks[stack_index]["stack_index"] = stack_index
	return ""
