extends SceneTree


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)
const TEST_DIRECTORY: String = "user://abyssal_bloom_save_slot_tests"

var failures: int = 0


func _init() -> void:
	CampaignSaveSlotStore.set_test_save_directory(TEST_DIRECTORY)
	_cleanup()
	_test_v3_new_save_envelope_and_round_trip()
	_test_empty_refuge_snapshot_compatibility()
	_test_atomic_backup_recovery()
	_test_pre_v3_is_incompatible_and_preserved()
	_test_malformed_v3_is_transactional()
	_test_legacy_item_id_restore_migration()
	_test_slot_validation_and_deletion()
	_cleanup()
	CampaignSaveSlotStore.clear_test_save_directory()
	if failures == 0:
		print("Production campaign save-slot tests passed.")
	else:
		push_error("%d production save-slot test(s) failed." % failures)
	quit(failures)


func _test_v3_new_save_envelope_and_round_trip() -> void:
	var generator := LayerMapGenerator.new()
	var source: RunState = _make_established_refuge_run(generator)
	var refuge_initialize_error: String = source.ensure_refuge_ownership_initialized()
	var refuge_setup_error: String = source.refuge_ownership.set_selected_party_order(
		[&"mira", &"lysandra", &"seraphine"]
	)
	if refuge_setup_error.is_empty():
		refuge_setup_error = source.refuge_ownership.add_preparation_item(
			&"lysandra",
			&"l01_bandage_roll",
			2
		)
	if refuge_setup_error.is_empty():
		refuge_setup_error = source.refuge_ownership.add_stash_item(
			&"l01_smelling_salts",
			3
		)
	if refuge_setup_error.is_empty():
		refuge_setup_error = source.refuge_ownership.assign_memento(
			&"mira",
			&"l01_hollow_livery_pin"
		)
	_set_refuge_main_hand_condition(source.refuge_ownership, &"lysandra", 2)
	source.narrative_state.campaign_item_ids = [&"l01_torn_cuff"]
	if refuge_setup_error.is_empty():
		refuge_setup_error = _prepare_refuge_recipe_persistence(
			source.refuge_ownership
		)
	var prepared_item_bar_before_save: Array[Dictionary] = (
		source.refuge_ownership.prepared_item_bar_slots.duplicate(true)
	)
	var knowledge := KnowledgeState.new()
	knowledge.discovered_entries = {"butlers_records": true}
	var save_error: String = CampaignSaveSlotStore.save_refuge_slot(
		1,
		source,
		knowledge
	)
	var raw_envelope: Dictionary = _read_json_dictionary(
		CampaignSaveSlotStore.get_slot_path(1)
	)
	var envelope_keys: Array[String] = []
	for key: Variant in raw_envelope.keys():
		envelope_keys.append(String(key))
	envelope_keys.sort()
	var expected_envelope_keys: Array[String] = [
		"active_run_snapshot",
		"campaign_snapshot",
		"metadata",
		"refuge_snapshot",
		"save_version",
		"slot_id",
	]
	var metadata: Dictionary = raw_envelope.get("metadata", {}) as Dictionary
	var campaign_snapshot: Dictionary = raw_envelope.get(
		"campaign_snapshot",
		{}
	) as Dictionary
	var refuge_snapshot: Dictionary = raw_envelope.get(
		"refuge_snapshot",
		{}
	) as Dictionary
	var heroine_records: Dictionary = refuge_snapshot.get(
		"heroine_records",
		{}
	) as Dictionary
	_expect(
		save_error.is_empty()
		and envelope_keys == expected_envelope_keys
		and int(raw_envelope.get("save_version", 0)) == 3
		and int(raw_envelope.get("slot_id", 0)) == 1
		and int(metadata.get("campaign_seed", 0)) == 27072026
		and int(metadata.get("created_at_utc", 0)) > 0
		and int(metadata.get("updated_at_utc", 0))
		>= int(metadata.get("created_at_utc", 0))
		and refuge_initialize_error.is_empty()
		and refuge_setup_error.is_empty()
		and not refuge_snapshot.is_empty()
		and (refuge_snapshot.get("selected_party_ids", []) as Array) == [
			"mira",
			"lysandra",
			"seraphine",
		]
		and heroine_records.size() == 3
		and _item_bar_matches(
			refuge_snapshot.get(
			"prepared_item_bar_slots",
			[]
			) as Array,
			prepared_item_bar_before_save
		)
		and raw_envelope.has("active_run_snapshot")
		and raw_envelope.get("active_run_snapshot") == null
		and int((refuge_snapshot.get(
			"banked_materials",
			{}
		) as Dictionary).get("mat_l01_servant_cloth", 0)) == 1
		and int(campaign_snapshot.get("bloom", 0)) == 41,
		"A new production save must persist the exact Save Envelope v3 shape. %s"
		% save_error
	)

	var summary: Dictionary = CampaignSaveSlotStore.get_slot_summary(1)
	_expect(
		bool(summary.get("loadable", false))
		and String(summary.get("status", "")) == "ready"
		and int(summary.get("save_version", 0)) == 3
		and int(summary.get("campaign_seed", 0)) == 27072026
		and int(summary.get("bloom", 0)) == 41,
		"Slot discovery must summarize a valid v3 campaign without gameplay UI."
	)

	var read_result: Dictionary = CampaignSaveSlotStore.read_document_for_load(1)
	var envelope: Dictionary = read_result.get("document", {}) as Dictionary
	var restored := RunState.new()
	var restored_knowledge := KnowledgeState.new()
	var restore_error: String = CampaignSaveSlotStore.restore_envelope(
		envelope,
		1,
		restored,
		restored_knowledge,
		generator.generate_bloom_refuge_holding_state(27072026),
		BATTLER_CATALOG
	)
	_expect(
		restore_error.is_empty()
		and restored.bloom == 41
		and restored.has_established_refuge()
		and restored_knowledge.has_entry(&"butlers_records")
		and restored.narrative_state.campaign_item_ids == [&"l01_torn_cuff"]
		and restored.refuge_ownership.selected_party_ids == [
			&"mira",
			&"lysandra",
			&"seraphine",
		]
		and _get_refuge_preparation_quantity(
			restored.refuge_ownership,
			&"lysandra",
			&"l01_bandage_roll"
		) == 2
		and _get_stash_quantity(
			restored.refuge_ownership,
			&"l01_smelling_salts"
		) == 3
		and restored.refuge_ownership.memento_slots_by_heroine.get(
			&"mira",
			null
		) == &"l01_hollow_livery_pin"
		and _get_refuge_main_hand_condition(
			restored.refuge_ownership,
			&"lysandra"
		) == 2
		and _get_refuge_armor_condition(
			restored.refuge_ownership,
			&"seraphine"
		) == 1
		and restored.refuge_ownership.get_banked_material_quantity(
			&"mat_l01_servant_cloth"
		) == 1
		and _item_bar_matches(
			restored.refuge_ownership.prepared_item_bar_slots,
			prepared_item_bar_before_save
		),
		(
			"A production slot must restore through the existing transactional campaign serializer. "
			+ "error=%s bloom=%d refuge=%s prep=%d stash=%d memento=%s condition=%d"
		) % [
			restore_error,
			restored.bloom,
			restored.refuge_ownership != null,
			_get_refuge_preparation_quantity(
				restored.refuge_ownership,
				&"lysandra",
				&"l01_bandage_roll"
			) if restored.refuge_ownership != null else -1,
			_get_stash_quantity(
				restored.refuge_ownership,
				&"l01_smelling_salts"
			) if restored.refuge_ownership != null else -1,
			String(restored.refuge_ownership.memento_slots_by_heroine.get(
				&"mira",
				""
			)) if restored.refuge_ownership != null else "missing",
			_get_refuge_main_hand_condition(
				restored.refuge_ownership,
				&"lysandra"
			) if restored.refuge_ownership != null else -1,
		]
	)
	var reordered_start_error: String = restored.begin_next_layer_2_run(
		generator.generate_layer_2_run(27072028)
	)
	var started_party_order: Array[StringName] = []
	for heroine_key: Variant in restored.party_snapshot.keys():
		started_party_order.append(StringName(heroine_key))
	_expect(
		reordered_start_error.is_empty()
		and _item_bar_matches(
			restored.run_inventory.get_item_bar_snapshot(),
			prepared_item_bar_before_save
		)
		and started_party_order.size() == 3
		and started_party_order[0] == &"mira"
		and started_party_order[1] == &"lysandra"
		and started_party_order[2] == &"seraphine",
		"The persisted selected-party order must become the next run's active order without changing composition."
	)

	var external_snapshot: Dictionary = CampaignSaveStore.make_campaign_snapshot(
		source,
		knowledge
	)
	var duplicated_envelope: Dictionary = CampaignSaveSlotStore.make_v3_envelope(
		1,
		external_snapshot,
		27072026,
		100,
		101,
		refuge_snapshot
	)
	external_snapshot["bloom"] = 999
	(refuge_snapshot.get("selected_party_ids", []) as Array)[0] = "mutated"
	_expect(
		int((duplicated_envelope.get(
			"campaign_snapshot",
			{}
		) as Dictionary).get("bloom", 0)) == 41
		and ((duplicated_envelope.get(
			"refuge_snapshot",
			{}
		) as Dictionary).get("selected_party_ids", []) as Array)[0] == "mira",
		"The v3 envelope must deep-duplicate externally supplied campaign and Refuge snapshots."
	)


