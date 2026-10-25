extends SceneTree
## Isolated presentation fixture; never loads or writes a campaign save.
var failures: int = 0
var checks: int = 0
var view := SubViewport.new()
var captures: String = ""
var combat: ReusableCombatHUD
var field: ExplorationHUD
var states: Dictionary = {}

class ClickProbe extends Control:
	var hits: int = 0
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			hits += 1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hud-captures="):
			captures = argument.trim_prefix("--hud-captures=")
	root.add_child(view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true
	view.notify_mouse_entered()
	if "--hud-live-only" in OS.get_cmdline_user_args():
		await _verify_live_combat()
		print("Stage 10 live HUD fixture: %d checks, %d failures." % [checks, failures])
		view.queue_free()
		await process_frame
		quit(failures)
		return
	var background := TextureRect.new()
	background.texture = preload("res://New Rooms+Props/ABYSSAL_BLOOM_L1_L2_RESTYLED_SORTED_2026-08-30/Rooms/Layer_1/l01_room_opening_servant_corridor.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(background)
	var probe := ClickProbe.new()
	view.add_child(probe)
	var catalog: BattlerCatalogDefinition = load("res://data/battlers/battler_catalog.tres")
	for id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		# Explicit fixture unlocks exercise the same saved definitions as combat.
		states[id] = BattlerState.new(catalog.get_battler(id), HeroineProgressionState.new(id, RunState.make_default_heroine_progression_snapshot(true)[id]))
	states[&"mira"].current_resolve = 63
	states[&"mira"].current_corruption = 17
	states[&"mira"].current_actions = 1
	states[&"mira"].active_statuses.append(StatusInstance.new(preload("res://data/statuses/poison.tres")))
	combat = preload("res://scenes/battle/ui/reusable/combat_hud.tscn").instantiate()
	field = preload("res://scenes/exploration/components/exploration_hud.tscn").instantiate()
	view.add_child(combat)
	view.add_child(field)
	combat.ability_panel.cancelled.connect(combat.ability_panel.close_panel)
	field.hide()
	combat.set_header("Stage 10 QA", "Opening Servant Corridor", "Isolated presentation fixture")
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
		view.size = resolution
		view.size_2d_override = Vector2i(1920, roundi(1920.0 * resolution.y / resolution.x))
		background.size = view.size_2d_override
		probe.size = view.size_2d_override
		await process_frame
		for count: int in [1, 2, 3]:
			var ids: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
			ids.resize(count)
			combat.show()
			field.hide()
			combat.set_active_party_ids(ids)
			for id: StringName in ids:
				combat.display_heroine(id, states[id], id == ids[0])
			combat.set_grapple_context(false, true, false)
			combat.set_command_availability(true, true, true, true)
			for index: int in range(6):
				combat.display_item_slot(index, "%d\nEmpty" % (index + 1), false, "Empty slot")
			await _settle()
			_check_layout(combat.dock, ids, "combat")
			probe.hits = 0
			await _click(combat.dock.backdrop.get_global_rect().position + Vector2(1000, 10))
			_check(probe.hits == 0, "Dock gaps consume world clicks")
			await _shot(resolution, "combat_%d" % count)
			if count == 3:
				_populate_items(combat.item_bar)
				await _settle()
				_check_layout(combat.dock, ids, "populated combat")
				_check(combat.item_bar.slot_buttons[0].text == "×9999", "Large display quantity is exact")
				_check(combat.mira_card.status_label.text.contains("Poison"), "Real status summary is visible")
				await _shot(resolution, "combat_populated")
				combat.append_log_entry("Fixture: actual command events use the existing combat log.")
				await _click(combat.dock.log_tab.get_global_rect().get_center())
				await combat.log_animation.animation_finished
				_check(combat.log_is_open and combat.combat_log.get_global_rect().end.y <= combat.dock.log_tab.position.y + 1, "Combat Log animation ends above the dock")
				combat.close_log()
				await combat.log_animation.animation_finished
				_check(not combat.log_is_open and combat.combat_log.position.x > view.size_2d_override.x, "Combat Log collapses off-screen")
			var item_at: Vector2 = combat.item_bar.position
			combat.set_grapple_context(true, true, false)
			await _settle()
			_check(combat.command_bar.struggle_button.visible and combat.command_bar.grapple_wait_button.visible and combat.command_bar.submit_button.disabled and not combat.command_bar.attack_button.visible, "Struggle command context and Submit gate")
			_check(combat.dock.backpack_button.disabled and combat.dock.backpack_button.tooltip_text.contains("grappled"), "Grapple disables separate Backpack")
			_check(combat.item_bar.position == item_at, "Mode keeps items fixed")
			if count == 3:
				await _shot(resolution, "struggle")
				var grappler := BattlerState.new(catalog.get_battler(&"hollow_servant"))
				var track := GrappleTrackState.new(&"qa_track", &"lysandra", &"hollow_servant", grappler.definition.grapple_template)
				combat.struggle_panel.present(states[&"lysandra"], [track], {&"hollow_servant": grappler})
				await _settle()
				_check(combat.struggle_panel.get_global_rect().end.y <= combat.dock.log_tab.position.y, "Struggle popup clears dock and Log tab")
				await _shot(resolution, "struggle_popup")
				combat.struggle_panel.close_panel()
			combat.hide()
			field.show()
			field.set_active_party_ids(ids)
			for id: StringName in ids:
				field.get_party_card(id).display_state(states[id], id == ids[0])
			field.set_selected_state(states[ids[0]])
			_populate_items(field.item_bar)
			field.command_bar.set_refuge_established(false)
			await _settle()
			_check_layout(field.dock, ids, "exploration")
			if field.item_bar.position != item_at:
				print("ITEM POSITION ", resolution, " count=", count, " field=", field.item_bar.position, " combat=", item_at, " size ", field.item_bar.size)
			_check(field.item_bar.position == item_at, "Exploration shares item placement")
			_check(field.command_bar.recovery_button.text == "Rest" and field.command_bar.recovery_button.disabled and field.command_bar.party_button.disabled, "Unauthored actions remain unavailable")
			_check(not field.command_bar.back_button.visible and not field.command_bar.inventory_button.visible, "No map Back or duplicate Inventory action in dock")
			await _shot(resolution, "exploration_rest_%d" % count)
			field.command_bar.set_refuge_established(true)
			_check(field.command_bar.recovery_button.text == "Return", "Established Refuge changes context label")
			if count == 3:
				await _shot(resolution, "exploration_return")
				field.set_dialogue_active(true, true)
				field.dialogue_panel.speaker_label.text = "Stage 10 QA"
				field.dialogue_panel.dialogue_text.text = "Dialogue retains its existing runner and item rules. The dock remains reachable below it."
				await _settle()
				var dialogue_frame: Control = field.dialogue_panel.get_node("Frame")
				_check(dialogue_frame.get_global_rect().end.y < field.dock.log_tab.position.y, "Dialogue clears dock and Log tab")
				_check(field.command_bar.ability_button.disabled, "Dialogue prevents Ability browsing")
				await _shot(resolution, "dialogue_clearance")
				field.set_dialogue_active(false)
				var hp: int = states[ids[0]].current_hp
				var actions: int = states[ids[0]].current_actions
				await _click(field.command_bar.ability_button.get_global_rect().get_center())
				await _settle()
				_check(field.ability_panel.visible, "Mouse opens shared Ability popup")
				_check(field.ability_panel.get_global_rect().end.y <= field.dock.log_tab.position.y, "Ability popup clears dock and Log tab")
				for reason: String in field.ability_panel.availability_by_id.values():
					_check(not reason.is_empty(), "Field execution stays unavailable")
				await _shot(resolution, "ability")
				await _cancel()
				_check(not field.ability_panel.visible and view.gui_get_focus_owner() == field.command_bar.ability_button, "Escape closes Ability and restores focus")
				_check(states[ids[0]].current_hp == hp and states[ids[0]].current_actions == actions, "Ability browsing changes no gameplay state")
				field.record_dialogue("Fixture observation: the current room has been entered.")
				await _click(field.dock.log_tab.get_global_rect().get_center())
				_check(field.dock.log_open, "Mouse opens collapsible exploration Log")
				_check(field.combat_log.get_global_rect().end.y <= field.dock.log_tab.position.y + 1, "Log stays above command tab")
				await _shot(resolution, "log")
				await _cancel()
				_check(not field.dock.log_open, "Escape closes exploration Log")
	# Reordering is presentation only and does not move the stable item dock.
	field.set_active_party_ids([&"seraphine", &"lysandra"])
	await _settle()
	_check(field.party_strip.get_node("Cards").get_child(0) == field.seraphine_card, "Party order follows supplied current-party IDs")
	field.seraphine_card.grab_focus()
	var selections: Array[StringName] = []
	field.seraphine_card.selected.connect(func(id: StringName) -> void: selections.append(id))
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	view.push_input(accept, true)
	await process_frame
	_check(selections == [&"seraphine"], "Focused heroine card supports keyboard selection")
	combat.queue_free()
	field.queue_free()
	background.queue_free()
	probe.queue_free()
	await process_frame
	await _verify_exploration_progression()
	await _verify_live_combat()
	print("Stage 10 native HUD fixture: %d checks, %d failures." % [checks, failures])
	view.queue_free()
	states.clear()
	await process_frame
	await process_frame
	quit(failures)

func _check_layout(dock: RunHUDDock, ids: Array[StringName], context: String) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(view.size_2d_override))
	for control: Control in [dock.party, dock.items, dock.backpack_button, dock.commands]:
		if not bounds.encloses(control.get_global_rect()):
			print("LAYOUT ", control.name, " ", control.get_global_rect(), " minimum ", control.get_combined_minimum_size())
		_check(bounds.encloses(control.get_global_rect()), "%s %s fits viewport" % [context, control.name])
	_check(dock.party.get_global_rect().end.x <= dock.items.position.x, "Party clears six items")
	_check(dock.items.get_global_rect().end.x < dock.backpack_button.position.x, "Backpack separate from sixth item")
	_check(dock.backpack_button.get_global_rect().end.x < dock.commands.position.x, "Backpack clears commands")
	_check(dock.items.slot_buttons.size() == 6, "Exactly six consumable slots")
	var visible: int = 0
	for card: HeroineCardView in dock.party.get_node("Cards").get_children():
		if card.visible:
			visible += 1
			_check(dock.party.get_global_rect().encloses(card.get_global_rect()), "Heroine fits party strip")
	_check(visible == ids.size(), "Only current party displayed")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.18).timeout

