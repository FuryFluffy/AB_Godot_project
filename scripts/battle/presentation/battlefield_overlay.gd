class_name BattlefieldOverlay
extends Node2D


const CONNECTION_COLOR := Color(0.43, 0.78, 0.78, 0.46)
const ZONE_FILL_COLOR := Color(1.0, 1.0, 1.0, 0.045)
const ZONE_BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.32)
const ENGAGEMENT_FILL_COLOR := Color(0.26, 0.73, 0.72, 0.055)
const ENGAGEMENT_BORDER_COLOR := Color(0.26, 0.73, 0.72, 0.46)
const POSITION_COLOR := Color(0.78, 0.72, 0.58, 0.72)
const COVER_COLOR := Color(1.0, 0.74, 0.22, 0.9)
const SIGHT_BLOCK_COLOR := Color(0.85, 0.3, 0.96, 0.9)


@export var debug_geometry_visible: bool = false

var battlefield_definition: BattlefieldDefinition
var battlefield_state: BattlefieldState
var battler_states: Dictionary = {}


func initialize(
	new_definition: BattlefieldDefinition,
	new_state: BattlefieldState,
	new_battler_states: Dictionary
) -> void:
	battlefield_definition = new_definition
	battlefield_state = new_state
	battler_states = new_battler_states
	queue_redraw()


func set_debug_visible(enabled: bool) -> void:
	debug_geometry_visible = enabled
	queue_redraw()


func set_selected_battler(_battler_id: StringName) -> void:
	# Selection is now drawn contextually by BattlefieldInteractionOverlay.
	pass


func show_move_preview(
	_preview: MovementPreview,
	_destination_position_index: int
) -> void:
	# Movement routes are now drawn contextually by the interaction overlay.
	pass


func clear_move_preview() -> void:
	pass


func set_targeting_contacts(
	_active: bool,
	_actor_id: StringName = &"",
	_legal_target_ids: Array[StringName] = []
) -> void:
	# Position contacts define combat legality but are intentionally not drawn
	# in player-facing overlays. Legal targets remain visible on battler markers.
	pass


func _draw() -> void:
	if battlefield_definition == null:
		return
	if not debug_geometry_visible:
		return

	_draw_zones()
	_draw_connections()
	_draw_engagement_areas()
	_draw_terrain_lines()



func _draw_zones() -> void:
	for zone: BattleZoneDefinition in battlefield_definition.zones:
		if zone == null or zone.polygon_points.size() < 3:
			continue
		var polygon := PackedVector2Array(zone.polygon_points)
		draw_colored_polygon(polygon, ZONE_FILL_COLOR)
		_draw_polygon_outline(polygon, ZONE_BORDER_COLOR, 1.5)
		draw_string(
			ThemeDB.fallback_font,
			zone.map_center + Vector2(-110.0, 0.0),
			zone.display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			220.0,
			16,
			ZONE_BORDER_COLOR
		)


func _draw_connections() -> void:
	for anchor: AnchorDefinition in battlefield_definition.anchors:
		if anchor == null:
			continue
		for connected_anchor_id: StringName in anchor.connected_anchor_ids:
			if String(anchor.anchor_id) > String(connected_anchor_id):
				continue
			var connected := battlefield_definition.get_anchor(
				connected_anchor_id
			)
			if connected == null:
				continue
			draw_line(
				anchor.get_center(),
				connected.get_center(),
				CONNECTION_COLOR,
				2.0,
				true
			)


func _draw_engagement_areas() -> void:
	for anchor: AnchorDefinition in battlefield_definition.anchors:
		if anchor == null:
			continue
		var polygon := anchor.get_engagement_polygon()
		draw_colored_polygon(polygon, ENGAGEMENT_FILL_COLOR)
		_draw_polygon_outline(polygon, ENGAGEMENT_BORDER_COLOR, 2.0)
		for position_index: int in range(anchor.capacity):
			draw_circle(
				anchor.get_position_point(position_index),
				8.0,
				POSITION_COLOR
			)


func _draw_terrain_lines() -> void:
	for terrain_line: TerrainLineDefinition in (
		battlefield_definition.terrain_lines
	):
		if terrain_line == null:
			continue
		var line_color := (
			SIGHT_BLOCK_COLOR
			if terrain_line.blocks_line_of_sight
			else COVER_COLOR
		)
		draw_line(
			terrain_line.start_point,
			terrain_line.end_point,
			line_color,
			3.0,
			true
		)


func _draw_polygon_outline(
	polygon: PackedVector2Array,
	line_color: Color,
	width: float
) -> void:
	if polygon.size() < 3:
		return
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, line_color, width, true)
