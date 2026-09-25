class_name RunEquipmentState
extends RefCounted


signal equipment_changed


var definitions_by_id: Dictionary = {}
var loadouts_by_heroine: Dictionary = {}
var run_inventory: RunInventoryState


func initialize(
	battler_catalog: BattlerCatalogDefinition,
	heroine_ids: Array[StringName],
	new_run_inventory: RunInventoryState,
	legacy_party_snapshot: Dictionary = {}
) -> String:
	if battler_catalog == null:
		return "Run equipment requires the battler catalog."
	if new_run_inventory == null:
		return "Run equipment requires the shared run inventory."
	var staged_definitions: Dictionary = {}
	for battler: BattlerDefinition in battler_catalog.battlers:
		if battler == null or battler.default_loadout == null:
			continue
		for definition: EquipmentDefinition in battler.default_loadout.get_all_equipment():
			if definition == null:
				continue
			var definition_error: String = definition.validate_definition()
			if not definition_error.is_empty():
				return definition_error
			var existing: EquipmentDefinition = staged_definitions.get(
				definition.equipment_id
			) as EquipmentDefinition
			if existing != null and existing != definition:
				return "Duplicate equipment definition ID: %s." % definition.equipment_id
			staged_definitions[definition.equipment_id] = definition
	var staged_loadouts: Dictionary = {}
	for heroine_id: StringName in heroine_ids:
		if heroine_id == &"" or staged_loadouts.has(heroine_id):
			return "Run equipment heroine IDs must be non-empty and unique."
		var heroine: BattlerDefinition = battler_catalog.get_battler(heroine_id)
		if (
			heroine == null
			or heroine.faction != BattlerDefinition.Faction.HEROINE
			or heroine.default_loadout == null
		):
			return "Run equipment cannot resolve heroine '%s'." % heroine_id
		var loadout := PersonalEquipmentLoadoutState.new()
		var loadout_error: String = loadout.initialize_from_authored_loadout(
			heroine_id,
			heroine.default_loadout
		)
		if not loadout_error.is_empty():
			return loadout_error
		_apply_legacy_condition_to_loadout(
			loadout,
			legacy_party_snapshot.get(
				heroine_id,
				legacy_party_snapshot.get(String(heroine_id), {})
			) as Dictionary
		)
		staged_loadouts[heroine_id] = loadout
	definitions_by_id = staged_definitions
	loadouts_by_heroine = staged_loadouts
	run_inventory = new_run_inventory
	for loadout_value: Variant in loadouts_by_heroine.values():
		var loadout := loadout_value as PersonalEquipmentLoadoutState
		if loadout != null and not loadout.loadout_changed.is_connected(_on_loadout_changed):
			loadout.loadout_changed.connect(_on_loadout_changed)
	equipment_changed.emit()
	return ""


func initialize_from_snapshot(
	battler_catalog: BattlerCatalogDefinition,
	heroine_ids: Array[StringName],
	new_run_inventory: RunInventoryState,
	snapshot: Dictionary
) -> String:
	if battler_catalog == null:
		return "Run equipment requires the battler catalog."
	if new_run_inventory == null:
		return "Run equipment requires the shared run inventory."
	var definition_result: Dictionary = _make_definition_registry(
		battler_catalog
	)
	var definition_error: String = String(definition_result.get("error", ""))
	if not definition_error.is_empty():
		return definition_error
	var loadouts_value: Variant = snapshot.get("loadouts_by_heroine", null)
	if not (loadouts_value is Dictionary):
		return "Run equipment snapshot requires loadouts_by_heroine."
	var stored_loadouts: Dictionary = loadouts_value as Dictionary
	if stored_loadouts.size() != heroine_ids.size():
		return "Run equipment snapshot does not match the active heroine set."
	var staged_loadouts: Dictionary = {}
	var staged_definitions: Dictionary = definition_result.get(
		"definitions",
		{}
	) as Dictionary
	for heroine_id: StringName in heroine_ids:
		var loadout_value: Variant = stored_loadouts.get(
			heroine_id,
			stored_loadouts.get(String(heroine_id), null)
		)
		if not (loadout_value is Dictionary):
			return "Run equipment snapshot is missing heroine '%s'." % heroine_id
		var loadout := PersonalEquipmentLoadoutState.new()
		var loadout_error: String = loadout.restore_from_snapshot(
			(loadout_value as Dictionary).duplicate(true),
			staged_definitions
		)
		if not loadout_error.is_empty():
			return loadout_error
		if loadout.owner_heroine_id != heroine_id:
			return "Run equipment loadout owner does not match heroine '%s'." % heroine_id
		staged_loadouts[heroine_id] = loadout
	definitions_by_id = staged_definitions
	loadouts_by_heroine = staged_loadouts
	run_inventory = new_run_inventory
	_connect_loadouts()
	equipment_changed.emit()
	return ""


func initialize_empty(
	battler_catalog: BattlerCatalogDefinition,
	new_run_inventory: RunInventoryState
) -> String:
	if battler_catalog == null or new_run_inventory == null:
		return "Empty run equipment requires catalogs and run inventory."
	var definition_result: Dictionary = _make_definition_registry(
		battler_catalog
	)
	var definition_error: String = String(definition_result.get("error", ""))
	if not definition_error.is_empty():
		return definition_error
	definitions_by_id = definition_result.get("definitions", {}) as Dictionary
	loadouts_by_heroine = {}
	run_inventory = new_run_inventory
	equipment_changed.emit()
	return ""


