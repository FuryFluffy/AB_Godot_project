class_name CampaignSaveSlotStore
extends RefCounted


const SLOT_COUNT: int = 3
const SAVE_DIRECTORY: String = "user://saves"
const SLOT_FILE_PREFIX: String = "abyssal_bloom_slot_"
const INCOMPATIBLE_VERSION_ERROR: String = (
	"Incompatible campaign save version. Only Save Envelope v3 is supported."
)
const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const DEMO_HEROINE_IDS: Array[StringName] = [
	&"lysandra",
	&"mira",
	&"seraphine",
]

static var save_directory_override: String = ""
static var force_test_write_failure: bool = false


static func get_save_directory() -> String:
	if not save_directory_override.is_empty():
		return save_directory_override
	return SAVE_DIRECTORY


static func set_test_save_directory(directory: String) -> void:
	save_directory_override = directory.strip_edges()


static func clear_test_save_directory() -> void:
	save_directory_override = ""


static func is_valid_slot_id(slot_id: int) -> bool:
	return slot_id >= 1 and slot_id <= SLOT_COUNT


static func get_slot_path(slot_id: int) -> String:
	return "%s/%s%d.json" % [
		get_save_directory(),
		SLOT_FILE_PREFIX,
		slot_id,
	]


static func get_backup_path(slot_id: int) -> String:
	return "%s.bak" % get_slot_path(slot_id)


static func get_temporary_path(slot_id: int) -> String:
	return "%s.tmp" % get_slot_path(slot_id)


static func get_previous_backup_path(slot_id: int) -> String:
	return "%s.previous" % get_backup_path(slot_id)


static func save_refuge_slot(
	slot_id: int,
	run_state: RunState,
	knowledge_state: KnowledgeState,
	discard_unspent_bloom: bool = false
) -> String:
	if not is_valid_slot_id(slot_id):
		return "Campaign save slot must be between 1 and %d." % SLOT_COUNT
	var incompatible_path: String = _find_incompatible_slot_file(slot_id)
	if not incompatible_path.is_empty():
		return (
			"An incompatible pre-v3 save was preserved at %s. "
			+ "Delete that slot explicitly before saving a new campaign."
		) % incompatible_path
	var campaign_snapshot: Dictionary = CampaignSaveStore.make_campaign_snapshot(
		run_state,
		knowledge_state,
		discard_unspent_bloom
	)
	if campaign_snapshot.is_empty():
		return "Campaigns can only be saved from the established Bloom Refuge."
	var campaign_seed: int = maxi(
		run_state.campaign_lifecycle.campaign_seed,
		1
	)
	var now_utc: int = int(Time.get_unix_time_from_system())
	var created_at_utc: int = _get_existing_created_at_utc(
		slot_id,
		now_utc
	)
	var refuge_snapshot: Dictionary = run_state.make_refuge_ownership_snapshot()
	if refuge_snapshot.is_empty():
		return "The Bloom Refuge ownership state could not be serialized."
	var envelope: Dictionary = make_v3_envelope(
		slot_id,
		campaign_snapshot,
		campaign_seed,
		created_at_utc,
		maxi(now_utc, created_at_utc),
		refuge_snapshot
	)
	return _write_document_atomic(slot_id, envelope)


static func make_v3_envelope(
	slot_id: int,
	campaign_snapshot: Dictionary,
	campaign_seed: int,
	created_at_utc: int = 0,
	updated_at_utc: int = 0,
	refuge_snapshot: Dictionary = {},
	active_run_snapshot: Variant = null
) -> Dictionary:
	if not is_valid_slot_id(slot_id) or campaign_seed <= 0:
		return {}
	var now_utc: int = int(Time.get_unix_time_from_system())
	var created_timestamp: int = (
		created_at_utc if created_at_utc > 0 else now_utc
	)
	var updated_timestamp: int = (
		updated_at_utc if updated_at_utc > 0 else now_utc
	)
	return {
		"save_version": CampaignSaveStore.SAVE_VERSION,
		"slot_id": slot_id,
		"metadata": {
			"campaign_seed": campaign_seed,
			"created_at_utc": created_timestamp,
			"updated_at_utc": maxi(
				updated_timestamp,
				created_timestamp
			),
		},
		"campaign_snapshot": campaign_snapshot.duplicate(true),
		"refuge_snapshot": refuge_snapshot.duplicate(true),
		"active_run_snapshot": (
			(active_run_snapshot as Dictionary).duplicate(true)
			if active_run_snapshot is Dictionary
			else null
		),
	}


