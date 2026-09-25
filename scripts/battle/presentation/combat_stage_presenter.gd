class_name CombatStagePresenter
extends Node


const PRESENTATION_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const LAYER_Z: Dictionary = {
	&"rear": -20,
	&"mid": 5,
	&"foreground": 60,
}


var active_stage: CombatStageDefinition
var active_battlefield: AuthoredBattlefield
var generated_layer_root: Node2D


func apply_stage(
	stage: CombatStageDefinition,
	battlefield: AuthoredBattlefield
) -> String:
	clear_stage()
	if stage == null or battlefield == null:
		return "Combat-stage presentation requires a stage and battlefield."
	var stage_error: String = stage.validate_definition()
	if not stage_error.is_empty():
		return stage_error
	if stage.battlefield_id != battlefield.battlefield_id:
		return "Combat stage '%s' targets battlefield '%s', not '%s'." % [
			stage.stage_id,
			stage.battlefield_id,
			battlefield.battlefield_id,
		]
	active_stage = stage
	active_battlefield = battlefield
	if stage.background_texture != null:
		var background: Sprite2D = battlefield.get_node_or_null(
			"BackgroundLayer/BackgroundArt"
		) as Sprite2D
		if background == null:
			return "Combat stage '%s' cannot find BackgroundArt." % stage.stage_id
		background.texture = stage.background_texture
		_fit_background(background)
	generated_layer_root = Node2D.new()
	generated_layer_root.name = "StagePresentation"
	battlefield.add_child(generated_layer_root)
	for depth_band: StringName in [&"rear", &"mid", &"foreground"]:
		var layer := Node2D.new()
		layer.name = "%sProps" % String(depth_band).capitalize()
		layer.z_index = int(LAYER_Z.get(depth_band, 0))
		generated_layer_root.add_child(layer)
	for prop: CombatStagePropDefinition in stage.props:
		_add_prop(prop)
	return ""


func clear_stage() -> void:
	if is_instance_valid(generated_layer_root):
		generated_layer_root.queue_free()
	generated_layer_root = null
	active_stage = null
	active_battlefield = null


func get_presented_prop(prop_id: StringName) -> Node2D:
	if generated_layer_root == null:
		return null
	return generated_layer_root.find_child(
		"Prop_%s" % String(prop_id),
		true,
		false
	) as Node2D


func _exit_tree() -> void:
	clear_stage()


func _fit_background(background: Sprite2D) -> void:
	if background.texture == null:
		return
	var texture_size: Vector2 = background.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var cover_scale: float = maxf(
		PRESENTATION_SIZE.x / texture_size.x,
		PRESENTATION_SIZE.y / texture_size.y
	)
	background.centered = false
	background.scale = Vector2.ONE * cover_scale
	background.position = (
		PRESENTATION_SIZE - texture_size * cover_scale
	) * 0.5


func _add_prop(prop: CombatStagePropDefinition) -> void:
	if prop == null or generated_layer_root == null:
		return
	var layer: Node2D = generated_layer_root.get_node_or_null(
		"%sProps" % String(prop.depth_band).capitalize()
	) as Node2D
	if layer == null:
		return
	var prop_root := Node2D.new()
	prop_root.name = "Prop_%s" % String(prop.prop_id)
	prop_root.position = prop.position
	prop_root.rotation_degrees = prop.rotation_degrees
	prop_root.z_index = prop.z_order_bias
	prop_root.set_meta("prop_id", prop.prop_id)
	prop_root.set_meta("mechanical", prop.mechanical)
	prop_root.set_meta("battlefield_rule_id", prop.battlefield_rule_id)
	layer.add_child(prop_root)
	_add_prop_part(prop_root, "Rear", prop.rear_texture, prop, -1)
	_add_prop_part(prop_root, "Body", prop.body_texture, prop, 0)
	_add_prop_part(prop_root, "FrontMask", prop.front_mask_texture, prop, 1)


func _add_prop_part(
	parent: Node2D,
	part_name: String,
	texture: Texture2D,
	prop: CombatStagePropDefinition,
	z_offset: int
) -> void:
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = part_name
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = prop.scale
	sprite.position = -texture.get_size() * prop.floor_anchor * prop.scale
	sprite.z_index = z_offset
	parent.add_child(sprite)
