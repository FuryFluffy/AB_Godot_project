@tool
class_name AuthoredBattlefield
extends Node2D


const ROUTE_COLOR := Color(0.15, 0.94, 0.79, 0.64)
const CROSS_ZONE_ROUTE_COLOR := Color(0.35, 0.68, 1.0, 0.78)
const POSITION_CONTACT_COLOR := Color(0.96, 0.71, 0.26, 0.92)
const PRESENTATION_SIZE := Vector2(1920.0, 1080.0)
const DEFAULT_BATTLER_VISUAL_CATALOG: BattlerVisualProfileCatalog = preload(
	"res://data/presentation/battler_visual_profile_catalog.tres"
)


@export_group("Battlefield Identity")
@export var battlefield_id: StringName
@export var display_name: String = "Unnamed Battlefield"

@export_group("Editor Guide")
@export var show_anchor_connections: bool = true
@export var show_position_contacts: bool = true
@export_subgroup("Battler Size Preview")
@export var show_battler_previews: bool = false
@export var show_battler_preview_bounds: bool = true
@export_enum(
	"lysandra",
	"mira",
	"seraphine",
	"hollow_servant",
	"knife_footman",
	"prayer_rag_novice",
	"corrupted_butler",
	"red_wax_acolyte",
	"blood_nun",
	"chain_thrall",
	"iron_masked_guard",
	"cell_slime",
	"jailer"
)
var preview_battler_id: String = "lysandra"
@export_enum("idle", "move", "attack", "cast", "defend", "hurt", "defeated")
var preview_pose: String = "idle"
@export_range(0.05, 1.0, 0.05) var preview_opacity: float = 0.55
@export var battler_preview_catalog: BattlerVisualProfileCatalog = (
	DEFAULT_BATTLER_VISUAL_CATALOG
)
@export_tool_button("Validate Battlefield")
var validate_battlefield_button: Callable = _validate_from_editor

var definition: BattlefieldDefinition
var spawn_slots: Array[SpawnSlotDefinition] = []


func _ready() -> void:
	_fit_background_art_to_presentation()
	_refresh_runtime_sources()
	queue_redraw()