static func save_active_run_slot(
	slot_id: int,
	run_state: RunState,
	knowledge_state: KnowledgeState,
	safe_point_kind: String
) -> String:
	if not is_valid_slot_id(slot_id):
		return "Campaign save slot must be between 1 and %d." % SLOT_COUNT
	var active_snapshot: Dictionary = run_state.make_active_run_snapshot(
		safe_point_kind,
		knowledge_state
	)
	if active_snapshot.is_empty():
		return "The active run is not at a valid %s safe point." % safe_point_kind
	var incompatible_path: String = _find_incompatible_slot_file(slot_id)
	if not incompatible_path.is_empty():
		return "An incompatible pre-v3 save was preserved at %s." % incompatible_path
	var existing_result: Dictionary = read_document_for_load(slot_id)
	var existing_value: Variant = existing_result.get("document", {})
	var campaign_snapshot: Dictionary = {}
	var refuge_snapshot: Dictionary = {}
	var created_at_utc: int = int(Time.get_unix_time_from_system())
	var previous_updated: int = 0
	if existing_value is Dictionary and not (existing_value as Dictionary).is_empty():
		var existing: Dictionary = existing_value as Dictionary
		campaign_snapshot = (existing.get("campaign_snapshot") as Dictionary).duplicate(true)
		refuge_snapshot = (existing.get("refuge_snapshot") as Dictionary).duplicate(true)
		var metadata: Dictionary = existing.get("metadata") as Dictionary
		created_at_utc = int(metadata.get("created_at_utc", created_at_utc))
		previous_updated = int(metadata.get("updated_at_utc", 0))
	else:
		campaign_snapshot = CampaignSaveStore.make_active_campaign_anchor_snapshot(
			run_state,
			knowledge_state
		)
	if campaign_snapshot.is_empty():
		return "The campaign boundary for the active run could not be serialized."
	var now_utc: int = int(Time.get_unix_time_from_system())
	var envelope: Dictionary = make_v3_envelope(
		slot_id,
		campaign_snapshot,
		run_state.campaign_lifecycle.campaign_seed,
		created_at_utc,
		maxi(now_utc, previous_updated + 1),
		refuge_snapshot,
		active_snapshot
	)
	return _write_document_atomic(slot_id, envelope)


static func clear_active_run_snapshot(slot_id: int) -> String:
	var read_result: Dictionary = read_document_for_load(slot_id)
	var read_error: String = String(read_result.get("error", ""))
	if not read_error.is_empty():
		return read_error
	var document_value: Variant = read_result.get("document", {})
	if not (document_value is Dictionary):
		return "Campaign save did not contain a valid v3 envelope."
	var document: Dictionary = (document_value as Dictionary).duplicate(true)
	if document.get("active_run_snapshot", null) == null:
		return ""
	document["active_run_snapshot"] = null
	var metadata: Dictionary = document.get("metadata", {}) as Dictionary
	metadata["updated_at_utc"] = maxi(
		int(Time.get_unix_time_from_system()),
		int(metadata.get("updated_at_utc", 0)) + 1
	)
	return _write_document_atomic(slot_id, document)


static func validate_envelope(
	envelope: Dictionary,
	expected_slot_id: int = 0
) -> String:
	return _validate_document_shape(
		envelope.duplicate(true),
		expected_slot_id
	)


static func list_slots() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_id: int in range(1, SLOT_COUNT + 1):
		summaries.append(get_slot_summary(slot_id))
	return summaries


