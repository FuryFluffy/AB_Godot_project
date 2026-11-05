extends "res://tools/verify_run_backpack.gd"
## Production Main, Refuge, departure/save and combat hosts; prior story is fixture-controlled.
var main: AbyssalBloomMainController
var scene: Node

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--intel-captures="):
			captures = argument.trim_prefix("--intel-captures=")
	CampaignSaveSlotStore.set_test_save_directory("user://stage22_interface")
	CampaignSaveSlotStore.delete_slot(1)
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	scene = preload("res://scenes/main/main.tscn").instantiate()
	view.add_child(scene)
	main = scene.get_node("Controller")
	main.active_save_slot_id = 1
	var party: Dictionary = {}
	for id: StringName in HEROES:
		var definition: BattlerDefinition = BATTLERS.get_battler(id)
		party[id] = {"hp":definition.max_hp,"mp":definition.max_mp,"resolve":definition.starting_resolve,"corruption":definition.starting_corruption}
	main.run_state.initialize(2202,main.generator.generate_bloom_refuge_holding_state(2202),[],party)
	main.run_state.opening_completed = true
	main.run_state.completed_layer_ids = [&"layer_1"]
	main.run_state.narrative_state.recruited_heroine_ids = HEROES.duplicate()
	main.run_state.campaign_lifecycle.restore_legacy_refuge(2202)
	main.run_state.narrative_state.flags_by_scope[&"save"][RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	main.run_state.narrative_state.flags_by_scope[&"save"][RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	main.run_state.bloom = 1500
	main.run_state.ensure_refuge_ownership_initialized()
	main.run_state.run_changed.connect(main._refresh_map)
	_check(main._save_active_refuge().is_empty(),"Production Refuge slot created")
	main.boot_fallback.hide()
	main._show_refuge_hub()
	await _settle()
	await _intel_ui()
	await _departure()
	await _submit_combat()
	scene.queue_free()
	await process_frame
	CampaignSaveSlotStore.force_test_write_failure = false
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 22 native Intel/Submit: %d checks, %d failures." % [checks,failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _open_intel() -> RefugeExpeditionView:
	main.active_refuge.room_shell.open_station(&"expedition")
	main.active_refuge.expedition_view.show_section(&"intel")
	await _settle()
	return main.active_refuge.expedition_view

func _click_option(id: StringName) -> void:
	var button: Button = main.active_refuge.expedition_view.intel_buttons[id]
	button.grab_focus()
	await _settle()
	await _click(button.get_global_rect().get_center())
	await _settle()

func _tab(index: int) -> void:
	var tabs: TabBar = main.active_refuge.expedition_view.intel_tabs
	tabs.grab_focus()
	await _settle()
	await _click(tabs.global_position + tabs.get_tab_rect(index).get_center())
	await _settle()

func _intel_ui() -> void:
	var expedition: RefugeExpeditionView = await _open_intel()
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1024,768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920,roundi(1920.0*resolution.y/resolution.x))
		await _tab(0)
		_check(expedition.intel_list.get_child_count() == 9 and not expedition.intel_buttons.scouting.disabled,"This Run shows all nine Intel options")
		_check(not expedition.intel_buttons.castle_memory.disabled and expedition.passage_purchase_selector.item_count > 0,"Castle Memory and eligible Passage controls are present")
		_check(Rect2(Vector2.ZERO,Vector2(view.size_2d_override)).encloses(main.active_refuge.room_shell.panel.get_global_rect()),"Intel modal fits viewport")
		await _shot(resolution,"intel_this_run")
		await _tab(1)
		_check(expedition.intel_list.get_child_count() == 10 and expedition.intel_buttons.scouting.text == "1000 Bloom" and expedition.intel_buttons.submit.text == "100 Bloom","Permanent counterparts and separate Submit have approved prices")
		expedition.intel_buttons.submit.grab_focus()
		await _settle()
		await _shot(resolution,"intel_permanent_submit")
	_check(main.run_state.bloom == 1500 and main.run_state.refuge_ownership.pending_intel.is_empty(),"Viewing and changing tabs is free")
	await _tab(0)
	var before: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	CampaignSaveSlotStore.force_test_write_failure = true
	await _click_option(&"scouting")
	_check(main.run_state.bloom == 1500 and main.run_state.refuge_ownership.pending_intel.is_empty() and CampaignSaveSlotStore.read_document_for_load(1).document == before,"Real failed purchase leaves wallet, ownership and document unchanged")
	CampaignSaveSlotStore.force_test_write_failure = false
	await _click_option(&"scouting")
	_check(main.run_state.bloom == 1490 and main.run_state.refuge_ownership.pending_intel == [&"scouting"],"Actual purchase click charges once")
	await _cancel()
	await _cancel()
	expedition = await _open_intel()
	_check(expedition.intel_buttons.scouting.disabled and main.run_state.bloom == 1490,"Cancel and reopen retains paid next-run ownership without refund")
	_check(main.load_campaign_slot(1).is_empty(),"Main Load restores bought preparation")
	await _settle()
	expedition = await _open_intel()
	_check(expedition.intel_buttons.scouting.disabled and main.run_state.bloom == 1490,"Load keeps pending purchase and spent wallet")
	await _click_option(&"battle_sense")
	await _tab(1)
	await _click_option(&"pathfinding")
	await _click_option(&"submit")
	_check(main.run_state.bloom == 380 and main.run_state.refuge_ownership.permanent_intel.has(&"pathfinding") and main.run_state.refuge_ownership.permanent_intel.has(&"submit"),"Permanent purchases deduct exact approved costs")
	_check(main.active_refuge.expedition_view.intel_buttons.sanctuary_sense.disabled,"Unaffordable permanent purchase disabled")
	await _tab(0)
	_check(main.active_refuge.expedition_view.intel_buttons.pathfinding.disabled,"Permanent benefit needs no temporary repurchase")
	await _shot(view.size,"intel_purchased")

func _departure() -> void:
	main.active_refuge.expedition_view.show_section(&"hub")
	main.active_refuge.seed_edit.text = "2202"
	await _settle()
	var before: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	var pending: Array[StringName] = main.run_state.refuge_ownership.pending_intel.duplicate()
	CampaignSaveSlotStore.force_test_write_failure = true
	await _click(main.active_refuge.begin_button.get_global_rect().get_center())
	await _settle()
	_check(main.active_refuge != null and main.run_state.bloom == 380 and main.run_state.refuge_ownership.pending_intel == pending,"Failed Explore preserves wallet and pending purchases")
	_check(CampaignSaveSlotStore.read_document_for_load(1).document == before,"Failed Explore retains previous durable Refuge")
	CampaignSaveSlotStore.force_test_write_failure = false
	await _click(main.active_refuge.begin_button.get_global_rect().get_center())
	await _settle()
	_check(main.active_refuge == null and main.run_state.bloom == 0 and main.run_state.refuge_ownership.pending_intel.is_empty(),"Successful Explore consumes temporary ownership once and keeps existing Bloom discard")
	_check(main.run_state.get_run_intel_ids().has(&"scouting") and main.run_state.get_run_intel_ids().has(&"battle_sense") and main.run_state.get_run_intel_ids().has(&"pathfinding"),"New run receives temporary plus permanent benefits")
	var document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	_check(document.active_run_snapshot is Dictionary and document.refuge_snapshot.pending_intel.is_empty(),"One durable departure contains active benefits and a consumed fallback boundary")
	var graph: Dictionary = main.run_state.graph.to_snapshot()
	_check(main.continue_active_run_slot(1).is_empty(),"Continue resumes departure immediately")
	await _settle()
	_check(main.run_state.graph.to_snapshot() == graph and main.run_state.get_run_intel_ids().has(&"scouting") and main.run_state.refuge_ownership.permanent_intel.has(&"submit"),"Continue preserves map knowledge and permanent combat unlock")
	await _shot(view.size,"intel_map")

func _submit_combat() -> void:
	var node: MapNodeState
	for candidate: MapNodeState in main.run_state.graph.nodes.values():
		if candidate.node_type == MapNodeState.NodeType.BATTLE:
			node = candidate
			break
	var origin: MapNodeState = main.run_state.graph.get_map_node(node.incoming_ids[0])
	origin.visited = true
	origin.cleared = true
	origin.exit_completed = true
	origin.encounter_cleared = origin.has_encounter_content()
	origin.reward_claimed = true
	main.run_state.current_node_id = origin.node_id
	main.run_state.graph.reveal_adjacency(origin.node_id,true)
	main.run_state.select_node(node.node_id)
	main._on_travel_pressed()
	await _settle()
	var encounter: CombatEncounter = main.active_battle
	_check(encounter != null and encounter.combat_engine.submit_unlocked,"Production combat receives permanent Submit entitlement")
	if encounter == null: return
	_check(encounter.battle_flow_controller.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST).is_empty(),"Actual encounter starts")
	var heroine: BattlerState = encounter.get_battler_state(&"lysandra")
	var enemy: BattlerState
	for candidate: BattlerState in encounter.battler_states.values():
		if candidate.definition.faction == BattlerDefinition.Faction.ENEMY and candidate.definition.grapple_template != null:
			enemy = candidate
			break
	_check(enemy != null,"Authored enemy supports Grapple")
	if enemy == null: return
	var anchor: AnchorDefinition = encounter.battlefield_state.get_battler_anchor(&"lysandra")
	var slots: Array[int] = encounter.battlefield_state.get_free_position_indices(anchor.anchor_id)
	_check(not slots.is_empty() and encounter.battlefield_state.place_battler(enemy.definition.battler_id,anchor.anchor_id,slots[0]).is_empty(),"Fixture places existing enemy adjacent to heroine")
	enemy.set_current_actions(3)
	encounter.grapple_controller.prepare_initiation(enemy.definition.battler_id,&"lysandra")
	_check(encounter.grapple_controller.resolve_initiation(false).succeeded,"Production Grapple established")
	encounter._restore_selected_battler(&"lysandra")
	heroine.current_hp = maxi(1,heroine.get_max_hp()-2)
	heroine.current_mp = 0
	heroine.set_current_actions(3)
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1024,768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920,roundi(1920.0*resolution.y/resolution.x))
		await _settle()
		encounter._refresh_grapple_command_bar()
		_check(encounter.submit_button.visible and not encounter.submit_button.disabled,"Unlocked Submit is available in eligible Struggle")
		await _key(KEY_B)
		_check(not encounter.backpack_panel.visible and encounter.reusable_hud.dock.backpack_button.disabled,"Grapple still blocks Backpack")
		await _shot(resolution,"submit_struggle")
	var track: GrappleTrackState = encounter.grapple_controller.get_main_track_for_heroine(&"lysandra")
	var stage: int = track.stage_index
	var hp: int = heroine.current_hp
	await _click(encounter.submit_button.get_global_rect().get_center())
	await _settle()
	_check(track.stage_index == stage+1 and heroine.current_actions == 0 and heroine.current_hp == hp+1,"Native Submit advances one stage, heals one and spends all Actions")
	_check(encounter.battle_runtime.battle_state.phase == BattleState.Phase.HERO,"Submit preserves Hero Phase")
	_check(encounter.submit_button.disabled,"No duplicate Submit with exhausted Actions")