func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		view.push_input(event, true)
		await process_frame

func _cancel() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	view.push_input(event, true)
	await process_frame

func _shot(resolution: Vector2i, label: String) -> void:
	if captures.is_empty():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(captures)
	view.get_texture().get_image().save_png("%s/%dx%d_%s.png" % [captures, resolution.x, resolution.y, label])


func _populate_items(bar: ItemBarView) -> void:
	var paths: Array[String] = ["servants_tonic", "bandage_roll", "red_wax_ampoule", "wax_sealed_needle", "servants_tonic", "bandage_roll"]
	for index: int in range(6):
		var item: ItemDefinition = load("res://data/items/layer_1/%s.tres" % paths[index])
		# 9999 is a presentation stress case, never an inventory grant.
		var quantity: int = 9999 if index == 0 else item.stack_limit
		bar.display_slot(index, "%d\n%s\n×%d" % [index + 1, item.display_name, quantity], true, "%s ×%d" % [item.display_name, quantity], false, item.icon)


func _verify_live_combat() -> void:
	view.size = Vector2i(1280, 720)
	view.size_2d_override = Vector2i(1920, 1080)
	var encounter: CombatEncounter = preload("res://scenes/battle/combat_encounter.tscn").instantiate()
	view.add_child(encounter)
	await _settle()
	var hud: ReusableCombatHUD = encounter.reusable_hud
	var start_error: String = encounter.battle_flow_controller.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST)
	_check(start_error.is_empty(), "Live encounter starts with existing flow controller")
	encounter.combat_presenter.refresh_all()
	await _click(hud.lysandra_card.get_global_rect().get_center())
	_check(encounter.battle_runtime.selected_battler_id == &"lysandra", "Dock selection reaches live encounter")
	var actor: BattlerState = encounter.get_battler_state(&"lysandra")
	var actions: int = actor.current_actions
	await _click(hud.command_bar.attack_button.get_global_rect().get_center())
	_check(not encounter.battle_runtime.is_selecting_attack_target and actor.current_actions == actions and hud.combat_log.entries.get_child(-1).text.contains("no legal targets"), "Attack preserves authored out-of-range restriction")
	await _click(hud.command_bar.move_button.get_global_rect().get_center())
	_check(encounter.battle_runtime.is_selecting_move, "Move enters existing targeting")
	await _click(hud.dock.backpack_button.get_global_rect().get_center())
	_check(encounter.battle_runtime.is_selecting_move and actor.current_actions == actions, "Disabled Backpack neither targets the field nor spends Actions")
	await _cancel()
	_check(not encounter.battle_runtime.is_selecting_move, "Escape cancels live targeting")
	await _click(hud.command_bar.move_button.get_global_rect().get_center())
	_check(encounter.battle_runtime.is_selecting_move, "Move enters existing targeting")
	var right_mouse := InputEventMouseButton.new()
	right_mouse.button_index = MOUSE_BUTTON_RIGHT
	right_mouse.pressed = true
	view.push_input(right_mouse, true)
	await process_frame
	_check(not encounter.battle_runtime.is_selecting_move, "Right click cancels Move")
	await _click(hud.command_bar.ability_button.get_global_rect().get_center())
	await _settle()
	_check(hud.ability_panel.visible and not hud.ability_panel.presented_abilities.is_empty(), "Live Ability opens existing catalogue")
	_check(hud.ability_panel.get_global_rect().end.y < hud.dock.log_tab.position.y, "Live Ability clears dock and Log tab")
	await _shot(Vector2i(1280, 720), "live_combat_ability")
	await _click(hud.dock.log_tab.get_global_rect().get_center())
	await hud.log_animation.animation_finished
	_check(hud.log_is_open and not hud.ability_panel.visible, "Log cancels Ability through existing handler")
	await _shot(Vector2i(1280, 720), "live_combat_log")
	await _cancel()
	_check(not hud.log_is_open and actor.current_actions == actions, "Log cancellation preserves Actions")
	await hud.log_animation.animation_finished
	_check(hud.combat_log.position.x > view.size_2d_override.x, "Closed live Log is fully outside the viewport")
	await _shot(Vector2i(1280, 720), "live_combat")
	var round_before: int = encounter.battle_runtime.battle_state.round_number
	var phase_before: int = encounter.battle_runtime.battle_state.phase
	await _click(hud.command_bar.end_phase_button.get_global_rect().get_center())
	_check(encounter.battle_runtime.battle_state.phase != phase_before or encounter.battle_runtime.battle_state.round_number > round_before, "End Phase reaches existing phase handler")
	encounter.queue_free()
	await process_frame


