extends SceneTree


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_modular_scenes_load()
	_test_curated_party_portraits()
	await _test_live_battle_uses_art_hud()
	if failures == 0:
		print("Combat HUD tests passed.")
	else:
		push_error("%d Combat HUD test(s) failed." % failures)
	quit(failures)


func _test_modular_scenes_load() -> void:
	var scene_paths: Array[String] = [
		"res://scenes/battle/runtime/dice_roller.tscn",
		"res://scenes/battle/combat_encounter.tscn",
		"res://scenes/battle/runtime/combat_engine.tscn",
		"res://scenes/battle/runtime/combat_presenter.tscn",
		"res://scenes/battle/ui/reusable/combat_hud.tscn",
		"res://scenes/battle/ui/reusable/components/heroine_card_view.tscn",
		"res://scenes/battle/ui/reusable/components/item_bar_view.tscn",
		"res://scenes/battle/ui/reusable/components/command_bar_view.tscn",
		"res://scenes/battle/ui/reusable/components/combat_log_drawer.tscn",
		"res://scenes/battle/ui/reusable/components/reaction_exchange.tscn",
		"res://scenes/battle/ui/reusable/components/enemy_hud_view.tscn",
		"res://scenes/battle/ui/reusable/components/ability_panel.tscn",
		"res://scenes/battle/ui/reusable/components/struggle_panel.tscn",
	]
	for path: String in scene_paths:
		_expect(load(path) is PackedScene, "HUD scene should load: %s." % path)


func _test_curated_party_portraits() -> void:
	var expected_sources: Dictionary = {
		"LysandraCard": {
			"path": "assets/characters/curated/lysandra/core_idle_front.png",
			"region": Rect2(500.0, 50.0, 300.0, 400.0),
		},
		"MiraCard": {
			"path": "assets/characters/curated/mira/core_move_front.png",
			"region": Rect2(470.0, 30.0, 300.0, 400.0),
		},
		"SeraphineCard": {
			"path": "assets/characters/curated/seraphine/core_idle_front.png",
			"region": Rect2(470.0, 20.0, 300.0, 400.0),
		},
	}
	for proof: Dictionary in [
		{
			"scene": "res://scenes/battle/ui/reusable/combat_hud.tscn",
			"cards": "Root/PartyStrip/Cards",
		},
		{
			"scene": "res://scenes/exploration/components/exploration_hud.tscn",
			"cards": "PartyStrip/Cards",
		},
	]:
		var packed := load(String(proof.get("scene"))) as PackedScene
		var hud: Node = packed.instantiate() if packed != null else null
		_expect(hud != null, "Party portrait HUD should instantiate.")
		if hud == null:
			continue
		for card_name: String in expected_sources:
			var expected: Dictionary = expected_sources[card_name] as Dictionary
			var portrait := hud.get_node_or_null(
				"%s/%s/MarginContainer/HBoxContainer/PortraitFrame/Portrait"
				% [String(proof.get("cards")), card_name]
			) as TextureRect
			var atlas := portrait.texture as AtlasTexture if portrait != null else null
			_expect(
				atlas != null
				and atlas.atlas.resource_path.ends_with(
					String(expected.get("path", ""))
				)
				and atlas.region == expected.get("region", Rect2()),
				"%s should use a face-first crop of its current curated %s portrait."
				% [String(proof.get("scene")), card_name]
			)
		hud.free()


