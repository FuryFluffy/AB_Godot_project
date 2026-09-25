extends SceneTree


const CATALOG: LayerRoomCatalogDefinition = preload(
	"res://data/rooms/layer_1_2_room_catalog.tres"
)
const EXPECTED_LAYER_1_IDS: Array[StringName] = [
	&"opening_servant_corridor",
	&"servant_ledger_alcove",
	&"wine_cellar_warm_bottles",
	&"servant_dormitory",
	&"ruined_confessional",
	&"coat_beside_service_door",
	&"ruined_chapel",
	&"blood_nun_processing_chapel",
	&"lower_kitchen",
	&"cold_pantry",
	&"linen_sorting_room",
	&"bell_pull_gallery",
	&"butlers_office",
	&"dishwashing_hall",
	&"service_stair_landing",
	&"wax_prep_room",
	&"abandoned_guest_bedroom",
	&"laundry_boiler_room",
	&"dining_service_hall",
	&"sorting_vestibule",
]
const EXPECTED_LAYER_2_IDS: Array[StringName] = [
	&"offering_list_room",
	&"rusted_key_cell",
	&"false_safe_cell",
	&"quiet_shackle",
	&"empty_mens_cell",
	&"farthest_cell",
	&"jailers_gate_hall",
	&"jailers_containment_hall",
	&"intake_corridor",
	&"chain_maintenance_room",
	&"guard_station_without_guards",
	&"cell_block_crossroads",
	&"polished_shackle_gallery",
	&"prison_infirmary",
	&"isolation_cell",
	&"communal_prison_hall",
	&"drainage_passage",
	&"punishment_mechanism_room",
	&"wardens_records_office",
	&"sealed_exercise_yard",
]


var failures: int = 0


func _init() -> void:
	_test_catalog_coverage()
	_test_visual_coverage()
	_test_existing_authoring_links()
	if failures == 0:
		print("Layer 1–2 room registry tests passed.")
	else:
		push_error("%d Layer room registry test(s) failed." % failures)
	quit(failures)


func _test_catalog_coverage() -> void:
	_expect(CATALOG != null, "The Layer 1–2 room catalog should load.")
	if CATALOG == null:
		return
	_expect(CATALOG.validate_catalog().is_empty(), CATALOG.validate_catalog())
	_expect(CATALOG.rooms.size() == 40, "The catalog should contain 40 rooms.")
	_expect(
		_collect_ids(CATALOG.get_rooms_for_layer(1)) == EXPECTED_LAYER_1_IDS,
		"Layer 1 should contain its 20 canonical rooms in canonical order."
	)
	_expect(
		_collect_ids(CATALOG.get_rooms_for_layer(2)) == EXPECTED_LAYER_2_IDS,
		"Layer 2 should contain its 20 canonical rooms in canonical order."
	)


func _test_visual_coverage() -> void:
	var visual_count: int = 0
	var texture_count: int = 0
	for room: LayerRoomDefinition in CATALOG.rooms:
		for visual: LayerRoomVisualDefinition in room.visual_variants:
			visual_count += 1
			if visual.art_pending:
				continue
			texture_count += 1
			_expect(
				visual.texture != null,
				"%s/%s should load its background." % [
					room.room_id,
					visual.variant_id,
				]
			)
			if visual.texture != null:
				var size: Vector2 = visual.texture.get_size()
				_expect(
					size.x >= 1280.0 and size.y >= 720.0,
					"%s/%s should retain its authored desktop resolution." % [
						room.room_id,
						visual.variant_id,
					]
				)
	_expect(visual_count == 43, "The registry should contain 43 visual variants.")
	_expect(texture_count == 42, "The registry should bind all 42 delivered backgrounds.")
	var pending_rooms: Array[LayerRoomDefinition] = (
		CATALOG.get_rooms_with_pending_art()
	)
	_expect(
		pending_rooms.size() == 1
		and pending_rooms[0].room_id == &"intake_corridor",
		"Only the missing Intake Corridor background should be art-pending."
	)


func _test_existing_authoring_links() -> void:
	var authored_shell_dialogues: Dictionary = {
		&"servant_ledger_alcove": &"layer_1_servant_ledger_observation",
		&"ruined_confessional": &"layer_1_ruined_confessional",
		&"coat_beside_service_door": &"layer_1_coat_torn_cuff",
	}
	var exploration_count: int = 0
	var reusable_shell_count: int = 0
	var production_battlefield_count: int = 0
	var authoring_template_count: int = 0
	for room: LayerRoomDefinition in CATALOG.rooms:
		if room.exploration_definition != null:
			exploration_count += 1
			_expect(
				room.exploration_definition.validate_definition().is_empty(),
				"%s should expose a valid exploration definition." % room.room_id
			)
			if room.exploration_definition.presentation_texture != null:
				reusable_shell_count += 1
				var expected_dialogue_id := StringName(
					authored_shell_dialogues.get(room.room_id, "")
				)
				var entry_dialogue: DialogueDefinition = (
					room.exploration_definition.entry_dialogue
				)
				_expect(
					room.exploration_definition.presentation_texture
					== room.visual_variants[0].texture
					and room.exploration_definition.loot_profile == null
					and room.exploration_definition.event_profile == null
					and (
						(entry_dialogue == null and expected_dialogue_id == &"")
						or (
							entry_dialogue != null
							and entry_dialogue.dialogue_id == expected_dialogue_id
						)
					),
					"%s should use its registered art and only its explicitly authored shell dialogue."
					% room.room_id
				)
		production_battlefield_count += room.production_battlefields.size()
		authoring_template_count += room.battlefield_authoring_templates.size()
	_expect(
		exploration_count == 39,
		"Every room with available art should expose an exploration presentation."
	)
	_expect(
		reusable_shell_count == 34,
		"The 34 newly authored rooms should share the reusable presentation shell."
	)
	_expect(
		production_battlefield_count == 7,
		"The registry should expose the seven production battlefields."
	)
	_expect(
		authoring_template_count == 2,
		"The registry should expose the two existing battlefield templates."
	)


func _collect_ids(rooms: Array[LayerRoomDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for room: LayerRoomDefinition in rooms:
		ids.append(room.room_id)
	return ids


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
