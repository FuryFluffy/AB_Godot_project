class_name RoomTrapController
extends Node
## Bridges saved trap transactions to the existing room, dialogue and Loot UI.
signal result_committed(spawn_id: String, result: Dictionary, anchor: Vector2)

var room: EventRoomScreen
var anchors: Dictionary = {}
var records: Dictionary = {}
var markers: Dictionary = {}
var choice: ConfirmationDialog
var owner_picker: OptionButton
var message: Label
var choosing_id: String = ""
var entry_pending: bool = false
var notice_dialogue_id: StringName
var alarm_retry_id: String = ""
var preparation_failed: bool = false
var collect_button: Button

func configure(host: EventRoomScreen) -> String:
	room = host
	var by_anchor: Dictionary = {}
	for node: Node in room.presentation.find_children("*", "", true, false):
		if node is RoomItemSpawnAnchor:
			by_anchor[String(node.anchor_id)] = node
	var eligible: Array[String] = []
	for record: Dictionary in room.instance_state.local_state.get("item_spawns", []):
		var id: String = String(record.get("spawn_id", ""))
		var anchor: RoomItemSpawnAnchor = by_anchor.get(String(record.get("anchor_id", "")))
		records[id] = record
		if anchor == null:
			continue
		anchors[id] = anchor
		if anchor.trap_capable and anchor.container_id == &"":
			if anchor.place_name.strip_edges().is_empty():
				return "Trap-capable item anchor requires an authored place name."
			eligible.append(id)
	var error: String = RoomTrapState.assign(room.instance_state.local_state,room.instance_state.generation_seed,room.definition.trap_profile,eligible)
	if not error.is_empty():
		return error
	for id: String in traps():
		if not eligible.has(id) or not records.has(id):
			return "Saved trap does not match an eligible authored item."
	choice = ConfirmationDialog.new()
	choice.title = "Identified trap"
	choice.exclusive = true
	choice.transient = true
	room.exploration_hud.add_child(choice)
	choice.get_ok_button().text = "Disarm"
	choice.get_cancel_button().text = "Ignore"
	collect_button = choice.add_button("Collect", true, "collect")
	for button: Button in [choice.get_ok_button(),choice.get_cancel_button(),collect_button]:
		button.add_theme_font_size_override("font_size",24)
		button.custom_minimum_size = Vector2(145,48)
	var content := VBoxContainer.new()
	choice.add_child(content)
	message = Label.new()
	message.custom_minimum_size = Vector2(560,85)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size",24)
	content.add_child(message)
	owner_picker = OptionButton.new()
	owner_picker.add_theme_font_size_override("font_size",22)
	content.add_child(owner_picker)
	choice.confirmed.connect(_disarm)
	choice.custom_action.connect(_custom_action)
	choice.canceled.connect(func() -> void: choosing_id = "")
	var service := room.backpack_controller as RunLootController
	if service == null:
		return "Trap room requires the production Loot controller."
	service.collection_guard = _collection_error
	service.collection_effect = _collect_committed
	service.changed.connect(refresh_markers)
	result_committed.connect(_present_committed)
	entry_pending = true
	refresh_markers()
	return ""

func traps() -> Dictionary:
	return room.instance_state.local_state.get("item_traps", {})

func blocking() -> bool:
	if entry_pending or preparation_failed or (choice != null and choice.visible):
		return true
	for trap: Dictionary in traps().values():
		if trap.alarm_pending:
			return true
	return false

func _process(_delta: float) -> void:
	if (preparation_failed or not alarm_retry_id.is_empty()) and not choice.visible:
		choice.popup_centered(Vector2i(600,260))
	if entry_pending and room != null and not room.mode_controller.is_dialogue_active():
		entry_pending = false
		_announce_entry()

