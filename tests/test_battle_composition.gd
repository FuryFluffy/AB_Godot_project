extends SceneTree


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_ruined_chapel_composition()
	await _test_processing_chapel_composition()
	if failures == 0:
		print("Battle Composition tests passed.")
	else:
		push_error("%d Battle Composition test(s) failed." % failures)
	quit(failures)


func _test_ruined_chapel_composition() -> void:
	var definition := EncounterDefinition.new()
	definition.encounter_id = &"composition_ruined_chapel_proof"
	definition.source_node_id = &"composition_test_node"
	definition.display_name = "Ruined Chapel Composition Proof"
	definition.enemy_ids = [
		&"hollow_servant",
		&"knife_footman",
		&"prayer_rag_novice",
	]
	definition.template = load(
		"res://data/encounters/ruined_chapel_template.tres"
	) as EncounterTemplateDefinition
	var assignment_error: String = definition.ensure_spawn_assignments()
	_expect(
		assignment_error.is_empty(),
		"Ruined Chapel template should assign all active battlers: %s"
		% assignment_error
	)
	if not assignment_error.is_empty():
		return
	var packed := load(
		"res://scenes/battle/combat_encounter.tscn"
	) as PackedScene
	var encounter := packed.instantiate() as CombatEncounter
	encounter.prepare_run_encounter(definition, {}, [])
	root.add_child(encounter)
	await process_frame
	_expect(
		encounter.active_battlefield != null
		and encounter.battlefield_definition.battlefield_id
		== &"ruined_chapel",
		"The explicit Ruined Chapel scenario should load its battlefield scene."
	)
	_expect(
		encounter.battler_markers.size() == 6
		and encounter.marker_host.get_child_count() == 6,
		"The generic host should create only three heroines and three active enemies."
	)
	_expect(
		encounter.active_battlefield.definition.initial_placements.is_empty()
		and encounter.battlefield_definition.initial_placements.size() == 6,
		"Authored battlefield data should stay neutral while runtime receives concrete placements."
	)
	encounter.queue_free()
	await process_frame


func _test_processing_chapel_composition() -> void:
	var definition := EncounterDefinition.new()
	definition.encounter_id = &"composition_boss_proof"
	definition.source_node_id = &"composition_test_node"
	definition.display_name = "Composition Boss Proof"
	definition.is_boss = true
	definition.enemy_ids = [&"blood_nun", &"prayer_rag_novice"]
	definition.template = load(
		"res://data/encounters/processing_chapel_template.tres"
	) as EncounterTemplateDefinition
	_expect(
		definition.ensure_spawn_assignments().is_empty(),
		"Processing Chapel template should assign all active battlers."
	)

	var packed := load(
		"res://scenes/battle/combat_encounter.tscn"
	) as PackedScene
	var encounter := packed.instantiate() as CombatEncounter
	encounter.prepare_run_encounter(definition, {}, [])
	root.add_child(encounter)
	await process_frame
	_expect(
		encounter.active_battlefield != null
		and encounter.battlefield_definition.battlefield_id
		== &"blood_nun_processing_chapel",
		"The same combat host should load the Processing Chapel battlefield."
	)
	_expect(
		encounter.battler_markers.size() == 5
		and encounter.get_node_or_null(
			"Battlefield/MarkerHost/BloodNunMarker"
		) != null
		and encounter.get_node_or_null(
			"Battlefield/MarkerHost/HollowServantMarker"
		) == null,
		"The second composition should create only its requested battler views."
	)
	_expect(
		encounter.active_battlefield.definition.terrain_lines.is_empty(),
		"Production battlefield authoring should keep cover and sight blockers deferred."
	)
	encounter.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