func _test_empty_refuge_snapshot_compatibility() -> void:
	var generator := LayerMapGenerator.new()
	var source: RunState = _make_established_refuge_run(generator)
	var knowledge := KnowledgeState.new()
	var envelope: Dictionary = CampaignSaveSlotStore.make_v3_envelope(
		3,
		CampaignSaveStore.make_campaign_snapshot(source, knowledge),
		27072026,
		100,
		101
	)
	var target := RunState.new()
	var target_knowledge := KnowledgeState.new()
	var restore_error: String = CampaignSaveSlotStore.restore_envelope(
		envelope,
		3,
		target,
		target_knowledge,
		generator.generate_bloom_refuge_holding_state(27072026),
		BATTLER_CATALOG
	)
	_expect(
		restore_error.is_empty()
		and (envelope.get("refuge_snapshot", {}) as Dictionary).is_empty()
		and target.refuge_ownership.selected_party_ids == [
			&"lysandra",
			&"mira",
			&"seraphine",
		]
		and target.refuge_ownership.equipment_loadouts_by_heroine.size() == 3
		and target.run_equipment.loadouts_by_heroine.is_empty()
		and envelope.get("active_run_snapshot") == null,
		"Milestone 2 v3 envelopes with an empty Refuge snapshot must load into safe defaults."
	)


