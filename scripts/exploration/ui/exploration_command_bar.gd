class_name ExplorationCommandBarView
extends PanelContainer

signal inventory_requested
signal party_requested
signal back_requested
signal log_requested
signal recovery_requested
signal ability_requested

@onready var inventory_button: Button = %Inventory
@onready var party_button: Button = %Party
@onready var back_button: Button = %Back
@onready var log_button: Button = %Log
@onready var ability_button: Button = %Ability
@onready var recovery_button: Button = %Recovery
var party_access: Callable
var recovery_access: Callable
var recovery_remaining: Callable
var refuge_established: bool = false
var dialogue_active: bool = false
var has_selected_heroine: bool = false

func _ready() -> void:
	inventory_button.pressed.connect(inventory_requested.emit)
	party_button.pressed.connect(party_requested.emit)
	back_button.pressed.connect(back_requested.emit)
	log_button.pressed.connect(log_requested.emit)
	ability_button.pressed.connect(ability_requested.emit)
	recovery_button.pressed.connect(recovery_requested.emit)
	inventory_button.hide()
	back_button.hide()
	log_button.hide()
	party_button.disabled = true
	party_button.tooltip_text = "Party is unavailable."
	recovery_button.disabled = true
	set_refuge_established(false)
	set_selected_heroine(false)

func set_refuge_established(established: bool) -> void:
	refuge_established = established
	recovery_button.text = "Return" if established else "Rest"
	recovery_button.tooltip_text = "%s is not yet available." % recovery_button.text

func set_selected_heroine(selected: bool) -> void:
	has_selected_heroine = selected
	ability_button.disabled = dialogue_active or not selected
	ability_button.tooltip_text = "View selected heroine's abilities." if selected else "Select a heroine to view abilities."

func set_dialogue_mode(active: bool, mandatory: bool) -> void:
	dialogue_active = active
	back_button.disabled = active and mandatory
	set_selected_heroine(has_selected_heroine)

func _process(_delta: float) -> void:
	var error: String = String(party_access.call()) if party_access.is_valid() else "Party is unavailable."
	party_button.disabled = dialogue_active or not error.is_empty()
	party_button.tooltip_text = error if not error.is_empty() else "Inspect and reorder current party."

	var recovery_error: String = String(recovery_access.call()) if recovery_access.is_valid() else "Recovery is unavailable."
	recovery_button.disabled = dialogue_active or not recovery_error.is_empty()
	recovery_button.tooltip_text = recovery_error if not recovery_error.is_empty() else "Confirm " + recovery_button.text.to_lower() + "."

	if not refuge_established and recovery_remaining.is_valid():
		recovery_button.text = "Rest (%d/2)" % int(recovery_remaining.call())
