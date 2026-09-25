class_name ReusableCombatHUD
extends CanvasLayer


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


@onready var root: Control = $Root
@onready var party_strip: PanelContainer = $Root/PartyStrip
@onready var lysandra_card: HeroineCardView = %LysandraCard
@onready var mira_card: HeroineCardView = %MiraCard
@onready var seraphine_card: HeroineCardView = %SeraphineCard
@onready var item_bar: ItemBarView = %ItemBar
@onready var command_bar: CommandBarView = %CommandBar
@onready var combat_log: CombatLogDrawer = %CombatLogDrawer
@onready var log_animation: AnimationPlayer = %LogAnimation
@onready var reaction_exchange: ReactionExchange = %ReactionExchange
@onready var ability_panel: AbilityPanel = %AbilityPanel
@onready var struggle_panel: StrugglePanel = %StrugglePanel

var log_is_open: bool = false


func _ready() -> void:
	for card: HeroineCardView in [
		lysandra_card,
		mira_card,
		seraphine_card,
	]:
		card.selected.connect(heroine_selected.emit)
	command_bar.attack_requested.connect(attack_requested.emit)
	command_bar.move_requested.connect(move_requested.emit)
	command_bar.ability_requested.connect(ability_requested.emit)
	command_bar.end_phase_requested.connect(end_phase_requested.emit)
	command_bar.struggle_requested.connect(struggle_requested.emit)
	command_bar.grapple_wait_requested.connect(
		grapple_wait_requested.emit
	)
	command_bar.submit_requested.connect(submit_requested.emit)
	command_bar.log_requested.connect(toggle_log)
	item_bar.slot_requested.connect(item_requested.emit)
	combat_log.close_requested.connect(close_log)
	reaction_exchange.reaction_selected.connect(
		reaction_selected.emit
	)
	reaction_exchange.defence_selected.connect(
		defence_selected.emit
	)
	reaction_exchange.equipment_break_selected.connect(
		equipment_break_selected.emit
	)
	reaction_exchange.grapple_response_selected.connect(
		grapple_response_selected.emit
	)
	reaction_exchange.move_reaction_selected.connect(
		move_reaction_selected.emit
	)
	ability_panel.attach_to_command(command_bar.ability_button)
	struggle_panel.attach_to_command(command_bar.struggle_button)
	ability_panel.close_panel()
	struggle_panel.close_panel()
	# Preserve the reusable UI project's authored drawer lifecycle. The log
	# remains visible as a Control and is moved just outside the 1920-wide
	# design canvas at rest; the AnimationPlayer brings it on-screen.
	log_animation.play(&"log_open")
	log_animation.seek(0.0, true)
	log_animation.pause()
	log_is_open = false


func set_header(
	layer_text: String,
	room_text: String,
	objective_text: String
) -> void:
	%LayerLabel.text = layer_text
	%RoomLabel.text = room_text
	%ObjectiveLabel.text = objective_text


func display_heroine(
	battler_id: StringName,
	state: BattlerState,
	is_selected: bool
) -> void:
	var card := _get_card(battler_id)
	if card != null:
		card.display_state(state, is_selected)


func set_active_party_ids(
	active_party_ids: Array[StringName]
) -> void:
	var active_count: int = 0
	for card: HeroineCardView in [
		lysandra_card,
		mira_card,
		seraphine_card,
	]:
		card.visible = active_party_ids.has(card.battler_id)
		if card.visible:
			active_count += 1

	# The authored three-card frame is 364 px tall: 16 px frame margin,
	# three 112 px cards, and two 6 px separations. Preserve its bottom-left
	# position while fitting solo and two-member encounters to visible cards.
	var content_height: float = (
		16.0
		+ float(active_count * 112)
		+ float(maxi(active_count - 1, 0) * 6)
	)
	party_strip.offset_top = party_strip.offset_bottom - content_height


func set_heroine_portrait(
	battler_id: StringName,
	texture: Texture2D
) -> void:
	var card := _get_card(battler_id)
	if card != null:
		card.set_portrait(texture)


func display_item_slot(
	slot_index: int,
	label: String,
	enabled: bool,
	tooltip: String,
	selected: bool = false,
	icon: Texture2D = null
) -> void:
	item_bar.display_slot(
		slot_index,
		label,
		enabled,
		tooltip,
		selected,
		icon
	)