func _test_atomic_backup_recovery() -> void:
	var generator := LayerMapGenerator.new()
	var source: RunState = _make_established_refuge_run(generator)
	var knowledge := KnowledgeState.new()
	var first_envelope: Dictionary = _read_json_dictionary(
		CampaignSaveSlotStore.get_slot_path(1)
	)
	var first_metadata: Dictionary = first_envelope.get(
		"metadata",
		{}
	) as Dictionary

	# The second successful write rotates the first document into the recovery
	# backup. Corrupting the new primary must therefore recover Bloom 41.
	source.bloom = 77
	var second_save_error: String = CampaignSaveSlotStore.save_refuge_slot(
		1,
		source,
		knowledge
	)
	var corrupt_file: FileAccess = FileAccess.open(
		CampaignSaveSlotStore.get_slot_path(1),
		FileAccess.WRITE
	)
	if corrupt_file != null:
		corrupt_file.store_string("{broken primary")
		corrupt_file.close()
	var recovery_summary: Dictionary = (
		CampaignSaveSlotStore.get_slot_summary(1)
	)
	var recovery_read: Dictionary = (
		CampaignSaveSlotStore.read_document_for_load(1)
	)
	var recovery_document: Dictionary = (
		recovery_read.get("document", {}) as Dictionary
	)
	var recovery_snapshot: Dictionary = recovery_document.get(
		"campaign_snapshot",
		{}
	) as Dictionary
	var recovery_metadata: Dictionary = recovery_document.get(
		"metadata",
		{}
	) as Dictionary
	_expect(
		second_save_error.is_empty()
		and bool(recovery_summary.get("loadable", false))
		and bool(recovery_summary.get("used_backup", false))
		and bool(recovery_read.get("used_backup", false))
		and int(recovery_snapshot.get("bloom", 0)) == 41
		and int(recovery_metadata.get("created_at_utc", 0))
		== int(first_metadata.get("created_at_utc", -1)),
		"An unreadable primary slot must fall back to the previous verified save."
	)

	# Saving after a recovery must not rotate the known-corrupt primary over
	# the last good backup.
	source.bloom = 99
	var recovery_save_error: String = (
		CampaignSaveSlotStore.save_refuge_slot(1, source, knowledge)
	)
	corrupt_file = FileAccess.open(
		CampaignSaveSlotStore.get_slot_path(1),
		FileAccess.WRITE
	)
	if corrupt_file != null:
		corrupt_file.store_string("{broken again")
		corrupt_file.close()
	var repeated_recovery: Dictionary = (
		CampaignSaveSlotStore.read_document_for_load(1)
	)
	var repeated_document: Dictionary = (
		repeated_recovery.get("document", {}) as Dictionary
	)
	var repeated_snapshot: Dictionary = repeated_document.get(
		"campaign_snapshot",
		{}
	) as Dictionary
	_expect(
		recovery_save_error.is_empty()
		and bool(repeated_recovery.get("used_backup", false))
		and int(repeated_snapshot.get("bloom", 0)) == 41,
		"A save made after backup recovery must retain the last known-good backup."
	)


