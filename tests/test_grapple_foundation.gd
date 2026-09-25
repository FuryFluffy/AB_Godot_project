extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_template_validation()
	_test_initial_grapple_hold_progress_and_climax()
	_test_secondary_attachment_suppression_and_succession()
	_test_successful_struggle_releases_stage_one()
	_test_struggle_panel_preserves_battler_registry()
	_test_forced_cluster_movement_keeps_bundle_together()
	_test_detachment_uses_connected_anchor_fallback()
	_test_detachment_over_capacity_fallback()

	if failures == 0:
		print("Grapple foundation tests passed.")
	else:
		push_error(
			"%d Grapple foundation test(s) failed." % failures
		)

	quit(failures)


func _test_template_validation() -> void:
	var template: GrappleTemplateDefinition = load(
		"res://data/grapples/standard_hollow_servant_grapple.tres"
	) as GrappleTemplateDefinition
	_expect(template != null, "The test Grapple template should load.")
	if template == null:
		return
	_expect(
		template.validate_definition().is_empty(),
		"The standard template should pass authoring validation."
	)
	_expect(
		template.get_stage_count() == 3,
		"The standard template should contain three stages."
	)
	_expect(
		template.get_stage(2).is_climax,
		"The final standard stage should be Climax."
	)
	var visual_track: GrappleTrackState = GrappleTrackState.new(
		&"visual_test",
		&"lysandra",
		&"hollow_servant",
		template
	)
	_expect(
		visual_track.get_combined_visual_key() == &"HS_x1_Lysandra",
		"The template should expose the future combined-sprite key."
	)


func _test_initial_grapple_hold_progress_and_climax() -> void:
	var fixture: Dictionary = _make_fixture()
	var controller: GrappleController = fixture.get(
		"controller"
	) as GrappleController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var heroine: BattlerState = battlers.get(&"lysandra") as BattlerState
	var grappler: BattlerState = (
		battlers.get(&"hollow_servant") as BattlerState
	)

	var attempt: GrappleAttemptResult = controller.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	_expect(
		attempt.error_message.is_empty(),
		"A legal adjacent Grapple should prepare."
	)
	_expect(
		attempt.rolled_pool >= 1 and attempt.automatic_successes == 1,
		"Grapple must enforce one rolled die plus one automatic success."
	)

	attempt = controller.resolve_initiation(false)
	_expect(attempt.succeeded, "Skip should allow Grapple to succeed.")
	_expect(
		heroine.current_corruption == 1
		and heroine.current_resolve == 99,
		"Main Stage 1 should apply +1 Corruption and -1 Resolve."
	)
	_expect(
		heroine.is_grappled() and grappler.is_attached_grappler(),
		"Both participants should record the active track."
	)
	var heroine_position: BattlerPositionState = (
		battlefield.get_battler_position(&"lysandra")
	)
	var grappler_position: BattlerPositionState = (
		battlefield.get_battler_position(&"hollow_servant")
	)
	_expect(
		heroine_position.anchor_id == grappler_position.anchor_id
		and heroine_position.position_index
		== grappler_position.position_index,
		"Grapple participants should share one Position."
	)

	grappler.set_current_actions(2)
	var hold: GrappleActionResult = controller.hold_track(
		&"hollow_servant"
	)
	_expect(
		hold.succeeded and hold.actions_spent == 2,
		"Hold should consume every available Action."
	)
	_expect(
		heroine.current_corruption == 2
		and heroine.current_resolve == 98,
		"Main Hold should repeat the current stage effects."
	)
	grappler.set_current_actions(3)
	_expect(
		not controller.hold_track(&"hollow_servant").succeeded,
		"Hold should become illegal after the stage allowance is exhausted."
	)

	var progress: GrappleActionResult = controller.progress_track(
		&"hollow_servant"
	)
	_expect(
		progress.succeeded and progress.stage_after == 2,
		"Progress should advance to Stage 2."
	)
	_expect(
		heroine.current_corruption == 4
		and heroine.current_resolve == 96,
		"Stage 2 should apply its authored resource effects."
	)

	grappler.set_current_actions(1)
	var climax: GrappleActionResult = controller.progress_track(
		&"hollow_servant"
	)
	_expect(
		climax.succeeded and climax.climax_reached,
		"Progress into the final stage should resolve Climax."
	)
	_expect(
		not heroine.is_grappled()
		and not grappler.is_attached_grappler(),
		"Climax should end the track and release the heroine."
	)
	_expect(
		grappler.grapple_cooldown_activations == 1,
		"A surviving grappler should begin its authored cooldown."
	)


