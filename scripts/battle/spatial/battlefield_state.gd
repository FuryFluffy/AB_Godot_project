class_name BattlefieldState
extends RefCounted


signal position_changed(
	battler_id: StringName,
	anchor_id: StringName,
	position_index: int
)


enum SpatialRange {
	ADJACENT,
	CLOSE,
	FAR,
	VERY_FAR,
	BEYOND,
}


var definition: BattlefieldDefinition
var battler_states: Dictionary = {}
var battler_positions: Dictionary = {}
var over_capacity_anchor_by_battler: Dictionary = {}


func initialize(
	new_definition: BattlefieldDefinition,
	new_battler_states: Dictionary
) -> String:
	definition = new_definition
	battler_states = new_battler_states
	battler_positions.clear()
	over_capacity_anchor_by_battler.clear()

	var validation_error: String = _validate_definition()
	if not validation_error.is_empty():
		return validation_error

	for placement: BattlerPlacementDefinition in (
		definition.initial_placements
	):
		# A battlefield may describe every roster slot while a concrete
		# encounter instantiates only its selected composition.
		if not battler_states.has(placement.battler_id):
			continue
		var placement_error: String = place_battler(
			placement.battler_id,
			placement.anchor_id,
			placement.position_index,
			false
		)
		if not placement_error.is_empty():
			battler_positions.clear()
			return placement_error

	return ""


func get_battler_position(
	battler_id: StringName
) -> BattlerPositionState:
	return battler_positions.get(
		battler_id
	) as BattlerPositionState


func get_battler_at(
	anchor_id: StringName,
	position_index: int
) -> StringName:
	var battlers_at_position: Array[StringName] = get_battlers_at(
		anchor_id,
		position_index
	)
	if battlers_at_position.is_empty():
		return &""
	return battlers_at_position[0]


func get_battlers_at(
	anchor_id: StringName,
	position_index: int
) -> Array[StringName]:
	var battlers_at_position: Array[StringName] = []
	for position_value: Variant in battler_positions.values():
		var position_state: BattlerPositionState = (
			position_value as BattlerPositionState
		)
		if (
			position_state != null
			and position_state.anchor_id == anchor_id
			and position_state.position_index == position_index
		):
			battlers_at_position.append(position_state.battler_id)

	battlers_at_position.sort()
	return battlers_at_position


func get_occupants(
	anchor_id: StringName,
	excluding_battler_id: StringName = &""
) -> Array[StringName]:
	var occupants: Array[StringName] = []

	for position_value: Variant in battler_positions.values():
		var position_state: BattlerPositionState = (
			position_value as BattlerPositionState
		)
		if (
			position_state == null
			or position_state.anchor_id != anchor_id
			or position_state.battler_id == excluding_battler_id
		):
			continue

		occupants.append(position_state.battler_id)

	occupants.sort()
	return occupants


func get_adjacent_battler_ids_to_position(
	anchor_id: StringName,
	position_index: int,
	excluding_battler_id: StringName = &""
) -> Array[StringName]:
	var adjacent_ids: Array[StringName] = []
	for position_value: Variant in battler_positions.values():
		var position_state := position_value as BattlerPositionState
		if (
			position_state == null
			or position_state.battler_id == excluding_battler_id
		):
			continue
		if are_positions_adjacent(
			anchor_id,
			position_index,
			position_state.anchor_id,
			position_state.position_index
		):
			adjacent_ids.append(position_state.battler_id)
	adjacent_ids.sort()
	return adjacent_ids


func get_free_position_indices(
	anchor_id: StringName,
	excluding_battler_id: StringName = &""
) -> Array[int]:
	var free_positions: Array[int] = []
	var anchor: AnchorDefinition = definition.get_anchor(
		anchor_id
	)
	if anchor == null:
		return free_positions

	for position_index: int in range(anchor.capacity):
		var occupant_ids: Array[StringName] = get_battlers_at(
			anchor_id,
			position_index
		)
		occupant_ids.erase(excluding_battler_id)
		if occupant_ids.is_empty():
			free_positions.append(position_index)

	return free_positions


func is_battler_over_capacity(
	battler_id: StringName
) -> bool:
	return over_capacity_anchor_by_battler.has(battler_id)


