extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_contact_adjacency_and_targeting()
	_test_dodge_breaks_contact()
	_test_reposition_move_reaction()
	_test_grapple_pulls_across_contact()
	_test_ranged_weapon_does_not_extend_grapple_range()
	_test_cross_zone_multiple_contacts_validate()

	if failures == 0:
		print("Position contact adjacency tests passed.")
	else:
		push_error(
			"%d Position contact adjacency test(s) failed."
			% failures
		)
	quit(failures)


func _test_contact_adjacency_and_targeting() -> void:
	var fixture := _make_fixture()
	var battlefield := fixture.get("battlefield") as BattlefieldState
	var targeting := fixture.get("targeting") as BattleTargetingController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var lysandra := battlers.get(&"lysandra") as BattlerState

	_expect(
		not battlefield.are_adjacent(&"lysandra", &"hollow_servant"),
		"Unlinked Positions in neighboring Anchors must remain non-Adjacent."
	)
	battlefield.place_battler(&"lysandra", &"left", 1)
	_expect(
		battlefield.are_adjacent(&"lysandra", &"hollow_servant"),
		"An authored Position contact must grant cross-Anchor Adjacency."
	)
	_expect(
		targeting.evaluate_attack(
			&"lysandra",
			&"hollow_servant",
			lysandra.get_main_hand_weapon()
		).is_legal,
		"Ordinary melee must accept an authored cross-Anchor contact."
	)


func _test_dodge_breaks_contact() -> void:
	var fixture := _make_fixture()
	var battlefield := fixture.get("battlefield") as BattlefieldState
	var dodge := DodgeStepController.new()
	dodge.initialize(
		fixture.get("battlers") as Dictionary,
		battlefield
	)
	battlefield.place_battler(&"lysandra", &"left", 1)
	var destinations := dodge.get_legal_destinations(
		&"lysandra",
		&"hollow_servant"
	)
	_expect(
		_has_destination(destinations, &"left", 0)
		and _has_destination(destinations, &"left", 2)
		and not _has_destination(destinations, &"left", 1)
		and not _has_anchor_destination(destinations, &"centre"),
		"Dodge should offer safe local Positions and reject every Position that remains Adjacent."
	)


func _test_reposition_move_reaction() -> void:
	var fixture := _make_fixture()
	var movement := fixture.get("movement") as BattleMovementController
	var previews := movement.begin_move_selection(&"lysandra")
	var reposition := _find_preview(previews, [&"left"])
	_expect(reposition != null, "A same-Anchor reposition preview should exist.")
	if reposition == null:
		return
	_expect(
		reposition.is_destination_position_threatened(1)
		and not reposition.is_destination_position_threatened(2),
		"Only the linked boundary Position should preview the Move Reaction."
	)
	var committed := movement.begin_committed_move(reposition, 1)
	_expect(committed.is_valid, "The boundary reposition should commit.")
	if not committed.is_valid:
		return
	_expect(
		movement.advance_active_move_step().is_empty(),
		"The same-Anchor reposition should reach its exact Position."
	)
	_expect(
		movement.get_active_move_reactor_ids() == [&"hollow_servant"],
		"Entering contact by repositioning must open a Move Reaction."
	)


func _test_grapple_pulls_across_contact() -> void:
	var fixture := _make_fixture()
	var battlefield := fixture.get("battlefield") as BattlefieldState
	var grapple := fixture.get("grapple") as GrappleController
	battlefield.place_battler(&"lysandra", &"left", 1)
	_expect(
		grapple.can_initiate(&"hollow_servant", &"lysandra"),
		"Grapple initiation should be legal through Position contact."
	)
	var attempt := grapple.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	_expect(
		attempt.error_message.is_empty(),
		"Contact Grapple should prepare without a range error."
	)
	if not attempt.error_message.is_empty():
		return
	attempt = grapple.resolve_initiation(false)
	var heroine_position := battlefield.get_battler_position(&"lysandra")
	var grappler_position := battlefield.get_battler_position(&"hollow_servant")
	_expect(
		attempt.succeeded
		and heroine_position != null
		and grappler_position != null
		and grappler_position.anchor_id == heroine_position.anchor_id
		and grappler_position.position_index == heroine_position.position_index,
		"Successful contact Grapple must pull the grappler into the heroine's Position."
	)


