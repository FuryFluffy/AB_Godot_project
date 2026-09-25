extends SceneTree


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
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
const HEROINE_IDS: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]


var failures: int = 0


func _init() -> void:
	_test_authored_catalogs()
	_test_salvage_yields_locations_and_rollback()
	_test_repair_recipe_and_snapshot_persistence()
	if failures == 0:
		print("Refuge Material, salvage, and recipe tests passed.")
	else:
		push_error("%d Refuge salvage/recipe test(s) failed." % failures)
	quit(failures)


func _test_authored_catalogs() -> void:
	_expect(
		EQUIPMENT_CATALOG.equipment.size() == 26
		and MATERIAL_CATALOG.materials.size() == 4
		and RECIPE_CATALOG.recipes.size() == 1,
		"Milestone 10 must register 26 executable equipment definitions, four Layer 1-2 Materials, and one neutral repair service."
	)
	_expect(
		MATERIAL_CATALOG.validate_catalog().is_empty()
		and EQUIPMENT_CATALOG.validate_catalog(MATERIAL_CATALOG).is_empty()
		and RECIPE_CATALOG.validate_catalog(MATERIAL_CATALOG).is_empty()
		and MATERIAL_CATALOG.validate_references(
			EQUIPMENT_CATALOG,
			RECIPE_CATALOG
		).is_empty(),
		"Authored Equipment, Material, mapping, and recipe references must validate as one graph."
	)
	for material: MaterialDefinition in MATERIAL_CATALOG.materials:
		_expect(
			material != null
			and ITEM_CATALOG.get_item(material.item_id) == material
			and material.content_category == ItemDefinition.ContentCategory.MATERIAL
			and material.icon != null
			and material.icon.resource_path == (
				"res://assets/items/by_stable_id/%s.png" % material.item_id
			),
			"Every executable Material must share the canonical Item Catalog resource and Stable-ID icon."
		)
	var expected_salvage: Dictionary = {
		"red_wax_drip": ["mat_l01_red_wax", 1],
		"corrupted_butler_cloth": ["mat_l01_servant_cloth", 1],
		"chain_thrall_chain": ["mat_l02_chain_links", 2],
		"iron_guard_gaoler_pole": ["mat_l02_prison_iron", 3],
	}
	var destructible_count: int = 0
	for definition: EquipmentDefinition in EQUIPMENT_CATALOG.equipment:
		if not definition.destructible:
			continue
		destructible_count += 1
		var expected: Array = expected_salvage.get(
			String(definition.equipment_id),
			[]
		) as Array
		_expect(
			expected.size() == 2
			and String(definition.salvage_material_id) == String(expected[0])
			and definition.get_salvage_yield() == int(expected[1]),
			"Destructible equipment must retain its exact authored Material mapping and fixed rarity yield."
		)
	_expect(
		destructible_count == 4
		and EQUIPMENT_CATALOG.get_equipment(&"accurate_sword") == null
		and EQUIPMENT_CATALOG.get_equipment(&"ember_sword") == null,
		"Only the four directly mapped executable definitions may become destructible; example weapons stay outside production content."
	)

	var duplicate_material_catalog := MaterialCatalogDefinition.new()
	duplicate_material_catalog.materials = [
		MATERIAL_CATALOG.materials[0],
		MATERIAL_CATALOG.materials[0],
	]
	var duplicate_equipment_catalog := EquipmentCatalogDefinition.new()
	duplicate_equipment_catalog.equipment = [
		EQUIPMENT_CATALOG.equipment[0],
		EQUIPMENT_CATALOG.equipment[0],
	]
	var invalid_equipment_rarity := EQUIPMENT_CATALOG.get_equipment(
		&"red_wax_drip"
	).duplicate(true) as EquipmentDefinition
	invalid_equipment_rarity.rarity = 99
	var invalid_tier := MATERIAL_CATALOG.materials[0].duplicate(
		true
	) as MaterialDefinition
	invalid_tier.material_tier = 99
	var invalid_recipe := RefugeRecipeDefinition.new()
	invalid_recipe.recipe_id = &"invalid_recipe"
	invalid_recipe.display_name = "Invalid Recipe"
	invalid_recipe.material_inputs = {"missing_material": 1}
	_expect(
		not duplicate_material_catalog.validate_catalog().is_empty()
		and not duplicate_equipment_catalog.validate_catalog(
			MATERIAL_CATALOG
		).is_empty()
		and not invalid_equipment_rarity.validate_definition().is_empty()
		and not invalid_tier.validate_definition().is_empty()
		and not invalid_recipe.validate_definition(MATERIAL_CATALOG).is_empty(),
		"Duplicate catalog IDs, invalid Equipment/Material tiers, and orphan recipe inputs must be rejected."
	)