func is_anchor_over_capacity(
	anchor_id: StringName
) -> bool:
	return over_capacity_anchor_by_battler.values().has(anchor_id)


func get_over_capacity_battler_ids(
	anchor_id: StringName
) -> Array[StringName]:
	var battler_ids: Array[StringName] = []
	for battler_id: Variant in over_capacity_anchor_by_battler.keys():
		if (
			over_capacity_anchor_by_battler.get(battler_id)
			== anchor_id
		):
			battler_ids.append(StringName(battler_id))
	battler_ids.sort()
	return battler_ids


func place_battler(
	battler_id: StringName,
	anchor_id: StringName,
	position_index: int,
	emit_change: bool = true,
	allow_over_capacity_anchor: bool = false
) -> String:
	if not battler_states.has(battler_id):
		return "No BattlerState exists for placement '%s'." % (
			battler_id
		)

	var anchor: AnchorDefinition = definition.get_anchor(
		anchor_id
	)
	if anchor == null:
		return "Placement anchor '%s' does not exist." % (
			anchor_id
		)

	if position_index < 0 or position_index >= anchor.capacity:
		return "Position %d is outside anchor '%s'." % [
			position_index,
			anchor.display_name,
		]

	var current_position: BattlerPositionState = get_battler_position(
		battler_id
	)
	if (
		is_battler_over_capacity(battler_id)
		and current_position != null
		and current_position.anchor_id == anchor_id
		and not allow_over_capacity_anchor
	):
		return (
			"%s is over capacity in '%s' and its next movement must leave the Anchor."
			% [battler_id, anchor.display_name]
		)
	if (
		is_anchor_over_capacity(anchor_id)
		and not allow_over_capacity_anchor
	):
		return (
			"Anchor '%s' is over capacity and cannot accept voluntary entry."
			% anchor.display_name
		)

	var occupant_ids: Array[StringName] = get_battlers_at(
		anchor_id,
		position_index
	)
	occupant_ids.erase(battler_id)
	if not occupant_ids.is_empty():
		return "Anchor '%s' position %d is already occupied." % [
			anchor.display_name,
			position_index + 1,
		]

	var position_state: BattlerPositionState = current_position
	if position_state == null:
		position_state = BattlerPositionState.new(
			battler_id,
			anchor_id,
			position_index
		)
		battler_positions[battler_id] = position_state
	else:
		position_state.anchor_id = anchor_id
		position_state.position_index = position_index
	over_capacity_anchor_by_battler.erase(battler_id)

	if emit_change:
		position_changed.emit(
			battler_id,
			anchor_id,
			position_index
		)

	return ""


func force_place_battler_over_capacity(
	battler_id: StringName,
	anchor_id: StringName,
	display_position_index: int
) -> String:
	if not battler_states.has(battler_id):
		return "No BattlerState exists for over-capacity placement '%s'." % (
			battler_id
		)
	var anchor: AnchorDefinition = definition.get_anchor(anchor_id)
	if anchor == null:
		return "Over-capacity anchor '%s' does not exist." % anchor_id
	if (
		display_position_index < 0
		or display_position_index >= anchor.capacity
	):
		return "Over-capacity display Position %d is outside '%s'." % [
			display_position_index,
			anchor.display_name,
		]

	var position_state: BattlerPositionState = get_battler_position(
		battler_id
	)
	if position_state == null:
		position_state = BattlerPositionState.new(
			battler_id,
			anchor_id,
			display_position_index
		)
		battler_positions[battler_id] = position_state
	else:
		position_state.anchor_id = anchor_id
		position_state.position_index = display_position_index
	over_capacity_anchor_by_battler[battler_id] = anchor_id
	position_changed.emit(
		battler_id,
		anchor_id,
		display_position_index
	)
	return ""


func bundle_battler_with(
	battler_id: StringName,
	cluster_owner_id: StringName
) -> String:
	var owner_position: BattlerPositionState = get_battler_position(
		cluster_owner_id
	)
	if owner_position == null:
		return "Cluster owner '%s' has no battlefield Position." % (
			cluster_owner_id
		)
	if not battler_states.has(battler_id):
		return "No BattlerState exists for bundled battler '%s'." % (
			battler_id
		)

	var position_state: BattlerPositionState = get_battler_position(
		battler_id
	)
	if position_state == null:
		position_state = BattlerPositionState.new(
			battler_id,
			owner_position.anchor_id,
			owner_position.position_index
		)
		battler_positions[battler_id] = position_state
	else:
		position_state.anchor_id = owner_position.anchor_id
		position_state.position_index = owner_position.position_index
	over_capacity_anchor_by_battler.erase(battler_id)

	position_changed.emit(
		battler_id,
		owner_position.anchor_id,
		owner_position.position_index
	)
	return ""


