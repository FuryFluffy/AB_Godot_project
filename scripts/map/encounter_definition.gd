class_name EncounterDefinition
extends RefCounted


var encounter_id: StringName = &""
var source_node_id: StringName = &""
var authored_room_id: StringName = &""
var combat_stage_id: StringName = &""
var display_name: String = ""
var node_type: MapNodeState.NodeType = MapNodeState.NodeType.BATTLE
var encounter_seed: int = 0
var is_boss: bool = false
var difficulty_label: String = "Regular"
var template: EncounterTemplateDefinition
var party_ids: Array[StringName] = [
	&"lysandra",
	&"mira",
	&"seraphine",
]
var enemy_ids: Array[StringName] = []
var spawn_assignments: Dictionary = {}


func get_enemy_count() -> int:
	return enemy_ids.size()


func get_composition_label() -> String:
	if enemy_ids.is_empty():
		return "No enemies"
	return ", ".join(PackedStringArray(enemy_ids))


func get_all_battler_ids() -> Array[StringName]:
	var battler_ids: Array[StringName] = party_ids.duplicate()
	battler_ids.append_array(enemy_ids)
	return battler_ids


func ensure_spawn_assignments() -> String:
	if template == null:
		return "Encounter '%s' has no EncounterTemplateDefinition." % (
			encounter_id
		)
	var capacity_error: String = template.validate_capacity(
		party_ids.size(),
		enemy_ids.size()
	)
	if not capacity_error.is_empty():
		return capacity_error
	if spawn_assignments.is_empty():
		spawn_assignments = template.make_spawn_assignments(
			party_ids,
			enemy_ids
		)
	for battler_id: StringName in get_all_battler_ids():
		if not spawn_assignments.has(battler_id):
			return "Battler '%s' has no spawn assignment." % battler_id
	return ""