func _test_successful_struggle_releases_stage_one() -> void:
	var fixture: Dictionary = _make_fixture()
	var controller: GrappleController = fixture.get(
		"controller"
	) as GrappleController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var heroine: BattlerState = battlers.get(&"lysandra") as BattlerState
	var grappler: BattlerState = (
		battlers.get(&"hollow_servant") as BattlerState
	)

	var attempt: GrappleAttemptResult = controller.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	_expect(
		attempt.error_message.is_empty(),
		"The Struggle fixture should prepare Grapple."
	)
	if not attempt.error_message.is_empty():
		return
	controller.resolve_initiation(false)

	heroine.definition.attributes.might = 12
	grappler.definition.attributes.might = 0
	heroine.set_current_actions(2)
	var winning_seed: int = _find_winning_struggle_seed(
		heroine.definition.attributes.might
	)
	var struggle: GrappleActionResult = controller.struggle(
		&"lysandra",
		AttributeSet.Attribute.MIGHT,
		winning_seed
	)
	_expect(struggle.succeeded, "The seeded Struggle should succeed.")
	_expect(
		struggle.actions_spent == 2,
		"Struggle should consume all currently available Actions."
	)
	_expect(
		struggle.detached and not heroine.is_grappled(),
		"Successful Stage 1 Struggle should detach the grappler."
	)
	_expect(
		heroine.current_resolve == 100,
		"Successful Struggle should restore the undone stage's Resolve."
	)


func _test_struggle_panel_preserves_battler_registry() -> void:
	var fixture: Dictionary = _make_fixture()
	var controller: GrappleController = fixture.get(
		"controller"
	) as GrappleController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var heroine: BattlerState = battlers.get(&"lysandra") as BattlerState

	var attempt: GrappleAttemptResult = controller.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	_expect(
		attempt.error_message.is_empty(),
		"The Struggle-panel fixture should prepare Grapple."
	)
	if not attempt.error_message.is_empty():
		return
	controller.resolve_initiation(false)

	var packed_panel := load(
		"res://scenes/battle/ui/reusable/components/struggle_panel.tscn"
	) as PackedScene
	var panel := packed_panel.instantiate() as StrugglePanel
	get_root().add_child(panel)

	var registry_size_before: int = battlers.size()
	panel.present(
		heroine,
		controller.get_tracks_for_heroine(&"lysandra"),
		battlers
	)
	panel.close_panel()

	_expect(
		battlers.size() == registry_size_before
		and battlers.has(&"lysandra")
		and battlers.has(&"hollow_servant"),
		"Closing StrugglePanel must not clear the encounter battler registry."
	)
	_expect(
		controller.get_main_track_for_heroine(&"lysandra") != null
		and heroine.is_grappled(),
		"Closing StrugglePanel must not alter the active Grapple track."
	)

	get_root().remove_child(panel)
	panel.free()


