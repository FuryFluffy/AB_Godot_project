class_name RefugeManagementController
extends RefCounted


signal state_changed


const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)
const MATERIAL_CATALOG: MaterialCatalogDefinition = preload(
	"res://data/materials/layer_1_2_material_catalog.tres"
)
const EQUIPMENT_CATALOG: EquipmentCatalogDefinition = preload(
	"res://data/equipment/layer_1_2_equipment_catalog.tres"
)
const RECIPE_CATALOG: RefugeRecipeCatalogDefinition = preload(
	"res://data/refuge/refuge_recipe_catalog.tres"
)


var run_state: RunState
var battler_catalog: BattlerCatalogDefinition
var persist_callback: Callable


func bind(
	new_run_state: RunState,
	new_battler_catalog: BattlerCatalogDefinition,
	new_persist_callback: Callable = Callable()
) -> String:
	if new_run_state == null or new_battler_catalog == null:
		return "Refuge management requires campaign and battler state."
	if not new_run_state.has_established_refuge():
		return "Refuge management is unavailable before the Refuge exists."
	var ownership_error: String = new_run_state.ensure_refuge_ownership_initialized()
	if not ownership_error.is_empty():
		return ownership_error
	run_state = new_run_state
	battler_catalog = new_battler_catalog
	persist_callback = new_persist_callback
	return ""


func reorder_party(heroine_id: StringName, offset: int) -> Dictionary:
	if offset not in [-1, 1]:
		return _error("Party order movement must be one position.")
	var order: Array[StringName] = _ownership().selected_party_ids.duplicate()
	var index: int = order.find(heroine_id)
	var target_index: int = index + offset
	if index < 0 or target_index < 0 or target_index >= order.size():
		return _error("The selected heroine cannot move farther in that direction.")
	var temporary: StringName = order[index]
	order[index] = order[target_index]
	order[target_index] = temporary
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		return staged.set_selected_party_order(order)
	)


func transfer_item(
	source: StringName,
	destination: StringName,
	heroine_id: StringName,
	item_id: StringName,
	quantity: int = 1
) -> Dictionary:
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		if source == &"preparation" and destination == &"item_bar":
			return staged.move_preparation_item_to_item_bar(
				heroine_id, item_id, quantity
			)
		if source == &"item_bar" and destination == &"preparation":
			return staged.move_item_bar_item_to_preparation(
				heroine_id, item_id, quantity
			)
		if source == &"preparation" and destination == &"stash":
			return staged.move_preparation_item_to_stash(
				heroine_id, item_id, quantity
			)
		if source == &"stash" and destination == &"preparation":
			return staged.move_stash_item_to_preparation(
				heroine_id, item_id, quantity
			)
		if source == &"item_bar" and destination == &"stash":
			return staged.move_item_bar_item_to_stash(item_id, quantity)
		if source == &"stash" and destination == &"item_bar":
			return staged.move_stash_item_to_item_bar(item_id, quantity)
		return "Unsupported Refuge item transfer."
	)


func inventory_request(source: Dictionary) -> Dictionary:
	return {"source": source.duplicate(true), "snapshot": _ownership().to_snapshot()}


func transfer_inventory(request: Dictionary, target: Dictionary, quantity: int, quick: bool = false) -> Dictionary:
	if request.get("snapshot", {}) != _ownership().to_snapshot():
		return _error("Inventory changed. Select the source again.")
	return _mutate(func(staged: RefugeOwnershipState) -> Dictionary:
		return RefugeInventoryTransfer.apply(staged, request.get("source", {}), target, quantity, quick)
	)


func get_loadout_candidates(heroine: StringName, slot: StringName) -> Array[Dictionary]:
	return RefugeLoadoutExchange.candidates(_ownership(), heroine, slot)


func get_equipped_entries(heroine: StringName) -> Array[Dictionary]:
	return RefugeLoadoutExchange.equipped_entries(_ownership(), heroine)


func exchange_loadout(heroine: StringName, slot: StringName, source: Dictionary, expected_snapshot: Dictionary) -> Dictionary:
	if expected_snapshot != _ownership().to_snapshot():
		return _error("Ownership changed. Reopen Change to refresh the available sources.")
	return _mutate(func(staged: RefugeOwnershipState) -> Dictionary:
		return RefugeLoadoutExchange.apply(staged, heroine, slot, source)
	)


func equip_instance(
	heroine_id: StringName,
	slot: EquipmentDefinition.Slot,
	instance_id: StringName
) -> Dictionary:
	if not _is_player_available_owned_instance(instance_id):
		return _error("That equipment is not authored for heroine Refuge use.")
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		return staged.equip_owned_instance(heroine_id, slot, instance_id)
	)