func _test_salvage_yields_locations_and_rollback() -> void:
	var refuge: RefugeOwnershipState = _make_refuge()
	var setup_error: String = _add_stash_instance(
		refuge,
		&"red_wax_drip",
		&"salvage:red_wax:broken",
		0
	)
	if setup_error.is_empty():
		setup_error = _add_stash_instance(
			refuge,
			&"corrupted_butler_cloth",
			&"salvage:cloth:full",
			2
		)
	if setup_error.is_empty():
		setup_error = _add_stash_instance(
			refuge,
			&"chain_thrall_chain",
			&"salvage:chain:equipped",
			4
		)
	if setup_error.is_empty():
		setup_error = refuge.move_stash_equipment_to_heroine(
			&"salvage:chain:equipped",
			&"lysandra"
		)
	if setup_error.is_empty():
		setup_error = refuge.equip_owned_instance(
			&"lysandra",
			EquipmentDefinition.Slot.MAIN_HAND,
			&"salvage:chain:equipped"
		)
	if setup_error.is_empty():
		setup_error = _add_stash_instance(
			refuge,
			&"iron_guard_gaoler_pole",
			&"salvage:iron:rare",
			1
		)
	_expect(setup_error.is_empty(), "Salvage fixtures must enter legal Refuge ownership.")
	if not setup_error.is_empty():
		return

	var broken_common: Dictionary = refuge.salvage_owned_equipment(
		&"salvage:red_wax:broken"
	)
	var full_common: Dictionary = refuge.salvage_owned_equipment(
		&"salvage:cloth:full"
	)
	var equipped_uncommon: Dictionary = refuge.salvage_owned_equipment(
		&"salvage:chain:equipped"
	)
	var rare: Dictionary = refuge.salvage_owned_equipment(
		&"salvage:iron:rare"
	)
	var lysandra_snapshot: Dictionary = refuge.equipment_loadouts_by_heroine.get(
		&"lysandra",
		{}
	) as Dictionary
	var lysandra_slots: Dictionary = lysandra_snapshot.get("slots", {}) as Dictionary
	var lysandra_instances: Dictionary = lysandra_snapshot.get(
		"instances",
		{}
	) as Dictionary
	_expect(
		String(broken_common.get("error", "")).is_empty()
		and String(full_common.get("error", "")).is_empty()
		and int(broken_common.get("quantity", 0)) == 1
		and int(full_common.get("quantity", 0)) == 1
		and refuge.get_banked_material_quantity(&"mat_l01_red_wax") == 1
		and refuge.get_banked_material_quantity(&"mat_l01_servant_cloth") == 1,
		"Common salvage must yield one regardless of zero or full condition."
	)
	_expect(
		String(equipped_uncommon.get("error", "")).is_empty()
		and int(equipped_uncommon.get("quantity", 0)) == 2
		and String(equipped_uncommon.get("removed_slot", "")) == "main_hand"
		and String(lysandra_slots.get("main_hand", "")).is_empty()
		and not lysandra_instances.has("salvage:chain:equipped")
		and refuge.get_banked_material_quantity(&"mat_l02_chain_links") == 2,
		"Uncommon equipped salvage must yield two and clear only its exact slot/reference."
	)
	_expect(
		String(rare.get("error", "")).is_empty()
		and int(rare.get("quantity", 0)) == 3
		and refuge.get_banked_material_quantity(&"mat_l02_prison_iron") == 3,
		"Rare Stash salvage must deterministically yield three."
	)

	var before_rejections: Dictionary = refuge.to_snapshot()
	var sword_id := StringName(
		_find_definition_instance_id(lysandra_instances, &"lysandra_sword")
	)
	var non_destructible: Dictionary = refuge.salvage_owned_equipment(sword_id)
	var foreign: Dictionary = refuge.salvage_owned_equipment(&"foreign:instance")
	var duplicate: Dictionary = refuge.salvage_owned_equipment(
		&"salvage:iron:rare"
	)
	var malformed: Dictionary = refuge.salvage_owned_equipment(&"")
	_expect(
		not String(non_destructible.get("error", "")).is_empty()
		and not String(foreign.get("error", "")).is_empty()
		and not String(duplicate.get("error", "")).is_empty()
		and not String(malformed.get("error", "")).is_empty()
		and refuge.to_snapshot() == before_rejections,
		"Non-destructible, foreign, duplicate, and malformed salvage must roll back completely."
	)

	var malformed_snapshot: Dictionary = refuge.to_snapshot()
	var malformed_stash: Dictionary = malformed_snapshot.get("stash", {}) as Dictionary
	var malformed_equipment: Dictionary = malformed_stash.get(
		"equipment_instances",
		{}
	) as Dictionary
	malformed_equipment["broken:record"] = {
		"instance_id": "broken:record",
		"definition_id": "red_wax_drip",
		"current_condition": "bad",
	}
	var before_bad_restore: Dictionary = refuge.to_snapshot()
	var restore_error: String = refuge.restore_from_snapshot(
		malformed_snapshot,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)
	_expect(
		not restore_error.is_empty()
		and refuge.to_snapshot() == before_bad_restore,
		"Malformed equipment snapshots must reject without losing existing Refuge ownership."
	)

	var transfer: Dictionary = refuge.make_run_start_transfer()
	var deployed_refuge: RefugeOwnershipState = transfer.get(
		"refuge_state"
	) as RefugeOwnershipState
	var run_equipment: RunEquipmentState = transfer.get(
		"run_equipment"
	) as RunEquipmentState
	var active_loadout: PersonalEquipmentLoadoutState = (
		run_equipment.get_loadout(&"lysandra") if run_equipment != null else null
	)
	var active_equipment: EquipmentInstance = (
		active_loadout.get_equipped_instance(EquipmentDefinition.Slot.ARMOR)
		if active_loadout != null
		else null
	)
	var active_before: Dictionary = (
		deployed_refuge.to_snapshot() if deployed_refuge != null else {}
	)
	var active_run_salvage: Dictionary = (
		deployed_refuge.salvage_owned_equipment(active_equipment.instance_id)
		if deployed_refuge != null and active_equipment != null
		else {"error": "Fixture did not produce deployed equipment."}
	)
	_expect(
		String(transfer.get("error", "")).is_empty()
		and deployed_refuge != null
		and active_equipment != null
		and not String(active_run_salvage.get("error", "")).is_empty()
		and deployed_refuge.to_snapshot() == active_before,
		"Refuge salvage must reject active-run equipment without mutating deployed Refuge ownership."
	)