func set_commands_locked(locked: bool) -> void:
	command_bar.set_locked(locked)
	item_bar.set_locked(locked)


func set_command_availability(
	can_attack: bool,
	can_move: bool,
	can_use_ability: bool,
	can_end_phase: bool
) -> void:
	command_bar.set_contextual_availability(
		can_attack,
		can_move,
		can_use_ability,
		can_end_phase
	)


func set_phase_command_label(label: String) -> void:
	command_bar.set_phase_label(label)


func set_action_labels(
	attack_label: String = "ATTACK",
	move_label: String = "MOVE",
	ability_label: String = "ABILITY"
) -> void:
	command_bar.set_action_labels(
		attack_label,
		move_label,
		ability_label
	)


func set_grapple_context(
	grapple_mode: bool,
	can_act: bool,
	can_submit: bool = false
) -> void:
	command_bar.set_grapple_context(
		grapple_mode,
		can_act,
		can_submit
	)


func append_log_entry(text: String) -> void:
	combat_log.append_entry(text)


func append_log_detail(text: String) -> void:
	combat_log.append_detail(text)


func clear_log() -> void:
	combat_log.clear_entries()


func present_reaction(
	attacker_name: String,
	defender_name: String,
	successes: int,
	source_label: String,
	actions_remaining: int,
	can_attack: bool,
	can_dodge: bool,
	can_armor: bool,
	can_shield: bool,
	can_parry: bool,
	is_player_controlled: bool = true,
	anchor_position: Vector2 = Vector2.ZERO
) -> void:
	reaction_exchange.set_anchor_position(anchor_position)
	var starts_new_exchange := not reaction_exchange.visible
	reaction_exchange.open_exchange(starts_new_exchange)
	reaction_exchange.set_context(
		attacker_name,
		defender_name,
		successes,
		source_label
	)
	reaction_exchange.set_reactor(
		defender_name,
		actions_remaining
	)
	reaction_exchange.set_availability(
		can_attack,
		can_dodge,
		can_armor,
		can_shield,
		can_parry
	)
	reaction_exchange.set_player_controlled(
		is_player_controlled,
		defender_name
	)


func present_grapple_reaction(
	grappler_name: String,
	heroine_name: String,
	rolled_successes: int,
	automatic_successes: int,
	actions_remaining: int,
	can_dodge: bool,
	anchor_position: Vector2 = Vector2.ZERO
) -> void:
	reaction_exchange.set_anchor_position(anchor_position)
	reaction_exchange.open_grapple_exchange()
	reaction_exchange.set_grapple_context(
		grappler_name,
		heroine_name,
		rolled_successes,
		automatic_successes
	)
	reaction_exchange.set_reactor(
		heroine_name,
		actions_remaining
	)
	reaction_exchange.set_grapple_availability(can_dodge)


func present_move_reaction(
	reactor_name: String,
	mover_name: String,
	actions_remaining: int,
	anchor_position: Vector2 = Vector2.ZERO
) -> void:
	reaction_exchange.set_anchor_position(anchor_position)
	reaction_exchange.open_move_reaction(
		reactor_name,
		mover_name,
		actions_remaining
	)


func close_reaction_exchange() -> void:
	reaction_exchange.close_exchange()


func present_equipment_break(
	item_name: String,
	remaining_damage: int,
	anchor_position: Vector2 = Vector2.ZERO
) -> void:
	reaction_exchange.set_anchor_position(anchor_position)
	reaction_exchange.show_equipment_break_choice(
		item_name,
		remaining_damage
	)


func toggle_log() -> void:
	if log_is_open:
		log_animation.play_backwards(&"log_open")
	else:
		log_animation.play(&"log_open")
	log_is_open = not log_is_open


func close_log() -> void:
	if not log_is_open:
		return
	log_animation.play_backwards(&"log_open")
	log_is_open = false


func _get_card(battler_id: StringName) -> HeroineCardView:
	match battler_id:
		&"lysandra":
			return lysandra_card
		&"mira":
			return mira_card
		&"seraphine":
			return seraphine_card
	return null
