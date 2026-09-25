class_name RewardSourceResolver
extends RefCounted


const SEED_NAMESPACE: StringName = &"reward_source_selection"
const CURRENT_LAYER_WEIGHT_MULTIPLIER: int = 3
const EXECUTABLE_HEROINE_IDS: Array[StringName] = [
	&"lysandra",
	&"mira",
	&"seraphine",
]


static func collect_validation_errors(
	source: RoomLootSourceDefinition,
	item_catalog: ItemCatalogDefinition,
	current_layer: int = 0
) -> Array[String]:
	var errors: Array[String] = []
	if source == null:
		return ["Reward source is null."]
	errors.append_array(
		source.collect_validation_errors(
			"Reward source '%s'" % source.source_id
		)
	)
	if item_catalog == null:
		errors.append("Reward source validation requires the canonical Item Catalog.")
		return errors
	if current_layer > 0 and not source.eligible_layers.has(current_layer):
		errors.append(
			"Reward source '%s' is not eligible on Layer %d."
			% [source.source_id, current_layer]
		)
	if source.pool == null:
		return errors
	for entry: RoomItemPoolEntryDefinition in source.pool.entries:
		if entry == null or entry.item == null:
			continue
		var catalog_item: ItemDefinition = item_catalog.get_item(entry.item.item_id)
		if catalog_item == null or catalog_item != entry.item:
			errors.append(
				"Reward source '%s' entry '%s' is not the canonical catalog resource."
				% [source.source_id, entry.entry_id]
			)
			continue
		if not entry.item.canonical_workbook_item:
			errors.append(
				"Reward source '%s' entry '%s' is not canonical executable content."
				% [source.source_id, entry.entry_id]
			)
			continue
		var destination_error: String = _validate_destination(entry)
		if not destination_error.is_empty():
			errors.append(
				"Reward source '%s' entry '%s': %s"
				% [source.source_id, entry.entry_id, destination_error]
			)
	return errors


static func resolve(
	source: RoomLootSourceDefinition,
	item_catalog: ItemCatalogDefinition,
	current_layer: int,
	run_or_generation_seed: int,
	binding_id: StringName,
	allowed_entry_ids: Array[StringName] = []
) -> Dictionary:
	var errors: Array[String] = collect_validation_errors(
		source,
		item_catalog,
		current_layer
	)
	if run_or_generation_seed <= 0:
		errors.append("Reward resolution requires a positive run/generation seed.")
	if binding_id == &"":
		errors.append("Reward resolution requires a stable binding ID.")
	if not errors.is_empty():
		var error_lines := PackedStringArray()
		for error_message: String in errors:
			error_lines.append(error_message)
		return {"error": "\n".join(error_lines), "record": {}}

	var ordered_entries: Array[RoomItemPoolEntryDefinition] = []
	for entry: RoomItemPoolEntryDefinition in source.pool.entries:
		if entry == null:
			continue
		if not allowed_entry_ids.is_empty() and not allowed_entry_ids.has(entry.entry_id):
			continue
		ordered_entries.append(entry)
	ordered_entries.sort_custom(
		func(left: RoomItemPoolEntryDefinition, right: RoomItemPoolEntryDefinition) -> bool:
			return String(left.entry_id) < String(right.entry_id)
	)
	if ordered_entries.is_empty():
		return {
			"error": "Reward source '%s' has no eligible entries for '%s'."
				% [source.source_id, binding_id],
			"record": {},
		}

	var selected: RoomItemPoolEntryDefinition = null
	var effective_weight: int = 0
	var resolution_seed: int = make_seed(
		run_or_generation_seed,
		source.source_id,
		binding_id
	)
	if source.fixed_entry_id != &"":
		for entry: RoomItemPoolEntryDefinition in ordered_entries:
			if entry.entry_id == source.fixed_entry_id:
				selected = entry
				effective_weight = get_effective_weight(entry, current_layer)
				break
		if selected == null:
			return {
				"error": "Reward source '%s' fixed entry '%s' is not eligible for '%s'."
					% [source.source_id, source.fixed_entry_id, binding_id],
				"record": {},
			}
	else:
		var total_weight: int = 0
		for entry: RoomItemPoolEntryDefinition in ordered_entries:
			total_weight += get_effective_weight(entry, current_layer)
		if total_weight <= 0:
			return {"error": "Reward source '%s' has no positive weight." % source.source_id, "record": {}}
		var rng := RandomNumberGenerator.new()
		rng.seed = resolution_seed
		var roll: int = rng.randi_range(1, total_weight)
		var running_weight: int = 0
		for entry: RoomItemPoolEntryDefinition in ordered_entries:
			running_weight += get_effective_weight(entry, current_layer)
			if roll <= running_weight:
				selected = entry
				effective_weight = get_effective_weight(entry, current_layer)
				break

	if selected == null:
		return {"error": "Reward source '%s' did not resolve an entry." % source.source_id, "record": {}}
	var record: Dictionary = {
		"source_id": String(source.source_id),
		"source_channel": int(source.source_channel),
		"binding_id": String(binding_id),
		"entry_id": String(selected.entry_id),
		"item_id": String(selected.item.item_id),
		"quantity": selected.quantity,
		"owner_heroine_id": String(selected.owner_heroine_id),
		"resolution_seed": resolution_seed,
		"base_weight": selected.weight,
		"effective_weight": effective_weight,
		"current_layer": current_layer,
		"once_only": source.once_only,
		"claimed": false,
		"deferred": false,
	}
	return {"error": "", "record": record}