func unequip_slot(
	heroine_id: StringName,
	slot: EquipmentDefinition.Slot
) -> Dictionary:
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		return staged.unequip_owned_slot(heroine_id, slot)
	)


func move_heroine_equipment_to_stash(
	heroine_id: StringName,
	instance_id: StringName
) -> Dictionary:
	if not _is_player_available_owned_instance(instance_id):
		return _error("That equipment is not authored for heroine Refuge use.")
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		return staged.move_unequipped_equipment_to_stash(
			heroine_id, instance_id
		)
	)


func move_stash_equipment_to_heroine(
	instance_id: StringName,
	heroine_id: StringName
) -> Dictionary:
	if not _is_player_available_owned_instance(instance_id):
		return _error("That equipment is not authored for heroine Refuge use.")
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		return staged.move_stash_equipment_to_heroine(instance_id, heroine_id)
	)


func salvage_equipment(instance_id: StringName, expected_snapshot: Dictionary = {}) -> Dictionary:
	if not expected_snapshot.is_empty() and expected_snapshot != _ownership().to_snapshot():
		return _error("Ownership changed. Review salvage again before confirming.")
	var entry: Dictionary = get_equipment_entry(instance_id)
	if entry.is_empty() or not bool(entry.get("player_available", false)):
		return _error("That equipment is not an authored player salvage choice.")
	if StringName(entry.get("equipped_slot", "")) != &"":
		return _error("Unequip this equipment before salvaging it.")
	if not bool(entry.get("workbench_source", false)):
		return _error("Move this equipment to Stash or a Backpack first.")
	if not bool(entry.get("salvageable", false)):
		return _error("That equipment cannot be salvaged.")
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		return staged.salvage_owned_equipment(instance_id)
	)


func execute_repair(
	recipe_id: StringName,
	instance_id: StringName,
	expected_snapshot: Dictionary = {}
) -> Dictionary:
	if not expected_snapshot.is_empty() and expected_snapshot != _ownership().to_snapshot():
		return _error("Ownership changed. Review the repair again before confirming.")
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		return staged.execute_refuge_recipe(recipe_id, instance_id)
	)


func get_party_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _ownership() == null:
		return result
	for order_index: int in range(_ownership().selected_party_ids.size()):
		var heroine_id: StringName = _ownership().selected_party_ids[order_index]
		var definition: BattlerDefinition = battler_catalog.get_battler(heroine_id)
		var snapshot_value: Variant = run_state.party_snapshot.get(
			heroine_id,
			run_state.party_snapshot.get(String(heroine_id), {})
		)
		var snapshot: Dictionary = (
			snapshot_value as Dictionary if snapshot_value is Dictionary else {}
		)
		result.append({
			"heroine_id": heroine_id,
			"order_index": order_index,
			"display_name": definition.display_name if definition != null else String(heroine_id),
			"recruited": true,
			"active": true,
			"hp": int(snapshot.get("hp", definition.max_hp if definition != null else 0)),
			"max_hp": definition.max_hp if definition != null else 0,
			"mp": int(snapshot.get("mp", definition.max_mp if definition != null else 0)),
			"max_mp": definition.max_mp if definition != null else 0,
			"resolve": int(snapshot.get("resolve", 0)),
			"corruption": int(snapshot.get("corruption", 0)),
			"memento_id": _ownership().memento_slots_by_heroine.get(heroine_id, null),
		})
	return result


func get_preparation_entries(heroine_id: StringName) -> Array[Dictionary]:
	return _make_slot_entries(
		_ownership().preparation_slots_by_heroine.get(heroine_id, []) as Array,
		&"backpack",
		(_ownership().equipment_loadouts_by_heroine.get(heroine_id, {}) as Dictionary).get("instances", {})
	)


func get_item_bar_entries() -> Array[Dictionary]:
	return _make_slot_entries(
		_ownership().prepared_item_bar_slots,
		&"item_bar"
	)


func get_stash_item_entries() -> Array[Dictionary]:
	return _make_slot_entries(_ownership().stash_item_stacks, &"stash")