func _fit_background_art_to_presentation() -> void:
	var background := get_node_or_null(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	if background == null or background.texture == null:
		return
	var texture_size: Vector2 = background.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var cover_scale: float = maxf(
		PRESENTATION_SIZE.x / texture_size.x,
		PRESENTATION_SIZE.y / texture_size.y
	)
	background.centered = false
	background.scale = Vector2.ONE * cover_scale
	background.position = (
		PRESENTATION_SIZE - texture_size * cover_scale
	) * 0.5


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(get_authoring_errors())


func _validate_from_editor() -> void:
	var errors := get_authoring_errors()
	update_configuration_warnings()
	if errors.is_empty():
		print("Battlefield authoring validation passed: %s." % display_name)
		return
	push_warning(
		"Battlefield authoring validation failed:\n- %s"
		% "\n- ".join(PackedStringArray(errors))
	)


func get_authored_zones() -> Array[AuthoredBattleZone]:
	var results: Array[AuthoredBattleZone] = []
	var host := get_node_or_null("Zones")
	if host == null:
		return results
	for child: Node in host.get_children():
		if child is AuthoredBattleZone:
			results.append(child as AuthoredBattleZone)
	return results


func get_authored_anchors() -> Array[AuthoredAnchor]:
	var results: Array[AuthoredAnchor] = []
	var host := get_node_or_null("Anchors")
	if host == null:
		return results
	for child: Node in host.get_children():
		if child is AuthoredAnchor:
			results.append(child as AuthoredAnchor)
	return results


func get_authored_spawn_slots() -> Array[AuthoredSpawnSlot]:
	var results: Array[AuthoredSpawnSlot] = []
	var host := get_node_or_null("SpawnSlots")
	if host == null:
		return results
	for child: Node in host.get_children():
		if child is AuthoredSpawnSlot:
			results.append(child as AuthoredSpawnSlot)
	return results


func get_authored_zone(
	zone_id: StringName
) -> AuthoredBattleZone:
	for zone: AuthoredBattleZone in get_authored_zones():
		if zone.zone_id == zone_id:
			return zone
	return null


func get_authored_anchor(
	anchor_id: StringName
) -> AuthoredAnchor:
	for anchor: AuthoredAnchor in get_authored_anchors():
		if anchor.anchor_id == anchor_id:
			return anchor
	return null


func get_authored_position_contacts() -> Array[PositionContactDefinition]:
	var results: Array[PositionContactDefinition] = []
	var seen_contact_keys: Dictionary = {}
	for first_anchor: AuthoredAnchor in get_authored_anchors():
		for first_position: AuthoredPosition in first_anchor.get_position_nodes():
			for second_position: AuthoredPosition in first_position.get_connected_positions():
				var second_anchor := second_position.get_parent() as AuthoredAnchor
				if second_anchor == null:
					continue
				var contact := PositionContactDefinition.new()
				contact.first_anchor_id = first_anchor.anchor_id
				contact.first_position_index = first_position.position_index
				contact.second_anchor_id = second_anchor.anchor_id
				contact.second_position_index = second_position.position_index
				var contact_key := contact.get_stable_key()
				if seen_contact_keys.has(contact_key):
					continue
				seen_contact_keys[contact_key] = true
				results.append(contact)
	return results


func get_authored_position(
	anchor_id: StringName,
	position_index: int
) -> AuthoredPosition:
	var anchor := get_authored_anchor(anchor_id)
	if anchor == null:
		return null
	for position_node: AuthoredPosition in anchor.get_position_nodes():
		if position_node.position_index == position_index:
			return position_node
	return null


## Builds the same floor-contact rectangles used by BattleMarker at runtime.
## Keeping this data available outside _draw() also makes the editor preview
## contract testable without adding preview nodes to exported combat scenes.
func get_battler_preview_for_position(
	anchor: AuthoredAnchor,
	position_node: AuthoredPosition
) -> Dictionary:
	if battler_preview_catalog == null or preview_battler_id.is_empty():
		return {}
	if anchor == null or position_node == null:
		return {}
	var resolution: Dictionary = battler_preview_catalog.resolve_visual(
		StringName(preview_battler_id),
		StringName(preview_pose),
		anchor.visual_orientation,
		&"battlefield_editor_preview"
	)
	if not String(resolution.get("error", "")).is_empty():
		return {}
	var texture: Texture2D = resolution.get("texture") as Texture2D
	if texture == null:
		return {}
	var pivot: Vector2 = resolution.get(
		"floor_contact_pivot",
		Vector2(0.5, 1.0)
	) as Vector2
	var baseline_scale: Vector2 = resolution.get(
		"baseline_scale",
		Vector2.ONE
	) as Vector2
	var scale_correction: Vector2 = resolution.get(
		"scale_correction",
		Vector2.ONE
	) as Vector2
	var offset_correction: Vector2 = resolution.get(
		"offset_correction",
		Vector2.ZERO
	) as Vector2
	var position_battler_scale: float = (
		position_node.get_effective_battler_scale()
	)
	var runtime_scale: Vector2 = (
		baseline_scale
		* scale_correction
		* position_battler_scale
	)
	var sprite_position: Vector2 = (
		offset_correction * position_battler_scale
		- texture.get_size() * pivot * runtime_scale
	)
	var floor_point: Vector2 = to_local(position_node.global_position)
	return {
		"anchor_id": anchor.anchor_id,
		"position_index": position_node.position_index,
		"orientation": StringName(
			resolution.get("resolved_orientation_key", &"front")
		),
		"texture": texture,
		"sprite_position": sprite_position,
		"sprite_scale": runtime_scale,
		"rect": Rect2(
			floor_point + sprite_position,
			texture.get_size() * runtime_scale
		),
		"floor_point": floor_point,
		"battler_scale": position_battler_scale,
		"visual_order": position_node.get_effective_visual_order(),
	}


func get_battler_preview_layout() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for anchor: AuthoredAnchor in get_authored_anchors():
		for position_node: AuthoredPosition in anchor.get_position_nodes():
			if not position_node.show_battler_preview:
				continue
			var preview: Dictionary = get_battler_preview_for_position(
				anchor,
				position_node
			)
			if not preview.is_empty():
				results.append(preview)
	results.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return int(first.get("visual_order", 0)) < int(
				second.get("visual_order", 0)
			)
	)
	return results


