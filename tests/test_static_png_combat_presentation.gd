extends SceneTree


const STAGE_CATALOG_PATH := "res://data/presentation/combat_stage_catalog.tres"
const COMBAT_SCENE_PATH := "res://scenes/battle/combat_encounter.tscn"


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(STAGE_CATALOG_PATH) as CombatStageCatalog
	_test_stage_catalog(catalog)
	await _test_profile_renderer_and_authoritative_movement(catalog)
	await _test_front_mask_presentation(catalog)
	_test_marker_only_fallback()
	if failures == 0:
		print("Static-PNG combat presentation tests passed.")
	else:
		push_error("%d static-PNG presentation test(s) failed." % failures)
	quit(failures)


func _test_stage_catalog(catalog: CombatStageCatalog) -> void:
	_expect(catalog != null, "The combat-stage catalog should load.")
	if catalog == null:
		return
	_expect(
		catalog.validate_definition().is_empty(),
		"The combat-stage catalog should validate: %s"
		% catalog.validate_definition()
	)
	_expect(
		catalog.stages.size() == 7 and catalog.bindings.size() == 7,
		"Exactly the seven production-reachable encounter variants should be bound."
	)
	for stage_id: StringName in [
		&"opening_servant_corridor_stage",
		&"ruined_chapel_stage",
		&"blood_nun_processing_chapel_stage",
		&"jailer_containment_landing_stage",
	]:
		var stage: CombatStageDefinition = catalog.get_stage(stage_id)
		_expect(
			stage != null and stage.background_texture != null,
			"Reviewed active stage '%s' should have an authored background." % stage_id
		)
	for preserved_id: StringName in [
		&"selected_layer_1_battle_stage",
		&"layer_2_chain_maintenance_stage",
	]:
		var preserved: CombatStageDefinition = catalog.get_stage(preserved_id)
		_expect(
			preserved != null and preserved.preserve_authored_background,
			"Tactically unreviewed stage '%s' should preserve its existing background."
			% preserved_id
		)
	for stage: CombatStageDefinition in catalog.stages:
		_expect(
			not stage.experimental_foreground_enabled,
			"Experimental foreground treatment must remain disabled on '%s'."
			% stage.stage_id
		)


