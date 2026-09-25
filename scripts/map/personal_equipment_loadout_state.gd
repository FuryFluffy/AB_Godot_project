class_name PersonalEquipmentLoadoutState
extends RefCounted


signal loadout_changed


var owner_heroine_id: StringName
var instances_by_id: Dictionary = {}
var slot_instance_ids: Dictionary = {}


func initialize_empty(new_owner_heroine_id: StringName) -> String:
	if new_owner_heroine_id == &"":
		return "A personal equipment loadout requires a heroine ID."
	owner_heroine_id = new_owner_heroine_id
	instances_by_id = {}
	slot_instance_ids = _make_empty_slots()
	loadout_changed.emit()
	return ""


func initialize_from_authored_loadout(
	new_owner_heroine_id: StringName,
	authored_loadout: EquipmentLoadout
) -> String:
	if new_owner_heroine_id == &"":
		return "A personal equipment loadout requires a heroine ID."
	if authored_loadout == null:
		return "Heroine '%s' requires an authored equipment loadout." % new_owner_heroine_id
	var loadout_error: String = authored_loadout.validate_definition()
	if not loadout_error.is_empty():
		return loadout_error
	var staged_instances: Dictionary = {}
	var staged_slots: Dictionary = _make_empty_slots()
	for slot: EquipmentDefinition.Slot in _equipment_slots():
		var definition: EquipmentDefinition = authored_loadout.get_equipment(slot)
		if definition == null:
			continue
		var slot_key: StringName = EquipmentDefinition.get_slot_key(slot)
		var instance_id := StringName(
			"%s:%s:%s:001" % [
				new_owner_heroine_id,
				slot_key,
				definition.equipment_id,
			]
		)
		var instance := EquipmentInstance.new()
		var instance_error: String = instance.initialize(instance_id, definition)
		if not instance_error.is_empty():
			return instance_error
		staged_instances[instance_id] = instance
		staged_slots[slot_key] = instance_id
	owner_heroine_id = new_owner_heroine_id
	instances_by_id = staged_instances
	slot_instance_ids = staged_slots
	loadout_changed.emit()
	return ""


func register_instance(instance: EquipmentInstance) -> String:
	if instance == null or instance.definition == null:
		return "A personal loadout can register only a resolved equipment instance."
	if instance.instance_id == &"":
		return "A personal loadout cannot register an empty instance ID."
	if instances_by_id.has(instance.instance_id):
		return "Equipment instance '%s' is already owned." % instance.instance_id
	instances_by_id[instance.instance_id] = instance
	loadout_changed.emit()
	return ""


func remove_unequipped_instance(instance_id: StringName) -> String:
	if get_instance(instance_id) == null:
		return "Equipment instance '%s' is not owned." % instance_id
	for assigned_value: Variant in slot_instance_ids.values():
		if StringName(assigned_value) == instance_id:
			return "Equipped instance '%s' must be unequipped first." % instance_id
	var staged_instances: Dictionary = instances_by_id.duplicate()
	staged_instances.erase(instance_id)
	staged_instances.erase(String(instance_id))
	instances_by_id = staged_instances
	loadout_changed.emit()
	return ""


func equip(slot: EquipmentDefinition.Slot, instance_id: StringName) -> String:
	if owner_heroine_id == &"":
		return "Equipment assignment requires a valid heroine owner."
	var slot_key: StringName = EquipmentDefinition.get_slot_key(slot)
	if slot_key == &"":
		return "Equipment assignment requested an unknown slot."
	var instance: EquipmentInstance = get_instance(instance_id)
	if instance == null or instance.definition == null:
		return "Heroine '%s' does not own equipment instance '%s'." % [
			owner_heroine_id,
			instance_id,
		]
	if not instance.definition.allows_slot(slot):
		return "Equipment '%s' is incompatible with %s." % [
			instance.definition_id,
			EquipmentDefinition.get_slot_label(slot),
		]
	for assigned_slot_value: Variant in slot_instance_ids.keys():
		var assigned_slot := StringName(assigned_slot_value)
		if (
			StringName(slot_instance_ids.get(assigned_slot, "")) == instance_id
			and assigned_slot != slot_key
		):
			return "Equipment instance '%s' is already assigned to %s." % [
				instance_id,
				EquipmentDefinition.get_slot_label(_slot_from_key(assigned_slot)),
			]
	var staged_slots: Dictionary = slot_instance_ids.duplicate(true)
	staged_slots[slot_key] = instance_id
	slot_instance_ids = staged_slots
	loadout_changed.emit()
	return ""


func unequip(slot: EquipmentDefinition.Slot) -> String:
	var slot_key: StringName = EquipmentDefinition.get_slot_key(slot)
	if slot_key == &"" or not slot_instance_ids.has(slot_key):
		return "Equipment removal requested an unknown slot."
	if StringName(slot_instance_ids.get(slot_key, "")) == &"":
		return ""
	var staged_slots: Dictionary = slot_instance_ids.duplicate(true)
	staged_slots[slot_key] = &""
	slot_instance_ids = staged_slots
	loadout_changed.emit()
	return ""