func get_spawn_slot(slot_id: StringName) -> SpawnSlotDefinition:
	_refresh_runtime_sources()
	for slot: SpawnSlotDefinition in spawn_slots:
		if slot != null and slot.slot_id == slot_id:
			return slot
	return null


func resolve_spawn_marker(
	marker: AuthoredSpawnSlot
) -> Dictionary:
	var best_distance := INF
	var best_anchor_id: StringName = &""
	var best_position_index := -1
	for anchor: AuthoredAnchor in get_authored_anchors():
		for position_node: AuthoredPosition in anchor.get_position_nodes():
			var distance := marker.global_position.distance_to(
				position_node.global_position
			)
			if distance >= best_distance:
				continue
			best_distance = distance
			best_anchor_id = anchor.anchor_id
			best_position_index = position_node.position_index
	if best_distance > marker.position_snap_radius:
		return {
			"anchor_id": &"",
			"position_index": -1,
			"distance": best_distance,
		}
	return {
		"anchor_id": best_anchor_id,
		"position_index": best_position_index,
		"distance": best_distance,
	}


func build_definition() -> BattlefieldDefinition:
	var result := BattlefieldDefinition.new()
	result.battlefield_id = battlefield_id
	result.display_name = display_name
	var zones: Array[BattleZoneDefinition] = []
	for authored_zone: AuthoredBattleZone in get_authored_zones():
		zones.append(authored_zone.make_definition(self))
	result.zones = zones
	var anchors: Array[AnchorDefinition] = []
	for authored_anchor: AuthoredAnchor in get_authored_anchors():
		anchors.append(authored_anchor.make_definition(self))
	result.anchors = anchors
	result.position_contacts = get_authored_position_contacts()
	var placements: Array[BattlerPlacementDefinition] = []
	result.initial_placements = placements
	var terrain: Array[TerrainLineDefinition] = []
	result.terrain_lines = terrain
	return result


func build_spawn_slots() -> Array[SpawnSlotDefinition]:
	var results: Array[SpawnSlotDefinition] = []
	for marker: AuthoredSpawnSlot in get_authored_spawn_slots():
		results.append(marker.make_definition(self))
	return results