func _test_secondary_attachment_suppression_and_succession() -> void:
	var fixture: Dictionary = _make_fixture()
	var controller: GrappleController = fixture.get(
		"controller"
	) as GrappleController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var heroine: BattlerState = battlers.get(&"lysandra") as BattlerState
	var hollow: BattlerState = (
		battlers.get(&"hollow_servant") as BattlerState
	)
	var footman: BattlerState = (
		battlers.get(&"knife_footman") as BattlerState
	)
	var template: GrappleTemplateDefinition = (
		hollow.definition.grapple_template
	)

	var attempt: GrappleAttemptResult = controller.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	_expect(
		attempt.error_message.is_empty(),
		"The multi-track fixture should prepare its main Grapple."
	)
	if not attempt.error_message.is_empty():
		return
	controller.resolve_initiation(false)

	footman.set_current_actions(0)
	_expect(
		not controller.can_attach_secondary(
			&"knife_footman",
			&"lysandra",
			template,
			true
		),
		"Corruption below 30 should limit the heroine to one participant."
	)

	heroine.change_corruption(30 - heroine.current_corruption)
	var resources_before: Vector2i = Vector2i(
		heroine.current_corruption,
		heroine.current_resolve
	)
	var attachment: GrappleActionResult = (
		controller.attach_secondary(
			&"knife_footman",
			&"lysandra",
			template,
			true
		)
	)
	_expect(
		attachment.succeeded
		and attachment.track != null
		and not attachment.track.is_main,
		"A paid Move entering a capacity-2 cluster should attach a secondary even at zero remaining Actions."
	)
	_expect(
		heroine.active_grapple_track_ids.size() == 2,
		"The heroine should record both independent tracks."
	)
	_expect(
		Vector2i(heroine.current_corruption, heroine.current_resolve)
		== resources_before,
		"Secondary Stage 1 attachment should suppress ordinary resource effects."
	)

	footman.restore_actions_to_maximum()
	var secondary_progress: GrappleActionResult = (
		controller.progress_track(&"knife_footman")
	)
	_expect(
		secondary_progress.succeeded
		and secondary_progress.stage_after == 2,
		"The secondary track should Progress independently."
	)
	_expect(
		Vector2i(heroine.current_corruption, heroine.current_resolve)
		== resources_before,
		"Secondary Progress should suppress ordinary Corruption and Resolve effects."
	)

	hollow.apply_damage(hollow.get_max_hp())
	var promoted: GrappleTrackState = (
		controller.get_main_track_for_heroine(&"lysandra")
	)
	_expect(
		promoted != null
		and promoted.grappler_id == &"knife_footman"
		and promoted.is_main,
		"Defeating the main grappler should immediately promote the remaining track."
	)
	_expect(
		promoted != null and promoted.get_stage_number() == 2,
		"Promotion should preserve the secondary track's current stage."
	)
	_expect(
		Vector2i(heroine.current_corruption, heroine.current_resolve)
		== resources_before,
		"Promotion should apply no resource effect."
	)


func _test_forced_cluster_movement_keeps_bundle_together() -> void:
	var fixture: Dictionary = _make_fixture()
	var controller: GrappleController = fixture.get(
		"controller"
	) as GrappleController
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState

	var attempt: GrappleAttemptResult = controller.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	if not attempt.error_message.is_empty():
		_expect(false, attempt.error_message)
		return
	controller.resolve_initiation(false)

	var move_error: String = controller.force_move_cluster(
		&"lysandra",
		&"central_nave",
		1
	)
	_expect(
		move_error.is_empty(),
		"A legal forced cluster destination should succeed."
	)
	var heroine_position: BattlerPositionState = (
		battlefield.get_battler_position(&"lysandra")
	)
	var grappler_position: BattlerPositionState = (
		battlefield.get_battler_position(&"hollow_servant")
	)
	_expect(
		heroine_position.anchor_id == &"central_nave"
		and heroine_position.position_index == 1
		and grappler_position.anchor_id == heroine_position.anchor_id
		and grappler_position.position_index
		== heroine_position.position_index,
		"Forced movement should move every cluster participant together."
	)
	_expect(
		not battlefield.get_battlers_at(&"central_nave", 0).is_empty()
		and not controller.force_move_cluster(
			&"lysandra",
			&"central_nave",
			0
		).is_empty(),
		"An occupied destination should fail instead of splitting the cluster."
	)


func _test_detachment_uses_connected_anchor_fallback() -> void:
	var fixture: Dictionary = _make_fixture()
	var controller: GrappleController = fixture.get(
		"controller"
	) as GrappleController
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState

	var attempt: GrappleAttemptResult = controller.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	if not attempt.error_message.is_empty():
		_expect(false, attempt.error_message)
		return
	controller.resolve_initiation(false)

	_expect(
		battlefield.place_battler(
			&"knife_footman",
			&"altar_left",
			2
		).is_empty(),
		"The fallback test should fill Altar Left Position 3."
	)
	_expect(
		battlefield.place_battler(
			&"prayer_rag_novice",
			&"altar_left",
			3
		).is_empty(),
		"The fallback test should fill Altar Left Position 4."
	)

	var separation: GrappleActionResult = (
		controller.force_separate_grappler(&"hollow_servant")
	)
	var detached_position: BattlerPositionState = (
		battlefield.get_battler_position(&"hollow_servant")
	)
	_expect(
		separation.succeeded
		and detached_position.anchor_id == &"central_nave",
		"With no same-Anchor slot, detachment should use the first authored connected Anchor."
	)