func _verify_exploration_progression() -> void:
	var screen: EventRoomScreen = preload("res://scenes/exploration/event_room_screen.tscn").instantiate()
	view.add_child(screen)
	var learned: Dictionary = RunState.make_default_heroine_progression_snapshot(true)
	var before: Dictionary = learned.duplicate(true)
	screen.heroine_progression_snapshot = learned.duplicate(true)
	var error: String = screen._prepare_party_strip(preload("res://data/battlers/battler_catalog.tres"), {&"lysandra": {"hp": 8, "mp": 8}})
	_check(error.is_empty(), "Exploration reconstructs current party with saved progression")
	screen._on_heroine_card_selected(&"lysandra")
	var hud: ExplorationHUD = screen.exploration_hud
	await _settle()
	await _click(hud.command_bar.ability_button.get_global_rect().get_center())
	await _settle()
	_check(hud.ability_panel.presented_abilities.size() == 1 and hud.ability_panel.presented_abilities[0].ability_id == &"forced_blade", "Learned authored ability appears in exploration")
	var button := hud.ability_panel.ability_list.get_node_or_null("Ability_forced_blade") as Button
	_check(button != null and button.disabled and button.text.contains("1A / 2MP") and button.tooltip_text.contains("unavailable during exploration"), "Existing costs and unavailable field execution are truthful")
	await _cancel()
	_check(screen.party_states[&"lysandra"].current_actions == 0 and screen.heroine_progression_snapshot == before and learned == before, "Browsing never grants combat Actions or changes saved unlocks")
	screen.queue_free()
	await process_frame
