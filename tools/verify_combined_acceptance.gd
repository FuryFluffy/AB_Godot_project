extends "res://tools/verify_castle_memory.gd"
## One campaign across real controllers, screens and durable saves.
## Prior story, route access, test recipes and battle outcomes are explicit fixtures.
const ROOMS = preload("res://data/exploration/rooms/event_room_catalog.tres")
const MEDIA = preload("res://tests/fixtures/refuge_archive_fixture.gd")
var recipe: RefugeRecipeDefinition
var journey_seed: int
var armor_id: StringName
var order: Array[StringName] = [&"mira", &"seraphine", &"lysandra"]

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--acceptance-captures="):
			captures = argument.trim_prefix("--acceptance-captures=")
	CampaignSaveSlotStore.set_test_save_directory("user://stage24_combined")
	CampaignSaveSlotStore.delete_slot(1)
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	view.physics_object_picking = true
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
	main.run_state.bloom = 50000
	main.run_state.campaign_lifecycle.mark_boss_defeated(RunState.JAILER_BOSS_ID)
	main.run_state.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	main.run_state.ensure_refuge_ownership_initialized()
	main.run_state.run_changed.connect(main._refresh_map)
	_check(main._save_active_refuge().is_empty(),"Production Refuge slot created")
	main.boot_fallback.hide()
	main._show_refuge_hub()
	await _settle()
	await _preparation()
	await _journey()

	scene.queue_free()
	await process_frame
	CampaignSaveSlotStore.force_test_write_failure = false
	CampaignSaveSlotStore.delete_slot(1)
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 24 combined campaign: %d checks, %d failures." % [checks,failures])
	view.queue_free()
	await process_frame
	quit(failures)