func _test_detachment_over_capacity_fallback() -> void:
	var fixture: Dictionary = _make_fixture()
	var controller: GrappleController = fixture.get(
		"controller"
	) as GrappleController
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var battlers: Dictionary = fixture.get("battlers") as Dictionary

	var attempt: GrappleAttemptResult = controller.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	if not attempt.error_message.is_empty():
		_expect(false, attempt.error_message)
		return
	controller.resolve_initiation(false)

	_expect(
		battlefield.place_battler(&"knife_footman", &"altar_left", 2).is_empty(),
		"Over-capacity fixture should fill Altar Left Position 3."
	)
	_expect(
		battlefield.place_battler(&"prayer_rag_novice", &"altar_left", 3).is_empty(),
		"Over-capacity fixture should fill Altar Left Position 4."
	)
	_add_dummy_occupant(
		battlers,
		battlefield,
		&"central_fill_0",
		&"central_nave",
		0
	)
	_add_dummy_occupant(
		battlers,
		battlefield,
		&"central_fill_1",
		&"central_nave",
		1
	)
	_add_dummy_occupant(
		battlers,
		battlefield,
		&"central_fill_2",
		&"central_nave",
		2
	)
	_add_dummy_occupant(
		battlers,
		battlefield,
		&"central_fill_3",
		&"central_nave",
		3
	)
	_add_dummy_occupant(
		battlers,
		battlefield,
		&"altar_right_fill",
		&"altar_right",
		1
	)

	var separation: GrappleActionResult = (
		controller.force_separate_grappler(&"hollow_servant")
	)
	_expect(
		separation.succeeded
		and battlefield.is_battler_over_capacity(&"hollow_servant"),
		"Detachment must still succeed through temporary over-capacity placement."
	)
	_expect(
		not battlefield.place_battler(
			&"seraphine",
			&"altar_left",
			0
		).is_empty(),
		"No battler may voluntarily enter an over-capacity Anchor."
	)
	_expect(
		not battlefield.place_battler(
			&"hollow_servant",
			&"altar_left",
			2
		).is_empty(),
		"An over-capacity battler's next movement cannot remain in that Anchor."
	)
	_expect(
		battlefield.place_battler(
			&"hollow_servant",
			&"right_nave",
			1
		).is_empty()
		and not battlefield.is_battler_over_capacity(
			&"hollow_servant"
		),
		"Leaving the Anchor should clear over-capacity state."
	)


func _add_dummy_occupant(
	battlers: Dictionary,
	battlefield: BattlefieldState,
	battler_id: StringName,
	anchor_id: StringName,
	position_index: int
) -> void:
	var source_definition: BattlerDefinition = load(
		"res://data/battlers/enemies/knife_footman.tres"
	) as BattlerDefinition
	var definition: BattlerDefinition = (
		source_definition.duplicate(true) as BattlerDefinition
	)
	definition.battler_id = battler_id
	definition.display_name = String(battler_id)
	var state: BattlerState = BattlerState.new(definition)
	battlers[battler_id] = state
	battlefield.battler_states[battler_id] = state
	_expect(
		battlefield.place_battler(
			battler_id,
			anchor_id,
			position_index
		).is_empty(),
		"Dummy occupancy placement should succeed."
	)


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
		BattleBootstrap.new().create_battler_states(definitions)
	)
	var battlefield: BattlefieldState = BattlefieldState.new()
	var field_definition: BattlefieldDefinition = load(
		"res://data/battlefields/ruined_chapel_spatial_test.tres"
	) as BattlefieldDefinition
	var error: String = battlefield.initialize(
		field_definition,
		battlers
	)
	_expect(error.is_empty(), "The Grapple fixture battlefield should load.")

	error = battlefield.place_battler(
		&"hollow_servant",
		&"altar_left",
		2
	)
	_expect(error.is_empty(), "The grappler should move beside Lysandra.")

	var targeting: BattleTargetingController = (
		BattleTargetingController.new()
	)
	targeting.initialize(battlers, battlefield)
	var controller: GrappleController = GrappleController.new()
	controller.initialize(
		battlers,
		battlefield,
		targeting,
		DiceResolver.new(),
		4100
	)
	return {
		"battlers": battlers,
		"battlefield": battlefield,
		"controller": controller,
	}


func _find_winning_struggle_seed(
	heroine_pool: int
) -> int:
	var resolver: DiceResolver = DiceResolver.new()
	for seed_value: int in range(1, 1000):
		var heroine_roll: RollResult = resolver.roll_attribute(
			heroine_pool,
			seed_value
		)
		var grappler_roll: RollResult = resolver.roll_attribute(
			0,
			seed_value + 1
		)
		if heroine_roll.total_successes > grappler_roll.total_successes:
			return seed_value
	return 1


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
