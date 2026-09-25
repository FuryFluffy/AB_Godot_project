@tool
extends Node2D


@onready var preview_sprite: Sprite2D = (
	$PreviewSprite
)


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_refresh_preview()
	else:
		visible = false
		set_process(false)


func _process(
	_delta: float
) -> void:
	_refresh_preview()


func _refresh_preview() -> void:
	var anchor := (
		get_parent()
		as RoomEventSpawnAnchor
	)

	if anchor == null:
		visible = false
		return

	visible = anchor.show_editor_preview

	if not visible:
		return

	var entry: RoomEventPoolEntryDefinition = (
		anchor.preview_entry
	)

	preview_sprite.visible = (
		entry != null
		and entry.world_texture != null
	)

	if preview_sprite.visible:
		preview_sprite.texture = (
			entry.world_texture
		)

		preview_sprite.position = Vector2.ZERO

		preview_sprite.scale = (
			entry.world_visual_scale
			* anchor.event_visual_scale
		)

		preview_sprite.rotation_degrees = (
			anchor
				.event_visual_rotation_degrees
		)

		preview_sprite.z_index = (
			anchor.event_z_index
		)

	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var anchor := (
		get_parent()
		as RoomEventSpawnAnchor
	)

	if anchor == null:
		return

	if (
		not anchor.show_editor_preview
		or not anchor.show_interaction_bounds
	):
		return

	var half_size: Vector2 = (
		anchor.interaction_size * 0.5
	)

	draw_rect(
		Rect2(
			-half_size,
			anchor.interaction_size
		),
		Color(
			0.82,
			0.35,
			1.0,
			0.95
		),
		false,
		2.0
	)

	draw_line(
		Vector2(-7.0, 0.0),
		Vector2(7.0, 0.0),
		Color(
			0.82,
			0.35,
			1.0,
			0.95
		),
		2.0
	)

	draw_line(
		Vector2(0.0, -7.0),
		Vector2(0.0, 7.0),
		Color(
			0.82,
			0.35,
			1.0,
			0.95
		),
		2.0
	)
