class_name CampaignLifecycleState
extends RefCounted


enum Mode {
	TUTORIAL_PRE_REFUGE,
	REFUGELESS_ASCENT,
	REFUGE_RUN,
	CAMPAIGN_COMPLETE,
}


const MODE_IDS: Dictionary = {
	Mode.TUTORIAL_PRE_REFUGE: "TUTORIAL_PRE_REFUGE",
	Mode.REFUGELESS_ASCENT: "REFUGELESS_ASCENT",
	Mode.REFUGE_RUN: "REFUGE_RUN",
	Mode.CAMPAIGN_COMPLETE: "CAMPAIGN_COMPLETE",
}


var mode: int = Mode.TUTORIAL_PRE_REFUGE
var campaign_seed: int = 1
var tutorial_layer_1_seed: int = 1
var refugeless_world_seed: int = 1
var active_run_seed: int = 0
var combat_sequence_index: int = 0
var refugeless_route_id: StringName = &""
var defeated_boss_ids: Array[StringName] = []
var refugeless_layer_seeds: Dictionary = {}
var active_run_layer_seeds: Dictionary = {}


func initialize_new(new_campaign_seed: int) -> void:
	campaign_seed = maxi(new_campaign_seed, 1)
	tutorial_layer_1_seed = campaign_seed
	refugeless_world_seed = StableSeedMixer.make_seed(
		campaign_seed,
		&"campaign_world",
		&"refugeless"
	)
	active_run_seed = 0
	combat_sequence_index = 0
	refugeless_route_id = &""
	defeated_boss_ids.clear()
	refugeless_layer_seeds.clear()
	active_run_layer_seeds.clear()
	mode = Mode.TUTORIAL_PRE_REFUGE


func get_mode_id() -> String:
	return String(MODE_IDS.get(mode, "TUTORIAL_PRE_REFUGE"))


func is_tutorial() -> bool:
	return mode == Mode.TUTORIAL_PRE_REFUGE


func is_refugeless() -> bool:
	return mode == Mode.REFUGELESS_ASCENT


func has_refuge() -> bool:
	return mode == Mode.REFUGE_RUN


func no_refuge_ending_is_eligible() -> bool:
	return mode in [
		Mode.TUTORIAL_PRE_REFUGE,
		Mode.REFUGELESS_ASCENT,
	]


func begin_refugeless_ascent(route_id: StringName) -> void:
	mode = Mode.REFUGELESS_ASCENT
	refugeless_route_id = route_id
	if refugeless_world_seed <= 0:
		refugeless_world_seed = StableSeedMixer.make_seed(
			campaign_seed,
			&"campaign_world",
			&"refugeless"
		)
	refugeless_layer_seeds = _make_layer_seed_manifest(
		refugeless_world_seed,
		&"refugeless_layer"
	)
	active_run_seed = 0
	active_run_layer_seeds.clear()


func establish_refuge() -> void:
	mode = Mode.REFUGE_RUN
	active_run_seed = 0
	active_run_layer_seeds.clear()


func begin_refuge_run(new_active_run_seed: int) -> void:
	mode = Mode.REFUGE_RUN
	active_run_seed = maxi(new_active_run_seed, 1)
	active_run_layer_seeds = _make_layer_seed_manifest(
		active_run_seed,
		&"refuge_run_layer"
	)


func finish_active_run() -> void:
	if mode != Mode.REFUGE_RUN:
		return
	active_run_seed = 0
	active_run_layer_seeds.clear()


func mark_boss_defeated(boss_id: StringName) -> void:
	if boss_id == &"" or defeated_boss_ids.has(boss_id):
		return
	defeated_boss_ids.append(boss_id)
	defeated_boss_ids.sort()


func is_boss_defeated(boss_id: StringName) -> bool:
	return defeated_boss_ids.has(boss_id)


func allocate_combat_seed(
	encounter_id: StringName,
	source_node_id: StringName
) -> int:
	combat_sequence_index += 1
	return StableSeedMixer.make_seed(
		campaign_seed,
		&"combat_sequence",
		StringName(
			"%d:%s:%s"
			% [
				combat_sequence_index,
				String(encounter_id),
				String(source_node_id),
			]
		)
	)