static func get_slot_summary(slot_id: int) -> Dictionary:
	var empty_summary: Dictionary = _empty_summary(slot_id)
	if not is_valid_slot_id(slot_id):
		empty_summary["status"] = "invalid"
		empty_summary["error"] = "Invalid campaign slot."
		return empty_summary

	var primary_result: Dictionary = _read_document_file(
		get_slot_path(slot_id)
	)
	var primary_validation_error: String = ""
	var primary_status: String = "corrupted"
	if bool(primary_result.get("exists", false)):
		var primary_document: Variant = primary_result.get("document", {})
		if primary_document is Dictionary:
			primary_validation_error = _validate_document_shape(
				primary_document as Dictionary,
				slot_id
			)
			primary_status = _status_for_validation_error(
				primary_validation_error
			)
			if primary_validation_error.is_empty():
				return _summarize_document(
					slot_id,
					primary_document as Dictionary,
					false
				)

	var backup_result: Dictionary = _read_document_file(
		get_backup_path(slot_id)
	)
	if bool(backup_result.get("exists", false)):
		var backup_document: Variant = backup_result.get("document", {})
		if backup_document is Dictionary:
			var backup_error: String = _validate_document_shape(
				backup_document as Dictionary,
				slot_id
			)
			if backup_error.is_empty():
				var summary: Dictionary = _summarize_document(
					slot_id,
					backup_document as Dictionary,
					true
				)
				summary["status"] = "backup_available"
				summary["error"] = (
					"The primary save is unreadable. A previous safe backup is available."
				)
				return summary

	if bool(primary_result.get("exists", false)):
		empty_summary["status"] = primary_status
		empty_summary["error"] = (
			primary_validation_error
			if not primary_validation_error.is_empty()
			else String(primary_result.get(
				"error",
				"Campaign save is unreadable."
			))
		)
	elif bool(backup_result.get("exists", false)):
		var backup_document: Variant = backup_result.get("document", {})
		var backup_validation_error: String = String(
			backup_result.get("error", "Campaign backup is unreadable.")
		)
		if backup_document is Dictionary:
			backup_validation_error = _validate_document_shape(
				backup_document as Dictionary,
				slot_id
			)
		empty_summary["status"] = _status_for_validation_error(
			backup_validation_error
		)
		empty_summary["error"] = backup_validation_error
	return empty_summary


static func has_loadable_slot(slot_id: int) -> bool:
	return bool(get_slot_summary(slot_id).get("loadable", false))


static func get_latest_loadable_slot_id() -> int:
	var latest_slot_id: int = 0
	var latest_saved_at: int = -1
	for summary: Dictionary in list_slots():
		if not bool(summary.get("loadable", false)):
			continue
		var saved_at: int = int(summary.get("saved_at_unix", 0))
		if saved_at > latest_saved_at:
			latest_saved_at = saved_at
			latest_slot_id = int(summary.get("slot_id", 0))
	return latest_slot_id


static func get_latest_resumable_slot_id() -> int:
	var latest_slot_id: int = 0
	var latest_saved_at: int = -1
	for summary: Dictionary in list_slots():
		if not bool(summary.get("resumable", false)):
			continue
		var saved_at: int = int(summary.get("saved_at_unix", 0))
		if saved_at > latest_saved_at:
			latest_saved_at = saved_at
			latest_slot_id = int(summary.get("slot_id", 0))
	return latest_slot_id