func _preparation() -> void:
	var management: RefugeManagementController = main.active_refuge.management
	_check(management.get_production_entries(RefugeRecipeDefinition.Station.ALCHEMY).is_empty(), "Shipped Alchemy remains empty before fixtures")
	_check(management.get_production_entries(RefugeRecipeDefinition.Station.CRAFTING).is_empty(), "Shipped Crafting remains empty before fixtures")
	# Fixture supplies and damaged equipment; all subsequent transactions persist normally.
	main.run_state.refuge_ownership.banked_materials["mat_l01_servant_cloth"] = 5
	armor_id = StringName(main.run_state.refuge_ownership.equipment_loadouts_by_heroine[&"seraphine"].slots.armor)
	main.run_state.refuge_ownership.equipment_loadouts_by_heroine[&"seraphine"].instances[String(armor_id)].current_condition = 0
	_check(String(management.execute_repair(&"refuge_repair_cloth_armor", armor_id, main.run_state.refuge_ownership.to_snapshot()).error).is_empty(), "Repair commits to same campaign")
	_check(String(management.unequip_slot(&"seraphine", EquipmentDefinition.Slot.ARMOR).error).is_empty(), "Unequip retains repaired instance")
	_check(String(management.equip_instance(&"seraphine", EquipmentDefinition.Slot.ARMOR, armor_id).error).is_empty(), "Equip restores exact repaired instance")
	var salvage: EquipmentDefinition = management.EQUIPMENT_CATALOG.get_equipment(&"red_wax_drip")
	var old_available: bool = salvage.player_refuge_available
	salvage.player_refuge_available = true
	var instance := EquipmentInstance.new()
	instance.initialize(&"fixture:acceptance:salvage",salvage,0)
	main.run_state.refuge_ownership.stash_equipment_instances[instance.instance_id] = instance.to_snapshot()
	_check(String(management.salvage_equipment(instance.instance_id).error).is_empty(), "Fixture-only salvage banks authored yield")
	salvage.player_refuge_available = old_available
	recipe = preload("res://tests/field_production_test_fixtures.gd").register_discovery()
	recipe.starts_known = true
	_check(String(management.produce_item(recipe.station, recipe.recipe_id, main.run_state.refuge_ownership.to_snapshot()).error).is_empty(), "Test recipe spends banked Materials into Stash")
	var stash: Array[Dictionary] = management.get_stash_item_entries()
	var index: int = -1
	for entry: Dictionary in stash:
		if String(entry.get("item_id", "")) == "l01_bandage_roll":
			index = int(entry.slot_index)
			break
	_check(index >= 0,"Refuge production output is in Stash")
	if index >= 0:
		var source: Dictionary = RefugeInventoryTransfer.address(&"stash",index)
		var target: Dictionary = RefugeInventoryTransfer.address(&"backpack",0,&"mira")
		_check(int(management.transfer_inventory(management.inventory_request(source), target, 1, true).get("moved",0)) == 1, "Crafted output transfers to preparation Backpack")
	main.active_refuge.room_shell.open_station(&"rest")
	_check(main.active_refuge.rest_view.restore_button.disabled and main.active_refuge.rest_view.cleanse_button.disabled, "Unauthored paid bed remains unavailable")
	main.active_refuge.room_shell.open_station(&"expedition")
	var expedition: RefugeExpeditionView = main.active_refuge.expedition_view
	expedition.show_section(&"level")
	_check(expedition.upgrade_button.disabled,"Unauthored Level Up remains unavailable")
	expedition.show_section(&"party")
	# Same Apply handler as the ordered sprite-selection UI; order is fixture-selected.
	expedition.draft = order.duplicate()
	expedition._refresh_draft()
	await _settle()
	await _click(expedition.apply_button.get_global_rect().get_center())
	_check(main.run_state.refuge_ownership.selected_party_ids == order,"Apply Party commits selected order")
	await _gallery()
	var before: Dictionary = main.run_state.refuge_ownership.to_snapshot()
	_check(main.load_campaign_slot(1).is_empty(),"Load repaired gear, crafted inventory and Party together")
	await _settle()
	_check(_same(main.run_state.refuge_ownership.to_snapshot(), before),"Load preserves combined preparation exactly")
	await _open_intel()
	await _tab(1)
	await _click_option(&"castle_memory")
	await _click_option(&"submit")
	_check(main.run_state.refuge_ownership.permanent_intel.has(&"castle_memory"),"Permanent Memory purchased before first departure")
	await _tab(0)
	await _click_option(&"conquerors_passage") # Layer 1 remains paid but unused on ordinary departure.
	await _cancel()
	await _cancel()
	var paid: int = main.run_state.bloom
	_check(main.load_campaign_slot(1).is_empty(),"Cancelled paid preparation restores")
	await _settle()
	_check(main.run_state.bloom == paid and main.run_state.refuge_ownership.pending_passage_layers == [1],"Cancel/Load neither refunds nor duplicates purchase")
	_check(String(main.active_refuge.management.select_passage(0).error).is_empty(),"Choose ordinary departure while retaining paid Layer 1 Passage")
	await _shot(view.size,"prepared_refuge")

func _gallery() -> void:
	main.active_refuge.room_shell.open_station(&"records")
	var records: RefugeRecordsView = main.active_refuge.records_view
	records.catalog = MEDIA.catalog()
	for entry: LoreEntryDefinition in records.catalog.entries:
		main.knowledge_state.discovered_entries[String(entry.lore_id)] = true
	records.tabs.current_tab = 3
	records.refresh()
	records.entry_list.select(1)
	records.entry_list.item_selected.emit(1)
	await _settle()
	var campaign: Dictionary = main.run_state.make_refuge_campaign_snapshot().duplicate(true)
	var known: Dictionary = main.knowledge_state.to_snapshot()
	var document: Dictionary = CampaignSaveSlotStore.read_document_for_load(1).document
	await _click(records.replay_button.get_global_rect().get_center())
	_check(records.nested_mode == &"replay", "Fixture Gallery scene opens isolated replay")
	await _shot(view.size,"gallery_replay")
	await _click(records.dialogue_panel.continue_button.get_global_rect().get_center())
	_check(records.nested_mode == &"" and campaign == main.run_state.make_refuge_campaign_snapshot() and known == main.knowledge_state.to_snapshot(),"Replay preserves campaign and discovery")
	_check(document == CampaignSaveSlotStore.read_document_for_load(1).document,"Replay never writes rewards or unlocks to disk")
	await _cancel()

