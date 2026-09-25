class_name GrappleTrackState
extends RefCounted


var track_id: StringName
var heroine_id: StringName
var grappler_id: StringName
var template: GrappleTemplateDefinition

var is_main: bool = true
var succession_order: int = 0
var stage_index: int = 0
var current_stage_holds: int = 0


func _init(
	new_track_id: StringName = &"",
	new_heroine_id: StringName = &"",
	new_grappler_id: StringName = &"",
	new_template: GrappleTemplateDefinition = null,
	new_is_main: bool = true,
	new_succession_order: int = 0
) -> void:
	track_id = new_track_id
	heroine_id = new_heroine_id
	grappler_id = new_grappler_id
	template = new_template
	is_main = new_is_main
	succession_order = new_succession_order


func get_current_stage() -> GrappleStageDefinition:
	if template == null:
		return null
	return template.get_stage(stage_index)


func get_stage_number() -> int:
	return stage_index + 1


func get_stage_count() -> int:
	if template == null:
		return 0
	return template.get_stage_count()


func is_at_climax() -> bool:
	var stage: GrappleStageDefinition = get_current_stage()
	return stage != null and stage.is_climax


func can_hold() -> bool:
	var stage: GrappleStageDefinition = get_current_stage()
	return (
		stage != null
		and not stage.is_climax
		and current_stage_holds < stage.maximum_holds
	)


func can_progress() -> bool:
	return (
		template != null
		and stage_index + 1 < template.get_stage_count()
	)


func progress() -> bool:
	if not can_progress():
		return false

	stage_index += 1
	current_stage_holds = 0
	return true


func record_hold() -> bool:
	if not can_hold():
		return false

	current_stage_holds += 1
	return true


func get_progress_ratio() -> float:
	var count: int = get_stage_count()
	if count <= 0:
		return 0.0
	return float(get_stage_number()) / float(count)


func get_combined_visual_key() -> StringName:
	if template == null or template.combined_visual_prefix.is_empty():
		return &""
	return StringName(
		"%s_x1_%s" % [
			template.combined_visual_prefix,
			String(heroine_id).capitalize().replace(" ", ""),
		]
	)