static func read_document_for_load(slot_id: int) -> Dictionary:
	if not is_valid_slot_id(slot_id):
		return {
			"error": "Invalid campaign save slot.",
			"document": {},
			"used_backup": false,
		}
	var primary: Dictionary = _read_document_file(get_slot_path(slot_id))
	var primary_document: Variant = primary.get("document", {})
	var primary_failure: String = String(
		primary.get("error", "Campaign save is unreadable.")
	)
	if primary_document is Dictionary:
		var primary_error: String = _validate_document_shape(
			primary_document as Dictionary,
			slot_id
		)
		if primary_error.is_empty():
			return {
				"error": "",
				"document": (primary_document as Dictionary).duplicate(true),
				"used_backup": false,
			}
		primary_failure = primary_error

	var backup: Dictionary = _read_document_file(get_backup_path(slot_id))
	var backup_document: Variant = backup.get("document", {})
	var backup_failure: String = String(
		backup.get("error", "Campaign backup is unreadable.")
	)
	if backup_document is Dictionary:
		var backup_error: String = _validate_document_shape(
			backup_document as Dictionary,
			slot_id
		)
		if backup_error.is_empty():
			return {
				"error": "",
				"document": (backup_document as Dictionary).duplicate(true),
				"used_backup": true,
			}
		backup_failure = backup_error
	if not bool(primary.get("exists", false)):
		primary_failure = backup_failure

	return {
		"error": primary_failure,
		"document": {},
		"used_backup": false,
	}


static func restore_envelope(
	envelope: Dictionary,
	expected_slot_id: int,
	run_state: RunState,
	knowledge_state: KnowledgeState,
	refuge_graph: LayerMapGraph,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	var staged_envelope: Dictionary = envelope.duplicate(true)
	var validation_error: String = _validate_document_shape(
		staged_envelope,
		expected_slot_id
	)
	if not validation_error.is_empty():
		return validation_error
	var campaign_snapshot_value: Variant = staged_envelope.get(
		"campaign_snapshot",
		{}
	)
	if not (campaign_snapshot_value is Dictionary):
		return "Save Envelope v3 contains an invalid campaign_snapshot."
	var refuge_snapshot_value: Variant = staged_envelope.get(
		"refuge_snapshot",
		{}
	)
	if not (refuge_snapshot_value is Dictionary):
		return "Save Envelope v3 contains an invalid refuge_snapshot."
	var migrated_campaign_snapshot: Dictionary = (
		CampaignSaveStore.migrate_legacy_item_ids(
			(campaign_snapshot_value as Dictionary).duplicate(true)
		)
	)
	var legacy_item_bar_value: Variant = migrated_campaign_snapshot.get(
		"inventory_snapshot",
		[]
	)
	var legacy_item_bar: Array = (
		(legacy_item_bar_value as Array).duplicate(true)
		if legacy_item_bar_value is Array
		else []
	)
	var staged_refuge := RefugeOwnershipState.new()
	var refuge_error: String = ""
	if (refuge_snapshot_value as Dictionary).is_empty():
		var party_snapshot: Dictionary = (
			(campaign_snapshot_value as Dictionary).get(
				"party_snapshot",
				{}
			) as Dictionary
		)
		refuge_error = staged_refuge.initialize_default(
			ITEM_CATALOG,
			battler_catalog,
			DEMO_HEROINE_IDS,
			party_snapshot,
			legacy_item_bar
		)
	else:
		refuge_error = staged_refuge.restore_from_snapshot(
			(refuge_snapshot_value as Dictionary).duplicate(true),
			ITEM_CATALOG,
			battler_catalog,
			DEMO_HEROINE_IDS,
			legacy_item_bar
		)
	if not refuge_error.is_empty():
		return refuge_error
	var campaign_error: String = CampaignSaveStore.restore_campaign_snapshot(
		migrated_campaign_snapshot,
		run_state,
		knowledge_state,
		refuge_graph,
		battler_catalog
	)
	if not campaign_error.is_empty():
		return campaign_error
	return run_state.apply_restored_refuge_ownership(
		staged_refuge,
		battler_catalog
	)


static func delete_slot(slot_id: int) -> String:
	if not is_valid_slot_id(slot_id):
		return "Invalid campaign save slot."
	for path: String in [
		get_slot_path(slot_id),
		get_backup_path(slot_id),
		get_temporary_path(slot_id),
		get_previous_backup_path(slot_id),
	]:
		if not FileAccess.file_exists(path):
			continue
		var remove_error: Error = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(path)
		)
		if remove_error != OK:
			return "Could not remove campaign slot %d." % slot_id
	return ""