func get_world_position(
	battler_id: StringName
) -> Vector2:
	var position_state: BattlerPositionState = (
		get_battler_position(battler_id)
	)
	if position_state == null:
		return Vector2.ZERO

	var anchor: AnchorDefinition = definition.get_anchor(
		position_state.anchor_id
	)
	if anchor == null:
		return Vector2.ZERO

	return anchor.get_position_point(
		position_state.position_index
	)


func get_battler_anchor(
	battler_id: StringName
) -> AnchorDefinition:
	var position_state: BattlerPositionState = (
		get_battler_position(battler_id)
	)
	if position_state == null or definition == null:
		return null

	return definition.get_anchor(position_state.anchor_id)


func are_battler_anchors_connected(
	first_battler_id: StringName,
	second_battler_id: StringName
) -> bool:
	var first_anchor: AnchorDefinition = get_battler_anchor(
		first_battler_id
	)
	var second_anchor: AnchorDefinition = get_battler_anchor(
		second_battler_id
	)
	if first_anchor == null or second_anchor == null:
		return false

	return first_anchor.connected_anchor_ids.has(
		second_anchor.anchor_id
	)


func get_line_blocker_names(
	first_battler_id: StringName,
	second_battler_id: StringName
) -> Array[String]:
	return _get_intersecting_terrain_names(
		first_battler_id,
		second_battler_id,
		true
	)


func get_ranged_cover_names(
	first_battler_id: StringName,
	second_battler_id: StringName
) -> Array[String]:
	return _get_intersecting_terrain_names(
		first_battler_id,
		second_battler_id,
		false
	)


func has_line_of_sight(
	first_battler_id: StringName,
	second_battler_id: StringName
) -> bool:
	return get_line_blocker_names(
		first_battler_id,
		second_battler_id
	).is_empty()


func has_ranged_cover_between(
	first_battler_id: StringName,
	second_battler_id: StringName
) -> bool:
	return not get_ranged_cover_names(
		first_battler_id,
		second_battler_id
	).is_empty()


func are_adjacent(
	first_battler_id: StringName,
	second_battler_id: StringName
) -> bool:
	var first_position: BattlerPositionState = (
		get_battler_position(first_battler_id)
	)
	var second_position: BattlerPositionState = (
		get_battler_position(second_battler_id)
	)

	return (
		first_position != null
		and second_position != null
		and are_positions_adjacent(
			first_position.anchor_id,
			first_position.position_index,
			second_position.anchor_id,
			second_position.position_index
		)
	)


func are_positions_adjacent(
	first_anchor_id: StringName,
	first_position_index: int,
	second_anchor_id: StringName,
	second_position_index: int
) -> bool:
	if first_anchor_id == second_anchor_id:
		return true
	return (
		definition != null
		and definition.are_positions_in_contact(
			first_anchor_id,
			first_position_index,
			second_anchor_id,
			second_position_index
		)
	)


func is_position_adjacent_to_battler(
	anchor_id: StringName,
	position_index: int,
	battler_id: StringName
) -> bool:
	var battler_position := get_battler_position(battler_id)
	return (
		battler_position != null
		and are_positions_adjacent(
			anchor_id,
			position_index,
			battler_position.anchor_id,
			battler_position.position_index
		)
	)


