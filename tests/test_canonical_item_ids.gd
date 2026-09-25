extends SceneTree


const CATALOG_PATH: String = "res://data/items/layer_1_2_item_catalog.tres"
const MANIFEST_PATH: String = "res://data/items/item_sprite_manifest.json"
const LEGACY_BLANKET_PATH: String = (
	"res://data/items/layer_2/quiet_cell_blanket.tres"
)
const EXPECTED_MANIFEST_COUNT: int = 126
const EXPECTED_PRE_MATERIAL_ITEM_COUNT: int = 28
const EXPECTED_WORKBOOK_COUNT: int = 32
const EXPECTED_CATALOG_COUNT: int = 33
const EXECUTABLE_MATERIAL_IDS: Array[StringName] = [
	&"mat_l01_red_wax",
	&"mat_l01_servant_cloth",
	&"mat_l02_chain_links",
	&"mat_l02_prison_iron",
]


var failures: int = 0


func _init() -> void:
	_test_canonical_catalog_identity()
	_test_active_presentation_resources()

	if failures == 0:
		print("Canonical item Stable-ID tests passed.")
	else:
		push_error("%d canonical item Stable-ID test(s) failed." % failures)
	quit(failures)


func _test_canonical_catalog_identity() -> void:
	var manifest: Dictionary = _load_manifest()
	var catalog := load(CATALOG_PATH) as ItemCatalogDefinition
	_expect(catalog != null, "The canonical Layer 1–2 catalog should load.")
	if manifest.is_empty() or catalog == null:
		return

	var manifest_items: Array = manifest.get("items", []) as Array
	_expect(
		manifest_items.size() == EXPECTED_MANIFEST_COUNT,
		"The complete 126-entry sprite manifest must remain intact."
	)
	_expect(
		catalog.items.size() == EXPECTED_CATALOG_COUNT,
		"The catalog should contain 32 workbook items and one legacy item."
	)
	_expect(
		catalog.validate_catalog().is_empty(),
		"Canonical item metadata should pass catalog validation."
	)

	var manifest_by_id: Dictionary = {}
	var implemented_manifest_ids: Array[StringName] = []
	var pre_material_item_count: int = 0
	for item_value: Variant in manifest_items:
		if not (item_value is Dictionary):
			continue
		var record: Dictionary = item_value as Dictionary
		var stable_id := StringName(record.get("stable_id", ""))
		manifest_by_id[stable_id] = record
		if (
			String(record.get("source_kind", "")) == "existing_project_item"
			or EXECUTABLE_MATERIAL_IDS.has(stable_id)
		):
			implemented_manifest_ids.append(stable_id)
		if String(record.get("source_kind", "")) == "existing_project_item":
			pre_material_item_count += 1

	_expect(
		implemented_manifest_ids.size() == EXPECTED_WORKBOOK_COUNT,
		"The manifest should identify 28 carried items plus four executable Materials."
	)
	_expect(
		pre_material_item_count == EXPECTED_PRE_MATERIAL_ITEM_COUNT,
		"Milestone 10 must preserve the 28 previously executable carried items."
	)

	var seen_ids: Dictionary = {}
	var seen_workbook_ids: Dictionary = {}
	for item: ItemDefinition in catalog.items:
		_expect(item != null, "The canonical catalog must not contain null items.")
		if item == null:
			continue
		_expect(
			not seen_ids.has(item.item_id),
			"Canonical item IDs must be unique: %s" % item.item_id
		)
		seen_ids[item.item_id] = true
		if not item.canonical_workbook_item:
			continue
		seen_workbook_ids[item.item_id] = true
		var record_value: Variant = manifest_by_id.get(item.item_id, {})
		_expect(
			record_value is Dictionary and not (record_value as Dictionary).is_empty(),
			"Implemented item %s must resolve through the manifest." % item.item_id
		)
		if not (record_value is Dictionary) or (record_value as Dictionary).is_empty():
			continue
		var record: Dictionary = record_value as Dictionary
		var legacy_source_stem: String = String(
			record.get("source_path", "")
		).get_file().get_basename()
		var definition_stem: String = item.resource_path.get_file().get_basename()
		if String(record.get("source_kind", "")) == "existing_project_item":
			_expect(
				legacy_source_stem == definition_stem,
				"%s must be the definition matched by manifest source_path." % item.item_id
			)
		_expect(
			item.canonical_workbook_item,
			"%s must be marked as a canonical workbook item." % item.item_id
		)
		_expect(
			item.content_category == _expected_category(record),
			"%s must retain the manifest content category." % item.item_id
		)
		_expect(
			item.rarity == _expected_rarity(record),
			"%s must retain the manifest rarity." % item.item_id
		)
		_expect(
			item.layer == int(record.get("layer", 0)),
			"%s must retain the manifest origin Layer." % item.item_id
		)
		var expected_icon_path: String = String(record.get("texture_path", ""))
		_expect(
			item.icon != null and item.icon.resource_path == expected_icon_path,
			"%s must use its matching Stable-ID texture." % item.item_id
		)
		_expect(
			catalog.get_item(item.item_id) == item,
			"%s must resolve through the existing catalog." % item.item_id
		)

	for stable_id: StringName in implemented_manifest_ids:
		_expect(
			seen_workbook_ids.has(stable_id),
			"Implemented manifest item %s is missing from the catalog." % stable_id
		)
	_expect(
		seen_workbook_ids.size() == EXPECTED_WORKBOOK_COUNT
		and manifest_items.size() - seen_workbook_ids.size() == 94,
		"The remaining 94 art-only manifest rows must stay unimplemented."
	)

	_test_legacy_blanket_isolation(catalog, manifest_by_id)
	_test_legacy_save_id_migration(manifest_by_id, implemented_manifest_ids)


