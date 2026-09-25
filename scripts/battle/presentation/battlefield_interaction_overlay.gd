class_name BattlefieldInteractionOverlay
extends Node2D


signal move_preview_changed(
	preview: MovementPreview,
	destination_position_index: int
)
signal move_confirmed(
	preview: MovementPreview,
	destination_position_index: int
)
signal aoe_zone_confirmed(zone_id: StringName)
signal dodge_step_confirmed(
	anchor_id: StringName,
	position_index: int
)
signal selection_cancelled
signal selection_visibility_changed(active: bool)


enum SelectionMode {
	NONE,
	MOVE,
	AOE,
	DODGE_STEP,
}


const POSITION_HIT_RADIUS := 34.0

# One contextual battlefield language:
# white = broad BattleZone, teal = Engagement Area, gold = choice/path,
# red = danger, and the active ability colour = AOE preview.
const ZONE_CONTEXT_FILL := Color(1.0, 1.0, 1.0, 0.045)
const ZONE_CONTEXT_BORDER := Color(1.0, 1.0, 1.0, 0.42)
const ZONE_LEGAL_FILL := Color(1.0, 1.0, 1.0, 0.085)
const ENGAGEMENT_CONTEXT_FILL := Color(0.24, 0.72, 0.72, 0.025)
const ENGAGEMENT_CONTEXT_BORDER := Color(0.38, 0.78, 0.77, 0.38)
const ENGAGEMENT_LEGAL := Color(0.28, 0.82, 0.80, 0.94)
const SELECTED_GOLD := Color(0.96, 0.78, 0.30, 0.98)
const THREAT_RED := Color(0.94, 0.29, 0.20, 0.98)
const AOE_ABILITY_COLOR := Color(0.62, 0.34, 0.78, 0.92)
const TEXT_COLOR := Color(0.94, 0.96, 0.95, 0.96)


var battlefield_definition: BattlefieldDefinition
var battlefield_state: BattlefieldState

var selection_mode: SelectionMode = SelectionMode.NONE
var move_previews: Array[MovementPreview] = []
var move_path: Array[StringName] = []
var legal_zone_ids: Array[StringName] = []
var dodge_destinations: Array[Dictionary] = []
var selection_title := ""

var hovered_anchor_id: StringName = &""
var hovered_zone_id: StringName = &""
var hovered_position_anchor_id: StringName = &""
var hovered_position_index := -1


func _ready() -> void:
	set_process_input(false)
	visible = true


func initialize(
	new_definition: BattlefieldDefinition,
	new_state: BattlefieldState
) -> void:
	battlefield_definition = new_definition
	battlefield_state = new_state
	clear_selection()


func begin_move_selection(
	previews: Array[MovementPreview],
	mover_name: String
) -> void:
	clear_selection()
	if previews.is_empty():
		return

	move_previews = previews.duplicate()
	for preview: MovementPreview in move_previews:
		if (
			preview != null
			and preview.is_valid
			and not preview.anchor_path.is_empty()
		):
			move_path = [preview.anchor_path[0]]
			break

	if move_path.is_empty():
		clear_selection()
		return

	selection_mode = SelectionMode.MOVE
	selection_title = (
		"%s — choose an Engagement Area, then a Position"
		% mover_name
	)
	set_process_input(true)
	selection_visibility_changed.emit(true)
	queue_redraw()


func begin_aoe_selection(
	new_legal_zone_ids: Array[StringName],
	ability_name: String
) -> void:
	clear_selection()
	legal_zone_ids = new_legal_zone_ids.duplicate()
	if legal_zone_ids.is_empty():
		return

	selection_mode = SelectionMode.AOE
	selection_title = "%s — choose a BattleZone" % ability_name
	set_process_input(true)
	selection_visibility_changed.emit(true)
	queue_redraw()


func begin_dodge_step_selection(
	destinations: Array[Dictionary],
	defender_name: String
) -> void:
	clear_selection()
	dodge_destinations = destinations.duplicate(true)
	if dodge_destinations.is_empty():
		return
	selection_mode = SelectionMode.DODGE_STEP
	selection_title = (
		"%s — choose a Position, or right-click / press Esc to stay"
		% defender_name
	)
	set_process_input(true)
	selection_visibility_changed.emit(true)
	queue_redraw()