func get_spatial_range(
	first_battler_id: StringName,
	second_battler_id: StringName
) -> SpatialRange:
	var first_position: BattlerPositionState = (
		get_battler_position(first_battler_id)
	)
	var second_position: BattlerPositionState = (
		get_battler_position(second_battler_id)
	)
	if first_position == null or second_position == null:
		return SpatialRange.BEYOND

	if are_positions_adjacent(
		first_position.anchor_id,
		first_position.position_index,
		second_position.anchor_id,
		second_position.position_index
	):
		return SpatialRange.ADJACENT

	var first_anchor: AnchorDefinition = definition.get_anchor(
		first_position.anchor_id
	)
	var second_anchor: AnchorDefinition = definition.get_anchor(
		second_position.anchor_id
	)
	if first_anchor == null or second_anchor == null:
		return SpatialRange.BEYOND

	if first_anchor.zone_id == second_anchor.zone_id:
		return SpatialRange.CLOSE

	var zone_distance: int = get_zone_distance(
		first_anchor.zone_id,
		second_anchor.zone_id
	)
	match zone_distance:
		1:
			return SpatialRange.FAR
		2:
			return SpatialRange.VERY_FAR

	return SpatialRange.BEYOND


func get_spatial_range_label(
	spatial_range: SpatialRange
) -> String:
	match spatial_range:
		SpatialRange.ADJACENT:
			return "Adjacent"
		SpatialRange.CLOSE:
			return "Close"
		SpatialRange.FAR:
			return "Far"
		SpatialRange.VERY_FAR:
			return "Very Far"

	return "Beyond"


func get_zone_distance(
	start_zone_id: StringName,
	end_zone_id: StringName
) -> int:
	if start_zone_id == end_zone_id:
		return 0
	if (
		definition.get_zone(start_zone_id) == null
		or definition.get_zone(end_zone_id) == null
	):
		return -1

	var pending_zone_ids: Array[StringName] = [start_zone_id]
	var distances: Dictionary = {start_zone_id: 0}
	var queue_index: int = 0

	while queue_index < pending_zone_ids.size():
		var current_zone_id: StringName = pending_zone_ids[
			queue_index
		]
		queue_index += 1

		var current_zone: BattleZoneDefinition = (
			definition.get_zone(current_zone_id)
		)
		var current_distance: int = int(
			distances.get(current_zone_id, 0)
		)

		for neighbor_id: StringName in (
			current_zone.connected_zone_ids
		):
			if distances.has(neighbor_id):
				continue

			var neighbor_distance: int = current_distance + 1
			if neighbor_id == end_zone_id:
				return neighbor_distance

			distances[neighbor_id] = neighbor_distance
			pending_zone_ids.append(neighbor_id)

	return -1


func get_anchor_distance(
	start_anchor_id: StringName,
	end_anchor_id: StringName
) -> int:
	if start_anchor_id == end_anchor_id:
		return 0
	if (
		definition == null
		or definition.get_anchor(start_anchor_id) == null
		or definition.get_anchor(end_anchor_id) == null
	):
		return -1

	var pending_anchor_ids: Array[StringName] = [start_anchor_id]
	var distances: Dictionary = {start_anchor_id: 0}
	var queue_index: int = 0

	while queue_index < pending_anchor_ids.size():
		var current_anchor_id: StringName = pending_anchor_ids[
			queue_index
		]
		queue_index += 1

		var current_anchor: AnchorDefinition = definition.get_anchor(
			current_anchor_id
		)
		var current_distance: int = int(
			distances.get(current_anchor_id, 0)
		)

		for neighbor_id: StringName in (
			current_anchor.connected_anchor_ids
		):
			if distances.has(neighbor_id):
				continue

			var neighbor_distance: int = current_distance + 1
			if neighbor_id == end_anchor_id:
				return neighbor_distance

			distances[neighbor_id] = neighbor_distance
			pending_anchor_ids.append(neighbor_id)

	return -1


func get_location_label(
	battler_id: StringName
) -> String:
	var position_state: BattlerPositionState = (
		get_battler_position(battler_id)
	)
	if position_state == null:
		return "Unplaced"

	var anchor: AnchorDefinition = definition.get_anchor(
		position_state.anchor_id
	)
	if anchor == null:
		return "Invalid anchor"

	var zone: BattleZoneDefinition = definition.get_zone(
		anchor.zone_id
	)
	var zone_name: String = (
		zone.display_name
		if zone != null
		else String(anchor.zone_id)
	)

	return "%s — %s, Position %d" % [
		zone_name,
		anchor.display_name,
		position_state.position_index + 1,
	]


