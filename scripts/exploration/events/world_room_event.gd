class_name WorldRoomEvent
extends ExplorationInteractable


signal hover_changed(
	spawn_id: StringName,
	display_name: String,
	is_hovered: bool
)

signal activation_requested(
	spawn_id: StringName
)


@onready var event_sprite: Sprite2D = (
	$EventSprite
)

@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)


var spawn_id: StringName = &""
var event_definition: RoomEventDefinition
var is_resolved: bool = false


func _ready() -> void:
	super._ready()


func configure(
	new_spawn_id: StringName,
	new_event_definition: RoomEventDefinition,
	world_texture: Texture2D,
	visual_scale: Vector2,
	visual_rotation_degrees: float,
	interaction_size: Vector2,
	new_z_index: int
) -> String:
	if new_spawn_id == &"":
		return (
			"World room event requires a stable ID."
		)

	if new_event_definition == null:
		return (
			"World room event has no definition."
		)

	if world_texture == null:
		return (
			"World room event has no texture."
		)

	if (
		interaction_size.x <= 0.0
		or interaction_size.y <= 0.0
	):
		return (
			"World room event has an invalid "
			+ "interaction size."
		)

	spawn_id = new_spawn_id
	event_definition = new_event_definition

	event_sprite.texture = world_texture
	event_sprite.scale = visual_scale
	event_sprite.rotation_degrees = (
		visual_rotation_degrees
	)

	var rectangle := RectangleShape2D.new()
	rectangle.size = interaction_size
	collision_shape.shape = rectangle

	z_index = new_z_index
	set_interaction_enabled(true)

	return ""

func apply_resolved_state(
	resolved: bool
) -> void:
	is_resolved = resolved

	if not resolved:
		visible = true
		monitoring = true

		set_interaction_enabled(
			true
		)

		refresh_interaction_visual()
		return

	monitoring = false

	set_interaction_enabled(
		false
	)

	if (
		event_definition != null
		and event_definition.remove_on_resolve
	):
		visible = false
		return

	visible = true

	refresh_interaction_visual()

func get_interaction_id() -> StringName:
	return spawn_id


func get_interaction_display_name() -> String:
	if event_definition == null:
		return ""

	return event_definition.display_name


func get_interaction_prompt() -> String:
	if event_definition == null:
		return ""

	return event_definition.hover_prompt


func _get_hover_visual() -> CanvasItem:
	return event_sprite


func _get_idle_modulate() -> Color:
	if is_resolved:
		return Color(
			0.55,
			0.55,
			0.55,
			0.75
		)

	return Color.WHITE


func _interaction_hover_state_changed(
	is_hovered: bool
) -> void:
	if is_resolved:
		return

	hover_changed.emit(
		spawn_id,
		get_interaction_display_name(),
		is_hovered
	)


func _interaction_requested() -> void:
	if is_resolved:
		return

	activation_requested.emit(
		spawn_id
	)