func _journey() -> void:
	# Select one generated layout containing the representative services. No room registration changes.
	var kinds: Array[int] = [MapNodeState.NodeType.TREASURY,MapNodeState.NodeType.TRAP,MapNodeState.NodeType.ALCHEMY,MapNodeState.NodeType.REST,MapNodeState.NodeType.ELITE]
	for seed: int in range(1,1001):
		var graph: LayerMapGraph = main.generator.generate_layer_2_run(seed, main.run_state.get_defeated_boss_ids())
		var missing: Array[int] = kinds.duplicate()
		for node: MapNodeState in graph.nodes.values():
			missing.erase(node.node_type)
		if missing.is_empty():
			journey_seed = seed
			break
	_check(journey_seed > 0,"Generated combined journey seed found")
	if journey_seed == 0:
		return
	print("Combined campaign generated Layer 2 seed: ",journey_seed)
	await _explore(journey_seed)
	_check(main.run_state.refuge_ownership.selected_party_ids == order and main.run_state.run_inventory.material_pouch.is_empty(),"Ordered party departs without withdrawing banked Materials")
	await _treasury_visit()
	await _trap_visit()
	await _station_visit()
	await _rest_visit()
	await _fight(false,false)
	await _fight(true,false)
	var inventory: Dictionary = main.run_state.run_inventory.get_snapshot()
	var layout: Dictionary = main.run_state.graph.to_snapshot()
	_check(main._commit_refuge_return(null).is_empty(),"Production Return commits the combined expedition")
	await _settle()
	_check(main.load_campaign_slot(1).is_empty(),"Load returned campaign")
	await _settle()
	_check(main.run_state.refuge_ownership.knows_recipe(recipe.recipe_id) and main.run_state.refuge_ownership.selected_party_ids == order,"Return retains recipes and ordered party")
	_check(main.run_state.refuge_ownership.castle_layouts.layer_2.layout_seed == layout.layout_seed,"Return records visited layout")
	for material: String in inventory.material_pouch:
		_check(main.run_state.refuge_ownership.banked_materials.get(material,0) >= inventory.material_pouch[material],"Remaining run Material banks on Return: " + material)
	await _explore(journey_seed + 10000)
	_check(main.run_state.graph.layout_seed == layout.layout_seed and main.run_state.graph.run_seed != layout.run_seed,"Second expedition reuses layout with fresh content")
	_check(main.run_state.event_room_snapshots.is_empty() and main.run_state.run_inventory.material_pouch.is_empty(),"Remembered layout carries no claimed rooms or banked Materials into new run")
	await _fight(true,true)
	_check(main.run_state.refuge_ownership.knows_recipe(recipe.recipe_id) and main.run_state.refuge_ownership.pending_passage_layers == [1],"Defeat keeps permanent recipe and unused paid Passage")
	await _open_intel()
	_check(String(main.active_refuge.management.select_passage(1).error).is_empty(),"Select retained Layer 1 Passage after defeat")
	await _explore(journey_seed+10001)
	_check(main.run_state.graph.layer_id == &"layer_1" and main.run_state.current_node_id == main.run_state.graph.boss_node_id and main.run_state.refuge_ownership.pending_passage_layers.is_empty(),"Retained Passage starts correct defeated boss and consumes once")
	_check(main.continue_active_run_slot(1).is_empty(),"Continue final Passage safe point")
	await _settle()
	_check(main.run_state.refuge_ownership.pending_passage_layers.is_empty(),"Continue cannot restore consumed Passage")
	await _shot(view.size,"final_passage")
	RefugeOwnershipState.RECIPE_CATALOG.recipes.erase(recipe)

func _explore(seed: int) -> void:
	main.active_refuge.room_shell.open_station(&"expedition")
	main.active_refuge.expedition_view.show_section(&"hub")
	main.active_refuge.seed_edit.text = str(seed)
	await _settle()
	main.active_refuge.begin_button.grab_focus()
	await _settle()
	await _click(main.active_refuge.begin_button.get_global_rect().get_center())
	await _settle()
	_check(main.active_refuge == null,"Explore commits production departure")
	if main.active_refuge != null:
		print("Explore fixture diagnostic: ", main.active_refuge.begin_button.disabled, " / ", main.active_refuge.status_label.text)

func _node(kind: int) -> MapNodeState:
	for candidate: MapNodeState in main.run_state.graph.nodes.values():
		if candidate.node_type == kind:
			return candidate
	return null

