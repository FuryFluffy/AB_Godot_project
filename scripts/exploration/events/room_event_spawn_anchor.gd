@tool
class_name RoomEventSpawnAnchor
extends Marker2D


@export_group("Identity")
@export var anchor_id: StringName = &""

@export var anchor_tags: Array[StringName] = [
	&"small_tabletop_event",
]

@export_group("World Presentation")
@export var event_visual_scale: Vector2 = (
	Vector2.ONE
)

@export_range(
	-180.0,
	180.0,
	0.1
)
var event_visual_rotation_degrees: float = 0.0

@export var interaction_size: Vector2 = (
	Vector2(120, 120)
)

@export var event_z_index: int = 4

@export_group("Editor Preview")
@export var preview_entry: RoomEventPoolEntryDefinition
@export var show_editor_preview: bool = true
@export var show_interaction_bounds: bool = true


func accepts_tag(
	required_tag: StringName
) -> bool:
	return (
		required_tag == &""
		or anchor_tags.has(
			required_tag
		)
	)


func validate_anchor() -> String:
	if anchor_id == &"":
		return (
			"A room event anchor requires "
			+ "a stable anchor_id."
		)

	if anchor_tags.is_empty():
		return (
			"Room event anchor '%s' has no tags."
			% anchor_id
		)

	if (
		interaction_size.x <= 0.0
		or interaction_size.y <= 0.0
	):
		return (
			(
				"Room event anchor '%s' has "
				+ "an invalid interaction size."
			)
			% anchor_id
		)

	return ""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if anchor_id == &"":
		warnings.append(
			"This event anchor has no anchor_id."
		)

	if anchor_tags.is_empty():
		warnings.append(
			"This event anchor has no tags."
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
