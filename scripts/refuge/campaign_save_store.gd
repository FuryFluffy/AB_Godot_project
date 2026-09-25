class_name CampaignSaveStore
extends RefCounted


const SAVE_VERSION: int = 3
const UNSUPPORTED_LEGACY_SAVE_PATH: String = (
	"user://abyssal_bloom_campaign_v1.json"
)
const LEGACY_ITEM_ID_MIGRATIONS: Dictionary = {
	"bandage_roll": "l01_bandage_roll",
	"servants_tonic": "l01_servants_tonic",
	"repair_thread_and_wax": "l01_repair_thread_wax",
	"wax_sealed_needle": "l01_wax_sealed_needle",
	"warm_wine_flask": "l01_warm_wine_flask",
	"red_wax_ampoule": "l01_red_wax_ampoule",
	"kitchen_knife": "l01_kitchen_knife",
	"polished_serving_tray": "l01_polished_serving_tray",
	"smelling_salts": "l01_smelling_salts",
	"chapel_rosary": "l01_chapel_rosary",
	"hollow_livery_pin": "l01_hollow_livery_pin",
	"courtesy_collar": "l01_courtesy_collar",
	"ledger_seal": "l01_ledger_seal",
	"torn_cuff": "l01_torn_cuff",
	"rusty_key": "shared_rusty_key",
	"prisoners_poultice": "l02_prisoners_poultice",
	"rusted_nail_bundle": "l02_rusted_nail_bundle",
	"bitter_wakefulness_tonic": "l02_bitter_wakefulness_tonic",
	"chain_oil": "l02_chain_oil",
	"lime_dust_pouch": "l02_lime_dust_pouch",
	"iron_wedge": "l02_iron_wedge",
	"jailers_maintenance_kit": "l02_jailers_maintenance_kit",
	"filed_iron_shard": "l02_filed_iron_shard",
	"shackle_key": "l02_shackle_key",
	"mercy_chain": "l02_mercy_chain",
	"jailers_tag": "l02_jailers_tag",
	"quiet_shackle": "l02_quiet_shackle",
	"guiltless_key": "l02_guiltless_key",
}
const RETAINED_LEGACY_ITEM_IDS: Dictionary = {
	"quiet_cell_blanket": true,
}


static func make_campaign_snapshot(
	run_state: RunState,
	knowledge_state: KnowledgeState,
	discard_unspent_bloom: bool = false
) -> Dictionary:
	if run_state == null or knowledge_state == null:
		return {}
	var snapshot: Dictionary = run_state.make_refuge_campaign_snapshot()
	if snapshot.is_empty():
		return {}
	snapshot["knowledge_state"] = knowledge_state.to_snapshot()
	if discard_unspent_bloom:
		snapshot["bloom"] = 0
	return snapshot


static func make_active_campaign_anchor_snapshot(
	run_state: RunState,
	knowledge_state: KnowledgeState
) -> Dictionary:
	if run_state == null or knowledge_state == null or run_state.campaign_lifecycle == null:
		return {}
	var completed_layers: Array[String] = []
	for layer_id: StringName in run_state.completed_layer_ids:
		completed_layers.append(String(layer_id))
	return {
		"saved_location_id": "active_run_safe_point",
		"run_seed": run_state.run_seed,
		"campaign_lifecycle": run_state.campaign_lifecycle.to_snapshot(),
		"party_snapshot": run_state.party_snapshot.duplicate(true),
		"inventory_snapshot": run_state.inventory_snapshot.duplicate(true),
		"heroine_progression_snapshot": run_state.heroine_progression_snapshot.duplicate(true),
		"bloom": run_state.bloom,
		"completed_layer_ids": completed_layers,
		"narrative_state": run_state.narrative_state.to_snapshot(),
		"knowledge_state": knowledge_state.to_snapshot(),
	}


static func validate_campaign_snapshot_shape(snapshot: Dictionary) -> String:
	if String(snapshot.get("saved_location_id", "")) not in [
		"bloom_refuge_farthest_cell",
		"active_run_safe_point",
	]:
		return "Campaign save is not at a supported safe boundary."
	for field_name: String in [
		"knowledge_state",
		"party_snapshot",
		"heroine_progression_snapshot",
		"narrative_state",
		"campaign_lifecycle",
	]:
		if not (snapshot.get(field_name, null) is Dictionary):
			return "Campaign snapshot contains invalid %s." % field_name
	for field_name: String in [
		"inventory_snapshot",
		"completed_layer_ids",
	]:
		if not (snapshot.get(field_name, null) is Array):
			return "Campaign snapshot contains invalid %s." % field_name
	return ""


static func restore_campaign_snapshot(
	snapshot: Dictionary,
	run_state: RunState,
	knowledge_state: KnowledgeState,
	refuge_graph: LayerMapGraph,
	battler_catalog: BattlerCatalogDefinition
) -> String:
	if run_state == null or knowledge_state == null:
		return "Campaign restore requires the current run and knowledge state."
	var staged_snapshot: Dictionary = snapshot.duplicate(true)
	var shape_error: String = validate_campaign_snapshot_shape(staged_snapshot)
	if not shape_error.is_empty():
		return shape_error
	var knowledge_value: Variant = staged_snapshot.get("knowledge_state", {})
	if not (knowledge_value is Dictionary):
		return "Campaign save contains invalid knowledge state."

	# Validate both halves before committing either one. This keeps a malformed
	# file from replacing a usable in-memory Refuge state only partially.
	var staged_knowledge := KnowledgeState.new()
	var knowledge_error: String = staged_knowledge.restore_from_snapshot(
		knowledge_value as Dictionary
	)
	if not knowledge_error.is_empty():
		return knowledge_error
	staged_snapshot = migrate_legacy_item_ids(staged_snapshot)
	var run_error: String = run_state.restore_refuge_campaign_snapshot(
		staged_snapshot,
		refuge_graph,
		battler_catalog
	)
	if not run_error.is_empty():
		return run_error
	return knowledge_state.restore_from_snapshot(
		staged_knowledge.to_snapshot()
	)


static func migrate_legacy_item_ids(document: Dictionary) -> Dictionary:
	var migrated_document: Dictionary = document.duplicate(true)
	var inventory_value: Variant = migrated_document.get(
		"inventory_snapshot",
		[]
	)
	if not (inventory_value is Array):
		return migrated_document
	for slot_value: Variant in (inventory_value as Array):
		if not (slot_value is Dictionary):
			continue
		var slot: Dictionary = slot_value as Dictionary
		var stored_item_id: String = String(slot.get("item_id", ""))
		if RETAINED_LEGACY_ITEM_IDS.has(stored_item_id):
			continue
		if LEGACY_ITEM_ID_MIGRATIONS.has(stored_item_id):
			slot["item_id"] = String(
				LEGACY_ITEM_ID_MIGRATIONS[stored_item_id]
			)
	return migrated_document


# Retained for focused Milestone 1 tests and older development tooling.
static func _migrate_legacy_item_ids(document: Dictionary) -> Dictionary:
	return migrate_legacy_item_ids(document)