func _test_pre_v3_is_incompatible_and_preserved() -> void:
	var generator := LayerMapGenerator.new()
	var source: RunState = _make_established_refuge_run(generator)
	var knowledge := KnowledgeState.new()
	for version: int in [1, 2]:
		var slot_id: int = version + 1
		var legacy_document: Dictionary = (
			CampaignSaveStore.make_campaign_snapshot(source, knowledge)
		)
		legacy_document["format_version"] = version
		var slot_path: String = CampaignSaveSlotStore.get_slot_path(slot_id)
		_write_json_dictionary(slot_path, legacy_document)
		var before_text: String = FileAccess.get_file_as_string(slot_path)
		var summary: Dictionary = CampaignSaveSlotStore.get_slot_summary(slot_id)
		var read_result: Dictionary = (
			CampaignSaveSlotStore.read_document_for_load(slot_id)
		)
		var overwrite_error: String = CampaignSaveSlotStore.save_refuge_slot(
			slot_id,
			source,
			knowledge
		)
		_expect(
			String(summary.get("status", "")) == "incompatible"
			and not bool(summary.get("loadable", false))
			and String(summary.get("error", "")).contains("Incompatible")
			and String(read_result.get("error", "")).contains("Incompatible")
			and overwrite_error.contains("preserved")
			and FileAccess.file_exists(slot_path)
			and FileAccess.get_file_as_string(slot_path) == before_text,
			"A version-%d save must be incompatible and preserved on disk."
			% version
		)

	var standalone_legacy: Dictionary = (
		CampaignSaveStore.make_campaign_snapshot(source, knowledge)
	)
	standalone_legacy["format_version"] = 2
	_write_json_dictionary(
		CampaignSaveStore.UNSUPPORTED_LEGACY_SAVE_PATH,
		standalone_legacy
	)
	var legacy_warning: String = (
		CampaignSaveSlotStore.get_unsupported_legacy_save_warning()
	)
	_expect(
		legacy_warning.contains("incompatible")
		and FileAccess.file_exists(
			CampaignSaveStore.UNSUPPORTED_LEGACY_SAVE_PATH
		),
		"The unsupported single-file development save must be reported and preserved."
	)

	CampaignSaveSlotStore.delete_slot(2)
	CampaignSaveSlotStore.delete_slot(3)