func _test_ranged_weapon_does_not_extend_grapple_range() -> void:
	var definitions: Array[BattlerDefinition] = [
		load(
			"res://data/battlers/heroines/lysandra.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/corrupted_butler.tres"
		) as BattlerDefinition,
	]
	var battlers: Dictionary = (
		BattleBootstrap.new().create_battler_states(definitions)
	)

	var zone := BattleZoneDefinition.new()
	zone.zone_id = &"foreground"
	zone.display_name = "Foreground"

	var left := AnchorDefinition.new()
	left.anchor_id = &"left"
	left.display_name = "Left"
	left.zone_id = zone.zone_id
	left.connected_anchor_ids = [&"right"]
	left.capacity = 2
	left.position_points = [
		Vector2(100, 100),
		Vector2(160, 100),
	]

	var right := AnchorDefinition.new()
	right.anchor_id = &"right"
	right.display_name = "Right"
	right.zone_id = zone.zone_id
	right.connected_anchor_ids = [&"left"]
	right.capacity = 2
	right.position_points = [
		Vector2(240, 100),
		Vector2(300, 100),
	]

	var lysandra_placement := BattlerPlacementDefinition.new()
	lysandra_placement.battler_id = &"lysandra"
	lysandra_placement.anchor_id = left.anchor_id
	lysandra_placement.position_index = 0
	var butler_placement := BattlerPlacementDefinition.new()
	butler_placement.battler_id = &"corrupted_butler"
	butler_placement.anchor_id = right.anchor_id
	butler_placement.position_index = 0

	var definition := BattlefieldDefinition.new()
	definition.battlefield_id = &"ranged_grapple_range_test"
	definition.display_name = "Ranged Grapple Range Test"
	definition.zones = [zone]
	definition.anchors = [left, right]
	definition.initial_placements = [
		lysandra_placement,
		butler_placement,
	]

	var battlefield := BattlefieldState.new()
	var error := battlefield.initialize(definition, battlers)
	_expect(error.is_empty(), "Ranged Grapple fixture failed: %s" % error)

	var targeting := BattleTargetingController.new()
	targeting.initialize(battlers, battlefield)
	var grapple := GrappleController.new()
	grapple.initialize(
		battlers,
		battlefield,
		targeting,
		DiceResolver.new(),
		7500
	)

	_expect(
		not grapple.can_initiate(
			&"corrupted_butler",
			&"lysandra"
		),
		"A ranged Silver Tray must not make Grapple legal from an unlinked Position."
	)
	var attempt := grapple.prepare_initiation(
		&"corrupted_butler",
		&"lysandra"
	)
	_expect(
		not attempt.error_message.is_empty(),
		"Ranged Grapple revalidation must reject the unlinked target."
	)

	error = battlefield.place_battler(
		&"corrupted_butler",
		&"left",
		1
	)
	_expect(error.is_empty(), "The Butler should reposition beside Lysandra.")
	_expect(
		grapple.can_initiate(
			&"corrupted_butler",
			&"lysandra"
		),
		"The Butler should use an Unarmed melee Grapple once truly Adjacent."
	)


func _test_cross_zone_multiple_contacts_validate() -> void:
	var foreground := BattleZoneDefinition.new()
	foreground.zone_id = &"foreground"
	foreground.connected_zone_ids = [&"runway"]
	var runway := BattleZoneDefinition.new()
	runway.zone_id = &"runway"
	runway.connected_zone_ids = [&"foreground"]

	var left := AnchorDefinition.new()
	left.anchor_id = &"left"
	left.zone_id = foreground.zone_id
	left.capacity = 4
	left.connected_anchor_ids = [&"right"]
	left.position_points = [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]

	var right := AnchorDefinition.new()
	right.anchor_id = &"right"
	right.zone_id = runway.zone_id
	right.capacity = 4
	right.connected_anchor_ids = [&"left"]
	right.position_points = [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]

	var contact_a := PositionContactDefinition.new()
	contact_a.first_anchor_id = &"left"
	contact_a.first_position_index = 2
	contact_a.second_anchor_id = &"right"
	contact_a.second_position_index = 0
	var contact_b := PositionContactDefinition.new()
	contact_b.first_anchor_id = &"left"
	contact_b.first_position_index = 2
	contact_b.second_anchor_id = &"right"
	contact_b.second_position_index = 1

	var definition := BattlefieldDefinition.new()
	definition.battlefield_id = &"cross_zone_multi_contact_test"
	definition.zones = [foreground, runway]
	definition.anchors = [left, right]
	definition.position_contacts = [contact_a, contact_b]

	var battlefield := BattlefieldState.new()
	var error := battlefield.initialize(definition, {})
	_expect(
		error.is_empty(),
		"Cross-zone multiple Position contacts should validate: %s" % error
	)


