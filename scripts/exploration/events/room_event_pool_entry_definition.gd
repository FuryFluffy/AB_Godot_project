class_name RoomEventPoolEntryDefinition
extends Resource


@export_group("Identity")
@export var entry_id: StringName = &""

@export_group("Event")
@export var room_event: RoomEventDefinition

@export_group("World Presentation")
@export var world_texture: Texture2D
@export var world_visual_scale: Vector2 = (
	Vector2.ONE
)

@export var required_anchor_tag: StringName = (
	&"small_tabletop_event"
)

@export_group("Selection")
@export_range(1, 100, 1)
var weight: int = 1


func collect_validation_errors(
	entry_label: String
) -> Array[String]:
	var errors: Array[String] = []

	if entry_id == &"":
		errors.append(
			"%s has no entry_id."
			% entry_label
		)

	if room_event == null:
		errors.append(
			"%s has no RoomEventDefinition."
			% entry_label
		)
	else:
		errors.append_array(
			room_event.collect_validation_errors()
		)

	if world_texture == null:
		errors.append(
			"%s has no world texture."
			% entry_label
		)

	if (
		world_visual_scale.x <= 0.0
		or world_visual_scale.y <= 0.0
	):
		errors.append(
			"%s has an invalid world scale."
			% entry_label
		)

	if required_anchor_tag == &"":
		errors.append(
			"%s has no required anchor tag."
			% entry_label
		)

	if weight <= 0:
		errors.append(
			"%s has an invalid weight."
			% entry_label
		)

	return errors
