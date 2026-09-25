@tool
class_name RoomItemSpawnAnchor
extends Marker2D

@export var anchor_id: StringName = &""
@export var anchor_tags: Array[StringName] = [&"small_item"]
@export var item_visual_scale: Vector2 = Vector2.ONE
@export var item_visual_rotation_degrees: float = 0.0
@export var pickup_size: Vector2 = Vector2(80.0, 140.0)
@export var item_z_index: int = 1
@export_group("Editor Preview")
@export var preview_entry: RoomItemPoolEntryDefinition
@export var show_editor_preview: bool = true
@export var show_pickup_bounds: bool = true

func accepts_tag(required_tag: StringName) -> bool:
	return (
		required_tag == &""
		or anchor_tags.has(required_tag)
	)
	
func validate_anchor() -> String:
	if anchor_id == &"":
		return "A room item spawn anchor requires anchor_id"
		
	if anchor_tags.is_empty():
		return "Room item anchor '%s' has invalid pickup size" % anchor_id
		
	if pickup_size.x <= 0.0 or pickup_size.y <= 0.0:
		return "Room item anchor '%s' has invalid pickup size" % anchor_id
	
	return ""

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if anchor_id == &"":
		warnings.append(
			"This item anchor has no anchor_id."
		)

	if anchor_tags.is_empty():
		warnings.append(
			"This item anchor has no compatibility tags."
		)

	if (
		preview_entry != null
		and not accepts_tag(
			preview_entry.required_anchor_tag
		)
	):
		warnings.append(
			(
				"Preview entry '%s' requires tag '%s', "
				+ "which this anchor does not accept."
			)
			% [
				preview_entry.entry_id,
				preview_entry.required_anchor_tag,
			]
		)

	return warnings
