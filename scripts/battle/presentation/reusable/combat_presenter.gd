class_name CombatPresenter
extends Node


signal heroine_selected(battler_id: StringName)
signal attack_requested
signal move_requested
signal ability_requested
signal item_requested(slot_index: int)
signal end_phase_requested
signal struggle_requested
signal grapple_wait_requested
signal submit_requested
signal reaction_selected(reaction: StringName)
signal defence_selected(defence: StringName)
signal equipment_break_selected(choice: StringName)
signal grapple_response_selected(dodge: bool)
signal move_reaction_selected(react: bool)


var engine: CombatEngine
var hud: ReusableCombatHUD
var battle_markers: Array[BattleMarker] = []
var commands_locked: bool = false
var refresh_queued: bool = false
var refresh_in_progress: bool = false


func initialize(
	new_engine: CombatEngine,
	new_hud: ReusableCombatHUD,
	new_battle_markers: Array[BattleMarker]
) -> void:
	engine = new_engine
	hud = new_hud
	battle_markers = new_battle_markers
	var active_party_ids: Array[StringName] = []
	for state_value: Variant in engine.battler_states.values():
		var state := state_value as BattlerState
		if (
			state != null
			and state.definition != null
			and state.definition.faction
			== BattlerDefinition.Faction.HEROINE
		):
			active_party_ids.append(state.definition.battler_id)
	hud.set_active_party_ids(active_party_ids)
	_connect_hud_intents()
	_bind_states()
	refresh_all()


func connect_log(log_presenter: BattleLogPresenter) -> void:
	if (
		log_presenter != null
		and not log_presenter.entry_added.is_connected(
			_on_log_entry_added
		)
	):
		log_presenter.entry_added.connect(_on_log_entry_added)
	if (
		log_presenter != null
		and not log_presenter.detail_added.is_connected(
			_on_log_detail_added
		)
	):
		log_presenter.detail_added.connect(_on_log_detail_added)


func refresh_all() -> void:
	if engine == null or hud == null:
		return
	if refresh_in_progress:
		_queue_refresh()
		return

	refresh_in_progress = true
	for state_value: Variant in engine.battler_states.values():
		var state := state_value as BattlerState
		if state != null:
			_refresh_state(state)
	_refresh_items()
	_refresh_header_and_commands()
	refresh_in_progress = false


func set_commands_locked(locked: bool) -> void:
	commands_locked = locked
	if hud != null:
		hud.set_commands_locked(locked)
	_refresh_header_and_commands()


func set_action_labels(
	attack_label: String = "ATTACK",
	move_label: String = "MOVE",
	ability_label: String = "ABILITY"
) -> void:
	if hud != null:
		hud.set_action_labels(
			attack_label,
			move_label,
			ability_label
		)


func present_reaction(
	context: ReactionContext,
	attacker: BattlerState,
	target: BattlerState,
	is_player_controlled: bool = true
) -> void:
	if (
		hud == null
		or context == null
		or attacker == null
		or target == null
		or attacker.definition == null
		or target.definition == null
	):
		return

	var availability: Dictionary = (
		engine.reaction_exchange_controller.get_availability(target)
	)
	_set_reaction_focus(target.definition.battler_id)
	hud.present_reaction(
		attacker.definition.display_name,
		target.definition.display_name,
		context.attack_successes,
		(
			context.request.get_source_label()
			if context.request != null
			else "Attack"
		),
		target.current_actions,
		bool(availability.get("attack", false)),
		bool(availability.get("dodge", false)),
		bool(availability.get("armor", false)),
		bool(availability.get("shield", false)),
		bool(availability.get("parry", false)),
		is_player_controlled,
		_get_reaction_anchor(target.definition.battler_id)
	)


func present_grapple_reaction(
	attempt: GrappleAttemptResult,
	grappler: BattlerState,
	heroine: BattlerState
) -> void:
	if (
		hud == null
		or attempt == null
		or grappler == null
		or heroine == null
		or grappler.definition == null
		or heroine.definition == null
	):
		return
	_set_reaction_focus(heroine.definition.battler_id)
	hud.present_grapple_reaction(
		grappler.definition.display_name,
		heroine.definition.display_name,
		(
			attempt.attack_roll.total_successes
			if attempt.attack_roll != null
			else 0
		),
		attempt.automatic_successes,
		heroine.current_actions,
		not heroine.is_defeated and heroine.current_actions > 0,
		_get_reaction_anchor(heroine.definition.battler_id)
	)


func present_move_reaction(
	reactor: BattlerState,
	mover: BattlerState
) -> void:
	if (
		hud == null
		or reactor == null
		or mover == null
		or reactor.definition == null
		or mover.definition == null
	):
		return
	_set_reaction_focus(reactor.definition.battler_id)
	hud.present_move_reaction(
		reactor.definition.display_name,
		mover.definition.display_name,
		reactor.current_actions,
		_get_reaction_anchor(reactor.definition.battler_id)
	)


func close_reaction_exchange() -> void:
	_set_reaction_focus(&"")
	if hud != null:
		hud.close_reaction_exchange()


func present_equipment_break(
	item_name: String,
	remaining_damage: int,
	target: BattlerState = null
) -> void:
	if hud != null:
		var target_id: StringName = &""
		if target != null and target.definition != null:
			target_id = target.definition.battler_id
		_set_reaction_focus(target_id)
		hud.present_equipment_break(
			item_name,
			remaining_damage,
			_get_reaction_anchor(target_id)
		)