static func get_unsupported_legacy_save_warning() -> String:
	if not FileAccess.file_exists(
		CampaignSaveStore.UNSUPPORTED_LEGACY_SAVE_PATH
	):
		return ""
	return (
		"A pre-v3 development save is incompatible with Save Envelope v3. "
		+ "The original file was preserved and was not imported."
	)


static func _write_document_atomic(
	slot_id: int,
	document: Dictionary
) -> String:
	if force_test_write_failure:
		return "Campaign save write failed for the active test boundary."
	var staged_document: Dictionary = document.duplicate(true)
	var staged_validation_error: String = _validate_document_shape(
		staged_document,
		slot_id
	)
	if not staged_validation_error.is_empty():
		return staged_validation_error
	var directory_error: String = _ensure_save_directory()
	if not directory_error.is_empty():
		return directory_error
	var temporary_path: String = get_temporary_path(slot_id)
	var primary_path: String = get_slot_path(slot_id)
	var backup_path: String = get_backup_path(slot_id)
	var previous_backup_path: String = get_previous_backup_path(slot_id)
	_remove_if_present(temporary_path)
	_remove_if_present(previous_backup_path)

	var temporary_file: FileAccess = FileAccess.open(
		temporary_path,
		FileAccess.WRITE
	)
	if temporary_file == null:
		return "Could not open the temporary campaign save for writing."
	temporary_file.store_string(JSON.stringify(staged_document, "\t"))
	temporary_file.flush()
	temporary_file.close()

	var verification: Dictionary = _read_document_file(temporary_path)
	var verified_document: Variant = verification.get("document", {})
	if not (verified_document is Dictionary):
		_remove_if_present(temporary_path)
		return "The temporary campaign save could not be verified."
	var validation_error: String = _validate_document_shape(
		verified_document as Dictionary,
		slot_id
	)
	if not validation_error.is_empty():
		_remove_if_present(temporary_path)
		return validation_error

	var primary_absolute: String = ProjectSettings.globalize_path(primary_path)
	var backup_absolute: String = ProjectSettings.globalize_path(backup_path)
	var previous_backup_absolute: String = ProjectSettings.globalize_path(
		previous_backup_path
	)
	var temporary_absolute: String = ProjectSettings.globalize_path(
		temporary_path
	)
	var primary_was_valid: bool = _is_valid_document_file(
		primary_path,
		slot_id
	)
	if FileAccess.file_exists(primary_path) and not primary_was_valid:
		# Never rotate a known-corrupt primary over the last verified recovery
		# backup. The verified temporary document is already ready to commit.
		_remove_if_present(primary_path)
	if primary_was_valid:
		if FileAccess.file_exists(backup_path):
			var preserve_backup_error: Error = DirAccess.rename_absolute(
				backup_absolute,
				previous_backup_absolute
			)
			if preserve_backup_error != OK:
				_remove_if_present(temporary_path)
				return "Could not preserve the existing recovery backup."
		var backup_error: Error = DirAccess.rename_absolute(
			primary_absolute,
			backup_absolute
		)
		if backup_error != OK:
			if FileAccess.file_exists(previous_backup_path):
				DirAccess.rename_absolute(
					previous_backup_absolute,
					backup_absolute
				)
			_remove_if_present(temporary_path)
			return "Could not rotate the previous campaign save into backup."
	var commit_error: Error = DirAccess.rename_absolute(
		temporary_absolute,
		primary_absolute
	)
	if commit_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_absolute, primary_absolute)
		if FileAccess.file_exists(previous_backup_path):
			DirAccess.rename_absolute(
				previous_backup_absolute,
				backup_absolute
			)
		_remove_if_present(temporary_path)
		return "Could not commit the campaign save. The previous save was preserved."
	_remove_if_present(previous_backup_path)
	return ""


static func _is_valid_document_file(path: String, slot_id: int) -> bool:
	var result: Dictionary = _read_document_file(path)
	var document_value: Variant = result.get("document", {})
	return (
		document_value is Dictionary
		and _validate_document_shape(
			document_value as Dictionary,
			slot_id
		).is_empty()
	)