func _make_fixture() -> Dictionary:
	var definitions: Array[BattlerDefinition] = [
		load("res://data/battlers/heroines/lysandra.tres") as BattlerDefinition,
		load("res://data/battlers/enemies/hollow_servant.tres") as BattlerDefinition,
	]
	var battlers := BattleBootstrap.new().create_battler_states(definitions)

	var zone := BattleZoneDefinition.new()
	zone.zone_id = &"foreground"
	zone.display_name = "Foreground"

	var left := AnchorDefinition.new()
	left.anchor_id = &"left"
	left.display_name = "Left"
	left.zone_id = zone.zone_id
	left.connected_anchor_ids = [&"centre"]
	left.position_points = [
		Vector2(100, 200),
		Vector2(180, 160),
		Vector2(100, 280),
		Vector2(180, 280),
	]

	var centre := AnchorDefinition.new()
	centre.anchor_id = &"centre"
	centre.display_name = "Centre"
	centre.zone_id = zone.zone_id
	centre.connected_anchor_ids = [&"left"]
	centre.position_points = [
		Vector2(220, 160),
		Vector2(300, 200),
		Vector2(220, 280),
		Vector2(300, 280),
	]

	var contact := PositionContactDefinition.new()
	contact.first_anchor_id = left.anchor_id
	contact.first_position_index = 1
	contact.second_anchor_id = centre.anchor_id
	contact.second_position_index = 0

	var lysandra_placement := BattlerPlacementDefinition.new()
	lysandra_placement.battler_id = &"lysandra"
	lysandra_placement.anchor_id = left.anchor_id
	lysandra_placement.position_index = 0
	var hollow_placement := BattlerPlacementDefinition.new()
	hollow_placement.battler_id = &"hollow_servant"
	hollow_placement.anchor_id = centre.anchor_id
	hollow_placement.position_index = 0

	var definition := BattlefieldDefinition.new()
	definition.battlefield_id = &"position_contact_test"
	definition.display_name = "Position Contact Test"
	definition.zones = [zone]
	definition.anchors = [left, centre]
	definition.position_contacts = [contact]
	definition.initial_placements = [lysandra_placement, hollow_placement]

	var battlefield := BattlefieldState.new()
	var error := battlefield.initialize(definition, battlers)
	_expect(error.is_empty(), "Position contact fixture failed: %s" % error)

	var battle_state := BattleState.new()
	var flow := BattleFlowController.new()
	flow.initialize(battlers, battle_state, DiceResolver.new(), 7300)
	flow.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST)
	var runtime := BattleRuntimeState.new()
	runtime.battle_state = battle_state
	var movement := BattleMovementController.new()
	movement.initialize(battlers, battlefield, flow, runtime)
	var targeting := BattleTargetingController.new()
	targeting.initialize(battlers, battlefield)
	var grapple := GrappleController.new()
	grapple.initialize(
		battlers,
		battlefield,
		targeting,
		DiceResolver.new(),
		7400
	)

	return {
		"battlers": battlers,
		"battlefield": battlefield,
		"runtime": runtime,
		"movement": movement,
		"targeting": targeting,
		"grapple": grapple,
	}


func _find_preview(
	previews: Array[MovementPreview],
	path: Array[StringName]
) -> MovementPreview:
	for preview: MovementPreview in previews:
		if preview != null and preview.anchor_path == path:
			return preview
	return null


func _has_destination(
	destinations: Array[Dictionary],
	anchor_id: StringName,
	position_index: int
) -> bool:
	for destination: Dictionary in destinations:
		if (
			destination.get("anchor_id", &"") == anchor_id
			and int(destination.get("position_index", -1)) == position_index
		):
			return true
	return false


func _has_anchor_destination(
	destinations: Array[Dictionary],
	anchor_id: StringName
) -> bool:
	for destination: Dictionary in destinations:
		if destination.get("anchor_id", &"") == anchor_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
