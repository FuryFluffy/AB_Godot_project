class_name EncounterTemplateDefinition
extends Resource


@export_group("Identity")
@export var template_id: StringName
@export var display_name: String = "Unnamed Encounter Template"

@export_group("Composition")
@export var battlefield_scene: PackedScene
@export var enemy_group_rulebook: EnemyGroupRulebookDefinition
@export var preview_enemy_ids: Array[StringName] = []
@export var party_spawn_slot_ids: Array[StringName] = []
@export var enemy_spawn_slot_ids: Array[StringName] = []


func make_spawn_assignments(
	party_ids: Array[StringName],
	enemy_ids: Array[StringName]
) -> Dictionary:
	var assignments: Dictionary = {}
	for party_index: int in range(party_ids.size()):
		if party_index >= party_spawn_slot_ids.size():
			break
		assignments[party_ids[party_index]] = (
			party_spawn_slot_ids[party_index]
		)
	for enemy_index: int in range(enemy_ids.size()):
		if enemy_index >= enemy_spawn_slot_ids.size():
			break
		assignments[enemy_ids[enemy_index]] = (
			enemy_spawn_slot_ids[enemy_index]
		)
	return assignments


func validate_capacity(
	party_count: int,
	enemy_count: int
) -> String:
	if battlefield_scene == null:
		return "Encounter template '%s' has no battlefield scene." % (
			template_id
		)
	if enemy_group_rulebook == null:
		return "Encounter template '%s' has no enemy group rulebook." % (
			template_id
		)
	if party_count > party_spawn_slot_ids.size():
		return "Encounter template '%s' lacks party spawn slots." % (
			template_id
		)
	if enemy_count > enemy_spawn_slot_ids.size():
		return "Encounter template '%s' lacks enemy spawn slots." % (
			template_id
		)
	return ""
