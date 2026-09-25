class_name CommandBarView
extends PanelContainer


signal attack_requested
signal move_requested
signal ability_requested
signal end_phase_requested
signal log_requested
signal struggle_requested
signal grapple_wait_requested
signal submit_requested


@onready var attack_button: Button = %Attack
@onready var move_button: Button = %Move
@onready var ability_button: Button = %Ability
@onready var end_phase_button: Button = %EndPhase
@onready var log_button: Button = %Log
@onready var struggle_button: Button = %Struggle
@onready var grapple_wait_button: Button = %GrappleWait
@onready var submit_button: Button = %Submit


func _ready() -> void:
	attack_button.pressed.connect(attack_requested.emit)
	move_button.pressed.connect(move_requested.emit)
	ability_button.pressed.connect(ability_requested.emit)
	end_phase_button.pressed.connect(end_phase_requested.emit)
	log_button.pressed.connect(log_requested.emit)
	struggle_button.pressed.connect(struggle_requested.emit)
	grapple_wait_button.pressed.connect(grapple_wait_requested.emit)
	submit_button.pressed.connect(submit_requested.emit)
	_clear_visible_button_text()
	set_grapple_context(false, false, false)


func set_locked(locked: bool) -> void:
	attack_button.disabled = locked
	move_button.disabled = locked
	ability_button.disabled = locked
	end_phase_button.disabled = locked
	# The combat record remains available while gameplay commands are locked.
	log_button.disabled = false
	struggle_button.disabled = locked
	grapple_wait_button.disabled = locked
	submit_button.disabled = true


func set_contextual_availability(
	can_attack: bool,
	can_move: bool,
	can_use_ability: bool,
	can_end_phase: bool
) -> void:
	attack_button.disabled = not can_attack
	move_button.disabled = not can_move
	ability_button.disabled = not can_use_ability
	end_phase_button.disabled = not can_end_phase


func set_grapple_context(
	grapple_mode: bool,
	can_act: bool,
	can_submit: bool
) -> void:
	attack_button.visible = not grapple_mode
	move_button.visible = not grapple_mode
	ability_button.visible = not grapple_mode
	struggle_button.visible = grapple_mode
	grapple_wait_button.visible = grapple_mode
	submit_button.visible = grapple_mode
	if grapple_mode:
		struggle_button.disabled = not can_act
		grapple_wait_button.disabled = not can_act
		submit_button.disabled = not (can_act and can_submit)
		struggle_button.tooltip_text = (
			"Spend all remaining Actions on a Struggle."
			if can_act
			else "Struggle is unavailable in the current state."
		)
		grapple_wait_button.tooltip_text = (
			"End this heroine's activation without resisting."
			if can_act
			else "Wait is unavailable in the current state."
		)
		submit_button.tooltip_text = (
			"Requires Refuge Grapple upgrade level 1."
			if not can_submit
			else "Submit to the active Grapple."
		)


func set_phase_label(label: String) -> void:
	end_phase_button.text = ""
	end_phase_button.tooltip_text = (
		"Begin the encounter."
		if label.to_upper().contains("BEGIN")
		else "End the Hero Phase."
	)


func set_action_labels(
	attack_label: String,
	move_label: String,
	ability_label: String
) -> void:
	attack_button.text = ""
	move_button.text = ""
	ability_button.text = ""
	attack_button.tooltip_text = _state_tooltip("Attack", attack_label)
	move_button.tooltip_text = _state_tooltip("Move", move_label)
	ability_button.tooltip_text = _state_tooltip("Ability", ability_label)


func set_attack_hint(hint: String) -> void:
	attack_button.text = ""
	attack_button.tooltip_text = hint


func set_move_hint(hint: String) -> void:
	move_button.text = ""
	move_button.tooltip_text = hint


func set_ability_hint(hint: String) -> void:
	ability_button.text = ""
	ability_button.tooltip_text = hint


func _state_tooltip(command_name: String, state_label: String) -> String:
	if state_label.to_lower().contains("cancel"):
		return "%s targeting active. RMB or Esc cancels." % command_name
	return command_name


func _clear_visible_button_text() -> void:
	for button: Button in [
		attack_button,
		move_button,
		ability_button,
		end_phase_button,
		log_button,
		struggle_button,
		grapple_wait_button,
		submit_button,
	]:
		button.text = ""
