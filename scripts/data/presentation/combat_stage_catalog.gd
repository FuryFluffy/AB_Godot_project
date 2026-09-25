@tool
class_name CombatStageCatalog
extends Resource


@export var stages: Array[CombatStageDefinition] = []
@export var bindings: Array[CombatStageBindingDefinition] = []


func get_stage(stage_id: StringName) -> CombatStageDefinition:
	for stage: CombatStageDefinition in stages:
		if stage != null and stage.stage_id == stage_id:
			return stage
	return null


func get_binding(
	encounter_id: StringName,
	runtime_room_id: StringName = &""
) -> CombatStageBindingDefinition:
	for binding: CombatStageBindingDefinition in bindings:
		if (
			binding != null
			and binding.encounter_id == encounter_id
			and binding.matches_room(runtime_room_id)
		):
			return binding
	return null


func resolve_stage_for_encounter(
	encounter_id: StringName,
	runtime_room_id: StringName = &""
) -> CombatStageDefinition:
	var binding: CombatStageBindingDefinition = get_binding(
		encounter_id,
		runtime_room_id
	)
	return get_stage(binding.combat_stage_id) if binding != null else null


func get_default_stage_for_battlefield(
	battlefield_id: StringName
) -> CombatStageDefinition:
	var first_match: CombatStageDefinition
	for stage: CombatStageDefinition in stages:
		if stage == null or stage.battlefield_id != battlefield_id:
			continue
		if stage.preserve_authored_background:
			return stage
		if first_match == null:
			first_match = stage
	return first_match


func validate_definition() -> String:
	if stages.is_empty() or bindings.is_empty():
		return "Combat-stage catalog requires stages and bindings."
	var stage_ids: Dictionary = {}
	for stage: CombatStageDefinition in stages:
		if stage == null:
			return "Combat-stage catalog contains an empty stage."
		var stage_error: String = stage.validate_definition()
		if not stage_error.is_empty():
			return stage_error
		if stage_ids.has(stage.stage_id):
			return "Combat-stage catalog repeats stage '%s'." % stage.stage_id
		stage_ids[stage.stage_id] = stage
	var binding_ids: Dictionary = {}
	var encounter_ids: Dictionary = {}
	for binding: CombatStageBindingDefinition in bindings:
		if binding == null:
			return "Combat-stage catalog contains an empty binding."
		var binding_error: String = binding.validate_definition()
		if not binding_error.is_empty():
			return binding_error
		if binding_ids.has(binding.binding_id):
			return "Combat-stage catalog repeats binding '%s'." % binding.binding_id
		if encounter_ids.has(binding.encounter_id):
			return "Combat-stage catalog repeats encounter '%s'." % binding.encounter_id
		var stage: CombatStageDefinition = stage_ids.get(
			binding.combat_stage_id
		) as CombatStageDefinition
		if stage == null:
			return "Combat-stage binding '%s' references a missing stage." % binding.binding_id
		if stage.battlefield_id != binding.battlefield_id:
			return "Combat-stage binding '%s' disagrees with its battlefield." % binding.binding_id
		binding_ids[binding.binding_id] = true
		encounter_ids[binding.encounter_id] = true
	return ""
