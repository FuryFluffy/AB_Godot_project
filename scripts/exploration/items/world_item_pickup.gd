class_name WorldItemPickup
extends ExplorationInteractable


signal hover_changed(
	world_item_id: StringName,
	display_name: String,
	is_hovered: bool
)

signal pickup_requested(world_item_id: StringName)


@onready var item_sprite: Sprite2D = $ItemSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


var world_item_id: StringName = &""
var item_definition: ItemDefinition
var quantity: int = 1


func _ready() -> void:
	super._ready()


func configure(
	new_world_item_id: StringName,
	new_item_definition: ItemDefinition,
	world_texture: Texture2D,
	new_quantity: int,
	visual_scale: Vector2,
	visual_rotation_degrees: float,
	pickup_size: Vector2,
	new_z_index: int
) -> String:
	if new_world_item_id == &"":
		return "World item requires a stable ID."

	if new_item_definition == null:
		return "World item has no ItemDefinition."

	if world_texture == null:
		return "World item has no texture."

	world_item_id = new_world_item_id
	item_definition = new_item_definition
	quantity = maxi(new_quantity, 1)

	item_sprite.texture = world_texture
	item_sprite.scale = visual_scale
	item_sprite.rotation_degrees = visual_rotation_degrees

	var rectangle := RectangleShape2D.new()
	rectangle.size = pickup_size
	collision_shape.shape = rectangle

	z_index = new_z_index
	set_interaction_enabled(true)
	return ""
	
func get_interaction_id() -> StringName:
	return world_item_id


func get_interaction_display_name() -> String:
	if item_definition == null:
		return ""

	return item_definition.display_name


func get_interaction_prompt() -> String:
	return "Click to take"


func _get_hover_visual() -> CanvasItem:
	return item_sprite


func _interaction_hover_state_changed(
	is_hovered: bool
) -> void:
	hover_changed.emit(
		world_item_id,
		get_interaction_display_name(),
		is_hovered
	)


func _interaction_requested() -> void:
	pickup_requested.emit(
		world_item_id
	)