func get_instance(instance_id: StringName) -> EquipmentInstance:
	return instances_by_id.get(
		instance_id,
		instances_by_id.get(String(instance_id), null)
	) as EquipmentInstance


func get_equipped_instance(slot: EquipmentDefinition.Slot) -> EquipmentInstance:
	var slot_key: StringName = EquipmentDefinition.get_slot_key(slot)
	return get_instance(StringName(slot_instance_ids.get(slot_key, "")))


func get_equipped_definition(slot: EquipmentDefinition.Slot) -> EquipmentDefinition:
	var instance: EquipmentInstance = get_equipped_instance(slot)
	return instance.definition if instance != null else null


func to_snapshot() -> Dictionary:
	var serialized_instances: Dictionary = {}
	var instance_ids: Array[StringName] = []
	for instance_value: Variant in instances_by_id.keys():
		instance_ids.append(StringName(instance_value))
	instance_ids.sort()
	for instance_id: StringName in instance_ids:
		var instance: EquipmentInstance = get_instance(instance_id)
		if instance != null:
			serialized_instances[String(instance_id)] = instance.to_snapshot()
	return {
		"heroine_id": String(owner_heroine_id),
		"instances": serialized_instances,
		"slots": {
			"main_hand": String(slot_instance_ids.get(&"main_hand", "")),
			"off_hand": String(slot_instance_ids.get(&"off_hand", "")),
			"armor": String(slot_instance_ids.get(&"armor", "")),
		},
	}


func restore_from_snapshot(
	snapshot: Dictionary,
	definitions_by_id: Dictionary
) -> String:
	var heroine_value: Variant = snapshot.get("heroine_id", null)
	var instances_value: Variant = snapshot.get("instances", null)
	var slots_value: Variant = snapshot.get("slots", null)
	if not (heroine_value is String or heroine_value is StringName):
		return "Personal equipment snapshot requires heroine_id."
	var next_heroine_id := StringName(heroine_value)
	if next_heroine_id == &"":
		return "Personal equipment snapshot heroine_id cannot be empty."
	if not (instances_value is Dictionary) or not (slots_value is Dictionary):
		return "Personal equipment snapshot requires instances and slots dictionaries."
	var staged_instances: Dictionary = {}
	for instance_key: Variant in (instances_value as Dictionary).keys():
		var instance_value: Variant = (instances_value as Dictionary)[instance_key]
		if not (instance_value is Dictionary):
			return "Personal equipment snapshot contains a malformed instance."
		var instance := EquipmentInstance.new()
		var instance_error: String = instance.restore_from_snapshot(
			(instance_value as Dictionary).duplicate(true),
			definitions_by_id
		)
		if not instance_error.is_empty():
			return instance_error
		if String(instance.instance_id) != String(instance_key):
			return "Equipment instance dictionary key does not match instance_id."
		if staged_instances.has(instance.instance_id):
			return "Personal equipment snapshot repeats instance '%s'." % instance.instance_id
		staged_instances[instance.instance_id] = instance
	var staged_slots: Dictionary = _make_empty_slots()
	var assigned_instances: Dictionary = {}
	for slot: EquipmentDefinition.Slot in _equipment_slots():
		var slot_key: StringName = EquipmentDefinition.get_slot_key(slot)
		var stored_value: Variant = (slots_value as Dictionary).get(String(slot_key), null)
		if not (stored_value is String or stored_value is StringName):
			return "Personal equipment snapshot requires explicit %s assignment." % slot_key
		var instance_id := StringName(stored_value)
		if instance_id == &"":
			continue
		var instance: EquipmentInstance = staged_instances.get(instance_id) as EquipmentInstance
		if instance == null:
			return "Equipment slot '%s' references an unknown instance." % slot_key
		if not instance.definition.allows_slot(slot):
			return "Equipment '%s' is incompatible with %s." % [
				instance.definition_id,
				EquipmentDefinition.get_slot_label(slot),
			]
		if assigned_instances.has(instance_id):
			return "Equipment instance '%s' is assigned more than once." % instance_id
		assigned_instances[instance_id] = true
		staged_slots[slot_key] = instance_id
	owner_heroine_id = next_heroine_id
	instances_by_id = staged_instances
	slot_instance_ids = staged_slots
	loadout_changed.emit()
	return ""


func _make_empty_slots() -> Dictionary:
	return {
		&"main_hand": &"",
		&"off_hand": &"",
		&"armor": &"",
	}


func _equipment_slots() -> Array[EquipmentDefinition.Slot]:
	return [
		EquipmentDefinition.Slot.MAIN_HAND,
		EquipmentDefinition.Slot.OFF_HAND,
		EquipmentDefinition.Slot.ARMOR,
	]


func _slot_from_key(slot_key: StringName) -> EquipmentDefinition.Slot:
	match slot_key:
		&"main_hand":
			return EquipmentDefinition.Slot.MAIN_HAND
		&"off_hand":
			return EquipmentDefinition.Slot.OFF_HAND
	return EquipmentDefinition.Slot.ARMOR