func get_key_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array[StringName] = []
	for key: Variant in _ownership().key_chain.keys():
		ids.append(StringName(key))
	ids.sort()
	for item_id: StringName in ids:
		var definition: ItemDefinition = ITEM_CATALOG.get_item(item_id)
		result.append({
			"item_id": item_id,
			"display_name": definition.display_name if definition != null else String(item_id),
			"quantity": int(_ownership().key_chain.get(String(item_id), 0)),
			"icon": definition.icon if definition != null else null,
			"persistence": (
				"Persistent Refuge"
				if definition != null and definition.key_persistence_scope == ItemDefinition.KeyPersistenceScope.PERSISTENT_REFUGE
				else "Run only — lost on defeat"
			),
		})
	return result


func get_material_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for material: MaterialDefinition in MATERIAL_CATALOG.materials:
		result.append({
			"item_id": material.item_id,
			"display_name": material.display_name,
			"quantity": _ownership().get_banked_material_quantity(material.item_id),
			"icon": material.icon,
		})
	return result


func get_recipe_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe: RefugeRecipeDefinition in RECIPE_CATALOG.recipes:
		if recipe.action != RefugeRecipeDefinition.Action.REPAIR_EQUIPMENT:
			continue
		var inputs: Array[String] = []
		var missing_inputs: Array[String] = []
		for key: Variant in recipe.material_inputs.keys():
			var material: MaterialDefinition = MATERIAL_CATALOG.get_material(
				StringName(key)
			)
			var required: int = int(recipe.material_inputs[key])
			var available: int = _ownership().get_banked_material_quantity(
				StringName(key)
			)
			var material_name: String = (
				material.display_name if material != null else String(key)
			)
			inputs.append("%d × %s (banked %d)" % [
				required,
				material_name,
				available,
			])
			if available < required:
				missing_inputs.append("%d more %s" % [
					required - available,
					material_name,
				])
		result.append({
			"recipe_id": recipe.recipe_id,
			"display_name": recipe.display_name,
			"inputs_text": ", ".join(inputs),
			"condition_restore_amount": recipe.condition_restore_amount,
			"effect_text": "Restore %d condition to eligible %s." % [
				recipe.condition_restore_amount,
				_recipe_target_label(recipe.equipment_target),
			],
			"can_pay": missing_inputs.is_empty(),
			"disabled_reason": (
				""
				if missing_inputs.is_empty()
				else "Missing %s." % ", ".join(missing_inputs)
			),
		})
	return result


func get_all_equipment_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for heroine_id: StringName in _ownership().known_heroine_ids:
		var snapshot: Dictionary = _ownership().equipment_loadouts_by_heroine.get(
			heroine_id,
			{}
		) as Dictionary
		var slots: Dictionary = snapshot.get("slots", {}) as Dictionary
		var instances: Dictionary = snapshot.get("instances", {}) as Dictionary
		for key: Variant in instances.keys():
			result.append(_make_equipment_entry(
				instances[key] as Dictionary,
				&"heroine",
				heroine_id,
				_find_equipped_slot(slots, StringName(key))
			))
	for key: Variant in _ownership().stash_equipment_instances.keys():
		result.append(_make_equipment_entry(
			_ownership().stash_equipment_instances[key] as Dictionary,
			&"stash",
			&"",
			&""
		))
	return result