func _test_legacy_blanket_isolation(
	catalog: ItemCatalogDefinition,
	manifest_by_id: Dictionary
) -> void:
	var blanket := load(LEGACY_BLANKET_PATH) as ItemDefinition
	_expect(blanket != null, "Quiet Cell Blanket legacy content should be retained.")
	if blanket == null:
		return
	_expect(
		blanket.item_id == &"quiet_cell_blanket"
		and not blanket.canonical_workbook_item
		and blanket.content_category
		== ItemDefinition.ContentCategory.LEGACY_DEVELOPMENT
		and blanket.rarity == ItemDefinition.Rarity.UNSPECIFIED
		and not manifest_by_id.has(blanket.item_id)
		and catalog.get_item(blanket.item_id) == blanket,
		(
			"Quiet Cell Blanket must remain an isolated legacy/development "
			+ "catalog item, never a workbook item."
		)
	)
	var legacy_snapshot: Dictionary = {
		"inventory_snapshot": [{
			"slot_index": 0,
			"item_id": "quiet_cell_blanket",
			"quantity": 1,
		}],
	}
	var migrated_snapshot: Dictionary = (
		CampaignSaveStore._migrate_legacy_item_ids(legacy_snapshot)
	)
	var migrated_inventory: Array = migrated_snapshot.get(
		"inventory_snapshot",
		[]
	) as Array
	var retained_item_id := StringName(
		(migrated_inventory[0] as Dictionary).get("item_id", "")
	) if not migrated_inventory.is_empty() else &""
	_expect(
		CampaignSaveStore.RETAINED_LEGACY_ITEM_IDS.has(
			String(retained_item_id)
		)
		and retained_item_id == blanket.item_id
		and catalog.get_item(retained_item_id) == blanket,
		"Old snapshots must retain and resolve the legacy blanket ID."
	)