func _validate_definition() -> String:
	if definition == null:
		return "BattlefieldDefinition is missing."
	if definition.zones.is_empty():
		return "BattlefieldDefinition requires at least one BattleZone."
	if definition.anchors.is_empty():
		return "BattlefieldDefinition requires at least one Anchor."

	var zone_ids: Dictionary = {}
	for zone: BattleZoneDefinition in definition.zones:
		if zone == null or zone.zone_id == &"":
			return "A BattleZone has no valid ID."
		if zone_ids.has(zone.zone_id):
			return "Duplicate BattleZone ID '%s'." % zone.zone_id
		zone_ids[zone.zone_id] = true

	var anchor_ids: Dictionary = {}
	for anchor: AnchorDefinition in definition.anchors:
		if anchor == null or anchor.anchor_id == &"":
			return "An Anchor has no valid ID."
		if anchor_ids.has(anchor.anchor_id):
			return "Duplicate Anchor ID '%s'." % anchor.anchor_id
		if not zone_ids.has(anchor.zone_id):
			return "Anchor '%s' uses missing BattleZone '%s'." % [
				anchor.anchor_id,
				anchor.zone_id,
			]
		if anchor.capacity != 2 and anchor.capacity != 4:
			return "Anchor '%s' capacity must be 2 or 4." % (
				anchor.anchor_id
			)
		if anchor.position_points.size() < anchor.capacity:
			return "Anchor '%s' needs %d Position points." % [
				anchor.anchor_id,
				anchor.capacity,
			]
		anchor_ids[anchor.anchor_id] = true

	for zone: BattleZoneDefinition in definition.zones:
		for connected_zone_id: StringName in (
			zone.connected_zone_ids
		):
			if not zone_ids.has(connected_zone_id):
				return "BattleZone '%s' connects to missing zone '%s'." % [
					zone.zone_id,
					connected_zone_id,
				]
			var connected_zone: BattleZoneDefinition = (
				definition.get_zone(connected_zone_id)
			)
			if not connected_zone.connected_zone_ids.has(zone.zone_id):
				return "BattleZone connection '%s' ↔ '%s' is not two-way." % [
					zone.zone_id,
					connected_zone_id,
				]

	for anchor: AnchorDefinition in definition.anchors:
		for connected_anchor_id: StringName in (
			anchor.connected_anchor_ids
		):
			if not anchor_ids.has(connected_anchor_id):
				return "Anchor '%s' connects to missing anchor '%s'." % [
					anchor.anchor_id,
					connected_anchor_id,
				]
			var connected_anchor: AnchorDefinition = (
				definition.get_anchor(connected_anchor_id)
			)
			if not connected_anchor.connected_anchor_ids.has(
				anchor.anchor_id
			):
				return "Anchor connection '%s' ↔ '%s' is not two-way." % [
					anchor.anchor_id,
					connected_anchor_id,
				]

	var contact_keys: Dictionary = {}
	for contact: PositionContactDefinition in definition.position_contacts:
		if contact == null:
			return "A Position contact is empty."
		var first_anchor := definition.get_anchor(contact.first_anchor_id)
		var second_anchor := definition.get_anchor(contact.second_anchor_id)
		if first_anchor == null or second_anchor == null:
			return "Position contact '%s' references a missing Anchor." % (
				contact.get_stable_key()
			)
		if first_anchor == second_anchor:
			return "Position contact '%s' must cross two Anchors." % (
				contact.get_stable_key()
			)
		if not first_anchor.connected_anchor_ids.has(second_anchor.anchor_id):
			return "Position contact '%s' requires connected Anchors." % (
				contact.get_stable_key()
			)
		if (
			contact.first_position_index < 0
			or contact.first_position_index >= first_anchor.capacity
			or contact.second_position_index < 0
			or contact.second_position_index >= second_anchor.capacity
		):
			return "Position contact '%s' uses an invalid Position." % (
				contact.get_stable_key()
			)
		var contact_key := contact.get_stable_key()
		if contact_keys.has(contact_key):
			return "Duplicate Position contact '%s'." % contact_key
		contact_keys[contact_key] = true

	var terrain_ids: Dictionary = {}
	for terrain_line: TerrainLineDefinition in (
		definition.terrain_lines
	):
		if terrain_line == null:
			return "A terrain ray blocker is empty."
		if terrain_line.terrain_id == &"":
			return "A terrain ray blocker has no valid ID."
		if terrain_ids.has(terrain_line.terrain_id):
			return "Duplicate terrain line ID '%s'." % (
				terrain_line.terrain_id
			)
		if not terrain_line.is_meaningful():
			return "Terrain line '%s' has no usable segment or rule." % (
				terrain_line.terrain_id
			)
		terrain_ids[terrain_line.terrain_id] = true

	var placed_battlers: Dictionary = {}
	var occupied_positions: Dictionary = {}
	for placement: BattlerPlacementDefinition in (
		definition.initial_placements
	):
		if placement == null:
			return "An initial Battler placement is empty."
		if placed_battlers.has(placement.battler_id):
			return "Battler '%s' has duplicate initial placements." % (
				placement.battler_id
			)
		var anchor: AnchorDefinition = definition.get_anchor(
			placement.anchor_id
		)
		if anchor == null:
			return "Battler '%s' uses missing Anchor '%s'." % [
				placement.battler_id,
				placement.anchor_id,
			]
		if (
			placement.position_index < 0
			or placement.position_index >= anchor.capacity
		):
			return "Battler '%s' uses invalid Position %d." % [
				placement.battler_id,
				placement.position_index,
			]
		var position_key: String = "%s:%d" % [
			placement.anchor_id,
			placement.position_index,
		]
		var placement_is_active: bool = battler_states.has(
			placement.battler_id
		)
		if (
			placement_is_active
			and occupied_positions.has(position_key)
		):
			return "Initial Position '%s' is occupied twice." % (
				position_key
			)
		placed_battlers[placement.battler_id] = true
		if placement_is_active:
			occupied_positions[position_key] = true

	for battler_id: Variant in battler_states.keys():
		if not placed_battlers.has(battler_id):
			return "Battler '%s' has no initial spatial placement." % (
				battler_id
			)

	return ""