func _test_live_battle_uses_art_hud() -> void:
	var battle_scene := load(
		"res://scenes/battle/combat_encounter.tscn"
	) as PackedScene
	_expect(battle_scene != null, "CombatEncounter should load.")
	if battle_scene == null:
		return
	var battle := battle_scene.instantiate()
	root.add_child(battle)
	await process_frame
	_expect(
		battle.get_node_or_null(
			"Battlefield/BattlefieldHost/OpeningServantCorridorAuthoring/BackgroundLayer/BackgroundArt"
		)
		is Sprite2D,
		"Live battle should use the editor-aligned painted battlefield Sprite2D."
	)
	_expect(
		battle.get_node_or_null("CombatEngine") is CombatEngine,
		"Live battle should instance the reusable CombatEngine."
	)
	var engine := battle.get_node_or_null("CombatEngine") as CombatEngine
	_expect(
		engine != null and engine.is_initialized,
		"Reusable CombatEngine should initialize the live encounter."
	)
	_expect(
		battle.get_node_or_null("CombatPresenter") is CombatPresenter,
		"Live battle should instance the reusable CombatPresenter."
	)
	_expect(
		battle.get_node_or_null("ReusableCombatHUD")
		is ReusableCombatHUD,
		"Live battle should instance the reusable combat HUD."
	)
	var hud := battle.get_node_or_null(
		"ReusableCombatHUD"
	) as ReusableCombatHUD
	var imported_frame := load(
		"res://scenes/battle/ui/reusable/styles/hud_frame_style.tres"
	) as StyleBox
	var top_bar := hud.get_node("Root/TopBar") as PanelContainer
	_expect(
		hud != null
		and top_bar != null
		and top_bar.get_theme_stylebox("panel") == imported_frame,
		"The reusable UI must use its original imported frame StyleBox."
	)
	var party_strip := hud.get_node("Root/PartyStrip") as PanelContainer
	var cards := hud.get_node("Root/PartyStrip/Cards") as VBoxContainer
	_expect(
		party_strip != null
		and cards != null
		and cards.get_child_count() == 3
		and cards.get_child(0).name == "LysandraCard"
		and cards.get_child(1).name == "MiraCard"
		and cards.get_child(2).name == "SeraphineCard",
		"Party HUD should be a three-card vertical stack at bottom-left."
	)
	var item_bar := hud.get_node("Root/ItemBar") as ItemBarView
	var command_bar := hud.get_node("Root/CommandBar") as CommandBarView
	_expect(
		item_bar != null
		and command_bar != null
		and item_bar.custom_minimum_size == Vector2(74.0, 384.0)
		and command_bar.custom_minimum_size == Vector2(88.0, 372.0),
		"Items should use the right-edge tray and Commands the vertical icon bar."
	)
	_expect(
		hud.combat_log.custom_minimum_size == Vector2(320.0, 220.0)
		and hud.combat_log.position.x >= 1920.0,
		"The closed Log should remain off-screen at the user's authored height."
	)
	_expect(
		hud.ability_panel.command_anchor == command_bar.ability_button
		and hud.struggle_panel.command_anchor == command_bar.struggle_button,
		"Ability and Struggle panels should unfold from their command icons."
	)
	for command_name: String in [
		"Attack", "Move", "Ability", "EndPhase", "Log"
	]:
		var command := command_bar.get_node("%%%s" % command_name) as Button
		_expect(
			command != null
			and command.text.is_empty()
			and command.icon != null,
			"Command %s should be icon-only." % command_name
		)
	_expect(
		hud.find_child("SystemControls", true, false) == null,
		"The separately designed UI must not gain an extra controls strip."
	)
	var log_scroll := hud.combat_log.get_node(
		"MarginContainer/Content/LogScroll"
	) as ScrollContainer
	var log_entries := hud.combat_log.entries
	_expect(
		log_scroll != null
		and log_scroll.horizontal_scroll_mode
		== ScrollContainer.SCROLL_MODE_DISABLED,
		"Combat Log should use its drawer width instead of horizontal scrolling."
	)
	_expect(
		log_entries.size_flags_horizontal
		== Control.SIZE_EXPAND_FILL,
		"Combat Log entries should expand to the drawer width."
	)
	hud.combat_log.append_entry("Round 1 — Hero Phase")
	hud.combat_log.append_detail("Phase-start effects: none.")
	var sample_entry := log_entries.get_child(
		log_entries.get_child_count() - 1
	) as Label
	_expect(
		sample_entry != null
		and sample_entry.size_flags_horizontal
		== Control.SIZE_EXPAND_FILL
		and sample_entry.tooltip_text == "Phase-start effects: none."
		and sample_entry.mouse_filter == Control.MOUSE_FILTER_STOP
		and sample_entry.get_theme_font_size("font_size") == 12,
		"Compact Log entries should expose technical details on hover."
	)
	_expect(
		hud.reaction_exchange.custom_minimum_size
		== Vector2(430.0, 170.0)
		and hud.reaction_exchange.compact_frame_size
		== Vector2(430.0, 170.0)
		and hud.reaction_exchange.get_node_or_null("Dimmer") == null,
		"Reaction prompts should be compact sprite cards, not full-screen modals."
	)
	hud.reaction_exchange.set_context(
		"Corrupted Butler",
		"Mira",
		2,
		"Attack"
	)
	hud.reaction_exchange.open_exchange()
	await process_frame
	_expect(
		hud.reaction_exchange.size == Vector2(430.0, 170.0)
		and hud.reaction_exchange.custom_minimum_size
		== Vector2(430.0, 170.0)
		and hud.reaction_exchange.frame.size
		== hud.reaction_exchange.size
		and hud.reaction_exchange.frame.anchor_right == 1.0
		and hud.reaction_exchange.frame.anchor_bottom == 1.0,
		"Reaction window root should enforce its compact visible rectangle."
	)
	_expect(
		hud.struggle_panel is Control
		and hud.struggle_panel.get_node_or_null("Frame") is PanelContainer,
		"Struggle should use a fixed floating root with a content-sized Frame."
	)
	_expect(
		hud.reaction_exchange.context_label.text
		== "Corrupted Butler uses Attack on Mira"
		and not hud.reaction_exchange.context_label.text.contains("→"),
		"Reaction copy should avoid unsupported arrow glyphs."
	)
	hud.close_reaction_exchange()
	hud.present_equipment_break("Lysandra's Chain", 1)
	_expect(
		hud.reaction_exchange.visible
		and hud.reaction_exchange.equipment_choice_pending
		and hud.reaction_exchange.equipment_choices.visible,
		"Equipment break must reopen an exchange closed by zero-Action Skip."
	)
	hud.close_reaction_exchange()
	for heroine_name: String in [
		"LysandraMarker",
		"MiraMarker",
		"SeraphineMarker",
	]:
		var art := battle.get_node_or_null(
			"Battlefield/MarkerHost/%s/CharacterArt"
			% heroine_name
		) as Sprite2D
		_expect(
			art != null and art.texture != null,
			"Live battle should display profile art for %s."
			% heroine_name
		)
		var hit_area := battle.get_node_or_null(
			"Battlefield/MarkerHost/%s/SelectButton"
			% heroine_name
		) as Button
		_expect(
			hit_area != null
			and hit_area.size.x >= 140.0
			and hit_area.size.y >= 260.0
			and hit_area.text.is_empty(),
			"Heroine selection should use the full sprite HitArea for %s."
			% heroine_name
		)
	for enemy_name: String in [
		"HollowServantMarker",
		"CorruptedButlerMarker",
	]:
		var marker := battle.get_node_or_null(
			"Battlefield/MarkerHost/%s" % enemy_name
		) as BattleMarker
		_expect(
			marker != null
			and marker.enemy_hud != null
			and marker.enemy_hud.name_label.visible
			and not marker.enemy_hud.name_label.text.is_empty()
			and marker.enemy_hud.custom_minimum_size.y >= 58.0
			and marker.character_art != null
			and not marker.character_art.centered
			and marker.select_button_base_position.is_equal_approx(
				marker.character_art_base_position
			)
			and marker.enemy_hud_base_position.y < (
				marker.character_art_base_position.y
			)
			and not marker.should_draw_context_ring(),
			"Enemy %s should display its name, HP, and Actions above its sprite."
			% enemy_name
		)
		if marker != null:
			marker.present_visual_event(&"move", &"back", 0.0, false)
			_expect(
				marker.enemy_hud != null
				and marker.enemy_hud.visible
				and marker.select_button_base_position.is_equal_approx(
					marker.character_art_base_position
				)
				and marker.enemy_hud_base_position.y < (
					marker.character_art_base_position.y
				),
				"Enemy %s should keep its HUD attached after a dodge/pose swap."
				% enemy_name
			)
	var lysandra_marker := battle.get_node_or_null(
		"Battlefield/MarkerHost/LysandraMarker"
	) as BattleMarker
	var butler_marker := battle.get_node_or_null(
		"Battlefield/MarkerHost/CorruptedButlerMarker"
	) as BattleMarker
	var legal_target_ids: Array[StringName] = [&"corrupted_butler"]
	battle._set_attack_targeting_markers(true, legal_target_ids)
	_expect(
		lysandra_marker != null
		and butler_marker != null
		and is_equal_approx(
			lysandra_marker.character_art.self_modulate.a,
			0.46
		)
		and is_equal_approx(
			butler_marker.character_art.self_modulate.a,
			0.72
		)
		and is_equal_approx(butler_marker.enemy_hud.modulate.a, 1.0),
		"Battler targeting should fade non-target art while keeping the legal target and its HUD readable."
	)
	battle._set_attack_targeting_markers(false)
	battle._on_board_selection_visibility_changed(true)
	_expect(
		is_equal_approx(
			lysandra_marker.character_art.self_modulate.a,
			0.46
		)
		and is_equal_approx(
			butler_marker.character_art.self_modulate.a,
			0.46
		),
		"Spatial selection should fade all battler art uniformly."
	)
	battle._on_board_selection_visibility_changed(false)
	_expect(
		is_equal_approx(
			lysandra_marker.character_art.self_modulate.a,
			1.0
		)
		and is_equal_approx(
			butler_marker.character_art.self_modulate.a,
			1.0
		),
		"Leaving a selection should restore full battler opacity."
	)
	var defeated_marker := battle.get_node_or_null(
		"Battlefield/MarkerHost/HollowServantMarker"
	) as BattleMarker
	if defeated_marker != null and defeated_marker.battler_state != null:
		defeated_marker.battler_state.apply_damage(999)
		await process_frame
	_expect(
		defeated_marker != null
		and defeated_marker.enemy_hud != null
		and not defeated_marker.enemy_hud.visible,
		"A defeated enemy should keep its defeated art without an empty HUD."
	)
	_expect(
		battle.get_node_or_null(
			"Battlefield/MarkerHost/KnifeFootmanMarker"
		) == null,
		"Dynamic marker composition should not create inactive enemies."
	)
	_expect(
		battle.get_node_or_null("UILayer") == null,
		"Production combat must not contain the retired UI tree."
	)
	battle.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