func _announce_entry() -> void:
	for id: String in traps():
		if traps()[id].alarm_pending:
			room.room_alarm_requested.emit.call_deferred(id)
			return
	var dialogue := DialogueDefinition.new()
	dialogue.dialogue_id = StringName("trap_detection:" + String(room.instance_state.source_node_id))
	notice_dialogue_id = dialogue.dialogue_id
	var announcing: Array[Dictionary] = []
	for id: String in traps():
		var trap: Dictionary = traps()[id]
		RoomTrapState.detect(trap,room.party_states)
		if not trap.detected or trap.announced or trap.disarmed or trap.triggered:
			continue
		var detector: BattlerState = room.party_states.get(StringName(trap.detector_id))
		var item: ItemDefinition = room.available_item_catalog.get_item(StringName(records[id].item_id))
		if detector == null or item == null:
			continue
		var line := DialogueNodeDefinition.new()
		line.node_id = StringName("notice_%d" % dialogue.nodes.size())
		line.speaker_id = detector.definition.battler_id
		line.speaker_name = detector.definition.display_name
		line.text = "There is a trap here: %s, %s." % [anchors[id].place_name,item.display_name]
		if not dialogue.nodes.is_empty():
			dialogue.nodes[-1].default_next_node_id = line.node_id
		dialogue.nodes.append(line)
		announcing.append(trap)
	refresh_markers()
	if dialogue.nodes.is_empty():
		commit_preparation()
		return
	dialogue.start_node_id = dialogue.nodes[0].node_id
	var error: String = room.start_dialogue(dialogue,room.current_party_ids)
	if error.is_empty():
		for trap: Dictionary in announcing:
			trap.announced = true
	else:
		room.hover_label.text = error

func intercept(id: String) -> bool:
	if blocking():
		return true
	var trap: Dictionary = traps().get(id,{})
	if trap.is_empty() or not trap.detected or trap.disarmed or trap.triggered:
		return false
	if not room.backpack_controller.access_error().is_empty() or room.exploration_hud.backpack_panel.visible:
		return true
	choosing_id = id
	owner_picker.clear()
	for actor_id: StringName in room.current_party_ids:
		var actor: BattlerState = room.party_states[actor_id]
		if actor.is_defeated:
			continue
		owner_picker.add_item(actor.definition.display_name)
		owner_picker.set_item_metadata(owner_picker.item_count-1,String(actor_id))
		if actor_id == room.selected_heroine_id:
			owner_picker.select(owner_picker.item_count-1)
	if owner_picker.item_count == 0:
		room.hover_label.text = "No active heroine can interact."
		choosing_id = ""
		return true
	message.text = "%s: %s\nDisarm, collect despite the trap, or leave it alone." % [anchors[id].place_name,room.available_item_catalog.get_item(StringName(records[id].item_id)).display_name]
	choice.popup_centered(Vector2i(600,220))
	choice.get_cancel_button().grab_focus()
	return true

func _actor() -> BattlerState:
	if owner_picker.selected < 0:
		return null
	var id := StringName(owner_picker.get_item_metadata(owner_picker.selected))
	room.selected_heroine_id = id
	room._refresh_party_strip()
	return room.party_states.get(id)

func _disarm() -> void:
	choice.hide()
	if preparation_failed:
		commit_preparation()
		return
	if not alarm_retry_id.is_empty():
		room.room_alarm_requested.emit.call_deferred(alarm_retry_id)
		return
	var id: String = choosing_id
	choosing_id = ""
	if not traps().has(id):
		return
	var actor: BattlerState = _actor()
	var result: Dictionary = RoomTrapState.disarm(traps()[id],actor)
	room.hover_label.text = String(result.error)
	if result.get("disarmed",false):
		room.hover_label.text = "Disarmed. The item is safe to collect."
	refresh_markers()
	room._refresh_party_strip()
	_publish(id,result)

func _custom_action(action: StringName) -> void:
	if action != &"collect" or preparation_failed or not alarm_retry_id.is_empty():
		return
	choice.hide()
	var id: String = choosing_id
	choosing_id = ""
	if _actor() != null:
		room._open_world_item_loot(StringName(id))