static func _ensure_save_directory() -> String:
	var user_directory: DirAccess = DirAccess.open("user://")
	if user_directory == null:
		return "Could not access the user save directory."
	var relative_directory: String = get_save_directory().trim_prefix(
		"user://"
	)
	if relative_directory.is_empty():
		return ""
	if user_directory.dir_exists(relative_directory):
		return ""
	var make_error: Error = user_directory.make_dir_recursive(
		relative_directory
	)
	if make_error != OK:
		return "Could not create the campaign save directory."
	return ""


static func _read_document_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"exists": false,
			"document": {},
			"error": "Campaign save does not exist.",
		}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"exists": true,
			"document": {},
			"error": "Campaign save could not be opened.",
		}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return {
			"exists": true,
			"document": {},
			"error": "Campaign save is not valid JSON object data.",
		}
	return {
		"exists": true,
		"document": parsed as Dictionary,
		"error": "",
	}


static func _validate_document_shape(
	document: Dictionary,
	expected_slot_id: int = 0
) -> String:
	if not document.has("save_version"):
		if _document_is_incompatible(document):
			return INCOMPATIBLE_VERSION_ERROR
		return "Save Envelope v3 is missing save_version."
	if not _is_integer_value(document.get("save_version")):
		return "Save Envelope v3 has an invalid save_version."
	if int(document.get("save_version")) != CampaignSaveStore.SAVE_VERSION:
		return INCOMPATIBLE_VERSION_ERROR
	if not _is_integer_value(document.get("slot_id")):
		return "Save Envelope v3 has an invalid slot_id."
	var slot_id: int = int(document.get("slot_id"))
	if not is_valid_slot_id(slot_id):
		return "Save Envelope v3 has an out-of-range slot_id."
	if expected_slot_id > 0 and slot_id != expected_slot_id:
		return "Save Envelope v3 slot_id does not match its save slot."
	var metadata_value: Variant = document.get("metadata", null)
	if not (metadata_value is Dictionary):
		return "Save Envelope v3 contains invalid metadata."
	var metadata: Dictionary = metadata_value as Dictionary
	for field_name: String in [
		"campaign_seed",
		"created_at_utc",
		"updated_at_utc",
	]:
		if not _is_integer_value(metadata.get(field_name)):
			return "Save Envelope v3 metadata contains invalid %s." % field_name
	var campaign_seed: int = int(metadata.get("campaign_seed"))
	var created_at_utc: int = int(metadata.get("created_at_utc"))
	var updated_at_utc: int = int(metadata.get("updated_at_utc"))
	if campaign_seed <= 0:
		return "Save Envelope v3 metadata has an invalid campaign_seed."
	if created_at_utc <= 0 or updated_at_utc < created_at_utc:
		return "Save Envelope v3 metadata has invalid UTC timestamps."
	var campaign_snapshot_value: Variant = document.get(
		"campaign_snapshot",
		null
	)
	if not (campaign_snapshot_value is Dictionary):
		return "Save Envelope v3 contains an invalid campaign_snapshot."
	var campaign_shape_error: String = (
		CampaignSaveStore.validate_campaign_snapshot_shape(
			campaign_snapshot_value as Dictionary
		)
	)
	if not campaign_shape_error.is_empty():
		return campaign_shape_error
	var refuge_snapshot_value: Variant = document.get(
		"refuge_snapshot",
		null
	)
	if not (refuge_snapshot_value is Dictionary):
		return "Save Envelope v3 contains an invalid refuge_snapshot."
	if not (refuge_snapshot_value as Dictionary).is_empty():
		var refuge_error: String = RefugeOwnershipState.validate_snapshot(
			(refuge_snapshot_value as Dictionary).duplicate(true),
			ITEM_CATALOG,
			BATTLER_CATALOG,
			DEMO_HEROINE_IDS
		)
		if not refuge_error.is_empty():
			return refuge_error
	if not document.has("active_run_snapshot"):
		return "Save Envelope v3 is missing active_run_snapshot."
	var active_value: Variant = document.get("active_run_snapshot")
	if active_value != null:
		if not (active_value is Dictionary):
			return "Save Envelope v3 active_run_snapshot must be null or a Dictionary."
		var active_error: String = _validate_active_run_snapshot(
			active_value as Dictionary,
			campaign_seed
		)
		if not active_error.is_empty():
			return active_error
	var serializable_error: String = _validate_serializable_variant(
		document,
		"Save Envelope v3"
	)
	if not serializable_error.is_empty():
		return serializable_error
	return ""


