@tool
class_name AuthoredPosition
extends Marker2D


const FILL_COLOR := Color(0.96, 0.84, 0.28, 0.72)
const OUTLINE_COLOR := Color(0.12, 0.10, 0.08, 0.95)
const PREVIEW_BOUND_COLOR := Color(0.94, 0.83, 0.36, 0.72)
const PREVIEW_SPRITE_NAME := "BattlerEditorPreview"
const PREVIEW_BOUNDS_NAME := "BattlerEditorPreviewBounds"


@export_range(0, 3, 1) var position_index: int = 0

@export_group("Battler Presentation")
@export var show_battler_preview: bool = false
@export var use_anchor_battler_scale: bool = true
@export_range(0.1, 3.0, 0.01) var battler_scale: float = 1.0
@export var use_anchor_visual_order: bool = true
@export_range(-100, 100, 1) var battler_visual_order: int = 0

@export_group("Cross-Anchor Adjacency")
## Add any number of AuthoredPositions in other directly connected Anchors.
## Every entry is compiled as an undirected contact, so target Positions do
## not need matching reverse assignments. Duplicate and mirrored pairs are
## deduplicated by the battlefield compiler.
@export var connected_positions: Array[AuthoredPosition] = []


func _ready() -> void:
	visible = Engine.is_editor_hint()
	z_index = 2
	if Engine.is_editor_hint():
		_ensure_editor_preview_nodes()
		_refresh_editor_preview()
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()
		queue_redraw()


func get_effective_visual_order() -> int:
	if not use_anchor_visual_order:
		return battler_visual_order
	var anchor := get_parent() as AuthoredAnchor
	return anchor.visual_order if anchor != null else battler_visual_order


func get_effective_battler_scale() -> float:
	if not use_anchor_battler_scale:
		return battler_scale
	var anchor := get_parent() as AuthoredAnchor
	return anchor.battler_scale if anchor != null else battler_scale


func _get_battlefield() -> AuthoredBattlefield:
	var current: Node = get_parent()
	while current != null:
		if current is AuthoredBattlefield:
			return current as AuthoredBattlefield
		current = current.get_parent()
	return null


func _ensure_editor_preview_nodes() -> void:
	var preview_sprite := get_node_or_null(
		PREVIEW_SPRITE_NAME
	) as Sprite2D
	if preview_sprite == null:
		preview_sprite = Sprite2D.new()
		preview_sprite.name = PREVIEW_SPRITE_NAME
		preview_sprite.centered = false
		preview_sprite.z_as_relative = false
		add_child(preview_sprite, false, Node.INTERNAL_MODE_BACK)
	var preview_bounds := get_node_or_null(
		PREVIEW_BOUNDS_NAME
	) as Line2D
	if preview_bounds == null:
		preview_bounds = Line2D.new()
		preview_bounds.name = PREVIEW_BOUNDS_NAME
		preview_bounds.width = 2.0
		preview_bounds.default_color = PREVIEW_BOUND_COLOR
		preview_bounds.z_as_relative = false
		add_child(preview_bounds, false, Node.INTERNAL_MODE_BACK)


func _refresh_editor_preview() -> void:
	_ensure_editor_preview_nodes()
	var preview_sprite := get_node_or_null(
		PREVIEW_SPRITE_NAME
	) as Sprite2D
	var preview_bounds := get_node_or_null(
		PREVIEW_BOUNDS_NAME
	) as Line2D
	if preview_sprite == null or preview_bounds == null:
		return
	var battlefield := _get_battlefield()
	var anchor := get_parent() as AuthoredAnchor
	var should_show: bool = (
		battlefield != null
		and anchor != null
		and battlefield.show_battler_previews
		and show_battler_preview
	)
	preview_sprite.visible = should_show
	preview_bounds.visible = should_show and (
		battlefield.show_battler_preview_bounds if battlefield != null else false
	)
	if not should_show:
		return
	var preview: Dictionary = battlefield.get_battler_preview_for_position(
		anchor,
		self
	)
	var texture: Texture2D = preview.get("texture") as Texture2D
	if texture == null:
		preview_sprite.visible = false
		preview_bounds.visible = false
		return
	var sprite_position: Vector2 = preview.get(
		"sprite_position",
		Vector2.ZERO
	) as Vector2
	var sprite_scale: Vector2 = preview.get(
		"sprite_scale",
		Vector2.ONE
	) as Vector2
	var preview_size: Vector2 = texture.get_size() * sprite_scale
	var visual_order: int = int(preview.get("visual_order", 0))
	preview_sprite.texture = texture
	preview_sprite.position = sprite_position
	preview_sprite.scale = sprite_scale
	preview_sprite.modulate = Color(
		1.0,
		1.0,
		1.0,
		battlefield.preview_opacity
	)
	preview_sprite.z_index = visual_order + BattleMarker.CHARACTER_ART_Z_OFFSET
	preview_bounds.position = Vector2.ZERO
	preview_bounds.points = PackedVector2Array([
		sprite_position,
		sprite_position + Vector2(preview_size.x, 0.0),
		sprite_position + preview_size,
		sprite_position + Vector2(0.0, preview_size.y),
		sprite_position,
	])
	preview_bounds.z_index = visual_order + 1


func has_connected_position_references() -> bool:
	return not connected_positions.is_empty()


func get_connected_positions() -> Array[AuthoredPosition]:
	var results: Array[AuthoredPosition] = []
	var seen_instance_ids: Dictionary = {}
	for connected_position: AuthoredPosition in connected_positions:
		if connected_position == null:
			continue
		var instance_id := connected_position.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		results.append(connected_position)
	return results


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 13.0, FILL_COLOR)
	draw_arc(
		Vector2.ZERO,
		17.0,
		0.0,
		TAU,
		24,
		OUTLINE_COLOR,
		2.0,
		true
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-16.0, 5.0),
		"P%d" % (position_index + 1),
		HORIZONTAL_ALIGNMENT_CENTER,
		32.0,
		12,
		Color.WHITE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-28.0, 33.0),
		"Z %d" % get_effective_visual_order(),
		HORIZONTAL_ALIGNMENT_CENTER,
		56.0,
		11,
		Color(0.94, 0.83, 0.36, 0.96)
	)