func _test_malformed_v3_is_transactional() -> void:
	var generator := LayerMapGenerator.new()
	var source: RunState = _make_established_refuge_run(generator)
	var knowledge := KnowledgeState.new()
	var campaign_snapshot: Dictionary = CampaignSaveStore.make_campaign_snapshot(
		source,
		knowledge
	)
	var valid_envelope: Dictionary = CampaignSaveSlotStore.make_v3_envelope(
		2,
		campaign_snapshot,
		27072026,
		100,
		101
	)
	var malformed_envelope: Dictionary = valid_envelope.duplicate(true)
	(malformed_envelope["metadata"] as Dictionary)["campaign_seed"] = "invalid"
	var target: RunState = _make_established_refuge_run(generator)
	target.bloom = 222
	target.ensure_refuge_ownership_initialized()
	var target_refuge_before: Dictionary = target.refuge_ownership.to_snapshot()
	var target_knowledge := KnowledgeState.new()
	target_knowledge.discovered_entries = {"original_entry": true}
	var restore_error: String = CampaignSaveSlotStore.restore_envelope(
		malformed_envelope,
		2,
		target,
		target_knowledge,
		generator.generate_bloom_refuge_holding_state(27072026),
		BATTLER_CATALOG
	)
	_write_json_dictionary(
		CampaignSaveSlotStore.get_slot_path(2),
		malformed_envelope
	)
	var malformed_summary: Dictionary = CampaignSaveSlotStore.get_slot_summary(2)
	var populated_refuge: Dictionary = valid_envelope.duplicate(true)
	populated_refuge["refuge_snapshot"] = {"future_field": true}
	var malformed_refuge: Dictionary = valid_envelope.duplicate(true)
	var malformed_refuge_snapshot: Dictionary = source.make_refuge_ownership_snapshot()
	var malformed_records: Dictionary = malformed_refuge_snapshot.get(
		"heroine_records",
		{}
	) as Dictionary
	var malformed_lysandra: Dictionary = malformed_records.get(
		"lysandra",
		{}
	) as Dictionary
	var malformed_slots: Array = malformed_lysandra.get(
		"preparation_slots",
		[]
	) as Array
	(malformed_slots[0] as Dictionary)["quantity"] = 3
	malformed_refuge["refuge_snapshot"] = malformed_refuge_snapshot
	var malformed_refuge_error: String = CampaignSaveSlotStore.restore_envelope(
		malformed_refuge,
		2,
		target,
		target_knowledge,
		generator.generate_bloom_refuge_holding_state(27072026),
		BATTLER_CATALOG
	)
	var active_run: Dictionary = valid_envelope.duplicate(true)
	active_run["active_run_snapshot"] = {}
	var invalid_campaign: Dictionary = valid_envelope.duplicate(true)
	invalid_campaign["campaign_snapshot"] = []
	_expect(
		not restore_error.is_empty()
		and target.bloom == 222
		and target_knowledge.has_entry(&"original_entry")
		and not malformed_refuge_error.is_empty()
		and target.refuge_ownership.to_snapshot() == target_refuge_before
		and String(malformed_summary.get("status", "")) == "corrupted"
		and not CampaignSaveSlotStore.validate_envelope(
			populated_refuge,
			2
		).is_empty()
		and not CampaignSaveSlotStore.validate_envelope(
			active_run,
			2
		).is_empty()
		and not CampaignSaveSlotStore.validate_envelope(
			invalid_campaign,
			2
		).is_empty()
		and not CampaignSaveSlotStore.validate_envelope(
			valid_envelope,
			3
		).is_empty(),
		"Malformed v3 envelopes must be rejected without mutating campaign state."
	)
	CampaignSaveSlotStore.delete_slot(2)


