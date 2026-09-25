extends SceneTree


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(
		"res://scenes/battle/combat_encounter.tscn"
	) as PackedScene
	_expect(packed != null, "CombatEncounter should load.")
	if packed == null:
		quit(failures)
		return

	var encounter := packed.instantiate() as CombatEncounter
	root.add_child(encounter)
	await process_frame

	var hud := encounter.reusable_hud
	_expect(hud != null, "Reusable Combat HUD should initialize.")
	if hud == null:
		encounter.queue_free()
		quit(failures)
		return

	hud.command_bar.end_phase_button.pressed.emit()
	await process_frame
	await process_frame

	var state := encounter.battle_runtime.battle_state
	_expect(
		state.encounter_started,
		"Begin should start the encounter."
	)
	_expect(
		state.round_number == 1,
		"Begin should advance setup to round one."
	)
	_expect(
		not encounter.encounter_starting,
		"Deferred encounter startup should always release its guard."
	)
	_expect(
		hud.command_bar.end_phase_button.text != "BEGIN",
		"Begin should refresh the reusable command bar."
	)
	hud.command_bar.log_button.pressed.emit()
	await hud.log_animation.animation_finished
	_expect(
		hud.log_is_open and hud.combat_log.visible,
		"Log should open from the reusable command bar."
	)
	_expect(
		hud.combat_log.is_visible_in_tree(),
		"Open combat log should be visible in the scene tree."
	)
	hud.command_bar.log_button.pressed.emit()
	await hud.log_animation.animation_finished
	_expect(
		not hud.log_is_open
		and hud.combat_log.visible
		and hud.combat_log.position.x >= 1920.0,
		"Second Log press should finish closing the drawer off-screen."
	)

	encounter.queue_free()
	await process_frame
	await _test_butler_art_is_not_covered(packed)
	if failures == 0:
		print("Encounter startup test passed.")
	else:
		push_error(
			"%d encounter startup test(s) failed." % failures
		)
	quit(failures)


func _test_butler_art_is_not_covered(
	packed: PackedScene
) -> void:
	var definition := EncounterDefinition.new()
	definition.encounter_id = &"test_butler"
	definition.source_node_id = &"test_node"
	definition.enemy_ids = [&"corrupted_butler"]

	var encounter := packed.instantiate() as CombatEncounter
	encounter.prepare_run_encounter(definition, {}, [])
	root.add_child(encounter)
	await process_frame

	var marker := encounter.get_node(
		"Battlefield/MarkerHost/CorruptedButlerMarker"
	) as BattleMarker
	_expect(marker.visible, "Butler marker should be visible.")
	_expect(
		marker.character_art != null
		and marker.character_art.visible
		and marker.character_art.texture != null,
		"Butler CharacterArt should be visible and textured."
	)
	var normal := marker.select_button.get_theme_stylebox(
		"normal"
	) as StyleBoxFlat
	_expect(
		normal != null and normal.bg_color.a <= 0.01,
		"Butler's full-body hit area must not cover his sprite."
	)
	var start_error: String = (
		encounter.battle_flow_controller.start_encounter(
			BattleFlowController.OrderMode.FORCE_PARTY_MOMENTUM
		)
	)
	_expect(
		start_error.is_empty(),
		"Momentum lifecycle fixture should start."
	)
	encounter.battle_flow_controller.end_current_phase()
	encounter._queue_combat_progression()
	await process_frame
	await process_frame
	_expect(
		encounter.battle_runtime.battle_state.round_number == 2
		and encounter.battle_runtime.battle_state.phase
		== BattleState.Phase.HERO,
		"Party Momentum should continue directly to round-two Hero Phase."
	)
	encounter.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