func _test_repair_recipe_and_snapshot_persistence() -> void:
	var refuge: RefugeOwnershipState = _make_refuge()
	var snapshot: Dictionary = refuge.to_snapshot()
	snapshot["banked_materials"] = {"mat_l01_servant_cloth": 2}
	var records: Dictionary = snapshot.get("heroine_records", {}) as Dictionary
	var seraphine: Dictionary = records.get("seraphine", {}) as Dictionary
	var loadout: Dictionary = seraphine.get("equipment_loadout", {}) as Dictionary
	var slots: Dictionary = loadout.get("slots", {}) as Dictionary
	var armor_id: String = String(slots.get("armor", ""))
	var instances: Dictionary = loadout.get("instances", {}) as Dictionary
	var armor_instance: Dictionary = instances.get(armor_id, {}) as Dictionary
	armor_instance["current_condition"] = 0
	var restore_error: String = refuge.restore_from_snapshot(
		snapshot,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)
	var repair: Dictionary = refuge.execute_refuge_recipe(
		&"refuge_repair_cloth_armor",
		StringName(armor_id)
	)
	_expect(
		restore_error.is_empty()
		and String(repair.get("error", "")).is_empty()
		and int(repair.get("condition_before", -1)) == 0
		and int(repair.get("condition_after", -1)) == 1
		and refuge.get_banked_material_quantity(&"mat_l01_servant_cloth") == 1,
		"The authored repair service must consume exactly one banked Servant Cloth and restore exactly one Armor condition."
	)

	var round_trip := RefugeOwnershipState.new()
	var round_trip_error: String = round_trip.restore_from_snapshot(
		refuge.to_snapshot(),
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)
	_expect(
		round_trip_error.is_empty()
		and round_trip.get_banked_material_quantity(&"mat_l01_servant_cloth") == 1
		and _snapshot_instance_condition(round_trip, armor_id) == 1,
		"Recipe Material consumption and repaired condition must persist in the existing Refuge snapshot."
	)

	var lysandra_snapshot: Dictionary = round_trip.equipment_loadouts_by_heroine.get(
		&"lysandra",
		{}
	) as Dictionary
	var sword_id: StringName = StringName(
		(lysandra_snapshot.get("slots", {}) as Dictionary).get("main_hand", "")
	)
	var before_wrong_target: Dictionary = round_trip.to_snapshot()
	var wrong_target: Dictionary = round_trip.execute_refuge_recipe(
		&"refuge_repair_cloth_armor",
		sword_id
	)
	_expect(
		not String(wrong_target.get("error", "")).is_empty()
		and round_trip.to_snapshot() == before_wrong_target,
		"Recipe target validation must reject a Weapon without consuming Materials."
	)

	var second_repair: Dictionary = round_trip.execute_refuge_recipe(
		&"refuge_repair_cloth_armor",
		StringName(armor_id)
	)
	var insufficient_snapshot: Dictionary = round_trip.to_snapshot()
	var insufficient_records: Dictionary = insufficient_snapshot.get(
		"heroine_records",
		{}
	) as Dictionary
	var insufficient_heroine: Dictionary = insufficient_records.get(
		"seraphine",
		{}
	) as Dictionary
	var insufficient_loadout: Dictionary = insufficient_heroine.get(
		"equipment_loadout",
		{}
	) as Dictionary
	var insufficient_instances: Dictionary = insufficient_loadout.get(
		"instances",
		{}
	) as Dictionary
	var insufficient_instance: Dictionary = insufficient_instances.get(
		armor_id,
		{}
	) as Dictionary
	insufficient_instance["current_condition"] = 1
	var insufficient_setup_error: String = round_trip.restore_from_snapshot(
		insufficient_snapshot,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)
	var before_insufficient: Dictionary = round_trip.to_snapshot()
	var insufficient: Dictionary = round_trip.execute_refuge_recipe(
		&"refuge_repair_cloth_armor",
		StringName(armor_id)
	)
	_expect(
		String(second_repair.get("error", "")).is_empty()
		and insufficient_setup_error.is_empty()
		and not String(insufficient.get("error", "")).is_empty()
		and round_trip.to_snapshot() == before_insufficient,
		"Insufficient recipe inputs must fail transactionally after the exact available repairs."
	)
	_expect(
		not round_trip.withdraw_banked_material_to_run(
			&"mat_l01_servant_cloth",
			1
		).is_empty(),
		"Banked recipe Materials must remain unavailable to later runs."
	)