func clear_selection() -> void:
	var was_active: bool = selection_mode != SelectionMode.NONE
	selection_mode = SelectionMode.NONE
	move_previews.clear()
	move_path.clear()
	legal_zone_ids.clear()
	dodge_destinations.clear()
	selection_title = ""
	_clear_hover()
	set_process_input(false)
	if was_active:
		selection_visibility_changed.emit(false)
	queue_redraw()


func get_next_move_anchor_ids() -> Array[StringName]:
	var anchor_ids: Array[StringName] = []
	if selection_mode != SelectionMode.MOVE:
		return anchor_ids

	for preview: MovementPreview in move_previews:
		if (
			preview == null
			or not preview.is_valid
			or not _path_has_prefix(preview.anchor_path, move_path)
			or preview.anchor_path.size() <= move_path.size()
		):
			continue
		var next_anchor_id := preview.anchor_path[move_path.size()]
		if not anchor_ids.has(next_anchor_id):
			anchor_ids.append(next_anchor_id)

	anchor_ids.sort()
	return anchor_ids


func choose_next_move_anchor(anchor_id: StringName) -> bool:
	if not get_next_move_anchor_ids().has(anchor_id):
		return false

	move_path.append(anchor_id)
	var preview := _find_preview_for_path(move_path)
	if (
		preview != null
		and not preview.available_destination_positions.is_empty()
	):
		move_preview_changed.emit(
			preview,
			preview.available_destination_positions[0]
		)

	_clear_hover()
	queue_redraw()
	return true


func choose_move_position(
	anchor_id: StringName,
	position_index: int
) -> bool:
	if selection_mode != SelectionMode.MOVE:
		return false

	var current_preview := _find_preview_for_path(move_path)
	if (
		current_preview != null
		and current_preview.destination_anchor_id == anchor_id
		and current_preview.available_destination_positions.has(
			position_index
		)
	):
		move_preview_changed.emit(current_preview, position_index)
		move_confirmed.emit(current_preview, position_index)
		return true

	return false


func backtrack_move_path(anchor_id: StringName) -> bool:
	if selection_mode != SelectionMode.MOVE or move_path.size() <= 1:
		return false

	var anchor_index := move_path.find(anchor_id)
	if anchor_index < 0 or anchor_index >= move_path.size() - 1:
		return false

	move_path.resize(anchor_index + 1)
	var preview := _find_preview_for_path(move_path)
	if (
		preview != null
		and not preview.available_destination_positions.is_empty()
	):
		move_preview_changed.emit(
			preview,
			preview.available_destination_positions[0]
		)

	_clear_hover()
	queue_redraw()
	return true


func choose_aoe_zone(zone_id: StringName) -> bool:
	if (
		selection_mode != SelectionMode.AOE
		or not legal_zone_ids.has(zone_id)
	):
		return false
	aoe_zone_confirmed.emit(zone_id)
	return true


func choose_dodge_step(
	anchor_id: StringName,
	position_index: int
) -> bool:
	if selection_mode != SelectionMode.DODGE_STEP:
		return false
	for destination: Dictionary in dodge_destinations:
		if (
			destination.get("anchor_id", &"") == anchor_id
			and int(destination.get("position_index", -1))
			== position_index
		):
			dodge_step_confirmed.emit(anchor_id, position_index)
			return true
	return false


func _input(event: InputEvent) -> void:
	if selection_mode == SelectionMode.NONE:
		return

	if event is InputEventMouseMotion:
		_update_hover(to_local((event as InputEventMouseMotion).position))
		return

	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	):
		selection_cancelled.emit()
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		selection_cancelled.emit()
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if handle_board_click(mouse_event.position):
		get_viewport().set_input_as_handled()


func handle_board_click(viewport_point: Vector2) -> bool:
	var local_point := to_local(viewport_point)
	match selection_mode:
		SelectionMode.MOVE:
			return _handle_move_click(local_point)
		SelectionMode.AOE:
			return _handle_aoe_click(local_point)
		SelectionMode.DODGE_STEP:
			return _handle_dodge_click(local_point)
	return false