func _test_profile_renderer_and_authoritative_movement(
	catalog: CombatStageCatalog
) -> void:
	if catalog == null:
		return
	var definition := EncounterDefinition.new()
	definition.encounter_id = &"layer_1_lysandra_opening_hollow_servant"
	definition.source_node_id = &"layer_1_opening_servant_corridor"
	definition.authored_room_id = &"opening_servant_corridor"
	definition.combat_stage_id = &"opening_servant_corridor_stage"
	definition.display_name = "Opening Static-PNG Proof"
	definition.party_ids = [&"lysandra"]
	definition.enemy_ids = [&"hollow_servant"]
	definition.template = load(
		"res://data/encounters/opening_servant_corridor.tres"
	) as EncounterTemplateDefinition
	_expect(
		definition.ensure_spawn_assignments().is_empty(),
		"Opening proof encounter should assign its battlers."
	)
	var packed := load(COMBAT_SCENE_PATH) as PackedScene
	var encounter := packed.instantiate() as CombatEncounter
	encounter.prepare_run_encounter(definition, {}, [])
	root.add_child(encounter)
	await process_frame
	await process_frame
	var marker := encounter.get_node_or_null(
		"Battlefield/MarkerHost/LysandraMarker"
	) as BattleMarker
	var enemy_marker: BattleMarker
	for candidate: BattleMarker in encounter.battler_markers:
		if candidate != null and candidate.battler_id == &"hollow_servant":
			enemy_marker = candidate
			break
	_expect(
		encounter.active_combat_stage != null
		and encounter.active_combat_stage.stage_id
		== &"opening_servant_corridor_stage",
		"The opening encounter should resolve its linked combat stage."
	)
	_expect(
		marker != null
		and marker.uses_profile_art
		and marker.character_art != null
		and marker.character_art.texture != null
		and marker.current_orientation == &"back"
		and marker.character_art.texture.resource_path.ends_with(
			"assets/characters/curated/lysandra/core_idle_back.png"
		)
		and "assets/characters/curated/lysandra/" in (
			marker.character_art.texture.resource_path
		),
		"The opening marker should render Lysandra from behind in the reviewed corridor."
	)
	var party_placement: BattlerPositionState = (
		encounter.battlefield_state.get_battler_position(&"lysandra")
	)
	var enemy_placement: BattlerPositionState = (
		encounter.battlefield_state.get_battler_position(&"hollow_servant")
	)
	if party_placement != null and enemy_placement != null:
		encounter.battlefield_definition.get_anchor(
			party_placement.anchor_id
		).visual_orientation = &"front"
		encounter.battlefield_definition.get_anchor(
			enemy_placement.anchor_id
		).visual_orientation = &"back"
		encounter._apply_marker_anchor_presentation(
			marker,
			party_placement.anchor_id
		)
		encounter._apply_marker_anchor_presentation(
			enemy_marker,
			enemy_placement.anchor_id
		)
	_expect(
		marker != null and marker.current_orientation == &"back"
		and enemy_marker != null and enemy_marker.current_orientation == &"front",
		"Living opponents should face each other independently of contradictory anchor defaults."
	)
	if marker != null:
		marker.present_visual_event(&"attack_started", &"back", 0.3)
		await create_timer(0.18).timeout
		_expect(
			marker.current_pose_key == &"attack"
			and marker.current_orientation == &"back"
			and marker.character_art.texture.resource_path.ends_with(
				"assets/characters/curated/lysandra/core_attack_back.png"
			),
			(
				"Attack intent should retain the authored rear-facing presentation "
				+ "(pose=%s, orientation=%s, texture=%s)."
				% [
					marker.current_pose_key,
					marker.current_orientation,
					marker.character_art.texture.resource_path,
				]
			)
		)
		await create_timer(0.35).timeout
		_expect(
			marker.current_pose_key == &"idle",
			"A transient pose should return to idle through its owned timer."
		)
		var expected_idle_orientation: StringName = (
			encounter._resolve_battler_visual_orientation(
				&"lysandra",
				&"front"
			)
		)
		var stale_orientation: StringName = (
			&"front" if expected_idle_orientation == &"back" else &"back"
		)
		marker.present_visual_event(
			&"attack_started",
			stale_orientation,
			0.25,
			false
		)
		encounter._refresh_battler_marker_orientations()
		_expect(
			marker.current_visual_event == &"attack_started"
			and marker.current_orientation == expected_idle_orientation,
			"A dodge-time refresh should re-face an active Attack pose immediately."
		)
		await create_timer(0.35).timeout
		_expect(
			marker.current_visual_event == &"idle"
			and marker.current_orientation == expected_idle_orientation,
			"Transient completion should re-resolve nearest-opponent facing."
		)

	if enemy_marker != null and enemy_marker.battler_state != null:
		enemy_marker.battler_state.apply_damage(1)
		await create_timer(0.18).timeout
		_expect(
			enemy_marker.current_pose_key == &"hurt",
			"Damage should present the enemy Hurt pose."
		)
		var current_enemy_placement: BattlerPositionState = (
			encounter.battlefield_state.get_battler_position(&"hollow_servant")
		)
		if current_enemy_placement != null:
			encounter._apply_marker_anchor_presentation(
				enemy_marker,
				current_enemy_placement.anchor_id
			)
		await create_timer(0.6).timeout
		_expect(
			enemy_marker.current_visual_event == &"idle"
			and enemy_marker.current_pose_key == &"idle",
			"Spatial/facing relayout must not strand an enemy in Hurt."
		)

	if (
		marker != null
		and enemy_marker != null
		and marker.battler_state != null
		and enemy_marker.battler_state != null
		and enemy_marker.battler_state.definition.grapple_template != null
	):
		var grapple_track: GrappleTrackState = (
			encounter.grapple_controller._create_initial_track(
				marker.battler_state,
				enemy_marker.battler_state,
				enemy_marker.battler_state.definition.grapple_template
			)
		)
		encounter._refresh_grapple_cluster_marker_offsets()
		await create_timer(0.18).timeout
		_expect(
			grapple_track != null
			and marker.current_visual_event == &"grapple_subject"
			and marker.current_pose_key == &"hurt"
			and enemy_marker.current_visual_event == &"grapple_holder"
			and enemy_marker.current_pose_key == &"attack"
			and enemy_marker.character_art.z_index
			< marker.character_art.z_index
			and enemy_marker.cluster_display_offset.y < 0.0
			and marker.cluster_display_offset.y > 0.0,
			"An active Grapple should hold distinct subject/holder poses and layer the holder behind the heroine."
		)
		encounter.grapple_controller.force_separate_grappler(
			enemy_marker.battler_id
		)
		encounter._refresh_grapple_cluster_marker_offsets()
		await create_timer(0.18).timeout
		_expect(
			marker.current_visual_event == &"idle"
			and enemy_marker.current_visual_event == &"idle"
			and enemy_marker.character_art.z_index
			== BattleMarker.CHARACTER_ART_Z_OFFSET,
			"Separating a Grapple should restore idle poses and ordinary sprite layering."
		)

	if marker != null:
		_expect(
			encounter.battlefield_input_overlay.z_index > marker.z_index,
			"Contextual selection geometry should render above battler art."
		)
		marker.set_selection_visibility(true, 0.46)
		_expect(
			is_equal_approx(marker.character_art.self_modulate.a, 0.46),
			"Spatial selection should reveal geometry through battler art."
		)
		marker.set_selection_visibility(false)
		_expect(
			is_equal_approx(marker.character_art.self_modulate.a, 1.0),
			"Finishing selection should restore opaque battler art."
		)
		var original_position: Vector2 = marker.position
		var moved: bool = false
		var destination_anchor_id: StringName = &""
		var destination_position_index: int = -1
		for anchor: AnchorDefinition in encounter.battlefield_definition.anchors:
			for position_index: int in range(anchor.capacity):
				if not encounter.battlefield_state.get_battlers_at(
					anchor.anchor_id,
					position_index
				).is_empty():
					continue
				var place_error: String = encounter.battlefield_state.place_battler(
					&"lysandra",
					anchor.anchor_id,
					position_index
				)
				if not place_error.is_empty():
					continue
				moved = true
				destination_anchor_id = anchor.anchor_id
				destination_position_index = position_index
				break
			if moved:
				break
		_expect(moved, "The presentation test should find a free authored Position.")
		if moved:
			var destination_position: Vector2 = (
				encounter.battlefield_state.get_world_position(&"lysandra")
			)
			marker.position = original_position
			encounter.call_deferred(
				"_animate_move_step",
				&"lysandra",
				destination_anchor_id,
				destination_position_index
			)
			await create_timer(0.17).timeout
			_expect(
				marker.position == original_position
				and marker.character_art.modulate.a < 1.0,
				"A movement step should fade at its origin without gliding away."
			)
			await create_timer(0.5).timeout
			_expect(
				marker.position == destination_position
				and is_equal_approx(marker.character_art.modulate.a, 1.0)
				and marker.current_pose_key == &"idle",
				"A movement step should snap while hidden, fade in, and finish idle."
			)
	encounter.queue_free()
	await process_frame


