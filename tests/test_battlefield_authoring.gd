extends SceneTree


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_ruined_chapel_authoring()
	await _test_processing_chapel_authoring()
	await _test_jailer_containment_authoring()
	await _test_opening_servant_corridor_authoring()
	await _test_dining_service_hall_authoring()
	await _test_lower_kitchen_authoring()
	if failures == 0:
		print("Visual Battlefield Authoring tests passed.")
	else:
		push_error(
			"%d Visual Battlefield Authoring test(s) failed."
			% failures
		)
	quit(failures)


func _test_ruined_chapel_authoring() -> void:
	var battlefield := await _instantiate_battlefield(
		"res://scenes/battle/battlefields/ruined_chapel_battlefield.tscn"
	)
	_expect(
		battlefield != null,
		"Ruined Chapel authoring scene should instantiate."
	)
	if battlefield == null:
		return
	_expect(
		battlefield.validate_authoring().is_empty(),
		"Ruined Chapel visual authoring data should validate: %s"
		% battlefield.validate_authoring()
	)
	_expect(
		battlefield.get_authored_zones().size() == 6,
		"Authored Ruined Chapel should expose six editable BattleZones."
	)
	_expect(
		battlefield.get_authored_anchors().size() == 8,
		"Ruined Chapel should expose eight polygonal Engagement Areas."
	)
	_expect(
		battlefield.get_authored_spawn_slots().size() == 9,
		"Ruined Chapel should expose three party and six enemy spawn markers."
	)
	_expect(
		not _authored_polygons_overlap(
			battlefield.get_authored_zones()
		)
		and not _authored_polygons_overlap(
			battlefield.get_authored_anchors()
		),
		"Ruined Chapel zones and engagement areas should remain visually separate."
	)
	var central_zone := battlefield.definition.get_zone(&"central_nave")
	_expect(
		central_zone != null
		and central_zone.polygon_points.size() >= 3
		and central_zone.contains_point(Vector2(960, 650)),
		"Central Nave runtime snapshot should contain its painted polygon."
	)
	var foreground_center := battlefield.definition.get_anchor(
		&"foreground_center"
	)
	_expect(
		foreground_center != null
		and foreground_center.engagement_area_points.size() >= 3
		and foreground_center.contains_engagement_point(
			foreground_center.get_position_point(0)
		),
		"Foreground Centre should export an editable Engagement Area polygon."
	)
	var enemy_slot := battlefield.get_spawn_slot(&"enemy_1")
	_expect(
		enemy_slot != null
		and enemy_slot.anchor_id == &"central_nave"
		and enemy_slot.position_index == 1,
		"Dragged enemy_1 marker should resolve to Central Nave Position 2."
	)
	var rear_anchor := battlefield.definition.get_anchor(&"rear_gallery")
	_expect(
		rear_anchor != null
		and is_equal_approx(rear_anchor.battler_scale, 0.65)
		and rear_anchor.get_position_point(0).y >= 500.0
		and rear_anchor.visual_order == 10,
		"Rear Gallery should stay on the chapel floor with its authored depth scale and visual order."
	)
	_expect(
		rear_anchor != null
		and not rear_anchor.connected_anchor_ids.has(&"right_nave"),
		"Rear Gallery should not bypass Gallery Approach."
	)
	var background := battlefield.get_node_or_null(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	_expect(
		background != null
		and background.texture != null
		and background.texture.resource_path.ends_with(
			"New Rooms+Props/ABYSSAL_BLOOM_L1_L2_RESTYLED_SORTED_2026-08-30/Rooms/Layer_1/l01_room_ruined_chapel.png"
		),
		"Ruined Chapel must use only its reviewed restyled battlefield background."
	)
	battlefield.queue_free()
	await process_frame


func _test_processing_chapel_authoring() -> void:
	var battlefield := await _instantiate_battlefield(
		"res://scenes/battle/battlefields/processing_chapel_battlefield.tscn"
	)
	_expect(
		battlefield != null,
		"Processing Chapel authoring scene should instantiate."
	)
	if battlefield == null:
		return
	_expect(
		battlefield.validate_authoring().is_empty(),
		"Processing Chapel visual authoring data should validate: %s"
		% battlefield.validate_authoring()
	)
	_expect(
		battlefield.get_authored_zones().size() == 3
		and battlefield.get_authored_anchors().size() == 5
		and battlefield.definition.position_contacts.is_empty(),
		"Processing Chapel should retain its three-zone, five-area graph."
	)
	_expect(
		not _authored_polygons_overlap(
			battlefield.get_authored_zones()
		)
		and not _authored_polygons_overlap(
			battlefield.get_authored_anchors()
		),
		"Processing Chapel zones and engagement areas should remain visually separate."
	)
	var dais := battlefield.definition.get_anchor(&"dais")
	_expect(
		dais != null
		and dais.engagement_area_points.size() >= 3
		and dais.get_position_point(0).y >= 640.0
		and is_equal_approx(dais.get_position_battler_scale(0), 0.8),
		"Processing Chapel should keep its rear Engagement Area and battlers on the walkable floor."
	)
	var boss_slot := battlefield.get_spawn_slot(&"enemy_1")
	_expect(
		boss_slot != null
		and boss_slot.anchor_id == &"dais"
		and boss_slot.position_index == 0,
		"Boss spawn marker should resolve to Dais Position 1."
	)
	_expect(
		battlefield.definition.terrain_lines.is_empty(),
		"Visual authoring milestone must keep cover and line of sight deferred."
	)
	var background := battlefield.get_node_or_null(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	_expect(
		background != null
		and background.texture != null
		and background.texture.resource_path.ends_with(
			"New Rooms+Props/ABYSSAL_BLOOM_L1_L2_RESTYLED_SORTED_2026-08-30/Rooms/Layer_1/l01_room_blood_nun_processing_chapel.png"
		),
		"Processing Chapel must use only its reviewed restyled battlefield background."
	)
	battlefield.queue_free()
	await process_frame


func _test_jailer_containment_authoring() -> void:
	var battlefield := await _instantiate_battlefield(
		"res://scenes/battle/battlefields/jailer_containment_landing_battlefield.tscn"
	)
	_expect(
		battlefield != null,
		"Jailer Containment authoring scene should instantiate."
	)
	if battlefield == null:
		return
	_expect(
		battlefield.validate_authoring().is_empty(),
		"Jailer Containment authoring data should validate: %s"
		% battlefield.validate_authoring()
	)
	_expect(
		battlefield.get_authored_zones().size() == 3
		and battlefield.get_authored_anchors().size() == 5
		and battlefield.get_authored_spawn_slots().size() == 7
		and battlefield.definition.position_contacts.is_empty(),
		"Jailer Containment should retain its three-zone, five-area graph without inventing contacts."
	)
	_expect(
		not _authored_polygons_overlap(
			battlefield.get_authored_zones()
		)
		and not _authored_polygons_overlap(
			battlefield.get_authored_anchors()
		),
		"Jailer Containment zones and engagement areas should remain visually separate."
	)
	var boss_slot := battlefield.get_spawn_slot(&"enemy_1")
	var dais := battlefield.definition.get_anchor(&"dais")
	var background := battlefield.get_node_or_null(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	_expect(
		boss_slot != null
		and boss_slot.anchor_id == &"dais"
		and boss_slot.position_index == 0
		and dais != null
		and dais.get_position_point(0).y >= 640.0
		and is_equal_approx(dais.get_position_battler_scale(0), 0.8)
		and background != null
		and background.texture != null
		and background.texture.resource_path.ends_with(
			"New Rooms+Props/ABYSSAL_BLOOM_L1_L2_RESTYLED_SORTED_2026-08-30/Rooms/Layer_2/l02_room_jailers_containment_hall.png"
		),
		"The Jailer should retain the principal gate spawn on the reviewed containment-hall art."
	)
	battlefield.queue_free()
	await process_frame


func _test_opening_servant_corridor_authoring() -> void:
	var battlefield := await _instantiate_battlefield(
		"res://scenes/battle/battlefields/opening_servant_corridor_battlefield.tscn"
	)
	_expect(
		battlefield != null,
		"Opening Servant Corridor authoring scene should instantiate."
	)
	if battlefield == null:
		return
	_expect(
		battlefield.validate_authoring().is_empty(),
		"Opening Servant Corridor authoring data should validate: %s"
		% battlefield.validate_authoring()
	)
	_expect(
		battlefield.get_authored_zones().size() == 4
		and battlefield.get_authored_anchors().size() == 7
		and battlefield.definition.position_contacts.size() == 9
		and battlefield.definition.are_positions_in_contact(
			&"threshold_left",
			1,
			&"threshold_right",
			0
		)
		and battlefield.definition.are_positions_in_contact(
			&"threshold_left",
			2,
			&"lower_left",
			0
		)
		and battlefield.definition.are_positions_in_contact(
			&"lower_left",
			2,
			&"centre_gate",
			0
		)
		and battlefield.definition.are_positions_in_contact(
			&"centre_gate",
			0,
			&"far_left",
			1
		)
		and battlefield.definition.are_positions_in_contact(
			&"far_left",
			0,
			&"far_right",
			1
		),
		"The corridor should export its centered forward-depth graph and contacts."
	)
	_expect(
		not _authored_polygons_overlap(
			battlefield.get_authored_zones()
		)
		and not _authored_polygons_overlap(
			battlefield.get_authored_anchors()
		),
		"Opening Corridor zones and engagement areas should remain visually separate."
	)
	var threshold_left: AnchorDefinition = battlefield.definition.get_anchor(
		&"threshold_left"
	)
	var lower_left: AnchorDefinition = battlefield.definition.get_anchor(
		&"lower_left"
	)
	var far_left: AnchorDefinition = battlefield.definition.get_anchor(
		&"far_left"
	)
	var party_slot: SpawnSlotDefinition = battlefield.get_spawn_slot(&"party_1")
	var enemy_slot: SpawnSlotDefinition = battlefield.get_spawn_slot(&"enemy_1")
	var background := battlefield.get_node_or_null(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	_expect(
		threshold_left != null
		and threshold_left.visual_orientation == &"back"
		and lower_left != null
		and lower_left.visual_orientation == &"back"
		and far_left != null
		and far_left.visual_orientation == &"front"
		and is_equal_approx(
			threshold_left.get_position_battler_scale(0),
			1.7
		)
		and is_equal_approx(
			threshold_left.get_position_battler_scale(2),
			1.6
		)
		and is_equal_approx(
			lower_left.get_position_battler_scale(0),
			1.1
		)
		and is_equal_approx(
			far_left.get_position_battler_scale(0),
			0.65
		)
		and far_left.get_position_point(0).y >= 500.0
		and party_slot != null
		and party_slot.anchor_id == &"threshold_left"
		and enemy_slot != null
		and enemy_slot.anchor_id == &"far_left"
		and background != null
		and background.texture.resource_path.ends_with(
			"l01_room_opening_servant_corridor.png"
		),
		"Opening placement must face and scale battlers through the reviewed corridor depth."
	)
	var left_position_2 := battlefield.get_authored_position(
		&"threshold_left",
		1
	)
	var right_position_1 := battlefield.get_authored_position(
		&"threshold_right",
		0
	)
	_expect(
		left_position_2 != null
		and left_position_2.connected_positions.has(right_position_1)
		and right_position_1 != null
		and battlefield.definition.are_positions_in_contact(
			&"threshold_right",
			0,
			&"threshold_left",
			1
		),
		"One-sided Position declarations should compile as undirected contacts."
	)
	var right_position_2 := battlefield.get_authored_position(
		&"threshold_right",
		1
	)
	if left_position_2 != null and right_position_2 != null:
		left_position_2.connected_positions.append(right_position_2)
		var expanded_contacts := battlefield.get_authored_position_contacts()
		var has_extra_contact := false
		for contact: PositionContactDefinition in expanded_contacts:
			if contact.connects(
				&"threshold_left",
				1,
				&"threshold_right",
				1
			):
				has_extra_contact = true
				break
		_expect(
			expanded_contacts.size() == 10 and has_extra_contact,
			"One Position should be able to connect to several Positions."
		)
		right_position_2.connected_positions.append(left_position_2)
		_expect(
			battlefield.get_authored_position_contacts().size() == 10,
			"Mirrored Position declarations should remain deduplicated."
		)
	battlefield.queue_free()
	await process_frame


func _test_dining_service_hall_authoring() -> void:
	var battlefield := await _instantiate_battlefield(
		"res://scenes/battle/battlefields/dining_service_hall_battlefield.tscn"
	)
	_expect(
		battlefield != null,
		"Dining Service Hall authoring scene should instantiate."
	)
	if battlefield == null:
		return
	_expect(
		battlefield.validate_authoring().is_empty(),
		"Dining Service Hall authoring data should validate: %s"
		% battlefield.validate_authoring()
	)
	var west_lane: AnchorDefinition = battlefield.definition.get_anchor(
		&"west_lane"
	)
	var east_lane: AnchorDefinition = battlefield.definition.get_anchor(
		&"east_lane"
	)
	var entry_floor: AnchorDefinition = battlefield.definition.get_anchor(
		&"entry_floor_left"
	)
	var entry_floor_right: AnchorDefinition = battlefield.definition.get_anchor(
		&"entry_floor_right"
	)
	var rear_center: AnchorDefinition = battlefield.definition.get_anchor(
		&"rear_center"
	)
	_expect(
		battlefield.get_authored_zones().size() == 6
		and battlefield.get_authored_anchors().size() == 7
		and battlefield.get_authored_spawn_slots().size() == 6
		and west_lane != null
		and east_lane != null
		and entry_floor != null
		and entry_floor_right != null
		and rear_center != null
		and entry_floor.visual_orientation == &"back"
		and entry_floor_right.visual_orientation == &"back"
		and west_lane.visual_orientation == &"back"
		and east_lane.visual_orientation == &"back"
		and entry_floor.capacity == 2
		and entry_floor_right.capacity == 2
		and west_lane.capacity == 4
		and east_lane.capacity == 4
		and west_lane.connected_anchor_ids.has(&"east_lane")
		and east_lane.connected_anchor_ids.has(&"west_lane")
		and west_lane.connected_anchor_ids.has(&"rear_center")
		and east_lane.connected_anchor_ids.has(&"rear_center")
		and rear_center.connected_anchor_ids.has(&"rear_west")
		and rear_center.connected_anchor_ids.has(&"rear_east")
		and battlefield.definition.position_contacts.size() == 12,
		"Dining Service Hall must retain its split foreground, two lanes, and three-part rear dais."
	)
	_expect(
		battlefield.definition.terrain_lines.is_empty(),
		"Dining art must not invent cover or line-of-sight mechanics."
	)
	for authored_anchor: AuthoredAnchor in battlefield.get_authored_anchors():
		for authored_position: AuthoredPosition in authored_anchor.get_position_nodes():
			authored_position.show_battler_preview = false
	var preview_position := battlefield.get_authored_position(
		&"entry_floor_left",
		0
	)
	if preview_position != null:
		preview_position.show_battler_preview = true
		preview_position.use_anchor_battler_scale = false
		preview_position.battler_scale = 2.25
		preview_position.use_anchor_visual_order = false
		preview_position.battler_visual_order = 31
		battlefield._refresh_runtime_sources()
	var previews: Array[Dictionary] = battlefield.get_battler_preview_layout()
	var first_preview: Dictionary = (
		previews[0] if not previews.is_empty() else {}
	)
	var preview_texture: Texture2D = first_preview.get("texture") as Texture2D
	var preview_rect: Rect2 = first_preview.get("rect", Rect2()) as Rect2
	var preview_floor_point: Vector2 = first_preview.get(
		"floor_point",
		Vector2.ZERO
	) as Vector2
	_expect(
		battlefield.show_battler_previews
		and previews.size() == 1
		and preview_texture != null
		and preview_rect.size.x > 0.0
		and preview_rect.size.y > 0.0
		and is_equal_approx(preview_rect.end.y, preview_floor_point.y)
		and is_equal_approx(
			float(first_preview.get("battler_scale", 0.0)),
			2.25
		)
		and int(first_preview.get("visual_order", 0)) == 31
		and is_equal_approx(
			battlefield.definition.get_anchor(
				&"entry_floor_left"
			).get_position_battler_scale(0),
			2.25
		)
		and battlefield.definition.get_anchor(
			&"entry_floor_left"
		).get_position_visual_order(0) == 31,
		"Selected Dining Positions should preview their runtime scale, floor alignment, and visual order."
	)
	battlefield.queue_free()
	await process_frame


func _test_lower_kitchen_authoring() -> void:
	var battlefield := await _instantiate_battlefield(
		"res://scenes/battle/battlefields/lower_kitchen_battlefield.tscn"
	)
	_expect(
		battlefield != null,
		"Lower Kitchen authoring scene should instantiate."
	)
	if battlefield == null:
		return
	var validation_error: String = battlefield.validate_authoring()
	var foreground_left: AnchorDefinition = battlefield.definition.get_anchor(
		&"foreground_left"
	)
	var central_center: AnchorDefinition = battlefield.definition.get_anchor(
		&"central_center"
	)
	var rear_center: AnchorDefinition = battlefield.definition.get_anchor(
		&"rear_center"
	)
	var service_door: AnchorDefinition = battlefield.definition.get_anchor(
		&"service_door"
	)
	var party_slot: SpawnSlotDefinition = battlefield.get_spawn_slot(&"party_1")
	var enemy_slot: SpawnSlotDefinition = battlefield.get_spawn_slot(&"enemy_1")
	var background := battlefield.get_node_or_null(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	_expect(
		validation_error.is_empty(),
		"Lower Kitchen visual authoring data should validate: %s"
		% validation_error
	)
	_expect(
		battlefield.get_authored_zones().size() == 6
		and battlefield.get_authored_anchors().size() == 8
		and battlefield.get_authored_spawn_slots().size() == 9
		and battlefield.definition.position_contacts.size() == 12,
		"Lower Kitchen should expose its six-region, eight-area, twelve-contact graph."
	)
	_expect(
		not _authored_polygons_overlap(
			battlefield.get_authored_zones()
		)
		and not _authored_polygons_overlap(
			battlefield.get_authored_anchors()
		),
		"Lower Kitchen zones and engagement areas should remain visually separate."
	)
	_expect(
		foreground_left != null
		and central_center != null
		and rear_center != null
		and service_door != null
		and foreground_left.visual_orientation == &"back"
		and central_center.visual_orientation == &"back"
		and rear_center.visual_orientation == &"front"
		and service_door.visual_orientation == &"front"
		and is_equal_approx(
			foreground_left.get_position_battler_scale(0),
			1.65
		)
		and is_equal_approx(
			service_door.get_position_battler_scale(1),
			0.75
		),
		"Lower Kitchen should preserve its foreground-to-door perspective and facing."
	)
	_expect(
		party_slot != null
		and party_slot.anchor_id == &"foreground_left"
		and party_slot.position_index == 0
		and enemy_slot != null
		and enemy_slot.anchor_id == &"service_door"
		and enemy_slot.position_index == 0,
		"Lower Kitchen should place the party in front and the Butler at the unobstructed service door."
	)
	_expect(
		background != null
		and background.texture != null
		and background.texture.resource_path.ends_with(
			"New Rooms+Props/ABYSSAL_BLOOM_L1_L2_RESTYLED_SORTED_2026-08-30/Rooms/Layer_1/l01_room_lower_kitchen.png"
		),
		"Lower Kitchen must use only its reviewed restyled battlefield background."
	)
	battlefield.queue_free()
	await process_frame


func _authored_polygons_overlap(nodes: Array) -> bool:
	for first_index: int in range(nodes.size()):
		var first := nodes[first_index] as Polygon2D
		if first == null:
			continue
		var first_polygon := _global_polygon(first)
		for second_index: int in range(first_index + 1, nodes.size()):
			var second := nodes[second_index] as Polygon2D
			if second == null:
				continue
			if not Geometry2D.intersect_polygons(
				first_polygon,
				_global_polygon(second)
			).is_empty():
				return true
	return false


func _global_polygon(node: Polygon2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in node.polygon:
		result.append(node.to_global(point))
	return result


func _instantiate_battlefield(
	path: String
) -> AuthoredBattlefield:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var battlefield := packed.instantiate() as AuthoredBattlefield
	if battlefield == null:
		return null
	root.add_child(battlefield)
	await process_frame
	return battlefield


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
