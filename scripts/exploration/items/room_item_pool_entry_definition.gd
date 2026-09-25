class_name RoomItemPoolEntryDefinition
extends Resource


@export var entry_id: StringName = &""
@export var item: ItemDefinition
@export var world_texture: Texture2D
@export var world_visual_scale: Vector2 = Vector2.ONE
@export var required_anchor_tag: StringName = &"small_item"
@export_range(1, 100, 1) var weight: int = 1
@export_range(1, 99, 1) var quantity: int = 1
@export var guaranteed_once: bool = false
@export var owner_heroine_id: StringName = &""


func validate_definition() -> String:
	if entry_id == &"":
		return "A room item-pool entry requires an entry_id."

	if item == null:
		return "Room item-pool entry '%s' has no ItemDefinition." % (
			entry_id
		)

	if world_texture == null:
		return "Room item-pool entry '%s' has no world texture." % (
			entry_id
		)
		
	if (
		world_visual_scale.x <= 0.0
		or world_visual_scale.y <= 0.0
	):
		return "Room item pool entry '%s' has an invalid world visual scale" % entry_id

	if required_anchor_tag == &"":
		return "Room item-pool entry '%s' has no anchor tag." % (
			entry_id
		)

	if weight <= 0:
		return "Room item-pool entry '%s' has invalid weight." % (
			entry_id
		)

	if quantity <= 0:
		return "Room item-pool entry '%s' has invalid quantity." % (
			entry_id
		)

	return ""
