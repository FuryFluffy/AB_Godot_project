extends "res://tools/verify_run_backpack.gd"
## Synthetic trap profile on an existing room; no production balance/activation.
const LORE = preload("res://data/lore/lore_catalog.tres")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trap-captures="):
			captures = argument.trim_prefix("--trap-captures=")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.physics_object_picking = true
	view.notify_mouse_entered()
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(1920,1080)
	var definition: EventRoomDefinition = preload("res://data/exploration/rooms/layer1/l1_treasury_servants_storehouse.tres").duplicate()
	var authored: Node = definition.presentation_scene.instantiate()
	for node: Node in authored.find_children("*","",true,false):
		if node is RoomItemSpawnAnchor and node.container_id == &"":
			node.trap_capable = true
			node.place_name = "Supply shelf"
	var packed := PackedScene.new()
	_check(packed.pack(authored) == OK,"Test-only authored hotspot overrides pack")
	authored.free()
	definition.presentation_scene = packed
	var effect := RoomTrapDefinition.new()
	effect.trap_id = &"fixture_corruption"
	effect.display_name = "Corruption"
	effect.visual_id = &"corruption"
	effect.corruption_delta = 20
	effect.detection_successes = 2
	effect.disarm_successes = 2
	effect.automatic_detection_tier = SkillEntry.Tier.UNTRAINED
	var profile := RoomTrapProfile.new()
	profile.profile_id = &"fixture"
	profile.minimum_traps = 1
	profile.maximum_traps = 1
	profile.definitions = [effect]
	definition.trap_profile = profile
	var state := EventRoomInstanceState.new()
	state.room_id = definition.room_id
	state.source_node_id = &"test_trap_room"
	state.generation_seed = 333
	var party: Dictionary = {}
	for id: StringName in HEROES:
		party[id] = {"hp":BATTLERS.get_battler(id).max_hp,"mp":BATTLERS.get_battler(id).max_mp,"corruption":0,"resolve":70}
	var initial := RunInventoryState.new()
	initial.initialize(ITEMS,HEROES,false)
	var room: EventRoomScreen = preload("res://scenes/exploration/event_room_screen.tscn").instantiate()
	view.add_child(room)
	var error: String = room.prepare_room(definition,state,ITEMS,BATTLERS,LORE,KnowledgeState.new(),1,initial.get_item_bar_snapshot(),party)
	_check(error.is_empty(),"Real room prepares trap bridge: " + error)
	if not error.is_empty():
		quit(1)
		return
	await _settle()
	var bridge: RoomTrapController = room.trap_controller
	var id: String = state.local_state.item_traps.keys()[0]
	var trap: Dictionary = state.local_state.item_traps[id]
	_check(room.mode_controller.is_dialogue_active() and trap.announced and bridge.markers.has(id),"Detection uses actual dialogue and identified marker")
	_check(room.dialogue_runner.get_current_node().text.contains("Supply shelf") and room.dialogue_runner.get_current_node().speaker_name == room.party_states[StringName(trap.detector_id)].definition.display_name and room.dialogue_runner.get_current_node().text.contains(ITEMS.get_item(StringName(bridge.records[id].item_id)).display_name),"Notice names actual detector, place and item")
	await _shot(Vector2i(1280,720),"detection")
	room._on_dialogue_advance_requested()
	await _settle()
	_check(not room.mode_controller.is_dialogue_active() and room.pending_dialogue_results.is_empty(),"Notice completes without adding an unknown campaign graph")
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1024,768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920,roundi(1920.0*resolution.y/resolution.x))
		await _settle()
		await _click((room.active_pickups[StringName(id)] as Node2D).global_position)
		await _settle()
		_check(bridge.choice.visible and bridge.owner_picker.item_count == 3,"Identified item opens Disarm/Collect/Ignore with active heroine selection")
		var before: Dictionary = state.local_state.duplicate(true)
		await _key(KEY_B)
		_check(not room.exploration_hud.backpack_panel.visible,"Trap choice blocks background Backpack shortcut")
		await _shot(resolution,"trap_choice")
		await _click(Vector2(bridge.choice.position)+bridge.choice.get_cancel_button().get_global_rect().get_center())
		await _settle()
		_check(not bridge.choice.visible and state.local_state == before,"Ignore preserves all trap and item state")
	await _click((room.active_pickups[StringName(id)] as Node2D).global_position)
	await _settle()
	bridge.owner_picker.select(1)
	bridge._custom_action(&"collect")
	await _settle()
	var panel: RunBackpackPanel = room.exploration_hud.backpack_panel
	_check(panel.visible and panel.owner_id == &"mira" and not trap.triggered,"Collect choice opens ordinary Loot without triggering before commitment")
	var published: Array = []
	bridge.result_committed.connect(func(spawn: String,result: Dictionary,anchor: Vector2) -> void: published.append({"id":spawn,"result":result,"anchor":anchor}))
	var service := room.backpack_controller as RunLootController
	var result: Dictionary = service.collect(service.request({"domain":"loot","index":0}),{"domain":"backpack","heroine":"mira","index":-1},1)
	_check(result.moved == 1 and trap.triggered and room.party_states[&"mira"].current_corruption == 20 and room.party_states[&"lysandra"].current_corruption == 0,"Committed collection affects the chosen collector only")
	_check(published.size() == 1 and published[0].id == id and published[0].anchor == room.presentation.to_local(bridge.anchors[id].global_position),"Committed presentation event retains room-relative anchor independently of sprite lifetime")
	_check(not bridge.markers.has(id),"Triggered item loses the identified marker")
	var feedback: Node2D = room.presentation.get_child(room.presentation.get_child_count()-1)
	_check(feedback.get_child(0) is CPUParticles2D and feedback.position == published[0].anchor + Vector2(0,-25),"Committed cloud is a room-owned CPU effect at the captured item anchor")
	await create_timer(0.15).timeout
	await _shot(Vector2i(1024,768),"corruption_cloud")
	await create_timer(1.2).timeout
	_check(not is_instance_valid(feedback),"Native cloud cleans itself up after its brief lifetime")
	var poison := preload("res://scripts/exploration/traps/room_trap_feedback.gd").new()
	room.presentation.add_child(poison)
	poison.position = published[0].anchor + Vector2(0,-25)
	poison.play(&"poison")
	await create_timer(0.15).timeout
	await _shot(Vector2i(1024,768),"poison_cloud")
	panel.close_panel()
	bridge.entry_pending = true
	await _settle()
	_check(not room.mode_controller.is_dialogue_active(),"Re-evaluation does not repeat entry announcements")
	room.queue_free()
	await process_frame
	_check(not is_instance_valid(poison),"Room exit cleans up in-flight feedback")
	view.queue_free()
	await process_frame
	print("Stage 19 trap interface foundation: %d checks, %d failures." % [checks,failures])
	quit(failures)
