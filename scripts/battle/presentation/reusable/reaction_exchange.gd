class_name ReactionExchange
extends Control


signal reaction_selected(reaction: StringName)
signal defence_selected(defence: StringName)
signal equipment_break_selected(choice: StringName)
signal grapple_response_selected(dodge: bool)
signal move_reaction_selected(react: bool)


@export var compact_frame_size: Vector2 = Vector2(430.0, 170.0)
@export var reaction_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 64.0, 1.0) var sprite_gap: float = 12.0


@onready var frame: PanelContainer = %Frame
@onready var actions_label: Label = %Actions
@onready var context_label: Label = %Context
@onready var roll_label: Label = %RollSummary
@onready var reactions: HBoxContainer = %Reactions
@onready var defend_choices: HBoxContainer = %DefendChoices
@onready var equipment_choices: HBoxContainer = %EquipmentChoices
@onready var attack_button: Button = %Attack
@onready var dodge_button: Button = %Dodge
@onready var defend_button: Button = %Defend
@onready var parry_button: Button = %Parry
@onready var skip_button: Button = %Skip
@onready var armor_button: Button = %Armor
@onready var shield_button: Button = %Shield
@onready var preserve_button: Button = %Preserve
@onready var destroy_button: Button = %Destroy

var grapple_mode: bool = false
var move_reaction_mode: bool = false
var equipment_choice_pending: bool = false
var anchor_position: Vector2 = Vector2.ZERO
var detail_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	dodge_button.pressed.connect(_on_dodge_pressed)
	defend_button.pressed.connect(show_defence_choices)
	parry_button.pressed.connect(_on_parry_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	armor_button.pressed.connect(
		defence_selected.emit.bind(&"armor")
	)
	shield_button.pressed.connect(
		defence_selected.emit.bind(&"shield")
	)
	%Back.pressed.connect(show_reactions)
	preserve_button.pressed.connect(
		_on_equipment_break_pressed.bind(&"preserve")
	)
	destroy_button.pressed.connect(
		_on_equipment_break_pressed.bind(&"destroy")
	)
	close_exchange()


func set_anchor_position(screen_position: Vector2) -> void:
	anchor_position = screen_position
	if visible:
		_position_frame()


func open_exchange(clear_history: bool = true) -> void:
	grapple_mode = false
	move_reaction_mode = false
	equipment_choice_pending = false
	_set_standard_button_visibility()
	if clear_history:
		clear_entries()
	show()
	show_reactions()
	_apply_compact_size()
	_position_frame()


func open_grapple_exchange(clear_history: bool = true) -> void:
	grapple_mode = true
	move_reaction_mode = false
	equipment_choice_pending = false
	if clear_history:
		clear_entries()
	show()
	show_reactions()
	attack_button.hide()
	defend_button.hide()
	parry_button.hide()
	dodge_button.show()
	skip_button.show()
	_apply_compact_size()
	_position_frame()


func open_move_reaction(
	reactor_name: String,
	mover_name: String,
	actions_remaining: int
) -> void:
	grapple_mode = false
	move_reaction_mode = true
	equipment_choice_pending = false
	clear_entries()
	show()
	show_reactions()
	context_label.text = "%s crosses %s's threatened route" % [
		mover_name,
		reactor_name,
	]
	roll_label.text = "React before the Move continues."
	actions_label.text = "%s • %d Action%s" % [
		reactor_name,
		actions_remaining,
		"" if actions_remaining == 1 else "s",
	]
	attack_button.show()
	attack_button.text = "ATTACK"
	attack_button.disabled = actions_remaining <= 0
	dodge_button.hide()
	defend_button.hide()
	parry_button.hide()
	skip_button.show()
	skip_button.text = "WAIT"
	skip_button.disabled = false
	_apply_compact_size()
	_position_frame()


func close_exchange() -> void:
	hide()
	grapple_mode = false
	move_reaction_mode = false
	equipment_choice_pending = false
	anchor_position = Vector2.ZERO
	_set_standard_button_visibility()
	show_reactions()


func set_context(
	attacker_name: String,
	defender_name: String,
	successes: int,
	source_label: String = "Attack"
) -> void:
	context_label.text = "%s uses %s on %s" % [
		attacker_name,
		source_label,
		defender_name,
	]
	roll_label.text = "%d incoming success%s. Choose a reaction for %s." % [
		successes,
		"" if successes == 1 else "es",
		defender_name,
	]
	_update_tooltip()


func set_reactor(
	reactor_name: String,
	actions_remaining: int
) -> void:
	actions_label.text = "%s • %d Action%s" % [
		reactor_name,
		actions_remaining,
		"" if actions_remaining == 1 else "s",
	]


func set_availability(
	can_attack: bool,
	can_dodge: bool,
	can_armor: bool,
	can_shield: bool,
	can_parry: bool
) -> void:
	attack_button.disabled = not can_attack
	dodge_button.disabled = not can_dodge
	armor_button.disabled = not can_armor
	shield_button.disabled = not can_shield
	defend_button.disabled = not (can_armor or can_shield)
	parry_button.disabled = not can_parry
	skip_button.disabled = false


func set_grapple_context(
	grappler_name: String,
	heroine_name: String,
	rolled_successes: int,
	automatic_successes: int
) -> void:
	context_label.text = "%s attempts to Grapple %s" % [
		grappler_name,
		heroine_name,
	]
	var total_successes: int = rolled_successes + automatic_successes
	roll_label.text = "%s: %d success%s • %s: Dodge or Skip" % [
		grappler_name,
		total_successes,
		"" if total_successes == 1 else "es",
		heroine_name,
	]
	detail_lines.append(
		"Rolled %d; automatic %d."
		% [rolled_successes, automatic_successes]
	)
	_update_tooltip()


func set_grapple_availability(can_dodge: bool) -> void:
	dodge_button.disabled = not can_dodge
	skip_button.disabled = false


func set_player_controlled(
	is_player_controlled: bool,
	reactor_name: String
) -> void:
	if is_player_controlled:
		return
	for button: Button in [
		attack_button,
		dodge_button,
		defend_button,
		parry_button,
		skip_button,
		armor_button,
		shield_button,
	]:
		button.disabled = true
	actions_label.text = "%s • rulebook resolving" % reactor_name
	reactions.hide()
	defend_choices.hide()
	equipment_choices.hide()


func add_entry(text: String) -> void:
	if text.is_empty():
		return
	detail_lines.append(text)
	_update_tooltip()


func clear_entries() -> void:
	detail_lines.clear()
	_update_tooltip()


func show_reactions() -> void:
	reactions.show()
	defend_choices.hide()
	equipment_choices.hide()


func show_defence_choices() -> void:
	reactions.hide()
	defend_choices.show()
	equipment_choices.hide()


func show_equipment_break_choice(
	item_name: String,
	remaining_damage: int
) -> void:
	show()
	grapple_mode = false
	move_reaction_mode = false
	equipment_choice_pending = true
	preserve_button.disabled = false
	destroy_button.disabled = false
	context_label.text = "%s is at breaking point" % item_name
	roll_label.text = "%d damage remains. Preserve it or destroy it to absorb 1." % (
		remaining_damage
	)
	actions_label.text = "EQUIPMENT"
	reactions.hide()
	defend_choices.hide()
	equipment_choices.show()
	_apply_compact_size()
	_position_frame()


func _apply_compact_size() -> void:
	if frame == null:
		return
	# This node is the floating window. Keeping the window itself compact avoids
	# a full-screen parent applying a second vertical layout pass to its Frame.
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	custom_minimum_size = compact_frame_size
	size = compact_frame_size
	frame.anchor_left = 0.0
	frame.anchor_top = 0.0
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 0.0
	frame.offset_top = 0.0
	frame.offset_right = 0.0
	frame.offset_bottom = 0.0


func _position_frame() -> void:
	if frame == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	_apply_compact_size()
	var frame_size: Vector2 = compact_frame_size
	var wanted_position: Vector2
	if anchor_position == Vector2.ZERO:
		wanted_position = (viewport_size - frame_size) * 0.5
	else:
		wanted_position = Vector2(
			anchor_position.x - frame_size.x * 0.5,
			anchor_position.y - frame_size.y - sprite_gap
		)
	wanted_position += reaction_offset
	wanted_position.x = clampf(
		wanted_position.x,
		12.0,
		viewport_size.x - frame_size.x - 12.0
	)
	wanted_position.y = clampf(
		wanted_position.y,
		68.0,
		viewport_size.y - frame_size.y - 12.0
	)
	position = wanted_position


func _update_tooltip() -> void:
	if frame == null:
		return
	frame.tooltip_text = "\n".join(detail_lines)


func _set_standard_button_visibility() -> void:
	attack_button.show()
	attack_button.text = "ATTACK"
	dodge_button.show()
	defend_button.show()
	parry_button.show()
	skip_button.show()
	skip_button.text = "SKIP"


func _on_attack_pressed() -> void:
	if move_reaction_mode:
		move_reaction_selected.emit(true)
	else:
		reaction_selected.emit(&"attack")


func _on_dodge_pressed() -> void:
	if grapple_mode:
		grapple_response_selected.emit(true)
	else:
		reaction_selected.emit(&"dodge")


func _on_parry_pressed() -> void:
	reaction_selected.emit(&"parry")


func _on_equipment_break_pressed(choice: StringName) -> void:
	if not equipment_choice_pending:
		return
	equipment_choice_pending = false
	preserve_button.disabled = true
	destroy_button.disabled = true
	close_exchange()
	equipment_break_selected.emit(choice)


func _on_skip_pressed() -> void:
	if grapple_mode:
		grapple_response_selected.emit(false)
	elif move_reaction_mode:
		move_reaction_selected.emit(false)
	else:
		reaction_selected.emit(&"skip")
