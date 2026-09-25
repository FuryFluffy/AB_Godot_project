@tool
class_name CombatStageDefinition
extends Resource


@export_group("Identity")
@export var stage_id: StringName
@export var battlefield_id: StringName
@export var display_name: String

@export_group("Composition")
@export var background_texture: Texture2D
@export var preserve_authored_background: bool = false
@export var props: Array[CombatStagePropDefinition] = []
@export var experimental_foreground_enabled: bool = false


func get_prop(prop_id: StringName) -> CombatStagePropDefinition:
	for prop: CombatStagePropDefinition in props:
		if prop != null and prop.prop_id == prop_id:
			return prop
	return null


func validate_definition() -> String:
	if stage_id == &"":
		return "A combat stage has no stage_id."
	if battlefield_id == &"":
		return "Combat stage '%s' has no battlefield_id." % stage_id
	if display_name.strip_edges().is_empty():
		return "Combat stage '%s' has no display name." % stage_id
	if background_texture == null and not preserve_authored_background:
		return "Combat stage '%s' has no reviewed background." % stage_id
	if background_texture != null and preserve_authored_background:
		return "Combat stage '%s' cannot both replace and preserve its background." % stage_id
	var prop_ids: Dictionary = {}
	for prop: CombatStagePropDefinition in props:
		if prop == null:
			return "Combat stage '%s' contains an empty prop." % stage_id
		var prop_error: String = prop.validate_definition()
		if not prop_error.is_empty():
			return prop_error
		if prop_ids.has(prop.prop_id):
			return "Combat stage '%s' repeats prop '%s'." % [stage_id, prop.prop_id]
		prop_ids[prop.prop_id] = true
	return ""