static func make_seed(
	run_or_generation_seed: int,
	source_id: StringName,
	binding_id: StringName
) -> int:
	return StableSeedMixer.make_seed(
		run_or_generation_seed,
		SEED_NAMESPACE,
		StringName("%s:%s" % [source_id, binding_id])
	)


static func make_record_key(
	source_id: StringName,
	binding_id: StringName
) -> String:
	return "%s|%s" % [source_id, binding_id]


static func get_effective_weight(
	entry: RoomItemPoolEntryDefinition,
	current_layer: int
) -> int:
	if entry == null or entry.item == null:
		return 0
	var base_weight: int = maxi(entry.weight, 0)
	return (
		base_weight * CURRENT_LAYER_WEIGHT_MULTIPLIER
		if entry.item.layer == current_layer
		else base_weight
	)


static func validate_resolution_record(
	record: Dictionary,
	source_catalog: RewardSourceCatalogDefinition,
	item_catalog: ItemCatalogDefinition,
	expected_key: String = ""
) -> String:
	var source_id := StringName(record.get("source_id", ""))
	var binding_id := StringName(record.get("binding_id", ""))
	if source_id == &"" or binding_id == &"":
		return "Reward resolution record requires source_id and binding_id."
	if expected_key != "" and expected_key != make_record_key(source_id, binding_id):
		return "Reward resolution record key does not match its source binding."
	var source: RoomLootSourceDefinition = (
		source_catalog.get_source(source_id) if source_catalog != null else null
	)
	if source == null:
		return "Reward resolution references unknown source '%s'." % source_id
	if int(record.get("source_channel", -1)) != int(source.source_channel):
		return "Reward resolution '%s' has an invalid source channel." % expected_key
	var entry_id := StringName(record.get("entry_id", ""))
	var item_id := StringName(record.get("item_id", ""))
	var entry: RoomItemPoolEntryDefinition = (
		source.pool.get_entry(entry_id) if source.pool != null else null
	)
	if entry == null or entry.item == null or entry.item.item_id != item_id:
		return "Reward resolution '%s' does not match its authored entry." % expected_key
	if source.fixed_entry_id != &"" and entry_id != source.fixed_entry_id:
		return "Reward resolution '%s' does not match its fixed entry." % expected_key
	if item_catalog == null or item_catalog.get_item(item_id) != entry.item:
		return "Reward resolution '%s' does not use a canonical catalog item." % expected_key
	if int(record.get("quantity", 0)) != entry.quantity:
		return "Reward resolution '%s' has an invalid quantity." % expected_key
	if StringName(record.get("owner_heroine_id", "")) != entry.owner_heroine_id:
		return "Reward resolution '%s' has invalid ownership." % expected_key
	if typeof(record.get("claimed", null)) != TYPE_BOOL or typeof(record.get("deferred", null)) != TYPE_BOOL:
		return "Reward resolution '%s' has invalid claim state." % expected_key
	if bool(record.get("claimed")) and bool(record.get("deferred")):
		return "Reward resolution '%s' cannot be claimed and deferred." % expected_key
	if int(record.get("resolution_seed", 0)) <= 0:
		return "Reward resolution '%s' has an invalid seed." % expected_key
	var current_layer: int = int(record.get("current_layer", 0))
	if not source.eligible_layers.has(current_layer):
		return "Reward resolution '%s' has an invalid current layer." % expected_key
	if (
		int(record.get("base_weight", 0)) != entry.weight
		or int(record.get("effective_weight", 0))
		!= get_effective_weight(entry, current_layer)
	):
		return "Reward resolution '%s' has invalid authored weighting." % expected_key
	if typeof(record.get("once_only", null)) != TYPE_BOOL or bool(
		record.get("once_only")
	) != source.once_only:
		return "Reward resolution '%s' has invalid once-only policy." % expected_key
	return ""


static func _validate_destination(entry: RoomItemPoolEntryDefinition) -> String:
	var item: ItemDefinition = entry.item
	if (
		entry.owner_heroine_id != &""
		and not EXECUTABLE_HEROINE_IDS.has(entry.owner_heroine_id)
	):
		return "authored owner '%s' is not an executable heroine." % entry.owner_heroine_id
	match item.content_category:
		ItemDefinition.ContentCategory.ACTIVE:
			if not item.combat_usable and entry.owner_heroine_id == &"":
				return "exploration-only Active rewards require an authored heroine owner."
			return ""
		ItemDefinition.ContentCategory.KEY:
			if item.item_type != ItemDefinition.ItemType.KEY:
				return "Key rewards require executable Key item metadata."
			return ""
		ItemDefinition.ContentCategory.MATERIAL:
			if not (item is MaterialDefinition):
				return "Material rewards require an executable Material definition."
			return ""
		ItemDefinition.ContentCategory.MEMENTO:
			if entry.quantity != 1 or entry.owner_heroine_id == &"":
				return "Memento rewards require quantity one and an authored heroine owner."
			return ""
	return "the item category has no executable Run Inventory destination."