func get_authoring_errors() -> Array[String]:
	var errors: Array[String] = []
	if battlefield_id == &"":
		errors.append("The battlefield has no battlefield_id.")

	var zones := get_authored_zones()
	var zone_ids: Dictionary = {}
	if zones.is_empty():
		errors.append("The Zones node has no AuthoredBattleZone children.")
	for zone: AuthoredBattleZone in zones:
		if zone.zone_id == &"":
			errors.append("Zone node '%s' has no zone_id." % zone.name)
		elif zone_ids.has(zone.zone_id):
			errors.append("Duplicate BattleZone ID '%s'." % zone.zone_id)
		zone_ids[zone.zone_id] = zone
		if zone.polygon.size() < 3:
			errors.append(
				"BattleZone '%s' needs at least three polygon points."
				% zone.zone_id
			)

	for zone: AuthoredBattleZone in zones:
		for connected_zone_id: StringName in zone.connected_zone_ids:
			var connected_zone := zone_ids.get(
				connected_zone_id
			) as AuthoredBattleZone
			if connected_zone == null:
				errors.append(
					"BattleZone '%s' connects to missing zone '%s'."
					% [zone.zone_id, connected_zone_id]
				)
			elif not connected_zone.connected_zone_ids.has(zone.zone_id):
				errors.append(
					"BattleZone connection '%s' ↔ '%s' is not two-way."
					% [zone.zone_id, connected_zone_id]
				)

	var anchors := get_authored_anchors()
	var anchor_ids: Dictionary = {}
	if anchors.is_empty():
		errors.append("The Anchors node has no AuthoredAnchor children.")
	for anchor: AuthoredAnchor in anchors:
		if anchor.anchor_id == &"":
			errors.append("Anchor node '%s' has no anchor_id." % anchor.name)
		elif anchor_ids.has(anchor.anchor_id):
			errors.append("Duplicate Anchor ID '%s'." % anchor.anchor_id)
		anchor_ids[anchor.anchor_id] = anchor
		if anchor.visual_depth_band not in [
			&"foreground",
			&"midground",
			&"background",
		]:
			errors.append(
				"Anchor '%s' has invalid visual depth band '%s'."
				% [anchor.anchor_id, anchor.visual_depth_band]
			)
		if anchor.visual_orientation not in [&"front", &"back"]:
			errors.append(
				"Anchor '%s' has invalid visual orientation '%s'."
				% [anchor.anchor_id, anchor.visual_orientation]
			)
		var owning_zone := zone_ids.get(anchor.zone_id) as AuthoredBattleZone
		if anchor.polygon.size() < 3:
			errors.append(
				"Engagement Area '%s' needs at least three polygon points."
				% anchor.anchor_id
			)
		if owning_zone == null:
			errors.append(
				"Anchor '%s' uses missing BattleZone '%s'."
				% [anchor.anchor_id, anchor.zone_id]
			)
		elif not owning_zone.contains_battlefield_point(
			self,
			anchor.get_battlefield_position(self)
		):
			errors.append(
				"Anchor '%s' is outside its BattleZone '%s' polygon."
				% [anchor.anchor_id, anchor.zone_id]
			)
		var position_nodes := anchor.get_position_nodes()
		if position_nodes.size() != anchor.capacity:
			errors.append(
				"Anchor '%s' needs exactly %d Position children; found %d."
				% [anchor.anchor_id, anchor.capacity, position_nodes.size()]
			)
		var seen_position_indices: Dictionary = {}
		for position_node: AuthoredPosition in position_nodes:
			if seen_position_indices.has(position_node.position_index):
				errors.append(
					"Anchor '%s' repeats Position index %d."
					% [anchor.anchor_id, position_node.position_index]
				)
			seen_position_indices[position_node.position_index] = true
			if position_node.position_index >= anchor.capacity:
				errors.append(
					"Anchor '%s' has Position index %d beyond capacity %d."
					% [
						anchor.anchor_id,
						position_node.position_index,
						anchor.capacity,
					]
				)
			var battlefield_point := to_local(position_node.global_position)
			if (
				owning_zone != null
				and not owning_zone.contains_battlefield_point(
					self,
					battlefield_point
				)
			):
				errors.append(
					"Position %d of Engagement Area '%s' is outside BattleZone '%s'."
					% [
						position_node.position_index,
						anchor.anchor_id,
						anchor.zone_id,
					]
				)
			if (
				anchor.polygon.size() >= 3
				and not anchor.contains_battlefield_point(
					self,
					battlefield_point
				)
			):
				errors.append(
					"Position %d is outside its Engagement Area '%s' polygon."
					% [position_node.position_index, anchor.anchor_id]
				)

	for anchor: AuthoredAnchor in anchors:
		for connected_anchor_id: StringName in anchor.connected_anchor_ids:
			var connected_anchor := anchor_ids.get(
				connected_anchor_id
			) as AuthoredAnchor
			if connected_anchor == null:
				errors.append(
					"Anchor '%s' connects to missing anchor '%s'."
					% [anchor.anchor_id, connected_anchor_id]
				)
				continue
			if not connected_anchor.connected_anchor_ids.has(anchor.anchor_id):
				errors.append(
					"Anchor connection '%s' ↔ '%s' is not two-way."
					% [anchor.anchor_id, connected_anchor_id]
				)
			if anchor.zone_id != connected_anchor.zone_id:
				var anchor_zone := zone_ids.get(anchor.zone_id) as AuthoredBattleZone
				if (
					anchor_zone != null
					and not anchor_zone.connected_zone_ids.has(
						connected_anchor.zone_id
					)
				):
					errors.append(
						"Cross-zone Anchor connection '%s' ↔ '%s' lacks a BattleZone connection."
						% [anchor.anchor_id, connected_anchor_id]
					)

	for first_anchor: AuthoredAnchor in anchors:
		for first_position: AuthoredPosition in first_anchor.get_position_nodes():
			for target_node: AuthoredPosition in first_position.connected_positions:
				if target_node == null:
					errors.append(
						"Position '%s/%s' has an empty Connected Positions entry."
						% [first_anchor.anchor_id, first_position.name]
					)
				elif target_node == first_position:
					errors.append(
						"Position '%s/%s' cannot connect to itself."
						% [first_anchor.anchor_id, first_position.name]
					)
				elif not (target_node.get_parent() is AuthoredAnchor):
					errors.append(
						"Connected Position '%s' is not a child of an AuthoredAnchor."
						% target_node.name
					)
				elif not anchors.has(target_node.get_parent()):
					errors.append(
						"Connected Position '%s' is outside this battlefield's Anchors tree."
						% target_node.name
					)

	for contact: PositionContactDefinition in get_authored_position_contacts():
		var first_anchor := anchor_ids.get(
			contact.first_anchor_id
		) as AuthoredAnchor
		var second_anchor := anchor_ids.get(
			contact.second_anchor_id
		) as AuthoredAnchor
		if first_anchor == null or second_anchor == null:
			errors.append(
				"Position contact '%s' references a missing Anchor."
				% contact.get_stable_key()
			)
			continue
		if first_anchor == second_anchor:
			errors.append(
				"Position contact '%s' must cross two different Anchors."
				% contact.get_stable_key()
			)
		if (
			not first_anchor.connected_anchor_ids.has(second_anchor.anchor_id)
			or not second_anchor.connected_anchor_ids.has(first_anchor.anchor_id)
		):
			errors.append(
				"Position contact '%s' requires a two-way direct Anchor connection."
				% contact.get_stable_key()
			)
		if (
			contact.first_position_index < 0
			or contact.first_position_index >= first_anchor.capacity
			or contact.second_position_index < 0
			or contact.second_position_index >= second_anchor.capacity
		):
			errors.append(
				"Position contact '%s' uses an invalid Position index."
				% contact.get_stable_key()
			)
	for zone: AuthoredBattleZone in zones:
		for connected_zone_id: StringName in zone.connected_zone_ids:
			if String(zone.zone_id) > String(connected_zone_id):
				continue
			var has_crossing := false
			for anchor: AuthoredAnchor in anchors:
				if anchor.zone_id != zone.zone_id:
					continue
				for connected_anchor_id: StringName in anchor.connected_anchor_ids:
					var connected_anchor := anchor_ids.get(
						connected_anchor_id
					) as AuthoredAnchor
					if (
						connected_anchor != null
						and connected_anchor.zone_id == connected_zone_id
					):
						has_crossing = true
						break
				if has_crossing:
					break
			if not has_crossing:
				errors.append(
					"Connected BattleZones '%s' and '%s' have no crossing Anchor route."
					% [zone.zone_id, connected_zone_id]
				)

	var slot_ids: Dictionary = {}
	var occupied_spawn_positions: Dictionary = {}
	for marker: AuthoredSpawnSlot in get_authored_spawn_slots():
		if marker.slot_id == &"":
			errors.append("Spawn marker '%s' has no slot_id." % marker.name)
		elif slot_ids.has(marker.slot_id):
			errors.append("Duplicate spawn slot ID '%s'." % marker.slot_id)
		slot_ids[marker.slot_id] = true
		var resolved := resolve_spawn_marker(marker)
		var resolved_anchor_id := StringName(
			resolved.get("anchor_id", &"")
		)
		var resolved_position_index := int(
			resolved.get("position_index", -1)
		)
		if resolved_anchor_id == &"" or resolved_position_index < 0:
			errors.append(
				"Spawn slot '%s' is not within %.0f px of an authored Position."
				% [marker.slot_id, marker.position_snap_radius]
			)
			continue
		var position_key := "%s:%d" % [
			resolved_anchor_id,
			resolved_position_index,
		]
		if occupied_spawn_positions.has(position_key):
			errors.append(
				"Spawn slots '%s' and '%s' overlap the same authored Position."
				% [occupied_spawn_positions[position_key], marker.slot_id]
			)
		occupied_spawn_positions[position_key] = marker.slot_id
	return errors