func _visit(node: MapNodeState) -> void:
	# Route fixture only: preserve this campaign's ownership/claims while making adjacent Travel legal.
	var graph: LayerMapGraph = main.run_state.graph
	var origin: MapNodeState = graph.get_map_node(node.incoming_ids[0])
	origin.visited = true
	origin.cleared = true
	origin.exit_completed = true
	origin.encounter_cleared = origin.has_encounter_content()
	origin.reward_claimed = true
	main.run_state.current_node_id = origin.node_id
	graph.reveal_adjacency(origin.node_id)
	main._refresh_map()
	await _settle()
	main.run_state.select_node(node.node_id)
	main._on_travel_pressed()
	await _settle()
	_check(main.run_state.current_node_id == node.node_id,"Production Travel reaches " + String(node.node_id))

func _leave_and_reload(label: String) -> void:
	var room: EventRoomScreen = main.active_event_room
	await _click(room.map_exits[0].global_position)
	await _settle()
	_check(main.active_event_room == null,"Room exit completes: " + label)
	var before: Dictionary = main.run_state.make_active_run_snapshot("post_node",main.knowledge_state)
	_check(main.continue_active_run_slot(1).is_empty(),"Continue after " + label)
	await _settle()
	_check(_same(main.run_state.make_active_run_snapshot("post_node",main.knowledge_state), before),"Whole campaign safe point unchanged after " + label)

func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _treasury_visit() -> void:
	await _visit(_node(MapNodeState.NodeType.TREASURY))
	var room: EventRoomScreen = main.active_event_room
	_check(room != null,"Treasury opens in combined expedition")
	if room == null: return
	await _click((room.active_containers[&"chest"] as Node2D).global_position)
	await _settle()
	var service := room.backpack_controller as RunLootController
	var result: Dictionary = service.collect(service.request({"domain":"loot","index":0}), {"domain":"backpack","heroine":&"mira","index":-1},1)
	_check(result.moved == 1,"Partial chest claim adds one item to prepared inventory")
	await _key(KEY_ESCAPE)
	await _shot(view.size,"partial_treasury")
	await _leave_and_reload("partial Treasury")

func _trap_visit() -> void:
	await _visit(_node(MapNodeState.NodeType.TRAP))
	var room: EventRoomScreen = main.active_event_room
	if room == null:
		_check(false,"Trap room opens")
		return
	while room.mode_controller.is_dialogue_active():
		room._on_dialogue_advance_requested()
		await _settle()
	_check(not room.instance_state.local_state.item_traps.is_empty(),"Same campaign contains seeded trap observer records")
	await _shot(view.size,"trap_observers")
	await _leave_and_reload("trap observation")

func _station_visit() -> void:
	var node: MapNodeState = _node(MapNodeState.NodeType.ALCHEMY)
	var definition: EventRoomDefinition = ROOMS.get_room(node.room_definition_id)
	var original: FieldStationDefinition = definition.field_station
	definition.field_station = original.duplicate(true)
	# Switch the test recipe to discovery-only; the station must teach it permanently.
	recipe.starts_known = false
	recipe.material_inputs = {"mat_l02_prison_iron":1}
	definition.field_station.recipe_discoveries = [recipe.recipe_id]
	await _visit(node)
	var room: EventRoomScreen = main.active_event_room
	_check(room != null and room.field_dialog != null,"Field station opens after Treasury and Trap")
	if room == null: return
	var bank: Dictionary = main.run_state.refuge_ownership.banked_materials.duplicate(true)
	await _click(room.field_hotspot.global_position)
	await _settle()
	var dialog: FieldProductionDialog = room.field_dialog
	var before: int = room.run_inventory.material_pouch.get("mat_l02_prison_iron",0)
	await _click(Vector2(dialog.position)+dialog.view.action_button.get_global_rect().get_center())
	await _settle()
	_check(main.run_state.run_inventory.material_pouch.get("mat_l02_prison_iron",0) == before-1 and main.run_state.refuge_ownership.banked_materials == bank,"Field craft spends run Materials, preserves banked stock")
	_check(main.run_state.refuge_ownership.knows_recipe(recipe.recipe_id),"Field discovery becomes permanent")
	await _shot(view.size,"field_craft")
	await _click(Vector2(dialog.position)+dialog.get_ok_button().get_global_rect().get_center())
	await _settle()
	await _leave_and_reload("field craft and discovery")
	definition.field_station = original

