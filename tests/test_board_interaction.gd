extends SceneTree


var failures: int = 0
var confirmed_preview: MovementPreview
var confirmed_position_index: int = -1
var confirmed_zone_id: StringName = &""
var selection_visibility_active: bool = false
var selection_visibility_signal_count: int = 0


func _init() -> void:
	_test_exact_move_route_is_chosen_on_the_board()
	_test_aoe_zone_is_chosen_on_the_board()

	if failures == 0:
		print("Board interaction tests passed.")
	else:
		push_error(
			"%d board interaction test(s) failed."
			% failures
		)

	quit(failures)


func _test_exact_move_route_is_chosen_on_the_board() -> void:
	var fixture: Dictionary = _make_fixture()
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var overlay: BattlefieldInteractionOverlay = (
		BattlefieldInteractionOverlay.new()
	)
	root.add_child(overlay)
	overlay.initialize(
		battlefield.definition,
		battlefield
	)
	overlay.move_confirmed.connect(_on_move_confirmed)
	overlay.selection_visibility_changed.connect(
		_on_selection_visibility_changed
	)

	var previews: Array[MovementPreview] = (
		movement.begin_move_selection(&"seraphine")
	)
	overlay.begin_move_selection(previews, "Seraphine")
	_expect(
		selection_visibility_active
		and selection_visibility_signal_count == 1,
		"Board Move should request unobstructed selection visibility."
	)

	_expect(
		overlay.get_next_move_anchor_ids().has(&"altar_left"),
		"Board Move should expose Altar Left as Seraphine's first route step."
	)
	var altar_left: AnchorDefinition = (
		battlefield.definition.get_anchor(&"altar_left")
	)
	_expect(
		overlay.handle_board_click(altar_left.get_center()),
		"Clicking Altar Left should choose the first route step."
	)
	_expect(
		overlay.get_next_move_anchor_ids().has(&"central_nave"),
		"Board Move should expose Central Nave after choosing Altar Left."
	)
	var central_nave: AnchorDefinition = (
		battlefield.definition.get_anchor(&"central_nave")
	)
	_expect(
		overlay.handle_board_click(central_nave.get_center()),
		"Clicking Central Nave should choose the second route step."
	)
	_expect(
		overlay.handle_board_click(
			central_nave.get_position_point(2)
		),
		"Clicking Central Nave P3 should confirm the exact Position."
	)
	_expect(
		confirmed_preview != null
		and confirmed_preview.anchor_path
		== [
			&"altar_right",
			&"altar_left",
			&"central_nave",
		],
		"Board Move should preserve the exact clicked two-step route."
	)
	_expect(
		confirmed_position_index == 2,
		"Board Move should preserve the exact clicked Position."
	)
	overlay.clear_selection()
	_expect(
		not selection_visibility_active
		and selection_visibility_signal_count == 2,
		"Clearing board selection should restore normal battler visibility."
	)

	overlay.queue_free()


func _test_aoe_zone_is_chosen_on_the_board() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var overlay: BattlefieldInteractionOverlay = (
		BattlefieldInteractionOverlay.new()
	)
	root.add_child(overlay)
	overlay.initialize(
		battlefield.definition,
		battlefield
	)
	overlay.aoe_zone_confirmed.connect(_on_aoe_zone_confirmed)
	overlay.begin_aoe_selection(
		[&"central_nave", &"right_nave"],
		"Blight Bomb"
	)

	_expect(
		not overlay.choose_aoe_zone(&"left_nave"),
		"Board AOE should reject an unhighlighted BattleZone."
	)
	var central_zone: BattleZoneDefinition = (
		battlefield.definition.get_zone(&"central_nave")
	)
	_expect(
		overlay.handle_board_click(central_zone.map_center),
		"Board AOE should accept a highlighted BattleZone click."
	)
	_expect(
		confirmed_zone_id == &"central_nave",
		"Board AOE should emit the exact clicked BattleZone."
	)

	overlay.queue_free()


func _make_fixture() -> Dictionary:
	var definitions: Array[BattlerDefinition] = [
		load(
			"res://data/battlers/heroines/lysandra.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/heroines/mira.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/heroines/seraphine.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/hollow_servant.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/knife_footman.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/prayer_rag_novice.tres"
		) as BattlerDefinition,
	]
	var battlers: Dictionary = (
		BattleBootstrap.new().create_battler_states(
			definitions
		)
	)
	var battlefield_definition: BattlefieldDefinition = load(
		"res://data/battlefields/ruined_chapel_spatial_test.tres"
	) as BattlefieldDefinition
	var battlefield: BattlefieldState = BattlefieldState.new()
	var spatial_error: String = battlefield.initialize(
		battlefield_definition,
		battlers
	)
	if not spatial_error.is_empty():
		_expect(
			false,
			"Board interaction fixture failed: %s"
			% spatial_error
		)
		return {}

	var battle_state: BattleState = BattleState.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		battlers,
		battle_state,
		DiceResolver.new(),
		1200
	)
	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)

	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	runtime.battle_state = battle_state
	var movement: BattleMovementController = (
		BattleMovementController.new()
	)
	movement.initialize(
		battlers,
		battlefield,
		flow,
		runtime
	)

	return {
		"battlefield": battlefield,
		"movement": movement,
	}


func _on_move_confirmed(
	preview: MovementPreview,
	position_index: int
) -> void:
	confirmed_preview = preview
	confirmed_position_index = position_index


func _on_aoe_zone_confirmed(
	zone_id: StringName
) -> void:
	confirmed_zone_id = zone_id


func _on_selection_visibility_changed(active: bool) -> void:
	selection_visibility_active = active
	selection_visibility_signal_count += 1


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures += 1
	push_error(message)