func _test_active_presentation_resources() -> void:
	var warm_wine_entry := load(
		"res://data/exploration/item_pools/layer1/"
		+ "warm_wine_flask_room_entry.tres"
	) as RoomItemPoolEntryDefinition
	var rusty_key_entry := load(
		"res://data/exploration/item_pools/layer1/"
		+ "rusty_key_room_entry.tres"
	) as RoomItemPoolEntryDefinition
	var red_wax_entry := load(
		"res://data/exploration/events/entries/red_wax_vial_entry.tres"
	) as RoomEventPoolEntryDefinition
	_expect(
		warm_wine_entry != null
		and warm_wine_entry.item != null
		and warm_wine_entry.item.item_id == &"l01_warm_wine_flask"
		and warm_wine_entry.world_texture != null
		and warm_wine_entry.world_texture.resource_path == (
			"res://assets/items/by_stable_id/l01_warm_wine_flask.png"
		),
		"The Warm Wine pickup must use its canonical item and runtime texture."
	)
	_expect(
		rusty_key_entry != null
		and rusty_key_entry.item != null
		and rusty_key_entry.item.item_id == &"shared_rusty_key"
		and rusty_key_entry.world_texture != null
		and rusty_key_entry.world_texture.resource_path == (
			"res://assets/items/by_stable_id/shared_rusty_key.png"
		),
		"The Rusty Key pickup must use its canonical item and runtime texture."
	)
	_expect(
		red_wax_entry != null
		and red_wax_entry.world_texture != null
		and red_wax_entry.world_texture.resource_path == (
			"res://assets/items/by_stable_id/l01_red_wax_ampoule.png"
		),
		"The Red Wax Vial event must use the canonical ampoule runtime texture."
	)


func _test_legacy_save_id_migration(
	manifest_by_id: Dictionary,
	implemented_manifest_ids: Array[StringName]
) -> void:
	var legacy_inventory: Array[Dictionary] = []
	for stable_id: StringName in implemented_manifest_ids:
		var record: Dictionary = manifest_by_id.get(stable_id, {}) as Dictionary
		legacy_inventory.append({
			"item_id": String(record.get("source_path", ""))
				.get_file()
				.get_basename(),
			"quantity": 1,
		})
	var source_document: Dictionary = {
		"inventory_snapshot": legacy_inventory,
	}
	var migrated: Dictionary = CampaignSaveStore._migrate_legacy_item_ids(
		source_document
	)
	var migrated_inventory: Array = migrated.get("inventory_snapshot", []) as Array
	var all_ids_migrated: bool = migrated_inventory.size() == (
		implemented_manifest_ids.size()
	)
	for slot_index: int in range(migrated_inventory.size()):
		var slot: Dictionary = migrated_inventory[slot_index] as Dictionary
		all_ids_migrated = (
			all_ids_migrated
			and StringName(slot.get("item_id", ""))
			== implemented_manifest_ids[slot_index]
		)
	_expect(
		all_ids_migrated,
		"Every deliberately retained legacy save ID must migrate canonically."
	)
	_expect(
		StringName(legacy_inventory[0].get("item_id", ""))
		!= implemented_manifest_ids[0],
		"Legacy save migration must not mutate the source document."
	)


func _load_manifest() -> Dictionary:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	_expect(file != null, "The item sprite manifest should be readable.")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_expect(parsed is Dictionary, "The item sprite manifest should be valid JSON.")
	return parsed as Dictionary if parsed is Dictionary else {}


func _expected_category(record: Dictionary) -> ItemDefinition.ContentCategory:
	match String(record.get("class", "")):
		"Active":
			return ItemDefinition.ContentCategory.ACTIVE
		"Memento":
			return ItemDefinition.ContentCategory.MEMENTO
		"Key":
			return ItemDefinition.ContentCategory.KEY
		"Material":
			return ItemDefinition.ContentCategory.MATERIAL
		"Story":
			return ItemDefinition.ContentCategory.STORY
		"Knowledge":
			return ItemDefinition.ContentCategory.KNOWLEDGE
	return ItemDefinition.ContentCategory.UNSPECIFIED


func _expected_rarity(record: Dictionary) -> ItemDefinition.Rarity:
	match String(record.get("rarity", "")):
		"Common", "Common Material":
			return ItemDefinition.Rarity.COMMON
		"Uncommon", "Uncommon Material":
			return ItemDefinition.Rarity.UNCOMMON
		"Rare":
			return ItemDefinition.Rarity.RARE
		"Unique":
			return ItemDefinition.Rarity.UNIQUE
	return ItemDefinition.Rarity.UNSPECIFIED


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