func _handle_move_click(local_point: Vector2) -> bool:
	var current_preview := _find_preview_for_path(move_path)
	if current_preview != null:
		var current_anchor := battlefield_definition.get_anchor(
			current_preview.destination_anchor_id
		)
		if current_anchor != null:
			for position_index: int in (
				current_preview.available_destination_positions
			):
				if local_point.distance_to(
					current_anchor.get_position_point(position_index)
				) <= POSITION_HIT_RADIUS:
					return choose_move_position(
						current_anchor.anchor_id,
						position_index
					)

	for path_index: int in range(move_path.size() - 1):
		var previous_anchor := battlefield_definition.get_anchor(
			move_path[path_index]
		)
		if (
			previous_anchor != null
			and previous_anchor.contains_engagement_point(local_point)
		):
			return backtrack_move_path(previous_anchor.anchor_id)

	for next_anchor_id: StringName in get_next_move_anchor_ids():
		var next_anchor := battlefield_definition.get_anchor(next_anchor_id)
		if (
			next_anchor != null
			and next_anchor.contains_engagement_point(local_point)
		):
			return choose_next_move_anchor(next_anchor_id)
	return false


func _handle_aoe_click(local_point: Vector2) -> bool:
	for zone_id: StringName in legal_zone_ids:
		var zone := battlefield_definition.get_zone(zone_id)
		if zone != null and zone.contains_point(local_point):
			return choose_aoe_zone(zone_id)
	return false


func _handle_dodge_click(local_point: Vector2) -> bool:
	for destination: Dictionary in dodge_destinations:
		var anchor_id := StringName(destination.get("anchor_id", &""))
		var position_index := int(destination.get("position_index", -1))
		var anchor := battlefield_definition.get_anchor(anchor_id)
		if (
			anchor != null
			and local_point.distance_to(
				anchor.get_position_point(position_index)
			) <= POSITION_HIT_RADIUS
		):
			return choose_dodge_step(anchor_id, position_index)
	return false


func _find_preview_for_path(
	path: Array[StringName]
) -> MovementPreview:
	for preview: MovementPreview in move_previews:
		if (
			preview != null
			and preview.is_valid
			and _paths_match(preview.anchor_path, path)
		):
			return preview
	return null


func _path_has_prefix(
	full_path: Array[StringName],
	prefix: Array[StringName]
) -> bool:
	if full_path.size() < prefix.size():
		return false
	for path_index: int in range(prefix.size()):
		if full_path[path_index] != prefix[path_index]:
			return false
	return true


func _paths_match(
	first_path: Array[StringName],
	second_path: Array[StringName]
) -> bool:
	return (
		first_path.size() == second_path.size()
		and _path_has_prefix(first_path, second_path)
	)


func _update_hover(local_point: Vector2) -> void:
	var previous_state := [
		hovered_anchor_id,
		hovered_zone_id,
		hovered_position_anchor_id,
		hovered_position_index,
	]
	_clear_hover()

	match selection_mode:
		SelectionMode.MOVE:
			_update_move_hover(local_point)
		SelectionMode.AOE:
			for zone_id: StringName in legal_zone_ids:
				var zone := battlefield_definition.get_zone(zone_id)
				if zone != null and zone.contains_point(local_point):
					hovered_zone_id = zone_id
					break
		SelectionMode.DODGE_STEP:
			_update_dodge_hover(local_point)

	var current_state := [
		hovered_anchor_id,
		hovered_zone_id,
		hovered_position_anchor_id,
		hovered_position_index,
	]
	if current_state != previous_state:
		queue_redraw()


func _update_move_hover(local_point: Vector2) -> void:
	var current_preview := _find_preview_for_path(move_path)
	if current_preview != null:
		var current_anchor := battlefield_definition.get_anchor(
			current_preview.destination_anchor_id
		)
		if current_anchor != null:
			for position_index: int in (
				current_preview.available_destination_positions
			):
				if local_point.distance_to(
					current_anchor.get_position_point(position_index)
				) <= POSITION_HIT_RADIUS:
					hovered_position_anchor_id = current_anchor.anchor_id
					hovered_position_index = position_index
					return

	for next_anchor_id: StringName in get_next_move_anchor_ids():
		var next_anchor := battlefield_definition.get_anchor(next_anchor_id)
		if (
			next_anchor != null
			and next_anchor.contains_engagement_point(local_point)
		):
			hovered_anchor_id = next_anchor_id
			return