func _test_slot_validation_and_deletion() -> void:
	_expect(
		not CampaignSaveSlotStore.is_valid_slot_id(0)
		and CampaignSaveSlotStore.is_valid_slot_id(1)
		and CampaignSaveSlotStore.is_valid_slot_id(3)
		and not CampaignSaveSlotStore.is_valid_slot_id(4),
		"Production save slots must remain within the fixed three-slot contract."
	)
	var delete_error: String = CampaignSaveSlotStore.delete_slot(1)
	var summary: Dictionary = CampaignSaveSlotStore.get_slot_summary(1)
	_expect(
		delete_error.is_empty()
		and String(summary.get("status", "")) == "empty"
		and not bool(summary.get("loadable", false)),
		"Deleting a campaign slot must remove its primary, backup, and temporary document."
	)


func _test_legacy_item_id_restore_migration() -> void:
	var generator := LayerMapGenerator.new()
	var source: RunState = _make_established_refuge_run(generator)
	var knowledge := KnowledgeState.new()
	var campaign_snapshot: Dictionary = CampaignSaveStore.make_campaign_snapshot(
		source,
		knowledge
	)
	var inventory: Array = campaign_snapshot.get("inventory_snapshot", []) as Array
	_expect(not inventory.is_empty(), "The save migration fixture needs an item.")
	if inventory.is_empty():
		return
	var first_slot: Dictionary = inventory[0] as Dictionary
	var canonical_item_id: String = String(first_slot.get("item_id", ""))
	var legacy_item_id: String = ""
	for candidate: Variant in CampaignSaveStore.LEGACY_ITEM_ID_MIGRATIONS:
		if String(
			CampaignSaveStore.LEGACY_ITEM_ID_MIGRATIONS[candidate]
		) == canonical_item_id:
			legacy_item_id = String(candidate)
			break
	_expect(
		not legacy_item_id.is_empty(),
		"The current starting item should have a retained old-save migration."
	)
	if legacy_item_id.is_empty():
		return
	first_slot["item_id"] = legacy_item_id

	var restored := RunState.new()
	var restored_knowledge := KnowledgeState.new()
	var envelope: Dictionary = CampaignSaveSlotStore.make_v3_envelope(
		3,
		campaign_snapshot,
		27072026
	)
	var restore_error: String = CampaignSaveSlotStore.restore_envelope(
		envelope,
		3,
		restored,
		restored_knowledge,
		generator.generate_bloom_refuge_holding_state(27072026),
		BATTLER_CATALOG
	)
	var restored_slot: Dictionary = restored.inventory_snapshot[0]
	_expect(
		restore_error.is_empty()
		and String(restored_slot.get("item_id", "")) == canonical_item_id,
		"A retained old-format save item ID should restore as its Stable ID."
	)

	first_slot["item_id"] = "quiet_cell_blanket"
	envelope = CampaignSaveSlotStore.make_v3_envelope(
		3,
		campaign_snapshot,
		27072026
	)
	var blanket_restored := RunState.new()
	var blanket_knowledge := KnowledgeState.new()
	var blanket_restore_error: String = CampaignSaveSlotStore.restore_envelope(
		envelope,
		3,
		blanket_restored,
		blanket_knowledge,
		generator.generate_bloom_refuge_holding_state(27072026),
		BATTLER_CATALOG
	)
	var blanket_slot: Dictionary = (
		blanket_restored.inventory_snapshot[0]
		if not blanket_restored.inventory_snapshot.is_empty()
		else {}
	)
	var blanket_id := StringName(blanket_slot.get("item_id", ""))
	var blanket_definition: ItemDefinition = ITEM_CATALOG.get_item(blanket_id)
	var blanket_start_error: String = blanket_restored.begin_next_layer_2_run(
		generator.generate_layer_2_run(27072027)
	)
	var started_blanket_id := StringName(
		blanket_restored.run_inventory.get_item_bar_snapshot()[0].get(
			"item_id",
			""
		)
	) if blanket_start_error.is_empty() else &""
	_expect(
		blanket_restore_error.is_empty()
		and blanket_start_error.is_empty()
		and blanket_id == &"quiet_cell_blanket"
		and started_blanket_id == &"quiet_cell_blanket"
		and CampaignSaveStore.RETAINED_LEGACY_ITEM_IDS.has(
			String(blanket_id)
		)
		and blanket_definition != null
		and not blanket_definition.canonical_workbook_item
		and blanket_definition.content_category
		== ItemDefinition.ContentCategory.LEGACY_DEVELOPMENT,
		(
			"An old snapshot carrying Quiet Cell Blanket must restore, resolve, and cross the Refuge run-start boundary. "
			+ "restore=%s start=%s started_id=%s"
		) % [blanket_restore_error, blanket_start_error, started_blanket_id]
	)
	_expect(
		String(first_slot.get("item_id", "")) == "quiet_cell_blanket",
		"Stable-ID migration must not mutate the supplied v3 campaign snapshot."
	)