func _make_refuge() -> RefugeOwnershipState:
	var refuge := RefugeOwnershipState.new()
	var error: String = refuge.initialize_default(
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)
	_expect(error.is_empty(), "Default Refuge ownership must initialize for focused tests.")
	return refuge


func _add_stash_instance(
	refuge: RefugeOwnershipState,
	definition_id: StringName,
	instance_id: StringName,
	condition: int
) -> String:
	var definition: EquipmentDefinition = EQUIPMENT_CATALOG.get_equipment(
		definition_id
	)
	if definition == null:
		return "Missing fixture definition."
	var instance := EquipmentInstance.new()
	var instance_error: String = instance.initialize(
		instance_id,
		definition,
		condition
	)
	if not instance_error.is_empty():
		return instance_error
	var snapshot: Dictionary = refuge.to_snapshot()
	var stash: Dictionary = snapshot.get("stash", {}) as Dictionary
	var equipment: Dictionary = stash.get("equipment_instances", {}) as Dictionary
	equipment[String(instance_id)] = instance.to_snapshot()
	return refuge.restore_from_snapshot(
		snapshot,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)


func _find_definition_instance_id(
	instances: Dictionary,
	definition_id: StringName
) -> String:
	for instance_value: Variant in instances.values():
		if not (instance_value is Dictionary):
			continue
		var snapshot: Dictionary = instance_value as Dictionary
		if StringName(snapshot.get("definition_id", "")) == definition_id:
			return String(snapshot.get("instance_id", ""))
	return ""


func _snapshot_instance_condition(
	refuge: RefugeOwnershipState,
	instance_id: String
) -> int:
	for loadout_value: Variant in refuge.equipment_loadouts_by_heroine.values():
		if not (loadout_value is Dictionary):
			continue
		var instances: Dictionary = (loadout_value as Dictionary).get(
			"instances",
			{}
		) as Dictionary
		if instances.has(instance_id):
			return int((instances[instance_id] as Dictionary).get(
				"current_condition",
				-1
			))
	return -1


func _make_empty_item_bar() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_index: int in range(6):
		slots.append({
			"slot_index": slot_index,
			"item_id": "",
			"quantity": 0,
		})
	return slots


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