func validate_authoring() -> String:
	var errors := get_authoring_errors()
	if errors.is_empty():
		return ""
	return errors[0]


func validate_assignments(
	battler_definitions: Array[BattlerDefinition],
	assignments: Dictionary
) -> String:
	var authoring_error := validate_authoring()
	if not authoring_error.is_empty():
		return authoring_error
	_refresh_runtime_sources()
	if definition == null:
		return "Authored battlefield could not build its runtime definition."
	if not definition.initial_placements.is_empty():
		return (
			"Production battlefield '%s' contains concrete battler placements."
			% definition.battlefield_id
		)

	var seen_slots: Dictionary = {}
	for battler: BattlerDefinition in battler_definitions:
		if battler == null or battler.battler_id == &"":
			return "Encounter contains an invalid BattlerDefinition."
		var slot_id := StringName(assignments.get(battler.battler_id, &""))
		if slot_id == &"":
			return "Battler '%s' has no neutral spawn assignment." % (
				battler.battler_id
			)
		var slot := _find_cached_spawn_slot(slot_id)
		if slot == null:
			return "Battler '%s' uses missing spawn slot '%s'." % [
				battler.battler_id,
				slot_id,
			]
		if seen_slots.has(slot_id):
			return "Spawn slot '%s' is assigned more than once." % slot_id
		if not slot.accepts_faction(battler.faction):
			return "Spawn slot '%s' rejects battler '%s'." % [
				slot_id,
				battler.battler_id,
			]
		var anchor := definition.get_anchor(slot.anchor_id)
		if anchor == null:
			return "Spawn slot '%s' uses missing Anchor '%s'." % [
				slot_id,
				slot.anchor_id,
			]
		if slot.position_index < 0 or slot.position_index >= anchor.capacity:
			return "Spawn slot '%s' uses invalid Position %d." % [
				slot_id,
				slot.position_index,
			]
		seen_slots[slot_id] = true
	return ""