func _test_front_mask_presentation(catalog: CombatStageCatalog) -> void:
	if catalog == null:
		return
	var cases: Array[Dictionary] = [
		{
			"stage_id": &"ruined_chapel_stage",
			"scene": "res://scenes/battle/battlefields/ruined_chapel_battlefield.tscn",
			"prop_id": &"ruined_chapel_front_pew",
		},
		{
			"stage_id": &"jailer_containment_landing_stage",
			"scene": "res://scenes/battle/battlefields/jailer_containment_landing_battlefield.tscn",
			"prop_id": &"jailer_front_iron_divider",
		},
	]
	for proof: Dictionary in cases:
		var battlefield := (
			load(String(proof.get("scene"))) as PackedScene
		).instantiate() as AuthoredBattlefield
		var presenter := CombatStagePresenter.new()
		root.add_child(battlefield)
		root.add_child(presenter)
		var stage: CombatStageDefinition = catalog.get_stage(
			StringName(proof.get("stage_id"))
		)
		var error: String = presenter.apply_stage(stage, battlefield)
		var prop: Node2D = presenter.get_presented_prop(
			StringName(proof.get("prop_id"))
		)
		_expect(error.is_empty(), "Front-mask stage should apply: %s" % error)
		_expect(
			prop != null
			and prop.get_node_or_null("FrontMask") is Sprite2D
			and prop.get_parent().z_index > 30,
			"The L1/L2 proof prop should render as a foreground front mask."
		)
		_expect(
			prop != null
			and not bool(prop.get_meta("mechanical", true))
			and StringName(prop.get_meta("battlefield_rule_id", &"")) == &"",
			"Occlusion proof props should remain explicitly decorative."
		)
		presenter.clear_stage()
		await process_frame
		_expect(
			presenter.get_presented_prop(StringName(proof.get("prop_id"))) == null,
			"Stage cleanup should release generated prop presentation nodes."
		)
		presenter.queue_free()
		battlefield.queue_free()
		await process_frame


func _test_marker_only_fallback() -> void:
	var marker := (
		load("res://scenes/battle/presentation/battle_marker.tscn") as PackedScene
	).instantiate() as BattleMarker
	marker.battler_id = &"chain_warden"
	marker.configure_visual_profile(load(
		"res://data/presentation/battler_visual_profile_catalog.tres"
	) as BattlerVisualProfileCatalog)
	root.add_child(marker)
	_expect(
		not marker.present_visual_event(&"idle", &"front"),
		"Chain Warden should safely retain the marker-only fallback."
	)
	_expect(
		marker.select_button != null and not marker.uses_profile_art,
		"Marker-only fallback should preserve the accessible BattleMarker shell."
	)
	marker.set_battlefield_presentation(2.25, 30, &"foreground", false)
	_expect(
		is_equal_approx(marker.battlefield_presentation_scale, 2.25),
		"Runtime battler presentation should accept authored scales above 1.5."
	)
	marker.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
