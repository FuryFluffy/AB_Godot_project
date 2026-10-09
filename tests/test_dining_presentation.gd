extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: CombatStageCatalog = load("res://data/presentation/combat_stage_catalog.tres")
	for stage: CombatStageDefinition in catalog.stages:
		_expect((stage.presentation_profile != null) == (stage.stage_id == &"dining_service_hall_stage"),
			"Only Dining Hall should opt into the presentation pilot.")
	var encounter: CombatEncounter = _encounter()
	root.add_child(encounter)
	await process_frame
	await process_frame
	var director: CombatPresentationDirector = encounter.presentation_director
	_expect(director != null, "Dining Hall must compose its director.")
	if director == null:
		quit(1)
		return
	var start_error: String = encounter.battle_flow_controller.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST)
	_expect(start_error.is_empty(), "The real encounter should start.")
	encounter._refresh_battle_flow_ui()
	var lysandra: BattleMarker = encounter._get_battler_marker(&"lysandra")
	var source: Vector2 = lysandra.position
	var source_scale: float = lysandra.battlefield_presentation_scale
	var actions_before: int = lysandra.battler_state.current_actions
	var previews: Array[MovementPreview] = encounter.movement_controller.begin_move_selection(&"lysandra")
	var chosen: MovementPreview
	for preview: MovementPreview in previews:
		if preview.destination_anchor_id == &"west_lane" and preview.available_destination_positions.has(2):
			chosen = preview
	_expect(chosen != null, "The existing graph must offer the tested movement route.")
	if chosen != null:
		encounter._on_move_confirmed(chosen, 2)
		await create_timer(0.16).timeout
		var destination: Vector2 = encounter.battlefield_definition.get_anchor(&"west_lane").get_position_point(2)
		_expect(lysandra.position != source and lysandra.position != destination,
			"Committed movement should visibly interpolate rather than snap.")
		_expect(lysandra.battlefield_presentation_scale < source_scale,
			"Moving into the room should interpolate the authored smaller scale.")
		_expect(is_equal_approx(lysandra.character_art.modulate.a, 1.0),
			"Smooth movement must not reuse the fade-out transition.")
		await create_timer(0.8).timeout
		_expect(lysandra.position.is_equal_approx(destination), "Movement must end at its exact authored Position.")
		_expect(lysandra.battler_state.current_actions == actions_before - 1,
			"Presentation must preserve the existing one-Action Move cost.")
		_expect(not encounter.battle_runtime.has_active_move(), "The real committed Move must complete.")

	# Exercise the real attack/defense/result pipeline, including continuation
	# suppression while the lethal target has zero HP and a reaction is pending.
	encounter.battlefield_state.place_battler(&"lysandra", &"west_lane", 1)
	await process_frame
	encounter.battle_runtime.selected_battler_id = &"lysandra"
	var attack_error: String = encounter.action_controller.begin_attack_targeting()
	_expect(attack_error.is_empty(), "The sword attack should enter targeting.")
	var context: ReactionContext = encounter.action_controller.prepare_attack(&"hollow_servant")
	_expect(context.is_valid, "The sword attack should use an existing legal contact.")
	if context.is_valid:
		encounter._on_defense_chosen(DefenseChoice.Type.SKIP)
		await create_timer(0.10).timeout
		_expect(director.busy, "The resolved sword result should play a cinematic cue.")
		var sword_target: BattleMarker = encounter._get_battler_marker(&"hollow_servant")
		_expect(sword_target.current_visual_event != &"defeated",
			"The lethal target must keep its pre-impact pose until the sword lands.")
		var hp_after_resolution: int = sword_target.battler_state.current_hp
		var actions_after_resolution: int = lysandra.battler_state.current_actions
		encounter._on_defense_chosen(DefenseChoice.Type.SKIP)
		_expect(sword_target.battler_state.current_hp == hp_after_resolution
			and lysandra.battler_state.current_actions == actions_after_resolution,
			"Duplicate reaction callbacks must not resolve the same action twice.")
		var phase_before: int = encounter.battle_runtime.battle_state.phase
		encounter._on_phase_button_pressed()
		_expect(encounter.battle_runtime.battle_state.phase == phase_before,
			"Phase input must not skip an in-flight presentation.")
		await create_timer(1.2).timeout
		_expect(not director.busy and not encounter.battle_runtime.has_pending_reaction(),
			"Presentation must release resolution and pending reactions exactly once.")
		_expect(director.camera.position.is_equal_approx(CombatPresentationDirector.HOME)
			and director.camera.zoom.is_equal_approx(Vector2.ONE),
			"Camera must return to the authored tactical framing.")
		_expect(sword_target.current_visual_event == &"defeated" and not sword_target.defer_result_pose,
			"The actual defeated pose must be released at impact.")
	encounter.queue_free()
	await process_frame

	# Independent visual fixture checks: effects consume a resolved result only.
	encounter = _encounter()
	root.add_child(encounter)
	await process_frame
	director = encounter.presentation_director
	var caster: BattleMarker = encounter._get_battler_marker(&"seraphine")
	var target: BattleMarker = encounter._get_battler_marker(&"hollow_servant")
	encounter.battle_flow_controller.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST)
	encounter._refresh_battle_flow_ui()
	encounter.battlefield_state.place_battler(&"seraphine", &"east_lane", 2)
	await process_frame
	var real_spell: AbilityDefinition = caster.battler_state.get_ability(&"seraphine_light_arrow")
	var mp_before: int = caster.battler_state.current_mp
	var spell_actions_before: int = caster.battler_state.current_actions
	var legal_ids: Array[StringName] = encounter.ability_controller.begin_targeting(&"seraphine", real_spell)
	_expect(legal_ids.has(&"hollow_servant"), "Light Arrow must use an existing legal target.")
	var spell_outcome: Variant = encounter.ability_controller.commit_target(&"hollow_servant")
	_expect(spell_outcome is ReactionContext and spell_outcome.is_valid, "The real spell must prepare its reaction.")
	encounter._on_defense_chosen(DefenseChoice.Type.SKIP)
	await create_timer(0.1).timeout
	_expect(director.busy and target.current_visual_event != &"damage_received",
		"Light Arrow must retain the target pose during projectile flight.")
	await create_timer(1.2).timeout
	_expect(caster.battler_state.current_mp == mp_before - 1
		and caster.battler_state.current_actions == spell_actions_before - 1,
		"Light Arrow must preserve its one-MP and one-Action costs.")
	_expect(not director.busy and not encounter.battle_runtime.has_pending_reaction()
		and not target.defer_result_pose, "The real spell must release presentation and reaction state.")
	var hp: int = target.battler_state.current_hp
	var mp: int = caster.battler_state.current_mp
	var positions: Vector2 = caster.position
	var request := ActionRequest.new()
	request.actor_id = &"seraphine"
	request.target_id = &"hollow_servant"
	request.ability = load("res://data/abilities/seraphine_light_arrow.tres")
	var result := ActionResult.new()
	result.succeeded = true
	result.damage_dealt = 0
	director.profile = director.profile.duplicate()
	director.profile.cinematic_camera_enabled = false
	director.camera.enabled = false
	await director.play_action(request, result)
	_expect(target.battler_state.current_hp == hp and caster.battler_state.current_mp == mp
		and caster.position == positions, "Visual-only playback must never apply damage, costs or movement.")
	_expect(caster.character_art.material == null and target.character_art.material == null,
		"Temporary spell lighting must restore original sprite materials.")
	_expect(not director.camera.enabled and director.camera.zoom == Vector2.ONE,
		"Disabling cinematic camera must leave tactical framing intact.")
	# Let the previous camera-disabled effect finish its independent lifetime.
	await create_timer(0.3).timeout
	# Profile toggles retain safe tactical framing without VFX or camera motion.
	director.profile.effects_enabled = false
	director.camera.enabled = true
	director.camera.position = director._safe_focus(CombatPresentationDirector.HOME, 1.0)
	var passive_position: Vector2 = director.camera.position
	director.play_action(request, result)
	await create_timer(0.1).timeout
	_expect(director.camera.position == passive_position and director.camera.zoom == Vector2.ONE
		and director.camera.offset == Vector2.ZERO, "Disabled cinematic motion must retain passive dock clearance.")
	var effect_count: int = 0
	for child: Node in director.get_children():
		if child is CombatActionEffect:
			effect_count += 1
	_expect(effect_count == 0 and director.temporary_lights.is_empty(),
		"Disabling effects through the profile must create no effect nodes or sprite lights.")
	await create_timer(1.0).timeout
	_expect(not director.busy and target.battler_state.current_hp == hp
		and caster.battler_state.current_mp == mp, "Disabled presentation must finish without changing state.")
	director.profile.effects_enabled = true
	request.ability = null
	request.source = ActionRequest.Source.ITEM
	_expect(not director.supports_action(request), "Unconfigured item attacks must keep their existing presentation.")
	director.profile.cinematic_camera_enabled = true
	director.camera.enabled = true
	request.ability = load("res://data/abilities/seraphine_light_arrow.tres")
	director.play_action(request, result)
	await create_timer(0.1).timeout
	encounter.queue_free()
	await create_timer(1.0).timeout
	_expect(not is_instance_valid(director), "Exiting mid-cinematic must release its camera, VFX and tweens.")
	if failures == 0:
		print("Dining Hall presentation integration tests passed.")
	quit(failures)


func _encounter() -> CombatEncounter:
	var definition := EncounterDefinition.new()
	definition.encounter_id = &"dining_presentation_test"
	definition.authored_room_id = &"dining_service_hall"
	definition.combat_stage_id = &"dining_service_hall_stage"
	definition.display_name = "Dining Presentation Test"
	definition.enemy_ids.assign([&"hollow_servant"])
	definition.template = load("res://data/encounters/dining_service_hall_template.tres")
	var encounter: CombatEncounter = load("res://scenes/battle/combat_encounter.tscn").instantiate()
	var inventory: Array[Dictionary] = []
	encounter.prepare_run_encounter(definition, {}, inventory)
	return encounter


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