func _collection_error(record: Dictionary, owner: StringName) -> String:
	if blocking():
		return "Resolve the pending trap interaction first."
	var id: String = String(record.get("spawn_id", ""))
	if not traps().has(id):
		return ""
	var actor: BattlerState = room.party_states.get(owner)
	return "Choose a living active heroine." if actor == null or actor.is_defeated else ""

func _collect_committed(record: Dictionary, owner: StringName) -> void:
	var id: String = String(record.get("spawn_id", ""))
	if not traps().has(id):
		return
	var result: Dictionary = RoomTrapState.trigger(traps()[id],room.party_states[owner])
	_publish(id,result)

func _publish(id: String, result: Dictionary) -> void:
	if not result.get("triggered",false):
		return
	# Anchors outlive collectible sprites and share the displayed room transform.
	var anchor: Vector2 = room.presentation.to_local(anchors[id].global_position)
	result_committed.emit(id,result,anchor)

func commit_preparation() -> void:
	if not room.trap_preparation_commit.is_valid():
		return
	var error: String = String(room.trap_preparation_commit.call())
	preparation_failed = not error.is_empty()
	if preparation_failed:
		offer_alarm_retry("","Room preparation could not be saved. Retry before interacting.\n" + error)
	else:
		choice.title = "Identified trap"
		choice.get_ok_button().text = "Disarm"
		choice.get_cancel_button().disabled = false
		collect_button.disabled = false
		owner_picker.show()

func offer_alarm_retry(id: String, error: String) -> void:
	alarm_retry_id = id
	collect_button.disabled = true
	choice.get_cancel_button().disabled = true
	choice.title = "Alarm checkpoint"
	choice.get_ok_button().text = "Retry"
	message.text = error
	owner_picker.hide()
	choice.popup_centered(Vector2i(600,260))

func _present_committed(id: String, result: Dictionary, anchor: Vector2) -> void:
	var effect := preload("res://scripts/exploration/traps/room_trap_feedback.gd").new()
	room.presentation.add_child(effect)
	effect.position = anchor + Vector2(0,-25)
	effect.play(StringName(result.visual_id))
	var definition: Dictionary = traps()[id].definition
	room.hover_label.text = "Alarm!" if result.alarm else "HP %d · Resolve %d · Corruption +%d" % [definition.hp_delta,definition.resolve_delta,definition.corruption_delta]
	# Finish the Loot transaction before capturing a checkpoint or leaving its UI.
	_finish_committed.call_deferred(id,bool(result.alarm))

func _finish_committed(id: String, alarm: bool) -> void:
	room._refresh_party_strip()
	room.exploration_hud.backpack_panel.close_panel()
	if alarm:
		room.exploration_hud.backpack_panel.close_panel()
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = 0.3
		add_child(timer)
		timer.timeout.connect(func() -> void:
			timer.queue_free()
			room.room_alarm_requested.emit(id))
		timer.start()
		return
	for actor: BattlerState in room.party_states.values():
		if not actor.is_defeated:
			return
	room.exploration_hud.backpack_panel.close_panel()
	room.room_party_defeated.emit()

func refresh_markers() -> void:
	for id: String in traps():
		var trap: Dictionary = traps()[id]
		var show_marker: bool = (trap.detected or trap.disarmed) and not trap.triggered and LootClaim.remaining(records[id]) > 0
		if not show_marker:
			if markers.has(id):
				markers[id].queue_free()
				markers.erase(id)
			continue
		var marker: Sprite2D = markers.get(id)
		if marker == null:
			marker = Sprite2D.new()
			room.presentation.add_child(marker)
			marker.position = room.presentation.to_local(anchors[id].global_position) + Vector2(35,-35)
			marker.z_index = 5
			markers[id] = marker
		marker.texture = preload("res://assets/map/revision_2/traps/markers/trap_disarmed.png") if trap.disarmed else preload("res://assets/map/revision_2/map/intel/scouting.png")
		marker.scale = Vector2.ONE * (40.0 / maxf(marker.texture.get_width(),marker.texture.get_height()))