func _make_established_refuge_run(generator: LayerMapGenerator) -> RunState:
	var party: Dictionary = {
		&"lysandra": _heroine_snapshot(10, 4, 73, 8),
		&"mira": _heroine_snapshot(9, 6, 69, 12),
		&"seraphine": _heroine_snapshot(8, 8, 81, 4),
	}
	var run := RunState.new()
	run.initialize(
		27072026,
		generator.generate_bloom_refuge_holding_state(27072026),
		[],
		party
	)
	run.opening_completed = true
	run.bloom = 41
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	run.campaign_lifecycle.restore_legacy_refuge(27072026)
	run.campaign_lifecycle.mark_boss_defeated(
		RunState.BLOOD_NUN_BOSS_ID
	)
	var save_flags: Dictionary = run.narrative_state.flags_by_scope.get(
		&"save",
		{}
	) as Dictionary
	save_flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	save_flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	return run


func _heroine_snapshot(
	hp: int,
	mp: int,
	resolve: int,
	corruption: int
) -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"resolve": resolve,
		"corruption": corruption,
		"item_guard": 0,
		"weapon_damage": 0,
		"weapon_broken": false,
		"armor_damage": 0,
		"armor_broken": false,
		"shield_damage": 0,
		"shield_broken": false,
	}


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(path)
	)
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_json_dictionary(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "The save test fixture file should open for writing.")
	if file == null:
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


func _cleanup() -> void:
	for slot_id: int in range(1, CampaignSaveSlotStore.SLOT_COUNT + 1):
		CampaignSaveSlotStore.delete_slot(slot_id)
	var absolute_directory: String = ProjectSettings.globalize_path(
		TEST_DIRECTORY
	)
	if DirAccess.dir_exists_absolute(absolute_directory):
		DirAccess.remove_absolute(absolute_directory)
	if FileAccess.file_exists(CampaignSaveStore.UNSUPPORTED_LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			CampaignSaveStore.UNSUPPORTED_LEGACY_SAVE_PATH
		))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _item_bar_matches(left: Array, right: Array) -> bool:
	if left.size() != 6 or right.size() != 6:
		return false
	for index: int in range(6):
		var left_slot: Dictionary = left[index] as Dictionary
		var right_slot: Dictionary = right[index] as Dictionary
		if (
			int(left_slot.get("slot_index", -1)) != index
			or int(right_slot.get("slot_index", -1)) != index
			or String(left_slot.get("item_id", ""))
			!= String(right_slot.get("item_id", ""))
			or int(left_slot.get("quantity", -1))
			!= int(right_slot.get("quantity", -1))
		):
			return false
	return true


