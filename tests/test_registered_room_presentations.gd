extends SceneTree


const ROOM_CATALOG: LayerRoomCatalogDefinition = preload(
	"res://data/rooms/layer_1_2_room_catalog.tres"
)
const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)
const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const LORE_CATALOG: LoreCatalogDefinition = preload(
	"res://data/lore/lore_catalog.tres"
)


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_reusable_registered_room_shell()
	if failures == 0:
		print("Registered room presentation tests passed.")
	else:
		push_error("%d registered-room presentation test(s) failed." % failures)
	quit(failures)


func _test_reusable_registered_room_shell() -> void:
	var room: LayerRoomDefinition = ROOM_CATALOG.get_room(&"lower_kitchen")
	var screen_scene := load(
		"res://scenes/exploration/event_room_screen.tscn"
	) as PackedScene
	var screen := screen_scene.instantiate() as EventRoomScreen
	root.add_child(screen)
	await process_frame
	var run := RunState.new()
	var generator := LayerMapGenerator.new()
	var initialize_error: String = run.initialize(
		27072026,
		generator.generate_layer_1(27072026),
		generator.make_layer_1_generated_room_item_rules(),
		{
			&"lysandra": _heroine_snapshot(10, 4, 75, 8),
			&"mira": _heroine_snapshot(9, 6, 72, 12),
			&"seraphine": _heroine_snapshot(8, 8, 80, 4),
		}
	)
	var room_state := EventRoomInstanceState.new()
	room_state.source_node_id = &"registered_room_test"
	room_state.room_id = room.room_id
	room_state.generation_seed = 27072026
	var prepare_error: String = screen.prepare_room(
		room.exploration_definition,
		room_state,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		LORE_CATALOG,
		KnowledgeState.new(),
		1,
		run.inventory_snapshot,
		run.party_snapshot,
		run.get_narrative_state_snapshot(),
		run.get_run_inventory_snapshot(),
		run.run_equipment
	)
	var background := screen.presentation.find_child(
		"Background", true, false
	) as Sprite2D
	var exit_hotspot := screen.presentation.find_child(
		"RoomExitHotspot", true, false
	) as RoomExitHotspot
	_expect(
		initialize_error.is_empty()
		and prepare_error.is_empty()
		and background != null
		and background.texture == room.visual_variants[0].texture
		and exit_hotspot != null
		and screen.active_pickups.is_empty()
		and screen.active_room_events.is_empty()
		and screen.active_encounter_hotspots.is_empty(),
		"A registered presentation shell must show its own art and only a safe map exit."
	)
	root.remove_child(screen)
	screen.free()


func _heroine_snapshot(
	hp: int,
	mp: int,
	resolve: int,
	corruption: int
) -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"resolve": resolve,
		"corruption": corruption,
		"item_guard": 0,
		"weapon_damage": 0,
		"weapon_broken": false,
		"armor_damage": 0,
		"armor_broken": false,
		"shield_damage": 0,
		"shield_broken": false,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