func get_equipment_entries_for_heroine(
	heroine_id: StringName
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in get_all_equipment_entries():
		if (
			StringName(entry.get("heroine_id", "")) == heroine_id
			and bool(entry.get("player_available", false))
		):
			result.append(entry)
	return result


func get_stash_equipment_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in get_all_equipment_entries():
		if (
			StringName(entry.get("location", "")) == &"stash"
			and bool(entry.get("player_available", false))
		):
			result.append(entry)
	return result


func get_repair_target_entries(recipe_id: StringName) -> Array[Dictionary]:
	var recipe: RefugeRecipeDefinition = RECIPE_CATALOG.get_recipe(recipe_id)
	var result: Array[Dictionary] = []
	if recipe == null or recipe.action != RefugeRecipeDefinition.Action.REPAIR_EQUIPMENT:
		return result
	for entry: Dictionary in get_all_equipment_entries():
		var definition: EquipmentDefinition = EQUIPMENT_CATALOG.get_equipment(
			StringName(entry.get("definition_id", ""))
		)
		if (
			definition != null
			and bool(entry.get("player_available", false))
			and bool(entry.get("workbench_source", false))
			and recipe.accepts_target(definition)
			and int(entry.get("condition", 0)) < int(entry.get("condition_maximum", 0))
		):
			result.append(entry)
	return result


func get_salvage_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in get_all_equipment_entries():
		if (
			bool(entry.get("player_available", false))
			and bool(entry.get("salvageable", false))
			and bool(entry.get("workbench_source", false))
			and StringName(entry.get("equipped_slot", "")) == &""
		):
			result.append(entry)
	return result


func get_equipment_entry(instance_id: StringName) -> Dictionary:
	for entry: Dictionary in get_all_equipment_entries():
		if StringName(entry.get("instance_id", "")) == instance_id:
			return entry
	return {}


func _mutate(operation: Callable) -> Dictionary:
	if _ownership() == null:
		return _error("Refuge management is not bound to ownership state.")
	var staged := RefugeOwnershipState.new()
	var restore_error: String = staged.restore_from_snapshot(
		_ownership().to_snapshot(),
		ITEM_CATALOG,
		battler_catalog,
		_ownership().known_heroine_ids
	)
	if not restore_error.is_empty():
		return _error(restore_error)
	var operation_value: Variant = operation.call(staged)
	var result: Dictionary = (
		operation_value.duplicate(true)
		if operation_value is Dictionary
		else {"error": String(operation_value)}
	)
	var operation_error: String = String(result.get("error", ""))
	if not operation_error.is_empty():
		return result
	if result.has("changed") and not result.changed:
		return result
	var validation_error: String = RefugeOwnershipState.validate_snapshot(staged.to_snapshot(), ITEM_CATALOG, battler_catalog, staged.known_heroine_ids)
	if not validation_error.is_empty():
		return _error(validation_error)
	var original: RefugeOwnershipState = run_state.refuge_ownership
	run_state.refuge_ownership = staged
	var save_error: String = ""
	if persist_callback.is_valid():
		save_error = String(persist_callback.call())
	if not save_error.is_empty():
		run_state.refuge_ownership = original
		return _error(save_error)
	run_state.run_changed.emit()
	state_changed.emit()
	result["error"] = ""
	return result


func _make_slot_entries(slots: Array, domain: StringName, instances: Dictionary = {}) -> Array[Dictionary]:
	return InventorySlotPresenter.entries(slots, domain, ITEM_CATALOG, EQUIPMENT_CATALOG, instances)


func get_backpack_heroine_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for heroine_id: StringName in _ownership().known_heroine_ids:
		var definition: BattlerDefinition = battler_catalog.get_battler(heroine_id)
		result.append({"heroine_id": heroine_id, "display_name": definition.display_name if definition != null else String(heroine_id)})
	return result


func get_rest_heroine_entries() -> Array[Dictionary]:
	# Recovery has no authored service rules yet. This projection cannot mutate
	# campaign state or substitute starting stats for a missing current snapshot.
	if run_state == null or battler_catalog == null or _ownership() == null:
		return []
	var result: Array[Dictionary] = get_backpack_heroine_entries()
	for entry: Dictionary in result:
		var id := StringName(entry.heroine_id)
		var value: Variant = run_state.party_snapshot.get(id, run_state.party_snapshot.get(String(id), null))
		var snapshot: Dictionary = value if value is Dictionary else {}
		entry["resolve"] = snapshot.get("resolve", null)
		entry["corruption"] = snapshot.get("corruption", null)
	return result


func _make_equipment_entry(
	snapshot: Dictionary,
	location: StringName,
	heroine_id: StringName,
	equipped_slot: StringName
) -> Dictionary:
	var definition_id := StringName(snapshot.get("definition_id", ""))
	var definition: EquipmentDefinition = EQUIPMENT_CATALOG.get_equipment(
		definition_id
	)
	var condition: int = int(snapshot.get("current_condition", 0))
	var storage: String = _equipment_storage_label(heroine_id, StringName(snapshot.get("instance_id", "")), location, equipped_slot)
	var source: String = storage
	if heroine_id != &"":
		var owner: BattlerDefinition = battler_catalog.get_battler(heroine_id)
		var owner_name: String = owner.display_name if owner != null else String(heroine_id)
		source = storage.replace("Backpack ·", "Backpack · %s ·" % owner_name) if storage.begins_with("Backpack") else "%s · %s" % [storage, owner_name]
		if equipped_slot != &"":
			source += " · " + String(equipped_slot).replace("_", " ").capitalize()
	return {
		"instance_id": StringName(snapshot.get("instance_id", "")),
		"definition_id": definition_id,
		"display_name": definition.display_name if definition != null else String(definition_id),
		"location": location,
		"heroine_id": heroine_id,
		"equipped_slot": equipped_slot,
		"storage_label": storage,
		"source_label": source,
		"workbench_source": storage != "Personal reserve",
		"condition": condition,
		"condition_maximum": definition.condition_maximum if definition != null else 0,
		"broken": condition <= 0,
		"player_available": definition.player_refuge_available if definition != null else false,
		"salvageable": definition.destructible if definition != null else false,
		"salvage_material_id": definition.salvage_material_id if definition != null else &"",
		"salvage_yield": definition.get_salvage_yield() if definition != null else 0,
	}


func _equipment_storage_label(heroine_id: StringName, instance_id: StringName, location: StringName, equipped_slot: StringName) -> String:
	if location == &"stash":
		return "Stash"
	if equipped_slot != &"":
		return "Equipped"
	for entry: Dictionary in _ownership().preparation_slots_by_heroine.get(heroine_id, []):
		if StringName(entry.get("equipment_instance_id", "")) == instance_id:
			return "Backpack · slot %d" % (int(entry.slot_index) + 1)
	# Legacy registry reserves are not implicitly Backpack contents.
	return "Personal reserve"


func _find_equipped_slot(slots: Dictionary, instance_id: StringName) -> StringName:
	for key: Variant in slots.keys():
		if StringName(slots[key]) == instance_id:
			return StringName(key)
	return &""


func _is_player_available_owned_instance(instance_id: StringName) -> bool:
	var entry: Dictionary = get_equipment_entry(instance_id)
	return not entry.is_empty() and bool(entry.get("player_available", false))


func _recipe_target_label(
	target: RefugeRecipeDefinition.EquipmentTarget
) -> String:
	match target:
		RefugeRecipeDefinition.EquipmentTarget.WEAPON:
			return "Weapon"
		RefugeRecipeDefinition.EquipmentTarget.ARMOR:
			return "Armor"
		RefugeRecipeDefinition.EquipmentTarget.SHIELD:
			return "Shield"
	return "equipment"


func _ownership() -> RefugeOwnershipState:
	return run_state.refuge_ownership if run_state != null else null


func _error(message: String) -> Dictionary:
	return {"error": message}


func get_production_entries(station: RefugeRecipeDefinition.Station) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if station not in [RefugeRecipeDefinition.Station.ALCHEMY, RefugeRecipeDefinition.Station.CRAFTING]:
		return result
	for recipe: RefugeRecipeDefinition in RECIPE_CATALOG.recipes:
		if recipe.action != RefugeRecipeDefinition.Action.PRODUCE_ITEM or recipe.station != station:
			continue
		var error: String = recipe.validate_definition(MATERIAL_CATALOG, ITEM_CATALOG)
		if not error.is_empty():
			continue
		var inputs: Array[Dictionary] = []
		var can_pay: bool = true
		for id: Variant in recipe.material_inputs:
			var material: MaterialDefinition = MATERIAL_CATALOG.get_material(StringName(id))
			var owned: int = _ownership().get_banked_material_quantity(StringName(id))
			var required: int = int(recipe.material_inputs[id])
			inputs.append({"id": StringName(id), "name": material.display_name, "icon": material.icon, "owned": owned, "required": required})
			can_pay = can_pay and owned >= required
		var output: ItemDefinition = ITEM_CATALOG.get_item(recipe.output_item_id)
		result.append({"recipe_id": recipe.recipe_id, "name": recipe.display_name, "inputs": inputs, "can_pay": can_pay, "output_name": output.display_name, "output_icon": output.icon, "quantity": recipe.output_quantity})
	return result


func produce_item(station: RefugeRecipeDefinition.Station, recipe_id: StringName, expected_snapshot: Dictionary) -> Dictionary:
	if expected_snapshot != _ownership().to_snapshot():
		return _error("Ownership changed. Review the recipe again.")
	var recipe: RefugeRecipeDefinition = RECIPE_CATALOG.get_recipe(recipe_id)
	if recipe == null or recipe.action != RefugeRecipeDefinition.Action.PRODUCE_ITEM or recipe.station != station or station == RefugeRecipeDefinition.Station.WORKBENCH:
		return _error("This recipe is unavailable at this station.")
	return _mutate(func(staged: RefugeOwnershipState) -> Dictionary:
		return staged.execute_production_recipe(recipe_id)
	)


func apply_party_order(ids: Array[StringName], expected_order: Array[StringName]) -> Dictionary:
	if run_state == null or run_state.graph == null or run_state.graph.layer_id != &"bloom_refuge":
		return _error("Party preparation requires the Refuge.")
	if _ownership().selected_party_ids != expected_order:
		return _error("Party changed. Use Reset Draft before editing again.")
	if ids == expected_order:
		return {"error": "", "changed": false}
	return _mutate(func(staged: RefugeOwnershipState) -> Variant:
		return staged.set_selected_party_order(ids)
	)