static func _validate_active_run_snapshot(
	snapshot: Dictionary,
	expected_campaign_seed: int
) -> String:
	if int(snapshot.get("campaign_seed", 0)) != expected_campaign_seed:
		return "Active-run snapshot campaign_seed does not match envelope metadata."
	var staged_run := RunState.new()
	var restore_error: String = staged_run.restore_active_run_snapshot(
		snapshot.duplicate(true),
		BATTLER_CATALOG
	)
	if not restore_error.is_empty():
		return restore_error
	var run_value: Variant = snapshot.get("run_snapshot", null)
	if not (run_value is Dictionary):
		return "Active-run snapshot has invalid run state."
	var knowledge_value: Variant = (run_value as Dictionary).get(
		"knowledge_state",
		null
	)
	if not (knowledge_value is Dictionary):
		return "Active-run snapshot has invalid knowledge state."
	var staged_knowledge := KnowledgeState.new()
	return staged_knowledge.restore_from_snapshot(
		(knowledge_value as Dictionary).duplicate(true)
	)


static func _validate_serializable_variant(
	value: Variant,
	path: String
) -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return ""
		TYPE_ARRAY:
			var array_value: Array = value as Array
			for index: int in range(array_value.size()):
				var item_error: String = _validate_serializable_variant(
					array_value[index],
					"%s[%d]" % [path, index]
				)
				if not item_error.is_empty():
					return item_error
			return ""
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value as Dictionary
			for key: Variant in dictionary_value.keys():
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]:
					return "%s contains a non-string dictionary key." % path
				var entry_error: String = _validate_serializable_variant(
					dictionary_value[key],
					"%s.%s" % [path, String(key)]
				)
				if not entry_error.is_empty():
					return entry_error
			return ""
	return "%s contains a non-serializable Variant value." % path


