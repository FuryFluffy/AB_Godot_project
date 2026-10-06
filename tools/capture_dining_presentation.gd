extends SceneTree

## Deterministic visual QA fixture; uses real actions and existing authored Positions.
## Run with --write-movie /absolute/path/dining.avi --fixed-fps 60.
## Optional AB_PILOT_CAPTURE_DIR writes PNG frames for inspection.
var encounter: CombatEncounter
var failures: int = 0


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1920, 1080)
	await _new_encounter()
	await create_timer(0.7).timeout
	await _snapshot("01_tactical")
	var previews: Array[MovementPreview] = encounter.movement_controller.begin_move_selection(&"lysandra")
	var chosen: MovementPreview
	for preview: MovementPreview in previews:
		if preview.destination_anchor_id == &"west_lane" and preview.available_destination_positions.has(2):
			chosen = preview
	if chosen == null:
		_fail("Authored movement route unavailable.")
	else:
		encounter._on_move_confirmed(chosen, 2)
		await create_timer(0.22).timeout
		await _snapshot("02_move_depth")
		await create_timer(1.5).timeout
	await _new_encounter()
	encounter.battlefield_state.place_battler(&"lysandra", &"west_lane", 1)
	await process_frame
	encounter._on_battler_selected(&"lysandra")
	await create_timer(0.7).timeout
	encounter._on_attack_pressed()
	encounter._on_battler_selected(&"hollow_servant")
	if not encounter.battle_runtime.has_pending_reaction():
		_fail("Legal sword attack unavailable.")
	else:
		await create_timer(0.27).timeout
		await _snapshot("03_sword_impact")
		await create_timer(1.8).timeout
	await _new_encounter()
	encounter.battlefield_state.place_battler(&"seraphine", &"east_lane", 2)
	await process_frame
	encounter._on_battler_selected(&"seraphine")
	await create_timer(0.7).timeout
	encounter._on_ability_chosen(&"seraphine_light_arrow")
	if not encounter.battle_runtime.is_selecting_ability_target:
		_fail("Legal Light Arrow target unavailable.")
	else:
		encounter._on_battler_selected(&"hollow_servant")
		if not encounter.battle_runtime.has_pending_reaction():
			_fail("Light Arrow failed to prepare.")
		else:
			await create_timer(0.34).timeout
			await _snapshot("04_light_arrow_flight")
			await create_timer(0.19).timeout
			await _snapshot("05_light_arrow_impact")
			await create_timer(1.6).timeout
	encounter.queue_free()
	await process_frame
	print("Dining presentation capture completed; failures: %d" % failures)
	quit(failures)


func _new_encounter() -> void:
	if is_instance_valid(encounter):
		encounter.queue_free()
		await process_frame
	var definition := EncounterDefinition.new()
	definition.encounter_id = &"dining_presentation_capture"
	definition.authored_room_id = &"dining_service_hall"
	definition.combat_stage_id = &"dining_service_hall_stage"
	definition.display_name = "Dining Service Hall"
	definition.encounter_seed = 1
	definition.enemy_ids.assign([&"hollow_servant"])
	definition.template = load("res://data/encounters/dining_service_hall_template.tres")
	encounter = load("res://scenes/battle/combat_encounter.tscn").instantiate()
	var inventory: Array[Dictionary] = []
	encounter.prepare_run_encounter(definition, {}, inventory)
	root.add_child(encounter)
	await process_frame
	var error: String = encounter.battle_flow_controller.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST)
	if not error.is_empty():
		_fail(error)
	encounter._refresh_battle_flow_ui()
	await process_frame


func _snapshot(label: String) -> void:
	var directory: String = OS.get_environment("AB_PILOT_CAPTURE_DIR")
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	if error != OK:
		_fail("Could not write QA frame: " + label)


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