func _update_dodge_hover(local_point: Vector2) -> void:
	for destination: Dictionary in dodge_destinations:
		var anchor_id := StringName(destination.get("anchor_id", &""))
		var position_index := int(destination.get("position_index", -1))
		var anchor := battlefield_definition.get_anchor(anchor_id)
		if (
			anchor != null
			and local_point.distance_to(
				anchor.get_position_point(position_index)
			) <= POSITION_HIT_RADIUS
		):
			hovered_position_anchor_id = anchor_id
			hovered_position_index = position_index
			return


func _clear_hover() -> void:
	hovered_anchor_id = &""
	hovered_zone_id = &""
	hovered_position_anchor_id = &""
	hovered_position_index = -1


func _draw() -> void:
	if selection_mode == SelectionMode.NONE or battlefield_definition == null:
		return

	draw_string(
		ThemeDB.fallback_font,
		Vector2(460.0, 108.0),
		selection_title,
		HORIZONTAL_ALIGNMENT_CENTER,
		1000.0,
		20,
		TEXT_COLOR
	)

	match selection_mode:
		SelectionMode.MOVE:
			_draw_move_selection()
		SelectionMode.AOE:
			_draw_aoe_selection()
		SelectionMode.DODGE_STEP:
			_draw_dodge_step_selection()


func _draw_move_selection() -> void:
	# Broad BattleZones remain the stable white scaffold.
	for zone: BattleZoneDefinition in battlefield_definition.zones:
		if zone == null:
			continue
		_draw_zone(
			zone,
			ZONE_CONTEXT_FILL,
			ZONE_CONTEXT_BORDER,
			1.5
		)

	# Teal internal borders reveal the Engagement Areas only while movement
	# or local occupancy matters.
	for anchor: AnchorDefinition in battlefield_definition.anchors:
		if anchor == null:
			continue
		_draw_engagement_area(
			anchor,
			ENGAGEMENT_CONTEXT_FILL,
			ENGAGEMENT_CONTEXT_BORDER,
			1.5
		)

	for path_index: int in range(1, move_path.size()):
		var previous_anchor := battlefield_definition.get_anchor(
			move_path[path_index - 1]
		)
		var current_anchor := battlefield_definition.get_anchor(
			move_path[path_index]
		)
		if previous_anchor == null or current_anchor == null:
			continue
		var segment_color := SELECTED_GOLD
		var segment_path: Array[StringName] = []
		for segment_path_index: int in range(path_index + 1):
			segment_path.append(move_path[segment_path_index])
		var preview := _find_preview_for_path(segment_path)
		if (
			preview != null
			and preview.hostile_step_anchor_ids.has(
				current_anchor.anchor_id
			)
		):
			segment_color = THREAT_RED
		draw_line(
			previous_anchor.get_center(),
			current_anchor.get_center(),
			segment_color,
			4.0,
			true
		)

	for path_anchor_id: StringName in move_path:
		var path_anchor := battlefield_definition.get_anchor(path_anchor_id)
		if path_anchor != null:
			_draw_engagement_area(
				path_anchor,
				Color(SELECTED_GOLD.r, SELECTED_GOLD.g, SELECTED_GOLD.b, 0.11),
				SELECTED_GOLD,
				3.0
			)

	var current_anchor := battlefield_definition.get_anchor(
		move_path[move_path.size() - 1]
	)
	for next_anchor_id: StringName in get_next_move_anchor_ids():
		var next_anchor := battlefield_definition.get_anchor(next_anchor_id)
		if next_anchor == null:
			continue
		var next_color := _get_next_area_color(next_anchor_id)
		if hovered_anchor_id == next_anchor_id and next_color != THREAT_RED:
			next_color = SELECTED_GOLD
		if current_anchor != null:
			draw_line(
				current_anchor.get_center(),
				next_anchor.get_center(),
				Color(next_color.r, next_color.g, next_color.b, 0.64),
				2.5,
				true
			)
		_draw_engagement_area(
			next_anchor,
			Color(next_color.r, next_color.g, next_color.b, 0.095),
			next_color,
			3.0
		)

	var current_preview := _find_preview_for_path(move_path)
	if current_preview != null:
		_draw_destination_positions(current_preview)


func _get_next_area_color(anchor_id: StringName) -> Color:
	var next_path: Array[StringName] = move_path.duplicate()
	next_path.append(anchor_id)
	var preview := _find_preview_for_path(next_path)
	if (
		preview != null
		and preview.hostile_step_anchor_ids.has(anchor_id)
	):
		return THREAT_RED
	return ENGAGEMENT_LEGAL


