extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_initial_placements_adjacency_and_range()
	_test_full_allied_anchor_pass_through_and_threat_preview()
	_test_altar_left_has_enemy_entry_positions()
	_test_full_hostile_anchor_blocks_traversal()
	_test_committed_move_spends_one_action_and_uses_exact_position()

	if failures == 0:
		print("Spatial battle tests passed.")
	else:
		push_error(
			"%d spatial battle test(s) failed."
			% failures
		)

	quit(failures)


func _test_initial_placements_adjacency_and_range() -> void:
	var fixture: Dictionary = _make_spatial_fixture()
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState

	_expect(
		battlefield != null,
		"Spatial fixture must initialize."
	)
	if battlefield == null:
		return

	_expect(
		battlefield.are_adjacent(&"lysandra", &"mira"),
		"Lysandra and Mira should share the Altar Left cluster."
	)
	_expect(
		battlefield.get_spatial_range(
			&"lysandra",
			&"seraphine"
		) == BattlefieldState.SpatialRange.CLOSE,
		"Different Anchors in Broken Altar should be Close."
	)
	_expect(
		battlefield.get_spatial_range(
			&"hollow_servant",
			&"knife_footman"
		) == BattlefieldState.SpatialRange.FAR,
		"Left Nave to Central Nave should be Far."
	)
	_expect(
		battlefield.get_spatial_range(
			&"lysandra",
			&"prayer_rag_novice"
		) == BattlefieldState.SpatialRange.VERY_FAR,
		"Broken Altar to Right Nave should be Very Far."
	)


func _test_full_allied_anchor_pass_through_and_threat_preview() -> void:
	var fixture: Dictionary = _make_spatial_fixture()
	var battlers: Dictionary = fixture.get(
		"battlers"
	) as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController

	var first_extra_definition: BattlerDefinition = (
		(
			battlers.get(&"lysandra") as BattlerState
		).definition.duplicate(true) as BattlerDefinition
	)
	first_extra_definition.battler_id = &"heroine_extra_one"
	battlers[&"heroine_extra_one"] = BattlerState.new(
		first_extra_definition
	)
	var second_extra_definition: BattlerDefinition = (
		first_extra_definition.duplicate(true) as BattlerDefinition
	)
	second_extra_definition.battler_id = &"heroine_extra_two"
	battlers[&"heroine_extra_two"] = BattlerState.new(
		second_extra_definition
	)
	battlefield.place_battler(
		&"heroine_extra_one",
		&"altar_left",
		2
	)
	battlefield.place_battler(
		&"heroine_extra_two",
		&"altar_left",
		3
	)

	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	var previews: Array[MovementPreview] = (
		movement.begin_move_selection(&"seraphine")
	)
	var preview: MovementPreview = _find_preview(
		previews,
		[
			&"altar_right",
			&"altar_left",
			&"central_nave",
		]
	)

	_expect(
		preview != null,
		"Seraphine should pass through the full allied Altar Left cluster."
	)
	if preview == null:
		return

	_expect(
		preview.hostile_step_anchor_ids.has(&"central_nave"),
		"Entering the occupied Central Nave should be marked hostile."
	)
	_expect(
		preview.threat_battler_ids.has(&"knife_footman"),
		"Knife Footman should appear as a possible Move Reaction attacker."
	)
	_expect(
		_find_preview_by_destination(
			previews,
			&"altar_left"
		) == null,
		"A full allied Anchor may be crossed but not selected as destination."
	)


func _test_altar_left_has_enemy_entry_positions() -> void:
	var fixture: Dictionary = _make_spatial_fixture()
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController

	var free_positions: Array[int] = (
		battlefield.get_free_position_indices(&"altar_left")
	)
	_expect(
		free_positions == [2, 3],
		"Altar Left should reserve two entry Positions beside Lysandra and Mira."
	)

	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_ENEMIES_FIRST
	)
	var previews: Array[MovementPreview] = (
		movement.begin_move_selection(&"knife_footman")
	)
	var approach: MovementPreview = _find_preview(
		previews,
		[&"central_nave", &"altar_left"]
	)
	_expect(
		approach != null,
		"Knife Footman should be able to enter Lysandra and Mira's engagement cluster."
	)
	if approach != null:
		_expect(
			approach.available_destination_positions == [2, 3],
			"Enemy entry should use only the two unoccupied Altar Left Positions."
		)