func _rest_visit() -> void:
	await _visit(_node(MapNodeState.NodeType.REST))
	var room: EventRoomScreen = main.active_event_room
	if room == null:
		_check(false,"Rest room opens")
		return
	await _click(room.room_rest_hotspot.global_position)
	await _settle()
	var dialog: RunRecoveryDialog = room.room_rest_dialog
	await _key(KEY_B)
	_check(dialog.visible and not room.exploration_hud.backpack_panel.visible,"Recovery confirmation blocks Backpack click-through")
	await _shot(view.size,"room_rest")
	await _click(Vector2(dialog.position)+dialog.get_ok_button().get_global_rect().get_center())
	await _settle()
	_check(main.active_event_room.room_rest_used,"Room recovery commits once alongside prior claims")
	await _leave_and_reload("used Rest")

func _fight(elite: bool, defeat: bool) -> void:
	var kind: int = MapNodeState.NodeType.ELITE if elite else MapNodeState.NodeType.BATTLE
	var node: MapNodeState = _node(kind)
	_check(node != null,"Representative encounter exists")
	if node == null: return
	await _visit(node)
	var battle: CombatEncounter = main.active_battle
	_check(battle != null,"Same campaign launches " + ("Elite" if elite else "Normal"))
	if battle == null: return
	await _click(battle.reusable_hud.command_bar.end_phase_button.get_global_rect().get_center())
	await _settle()
	await _key(KEY_B)
	_check(battle.backpack_panel.visible,"Backpack opens in actual combat")
	await _key(KEY_ESCAPE)
	_check(not battle.backpack_panel.visible,"Escape closes combat Backpack")
	if not elite:
		await _struggle(battle)
	var gear: Dictionary = main.run_state.run_equipment.get_snapshot()
	if defeat:
		for id: StringName in order:
			var actor: BattlerState = battle.get_battler_state(id)
			actor.current_hp = 0
			actor.is_defeated = true
		battle.battle_runtime.battle_state.outcome = BattleState.Outcome.DEFEAT
	else:
		battle.battle_runtime.battle_state.outcome = BattleState.Outcome.VICTORY
	battle._emit_encounter_outcome_if_ready()
	await _settle()
	if not defeat and battle.backpack_panel.visible:
		await _key(KEY_ESCAPE)
		var panel: RunBackpackPanel = battle.backpack_panel
		_check(panel.confirmation.visible,"Fight surplus requires abandonment confirmation")
		await _click(Vector2(panel.confirmation.position)+panel.confirmation.get_ok_button().get_global_rect().get_center())
		await _settle()
	_check(main.return_overlay.visible,"Production outcome summary displayed")
	await _shot(view.size,"defeat_summary" if defeat else ("elite_summary" if elite else "normal_summary"))
	await _click(main.return_to_map_button.get_global_rect().get_center())
	await _settle()
	if defeat:
		_check(main.active_refuge != null,"Defeat returns same campaign to Refuge")
		_check(_same(main.run_state.refuge_ownership.equipment_loadouts_by_heroine,gear.loadouts_by_heroine),"Defeat retains repaired equipment identity and condition")
		_check(CampaignSaveSlotStore.read_document_for_load(1).document.active_run_snapshot == null,"Defeat removes ended run safe point")
		for slot: Dictionary in main.run_state.refuge_ownership.prepared_item_bar_slots:
			_check(BackpackPayload.is_empty(slot),"Defeat empties Item Bar")
		for id: StringName in order:
			for slot: Dictionary in main.run_state.refuge_ownership.preparation_slots_by_heroine[id]:
				_check(BackpackPayload.is_empty(slot),"Defeat empties carried consumables")
	else:
		_check(main.active_battle == null and main.map_screen.visible,"Victory summary returns to map")

func _struggle(encounter: CombatEncounter) -> void:
	_check(encounter.combat_engine.submit_unlocked,"Combined expedition retains purchased Submit")
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

	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	await _settle()