func _get_reaction_anchor(battler_id: StringName) -> Vector2:
	var marker: BattleMarker = _get_battler_marker(battler_id)
	if marker == null:
		return Vector2.ZERO
	return marker.get_reaction_anchor_screen_position()


func _set_reaction_focus(battler_id: StringName) -> void:
	for marker: BattleMarker in battle_markers:
		if marker != null:
			marker.set_reaction_focus(marker.battler_id == battler_id)


func _get_battler_marker(battler_id: StringName) -> BattleMarker:
	for marker: BattleMarker in battle_markers:
		if marker != null and marker.battler_id == battler_id:
			return marker
	return null


func _connect_hud_intents() -> void:
	if hud == null:
		return
	hud.heroine_selected.connect(heroine_selected.emit)
	hud.attack_requested.connect(attack_requested.emit)
	hud.move_requested.connect(move_requested.emit)
	hud.ability_requested.connect(ability_requested.emit)
	hud.item_requested.connect(item_requested.emit)
	hud.end_phase_requested.connect(end_phase_requested.emit)
	hud.struggle_requested.connect(struggle_requested.emit)
	hud.grapple_wait_requested.connect(grapple_wait_requested.emit)
	hud.submit_requested.connect(submit_requested.emit)
	hud.reaction_selected.connect(reaction_selected.emit)
	hud.defence_selected.connect(defence_selected.emit)
	hud.equipment_break_selected.connect(
		equipment_break_selected.emit
	)
	hud.grapple_response_selected.connect(
		grapple_response_selected.emit
	)
	hud.move_reaction_selected.connect(
		move_reaction_selected.emit
	)


func _bind_states() -> void:
	for state_value: Variant in engine.battler_states.values():
		var state := state_value as BattlerState
		if (
			state != null
			and not state.state_changed.is_connected(
				_queue_refresh
			)
		):
			state.state_changed.connect(_queue_refresh)
	if (
		engine.battle_runtime != null
		and engine.battle_runtime.battle_state != null
		and not engine.battle_runtime.battle_state.state_changed.is_connected(
			_queue_refresh
		)
	):
		engine.battle_runtime.battle_state.state_changed.connect(
			_queue_refresh
		)
	if (
		engine.item_inventory != null
		and not engine.item_inventory.inventory_changed.is_connected(
			_queue_refresh
		)
	):
		engine.item_inventory.inventory_changed.connect(_queue_refresh)


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_flush_queued_refresh")


func _flush_queued_refresh() -> void:
	refresh_queued = false
	refresh_all()


func _refresh_state(state: BattlerState) -> void:
	if state == null or state.definition == null:
		return
	if (
		state.definition.faction
		== BattlerDefinition.Faction.HEROINE
	):
		hud.display_heroine(
			state.definition.battler_id,
			state,
			engine.battle_runtime.selected_battler_id
			== state.definition.battler_id
		)
	else:
		pass


func _refresh_items() -> void:
	if engine == null or engine.item_inventory == null:
		return
	for slot_index: int in range(6):
		var slot := engine.item_inventory.get_slot(slot_index)
		if slot == null or slot.is_empty():
			hud.display_item_slot(
				slot_index,
				"%d\nEmpty" % (slot_index + 1),
				false,
				"Empty Item Bar slot."
			)
			continue
		var item: ItemDefinition = slot.item
		var availability := (
			engine.item_use_controller.get_availability_reason(
				engine.battle_runtime.selected_battler_id,
				slot_index
			)
		)
		hud.display_item_slot(
			slot_index,
			"%d\n%s\n×%d" % [
				slot_index + 1,
				item.display_name,
				slot.quantity,
			],
			not commands_locked and availability.is_empty(),
			item.description if availability.is_empty() else availability,
			engine.battle_runtime.pending_item_slot_index == slot_index,
			item.icon
		)


func _refresh_header_and_commands() -> void:
	if engine == null or hud == null or not engine.is_initialized:
		return
	var battle_state := engine.battle_runtime.battle_state
	var selected := engine.get_battler_state(
		engine.battle_runtime.selected_battler_id
	)
	hud.set_header(
		"ROUND %d" % battle_state.round_number,
		battle_state.get_phase_label().to_upper(),
		"Defeat all enemies"
	)
	hud.set_phase_command_label(
		"BEGIN"
		if not battle_state.encounter_started
		else (
			"END\nPHASE"
			if battle_state.phase == BattleState.Phase.HERO
			else battle_state.get_phase_label().to_upper()
		)
	)
	var active_heroine := (
		selected != null
		and selected.definition != null
		and selected.definition.faction
		== BattlerDefinition.Faction.HEROINE
		and battle_state.encounter_started
		and battle_state.phase == BattleState.Phase.HERO
		and not selected.is_defeated
		and selected.current_actions > 0
	)
	var grapple_mode: bool = (
		selected != null
		and selected.definition != null
		and selected.definition.faction
		== BattlerDefinition.Faction.HEROINE
		and selected.is_grappled()
	)
	hud.set_grapple_context(
		grapple_mode,
		not commands_locked and active_heroine,
		false
	)
	hud.set_command_availability(
		not commands_locked and active_heroine and not grapple_mode,
		not commands_locked and active_heroine and not grapple_mode,
		not commands_locked and active_heroine and not grapple_mode,
		not commands_locked and engine.battle_runtime.can_change_phase()
	)


func _on_log_entry_added(text: String) -> void:
	if hud != null:
		hud.append_log_entry(text)


func _on_log_detail_added(text: String) -> void:
	if hud != null:
		hud.append_log_detail(text)