func _get_intersecting_terrain_names(
	first_battler_id: StringName,
	second_battler_id: StringName,
	line_of_sight_only: bool
) -> Array[String]:
	var names: Array[String] = []
	if definition == null:
		return names

	var first_anchor: AnchorDefinition = get_battler_anchor(
		first_battler_id
	)
	var second_anchor: AnchorDefinition = get_battler_anchor(
		second_battler_id
	)
	if first_anchor == null or second_anchor == null:
		return names
	if first_anchor.anchor_id == second_anchor.anchor_id:
		return names

	var ray_start: Vector2 = first_anchor.get_center()
	var ray_end: Vector2 = second_anchor.get_center()

	for terrain_line: TerrainLineDefinition in (
		definition.terrain_lines
	):
		if terrain_line == null:
			continue

		var applies: bool = (
			terrain_line.blocks_line_of_sight
			if line_of_sight_only
			else terrain_line.provides_ranged_cover
		)
		if not applies:
			continue

		if _segments_intersect(
			ray_start,
			ray_end,
			terrain_line.start_point,
			terrain_line.end_point
		):
			names.append(terrain_line.display_name)

	names.sort()
	return names


func _segments_intersect(
	first_start: Vector2,
	first_end: Vector2,
	second_start: Vector2,
	second_end: Vector2
) -> bool:
	var first_vector: Vector2 = first_end - first_start
	var second_vector: Vector2 = second_end - second_start
	var denominator: float = first_vector.cross(second_vector)
	var start_delta: Vector2 = second_start - first_start

	if is_zero_approx(denominator):
		if not is_zero_approx(start_delta.cross(first_vector)):
			return false

		var first_length_squared: float = (
			first_vector.length_squared()
		)
		if is_zero_approx(first_length_squared):
			return false

		var overlap_start: float = start_delta.dot(
			first_vector
		) / first_length_squared
		var overlap_end: float = (
			(second_end - first_start).dot(first_vector)
			/ first_length_squared
		)
		var minimum_overlap: float = min(
			overlap_start,
			overlap_end
		)
		var maximum_overlap: float = max(
			overlap_start,
			overlap_end
		)
		return (
			maximum_overlap >= 0.0
			and minimum_overlap <= 1.0
		)

	var first_factor: float = (
		start_delta.cross(second_vector)
		/ denominator
	)
	var second_factor: float = (
		start_delta.cross(first_vector)
		/ denominator
	)
	return (
		first_factor >= 0.0
		and first_factor <= 1.0
		and second_factor >= 0.0
		and second_factor <= 1.0
	)
