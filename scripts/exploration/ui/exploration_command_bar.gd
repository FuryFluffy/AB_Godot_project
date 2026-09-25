class_name ExplorationCommandBarView
extends PanelContainer


signal inventory_requested
signal party_requested
signal back_requested
signal log_requested


@onready var inventory_button: Button = %Inventory
@onready var party_button: Button = %Party
@onready var back_button: Button = %Back
@onready var log_button: Button = %Log


func _ready() -> void:
	inventory_button.pressed.connect(
		inventory_requested.emit
	)

	party_button.pressed.connect(
		party_requested.emit
	)

	back_button.pressed.connect(
		back_requested.emit
	)

	log_button.pressed.connect(
		log_requested.emit
	)

	# Only Back is functional during this checkpoint.
	inventory_button.disabled = true
	party_button.disabled = true
	back_button.disabled = false
	log_button.disabled = true


func set_dialogue_mode(
	active: bool,
	mandatory: bool
) -> void:
	# Inventory, Party and Log remain visible. Their checkpoint-level
	# availability is preserved until their modal screens are implemented.
	back_button.disabled = active and mandatory