func _test_full_hostile_anchor_blocks_traversal() -> void:
	var fixture: Dictionary = _make_spatial_fixture()
	var battlers: Dictionary = fixture.get(
		"battlers"
	) as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController

	var extra_definition: BattlerDefinition = (
		(
			battlers.get(&"knife_footman") as BattlerState
		).definition.duplicate(true) as BattlerDefinition
	)
	extra_definition.battler_id = &"enemy_extra"
	battlers[&"enemy_extra"] = BattlerState.new(
		extra_definition
	)

	battlefield.place_battler(
		&"hollow_servant",
		&"central_nave",
		1
	)
	battlefield.place_battler(
		&"prayer_rag_novice",
		&"central_nave",
		2
	)
	battlefield.place_battler(
		&"enemy_extra",
		&"central_nave",
		3
	)

	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	var previews: Array[MovementPreview] = (
		movement.begin_move_selection(&"seraphine")
	)

	for preview: MovementPreview in previews:
		_expect(
			not preview.anchor_path.has(&"central_nave"),
			"A full hostile Central Nave must block entry and traversal."
		)


func _test_committed_move_spends_one_action_and_uses_exact_position() -> void:
	var fixture: Dictionary = _make_spatial_fixture()
	var battlers: Dictionary = fixture.get(
		"battlers"
	) as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController

	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	var previews: Array[MovementPreview] = (
		movement.begin_move_selection(&"lysandra")
	)
	var preview: MovementPreview = _find_preview(
		previews,
		[&"altar_left", &"central_nave"]
	)

	_expect(
		preview != null,
		"Lysandra should have a direct one-step route to Central Nave."
	)
	if preview == null:
		return

	var commit_error: String = movement.commit_move(
		preview,
		2
	)
	_expect(
		commit_error.is_empty(),
		"Legal exact-position Move should commit."
	)
	_expect(
		lysandra.current_actions == 2,
		"Move should spend exactly one Action."
	)

	var position_state: BattlerPositionState = (
		battlefield.get_battler_position(&"lysandra")
	)
	_expect(
		position_state.anchor_id == &"central_nave",
		"Committed Move should update the destination Anchor."
	)
	_expect(
		position_state.position_index == 2,
		"Committed Move should preserve the chosen exact Position."
	)
	_expect(
		battlefield.are_adjacent(
			&"lysandra",
			&"knife_footman"
		),
		"Sharing Central Nave's Anchor should make battlers Adjacent."
	)


func _make_spatial_fixture() -> Dictionary:
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
			"Spatial fixture failed: %s" % spatial_error
		)
		return {}

	var battle_state: BattleState = BattleState.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		battlers,
		battle_state,
		DiceResolver.new(),
		900
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
		"battlers": battlers,
		"battlefield": battlefield,
		"flow": flow,
		"runtime": runtime,
		"movement": movement,
	}


func _find_preview(
	previews: Array[MovementPreview],
	expected_path: Array[StringName]
) -> MovementPreview:
	for preview: MovementPreview in previews:
		if _paths_match(preview.anchor_path, expected_path):
			return preview

	return null


func _find_preview_by_destination(
	previews: Array[MovementPreview],
	destination_anchor_id: StringName
) -> MovementPreview:
	for preview: MovementPreview in previews:
		if preview.destination_anchor_id == destination_anchor_id:
			return preview

	return null


func _paths_match(
	first_path: Array[StringName],
	second_path: Array[StringName]
) -> bool:
	if first_path.size() != second_path.size():
		return false

	for path_index: int in range(first_path.size()):
		if first_path[path_index] != second_path[path_index]:
			return false

	return true


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures += 1
	push_error(message)
