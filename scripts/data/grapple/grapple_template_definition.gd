class_name GrappleTemplateDefinition
extends Resource


@export_group("Identity")
@export var template_id: StringName
@export var display_name: String = "Unnamed Grapple"
@export var combined_visual_prefix: String = ""

@export_group("Stages")
@export var stages: Array[GrappleStageDefinition] = []

@export_group("Lifecycle")
@export_range(0, 20, 1) var grapple_cooldown_activations: int = 0
@export var can_target_defeated_heroines: bool = false
@export var one_use_only: bool = false


func get_stage(
	stage_index: int
) -> GrappleStageDefinition:
	if stage_index < 0 or stage_index >= stages.size():
		return null
	return stages[stage_index]


func get_stage_count() -> int:
	return stages.size()


func validate_definition() -> String:
	if template_id == &"":
		return "Grapple template requires a template_id."
	if stages.is_empty():
		return "%s requires at least one stage." % display_name

	for index: int in range(stages.size()):
		var stage: GrappleStageDefinition = stages[index]
		if stage == null:
			return "%s has an empty stage at index %d." % [
				display_name,
				index,
			]
		if stage.stage_number != index + 1:
			return "%s stage numbering must be consecutive." % (
				display_name
			)
		if index < stages.size() - 1 and stage.is_climax:
			return "%s marks a non-final stage as Climax." % (
				display_name
			)

	if not stages[-1].is_climax:
		return "%s must end with a Climax stage." % display_name

	return ""