func _set_refuge_main_hand_condition(
	refuge: RefugeOwnershipState,
	heroine_id: StringName,
	condition: int
) -> void:
	var loadout: Dictionary = refuge.equipment_loadouts_by_heroine.get(
		heroine_id,
		{}
	) as Dictionary
	var slots: Dictionary = loadout.get("slots", {}) as Dictionary
	var instance_id: String = String(slots.get("main_hand", ""))
	var instances: Dictionary = loadout.get("instances", {}) as Dictionary
	if instances.get(instance_id, null) is Dictionary:
		(instances[instance_id] as Dictionary)["current_condition"] = condition


func _prepare_refuge_recipe_persistence(
	refuge: RefugeOwnershipState
) -> String:
	var snapshot: Dictionary = refuge.to_snapshot()
	snapshot["banked_materials"] = {"mat_l01_servant_cloth": 2}
	var records: Dictionary = snapshot.get("heroine_records", {}) as Dictionary
	var heroine: Dictionary = records.get("seraphine", {}) as Dictionary
	var loadout: Dictionary = heroine.get("equipment_loadout", {}) as Dictionary
	var slots: Dictionary = loadout.get("slots", {}) as Dictionary
	var instance_id: String = String(slots.get("armor", ""))
	var instances: Dictionary = loadout.get("instances", {}) as Dictionary
	var instance: Dictionary = instances.get(instance_id, {}) as Dictionary
	if instance.is_empty():
		return "Could not find Seraphine's Armor for recipe persistence."
	instance["current_condition"] = 0
	var restore_error: String = refuge.restore_from_snapshot(
		snapshot,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		[&"lysandra", &"mira", &"seraphine"]
	)
	if not restore_error.is_empty():
		return restore_error
	var result: Dictionary = refuge.execute_refuge_recipe(
		&"refuge_repair_cloth_armor",
		StringName(instance_id)
	)
	return String(result.get("error", ""))


func _get_refuge_main_hand_condition(
	refuge: RefugeOwnershipState,
	heroine_id: StringName
) -> int:
	var loadout: Dictionary = refuge.equipment_loadouts_by_heroine.get(
		heroine_id,
		{}
	) as Dictionary
	var slots: Dictionary = loadout.get("slots", {}) as Dictionary
	var instance_id: String = String(slots.get("main_hand", ""))
	var instances: Dictionary = loadout.get("instances", {}) as Dictionary
	return int((instances.get(instance_id, {}) as Dictionary).get(
		"current_condition",
		-1
	))


func _get_refuge_armor_condition(
	refuge: RefugeOwnershipState,
	heroine_id: StringName
) -> int:
	var loadout: Dictionary = refuge.equipment_loadouts_by_heroine.get(
		heroine_id,
		{}
	) as Dictionary
	var slots: Dictionary = loadout.get("slots", {}) as Dictionary
	var instance_id: String = String(slots.get("armor", ""))
	var instances: Dictionary = loadout.get("instances", {}) as Dictionary
	return int((instances.get(instance_id, {}) as Dictionary).get(
		"current_condition",
		-1
	))


func _get_refuge_preparation_quantity(
	refuge: RefugeOwnershipState,
	heroine_id: StringName,
	item_id: StringName
) -> int:
	var slots: Array = refuge.preparation_slots_by_heroine.get(heroine_id, []) as Array
	var total: int = 0
	for slot_value: Variant in slots:
		var slot: Dictionary = slot_value as Dictionary
		if StringName(slot.get("item_id", "")) == item_id:
			total += int(slot.get("quantity", 0))
	return total


func _get_stash_quantity(
	refuge: RefugeOwnershipState,
	item_id: StringName
) -> int:
	var total: int = 0
	for slot: Dictionary in refuge.stash_item_stacks:
		if StringName(slot.get("item_id", "")) == item_id:
			total += int(slot.get("quantity", 0))
	return total