func make_runtime_definition(
	battler_definitions: Array[BattlerDefinition],
	assignments: Dictionary
) -> BattlefieldDefinition:
	_refresh_runtime_sources()
	var runtime_definition := definition.duplicate(true) as BattlefieldDefinition
	var runtime_placements: Array[BattlerPlacementDefinition] = []
	runtime_definition.initial_placements = runtime_placements
	for battler: BattlerDefinition in battler_definitions:
		var slot_id := StringName(assignments.get(battler.battler_id, &""))
		var slot := _find_cached_spawn_slot(slot_id)
		var placement := BattlerPlacementDefinition.new()
		placement.battler_id = battler.battler_id
		placement.anchor_id = slot.anchor_id
		placement.position_index = slot.position_index
		runtime_definition.initial_placements.append(placement)
	return runtime_definition


func _refresh_runtime_sources() -> void:
	definition = build_definition()
	spawn_slots = build_spawn_slots()


func _find_cached_spawn_slot(
	slot_id: StringName
) -> SpawnSlotDefinition:
	for slot: SpawnSlotDefinition in spawn_slots:
		if slot != null and slot.slot_id == slot_id:
			return slot
	return null


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if show_anchor_connections:
		for anchor: AuthoredAnchor in get_authored_anchors():
			for connected_anchor_id: StringName in anchor.connected_anchor_ids:
				if String(anchor.anchor_id) > String(connected_anchor_id):
					continue
				var connected_anchor := get_authored_anchor(connected_anchor_id)
				if connected_anchor == null:
					continue
				var route_color := ROUTE_COLOR
				if anchor.zone_id != connected_anchor.zone_id:
					route_color = CROSS_ZONE_ROUTE_COLOR
				# Polygon vertices can be reshaped without moving the Anchor node's
				# transform origin. Draw routes between authored Position centroids
				# so the editor guide follows the playable floor instead of a stale
				# transform pivot.
				draw_line(
					anchor.get_battlefield_position(self),
					connected_anchor.get_battlefield_position(self),
					route_color,
					4.0,
					true
				)
	if not show_position_contacts:
		return
	for contact: PositionContactDefinition in get_authored_position_contacts():
		var first_position := get_authored_position(
			contact.first_anchor_id,
			contact.first_position_index
		)
		var second_position := get_authored_position(
			contact.second_anchor_id,
			contact.second_position_index
		)
		if first_position == null or second_position == null:
			continue
		draw_line(
			to_local(first_position.global_position),
			to_local(second_position.global_position),
			POSITION_CONTACT_COLOR,
			3.0,
			true
		)