func to_snapshot() -> Dictionary:
	var boss_ids: Array[String] = []
	for boss_id: StringName in defeated_boss_ids:
		boss_ids.append(String(boss_id))
	return {
		"mode": get_mode_id(),
		"campaign_seed": campaign_seed,
		"tutorial_layer_1_seed": tutorial_layer_1_seed,
		"refugeless_world_seed": refugeless_world_seed,
		"active_run_seed": active_run_seed,
		"combat_sequence_index": combat_sequence_index,
		"refugeless_route_id": String(refugeless_route_id),
		"defeated_boss_ids": boss_ids,
		"refugeless_layer_seeds": refugeless_layer_seeds.duplicate(true),
		"active_run_layer_seeds": active_run_layer_seeds.duplicate(true),
	}


func restore_from_snapshot(snapshot: Dictionary) -> String:
	var mode_id: String = String(snapshot.get("mode", ""))
	var restored_mode: int = -1
	for candidate: Variant in MODE_IDS.keys():
		if String(MODE_IDS[candidate]) == mode_id:
			restored_mode = int(candidate)
			break
	if restored_mode < 0:
		return "Campaign snapshot contains an unknown campaign mode."

	var restored_campaign_seed: int = int(snapshot.get("campaign_seed", 0))
	var restored_tutorial_seed: int = int(
		snapshot.get("tutorial_layer_1_seed", 0)
	)
	var restored_refugeless_seed: int = int(
		snapshot.get("refugeless_world_seed", 0)
	)
	if (
		restored_campaign_seed <= 0
		or restored_tutorial_seed <= 0
		or restored_refugeless_seed <= 0
	):
		return "Campaign snapshot contains an invalid seed scope."

	var boss_value: Variant = snapshot.get("defeated_boss_ids", [])
	var refugeless_seeds_value: Variant = snapshot.get(
		"refugeless_layer_seeds",
		{}
	)
	var active_seeds_value: Variant = snapshot.get(
		"active_run_layer_seeds",
		{}
	)
	if not (boss_value is Array):
		return "Campaign snapshot contains an invalid boss registry."
	if not (refugeless_seeds_value is Dictionary):
		return "Campaign snapshot contains invalid Refuge-less layer seeds."
	if not (active_seeds_value is Dictionary):
		return "Campaign snapshot contains invalid active-run layer seeds."

	var restored_boss_ids: Array[StringName] = []
	for boss_value_id: Variant in (boss_value as Array):
		var boss_id := StringName(boss_value_id)
		if boss_id != &"" and not restored_boss_ids.has(boss_id):
			restored_boss_ids.append(boss_id)
	restored_boss_ids.sort()

	mode = restored_mode
	campaign_seed = restored_campaign_seed
	tutorial_layer_1_seed = restored_tutorial_seed
	refugeless_world_seed = restored_refugeless_seed
	active_run_seed = maxi(int(snapshot.get("active_run_seed", 0)), 0)
	combat_sequence_index = maxi(
		int(snapshot.get("combat_sequence_index", 0)),
		0
	)
	refugeless_route_id = StringName(
		snapshot.get("refugeless_route_id", "")
	)
	defeated_boss_ids = restored_boss_ids
	refugeless_layer_seeds = (
		refugeless_seeds_value as Dictionary
	).duplicate(true)
	active_run_layer_seeds = (
		active_seeds_value as Dictionary
	).duplicate(true)
	return ""


func restore_legacy_refuge(new_campaign_seed: int) -> void:
	initialize_new(new_campaign_seed)
	mode = Mode.REFUGE_RUN
	active_run_seed = 0
	active_run_layer_seeds.clear()


func _make_layer_seed_manifest(
	base_seed: int,
	namespace_id: StringName
) -> Dictionary:
	var result: Dictionary = {}
	for layer_number: int in range(1, 11):
		result[str(layer_number)] = StableSeedMixer.make_seed(
			base_seed,
			namespace_id,
			StringName("layer_%d" % layer_number)
		)
	return result