func _draw_destination_positions(preview: MovementPreview) -> void:
	var anchor := battlefield_definition.get_anchor(
		preview.destination_anchor_id
	)
	if anchor == null:
		return
	for position_index: int in preview.available_destination_positions:
		var reticle_color := (
			THREAT_RED
			if preview.is_destination_position_threatened(position_index)
			else SELECTED_GOLD
		)
		if (
			hovered_position_anchor_id == anchor.anchor_id
			and hovered_position_index == position_index
		):
			reticle_color = Color(1.0, 0.93, 0.62, 1.0)
		_draw_position_reticle(
			anchor.get_position_point(position_index),
			reticle_color
		)


func _draw_aoe_selection() -> void:
	for zone_id: StringName in legal_zone_ids:
		var zone := battlefield_definition.get_zone(zone_id)
		if zone == null:
			continue
		var fill_color := ZONE_LEGAL_FILL
		var border_color := ZONE_CONTEXT_BORDER
		var width := 2.5
		if hovered_zone_id == zone_id:
			fill_color = Color(
				AOE_ABILITY_COLOR.r,
				AOE_ABILITY_COLOR.g,
				AOE_ABILITY_COLOR.b,
				0.22
			)
			border_color = SELECTED_GOLD
			width = 4.0
		_draw_zone(zone, fill_color, border_color, width)

	if hovered_zone_id != &"":
		var hovered_zone := battlefield_definition.get_zone(hovered_zone_id)
		if hovered_zone != null:
			draw_string(
				ThemeDB.fallback_font,
				hovered_zone.map_center + Vector2(-100.0, 6.0),
				hovered_zone.display_name,
				HORIZONTAL_ALIGNMENT_CENTER,
				200.0,
				17,
				TEXT_COLOR
			)


func _draw_dodge_step_selection() -> void:
	var drawn_zone_ids: Array[StringName] = []
	var drawn_anchor_ids: Array[StringName] = []
	for destination: Dictionary in dodge_destinations:
		var anchor_id := StringName(destination.get("anchor_id", &""))
		var position_index := int(destination.get("position_index", -1))
		var anchor := battlefield_definition.get_anchor(anchor_id)
		if anchor == null:
			continue
		if not drawn_zone_ids.has(anchor.zone_id):
			var zone := battlefield_definition.get_zone(anchor.zone_id)
			if zone != null:
				_draw_zone(
					zone,
					ZONE_CONTEXT_FILL,
					ZONE_CONTEXT_BORDER,
					1.5
				)
			drawn_zone_ids.append(anchor.zone_id)
		if not drawn_anchor_ids.has(anchor_id):
			_draw_engagement_area(
				anchor,
				ENGAGEMENT_CONTEXT_FILL,
				ENGAGEMENT_LEGAL,
				2.5
			)
			drawn_anchor_ids.append(anchor_id)
		var reticle_color := ENGAGEMENT_LEGAL
		if (
			hovered_position_anchor_id == anchor_id
			and hovered_position_index == position_index
		):
			reticle_color = SELECTED_GOLD
		_draw_position_reticle(
			anchor.get_position_point(position_index),
			reticle_color
		)



func _draw_zone(
	zone: BattleZoneDefinition,
	fill_color: Color,
	border_color: Color,
	width: float
) -> void:
	if zone.polygon_points.size() < 3:
		return
	var polygon := PackedVector2Array(zone.polygon_points)
	draw_colored_polygon(polygon, fill_color)
	_draw_polygon_outline(polygon, border_color, width)


func _draw_engagement_area(
	anchor: AnchorDefinition,
	fill_color: Color,
	border_color: Color,
	width: float
) -> void:
	var polygon := anchor.get_engagement_polygon()
	if polygon.size() < 3:
		return
	draw_colored_polygon(polygon, fill_color)
	_draw_polygon_outline(polygon, border_color, width)


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


func _draw_position_reticle(point: Vector2, reticle_color: Color) -> void:
	draw_circle(
		point,
		6.0,
		Color(reticle_color.r, reticle_color.g, reticle_color.b, 0.46)
	)
	for corner_index: int in range(4):
		var start_angle := corner_index * PI * 0.5 + 0.13
		draw_arc(
			point,
			20.0,
			start_angle,
			start_angle + 0.48,
			5,
			reticle_color,
			3.0,
			true
		)