static func _is_integer_value(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return (
		typeof(value) == TYPE_FLOAT
		and float(value) == floorf(float(value))
	)


static func _document_is_incompatible(document: Dictionary) -> bool:
	if document.has("save_version"):
		return (
			_is_integer_value(document.get("save_version"))
			and int(document.get("save_version"))
			!= CampaignSaveStore.SAVE_VERSION
		)
	return (
		_is_integer_value(document.get("format_version"))
		and int(document.get("format_version")) < CampaignSaveStore.SAVE_VERSION
	)


static func _status_for_validation_error(error: String) -> String:
	return (
		"incompatible"
		if error == INCOMPATIBLE_VERSION_ERROR
		else "corrupted"
	)


static func _find_incompatible_slot_file(slot_id: int) -> String:
	for path: String in [get_slot_path(slot_id), get_backup_path(slot_id)]:
		var read_result: Dictionary = _read_document_file(path)
		var document_value: Variant = read_result.get("document", {})
		if (
			document_value is Dictionary
			and _document_is_incompatible(document_value as Dictionary)
		):
			return path
	return ""


static func _get_existing_created_at_utc(
	slot_id: int,
	fallback_timestamp: int
) -> int:
	for path: String in [get_slot_path(slot_id), get_backup_path(slot_id)]:
		var read_result: Dictionary = _read_document_file(path)
		var document_value: Variant = read_result.get("document", {})
		if not (document_value is Dictionary):
			continue
		var document: Dictionary = document_value as Dictionary
		if not _validate_document_shape(document, slot_id).is_empty():
			continue
		var metadata: Dictionary = document.get("metadata", {}) as Dictionary
		return int(metadata.get("created_at_utc", fallback_timestamp))
	return fallback_timestamp


static func _derive_summary(
	slot_id: int,
	envelope: Dictionary
) -> Dictionary:
	var metadata: Dictionary = (
		(envelope.get("metadata", {}) as Dictionary).duplicate(true)
	)
	var campaign_snapshot: Dictionary = (
		(envelope.get("campaign_snapshot", {}) as Dictionary).duplicate(true)
	)
	var lifecycle_value: Variant = campaign_snapshot.get(
		"campaign_lifecycle",
		{}
	)
	var campaign_seed: int = int(metadata.get("campaign_seed", 1))
	var campaign_mode: String = "REFUGE_RUN"
	if lifecycle_value is Dictionary:
		campaign_mode = String((lifecycle_value as Dictionary).get(
			"mode",
			campaign_mode
		))
	var party_ids: Array[String] = []
	var party_value: Variant = campaign_snapshot.get("party_snapshot", {})
	if party_value is Dictionary:
		for party_id: Variant in (party_value as Dictionary).keys():
			party_ids.append(String(party_id))
	party_ids.sort()
	var completed_value: Variant = campaign_snapshot.get(
		"completed_layer_ids",
		[]
	)
	var completed_count: int = (
		(completed_value as Array).size()
		if completed_value is Array
		else 0
	)
	var active_value: Variant = envelope.get("active_run_snapshot", null)
	var resumable: bool = active_value is Dictionary
	var safe_point_kind: String = (
		String((active_value as Dictionary).get("safe_point_kind", ""))
		if resumable
		else ""
	)
	var campaign_loadable: bool = String(
		campaign_snapshot.get("saved_location_id", "")
	) == "bloom_refuge_farthest_cell"
	return {
		"save_version": CampaignSaveStore.SAVE_VERSION,
		"slot_id": slot_id,
		"created_at_utc": int(metadata.get("created_at_utc", 0)),
		"updated_at_utc": int(metadata.get("updated_at_utc", 0)),
		"saved_at_unix": int(metadata.get("updated_at_utc", 0)),
		"campaign_seed": campaign_seed,
		"campaign_mode": campaign_mode,
		"location_id": String(campaign_snapshot.get("saved_location_id", "")),
		"location_label": (
			"%s — %s safe point" % [
				String((active_value as Dictionary).get("layer_id", "Active Run")),
				safe_point_kind.replace("_", " ").capitalize(),
			]
			if resumable
			else "Bloom Refuge — Farthest Cell"
		),
		"bloom": maxi(int(campaign_snapshot.get("bloom", 0)), 0),
		"party_ids": party_ids,
		"completed_layer_count": completed_count,
		"campaign_loadable": campaign_loadable,
		"resumable": resumable,
		"active_safe_point_kind": safe_point_kind,
	}


static func _summarize_document(
	slot_id: int,
	document: Dictionary,
	used_backup: bool
) -> Dictionary:
	var metadata: Dictionary = _derive_summary(slot_id, document)
	metadata["slot_id"] = slot_id
	metadata["status"] = "backup_available" if used_backup else "ready"
	metadata["loadable"] = true
	metadata["used_backup"] = used_backup
	metadata["error"] = ""
	return metadata


static func _empty_summary(slot_id: int) -> Dictionary:
	return {
		"save_version": 0,
		"slot_id": slot_id,
		"status": "empty",
		"loadable": false,
		"used_backup": false,
		"error": "",
		"created_at_utc": 0,
		"updated_at_utc": 0,
		"saved_at_unix": 0,
		"campaign_seed": 0,
		"campaign_mode": "",
		"location_id": "",
		"location_label": "Empty Slot",
		"bloom": 0,
		"party_ids": [],
		"completed_layer_count": 0,
		"campaign_loadable": false,
		"resumable": false,
		"active_safe_point_kind": "",
	}


static func _remove_if_present(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