func bind_run_inventory(new_run_inventory: RunInventoryState) -> String:
	if new_run_inventory == null:
		return "Run equipment cannot bind a missing run inventory."
	run_inventory = new_run_inventory
	return ""


func get_loadout(heroine_id: StringName) -> PersonalEquipmentLoadoutState:
	return loadouts_by_heroine.get(
		heroine_id,
		loadouts_by_heroine.get(String(heroine_id), null)
	) as PersonalEquipmentLoadoutState


func equip(
	heroine_id: StringName,
	slot: EquipmentDefinition.Slot,
	instance_id: StringName
) -> String:
	var loadout: PersonalEquipmentLoadoutState = get_loadout(heroine_id)
	if loadout == null:
		return "Run equipment has no active heroine '%s'." % heroine_id
	return loadout.equip(slot, instance_id)


func unequip(
	heroine_id: StringName,
	slot: EquipmentDefinition.Slot
) -> String:
	var loadout: PersonalEquipmentLoadoutState = get_loadout(heroine_id)
	if loadout == null:
		return "Run equipment has no active heroine '%s'." % heroine_id
	return loadout.unequip(slot)


func assign_memento(heroine_id: StringName, item_id: StringName) -> String:
	if get_loadout(heroine_id) == null:
		return "Run equipment has no active heroine '%s'." % heroine_id
	if run_inventory == null:
		return "Run equipment has no Memento state owner."
	return run_inventory.assign_memento(heroine_id, item_id)


func clear_memento(heroine_id: StringName) -> String:
	if get_loadout(heroine_id) == null:
		return "Run equipment has no active heroine '%s'." % heroine_id
	if run_inventory == null:
		return "Run equipment has no Memento state owner."
	return run_inventory.clear_memento(heroine_id)


func get_memento_id(heroine_id: StringName) -> StringName:
	if get_loadout(heroine_id) == null or run_inventory == null:
		return &""
	return run_inventory.get_memento_id(heroine_id)


func get_snapshot() -> Dictionary:
	var serialized_loadouts: Dictionary = {}
	var heroine_ids: Array[StringName] = []
	for heroine_value: Variant in loadouts_by_heroine.keys():
		heroine_ids.append(StringName(heroine_value))
	heroine_ids.sort()
	for heroine_id: StringName in heroine_ids:
		var loadout: PersonalEquipmentLoadoutState = get_loadout(heroine_id)
		if loadout == null:
			continue
		var snapshot: Dictionary = loadout.to_snapshot()
		var memento_id: StringName = get_memento_id(heroine_id)
		snapshot["memento_id"] = String(memento_id) if memento_id != &"" else null
		serialized_loadouts[String(heroine_id)] = snapshot
	return {"loadouts_by_heroine": serialized_loadouts}


func _make_definition_registry(
	battler_catalog: BattlerCatalogDefinition
) -> Dictionary:
	var staged_definitions: Dictionary = {}
	for battler: BattlerDefinition in battler_catalog.battlers:
		if battler == null or battler.default_loadout == null:
			continue
		for definition: EquipmentDefinition in battler.default_loadout.get_all_equipment():
			if definition == null:
				continue
			var definition_error: String = definition.validate_definition()
			if not definition_error.is_empty():
				return {"error": definition_error, "definitions": {}}
			var existing: EquipmentDefinition = staged_definitions.get(
				definition.equipment_id
			) as EquipmentDefinition
			if existing != null and existing != definition:
				return {
					"error": "Duplicate equipment definition ID: %s." % definition.equipment_id,
					"definitions": {},
				}
			staged_definitions[definition.equipment_id] = definition
	return {"error": "", "definitions": staged_definitions}


func _connect_loadouts() -> void:
	for loadout_value: Variant in loadouts_by_heroine.values():
		var loadout := loadout_value as PersonalEquipmentLoadoutState
		if loadout != null and not loadout.loadout_changed.is_connected(_on_loadout_changed):
			loadout.loadout_changed.connect(_on_loadout_changed)


func _apply_legacy_condition_to_loadout(
	loadout: PersonalEquipmentLoadoutState,
	snapshot: Dictionary
) -> void:
	if snapshot.is_empty():
		return
	_set_legacy_instance_condition(
		loadout.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND),
		int(snapshot.get("weapon_damage", 0)),
		bool(snapshot.get("weapon_broken", false))
	)
	_set_legacy_instance_condition(
		loadout.get_equipped_instance(EquipmentDefinition.Slot.ARMOR),
		int(snapshot.get("armor_damage", 0)),
		bool(snapshot.get("armor_broken", false))
	)
	var off_hand: EquipmentInstance = loadout.get_equipped_instance(
		EquipmentDefinition.Slot.OFF_HAND
	)
	if off_hand != null and off_hand.definition is ShieldDefinition:
		_set_legacy_instance_condition(
			off_hand,
			int(snapshot.get("shield_damage", 0)),
			bool(snapshot.get("shield_broken", false))
		)


func _set_legacy_instance_condition(
	instance: EquipmentInstance,
	damage: int,
	broken: bool
) -> void:
	if instance == null or instance.definition == null:
		return
	instance.set_condition_clamped(
		0
		if broken
		else instance.definition.condition_maximum - maxi(damage, 0)
	)


func _on_loadout_changed() -> void:
	equipment_changed.emit()
