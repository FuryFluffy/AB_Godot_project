@tool
class_name WorldLorePickup
extends ExplorationInteractable


signal hover_changed(
	lore_entry_id: StringName,
	is_hovered: bool
)

signal pickup_requested(
	lore_entry_id: StringName
)


@export_group("Identity")
@export var lore_entry_id: StringName = &""

@export_group("Visual")

@export var world_texture: Texture2D:
	set(value):
		world_texture = value
		_refresh_visuals()

@export var hover_prompt: String = "Click to collect"

@export var visual_scale: Vector2 = Vector2.ONE:
	set(value):
		visual_scale = value
		_refresh_visuals()

@export_range(
	-180.0,
	180.0,
	0.1
)
var visual_rotation_degrees: float = 0.0:
	set(value):
		visual_rotation_degrees = value
		_refresh_visuals()

@export var pickup_size: Vector2 = Vector2(
	160,
	100
):
	set(value):
		pickup_size = value
		_refresh_visuals()

@export var pickup_z_index: int = 0:
	set(value):
		pickup_z_index = value
		_refresh_visuals()


@onready var item_sprite: Sprite2D = $ItemSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_refresh_visuals()

	if Engine.is_editor_hint():
		return

	super._ready()

func _refresh_visuals() -> void:
	if not is_node_ready():
		return

	if item_sprite == null:
		return

	if collision_shape == null:
		return

	item_sprite.texture = world_texture
	item_sprite.scale = visual_scale
	item_sprite.rotation_degrees = (
		visual_rotation_degrees
	)

	var rectangle := RectangleShape2D.new()
	rectangle.size = pickup_size
	collision_shape.shape = rectangle

	z_index = pickup_z_index

func validate_pickup() -> String:
	if lore_entry_id == &"":
		return "World lore pickup requires a stable lore_entry_id."

	if world_texture == null:
		return (
			"World lore pickup '%s' has no texture."
			% lore_entry_id
		)

	if pickup_size.x <= 0.0 or pickup_size.y <= 0.0:
		return (
			"World lore pickup '%s' has an invalid pickup size."
			% lore_entry_id
		)

	return ""


func apply_discovered_state(
	is_discovered: bool
) -> void:
	visible = not is_discovered
	monitoring = not is_discovered
	
	set_interaction_enabled(
		not is_discovered
	)

func get_hover_prompt() -> String:
	return hover_prompt

func get_interaction_id() -> StringName:
	return lore_entry_id


func get_interaction_prompt() -> String:
	return hover_prompt


func _get_hover_visual() -> CanvasItem:
	return item_sprite


func _interaction_hover_state_changed(
	is_hovered: bool
) -> void:
	hover_changed.emit(
		lore_entry_id,
		is_hovered
	)


func _interaction_requested() -> void:
	pickup_requested.emit(
		lore_entry_id
	)
