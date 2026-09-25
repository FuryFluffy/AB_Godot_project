class_name AbilityPanel
extends PanelContainer


signal ability_chosen(ability_id: StringName)
signal cancelled


@export var title_label: Label
@export var ability_list: VBoxContainer
@export var empty_label: Label
@export var cancel_button: Button

var presented_abilities: Array[AbilityDefinition] = []
var availability_by_id: Dictionary = {}
var command_anchor: Control
var open_tween: Tween


func _ready() -> void:
	if cancel_button != null and not cancel_button.pressed.is_connected(
		_on_cancel_pressed
	):
		cancel_button.pressed.connect(_on_cancel_pressed)
	hide()


func attach_to_command(control: Control) -> void:
	command_anchor = control


func present(
	caster: BattlerState,
	abilities: Array[AbilityDefinition],
	controller: AbilityActionController
) -> void:
	presented_abilities = abilities.duplicate()
	availability_by_id.clear()
	_clear_ability_buttons()

	for ability: AbilityDefinition in presented_abilities:
		if ability == null:
			continue
		var reason: String = controller.get_availability_reason(
			caster.definition.battler_id,
			ability
		)
		availability_by_id[ability.ability_id] = reason
		_add_ability_button(ability, reason)

	title_label.text = "%s — Abilities" % (
		caster.definition.display_name
	)
	empty_label.visible = ability_list.get_child_count() <= 1
	if empty_label.visible:
		empty_label.text = "No active abilities are available."

	show()
	_position_next_to_command()
	_play_roll_open()


func close_panel() -> void:
	if open_tween != null and open_tween.is_valid():
		open_tween.kill()
	hide()
	scale = Vector2.ONE
	modulate.a = 1.0
	presented_abilities.clear()
	availability_by_id.clear()
	_clear_ability_buttons()


func _add_ability_button(
	ability: AbilityDefinition,
	reason: String
) -> void:
	var button := Button.new()
	button.name = "Ability_%s" % String(ability.ability_id)
	button.custom_minimum_size = Vector2(320.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s    %s" % [
		ability.display_name,
		_get_cost_text(ability),
	]
	button.disabled = not reason.is_empty()
	button.tooltip_text = ability.description
	if not reason.is_empty():
		button.tooltip_text += "\nUnavailable: %s" % reason
	button.pressed.connect(
		_on_ability_pressed.bind(ability.ability_id)
	)
	ability_list.add_child(button)


func _get_cost_text(ability: AbilityDefinition) -> String:
	var cost_text: String = "%dA" % ability.action_cost
	if ability.mp_cost > 0:
		cost_text += " / %dMP" % ability.mp_cost
	return cost_text


func _clear_ability_buttons() -> void:
	if ability_list == null:
		return
	for child: Node in ability_list.get_children():
		if child == empty_label:
			continue
		ability_list.remove_child(child)
		child.queue_free()


func _position_next_to_command() -> void:
	if command_anchor == null or not command_anchor.is_inside_tree():
		return
	var anchor_rect: Rect2 = command_anchor.get_global_rect()
	var panel_size: Vector2 = custom_minimum_size
	if size.x > 0.0 and size.y > 0.0:
		panel_size = size
	var viewport_size: Vector2 = get_viewport_rect().size
	var wanted_position := Vector2(
		anchor_rect.position.x - panel_size.x - 10.0,
		anchor_rect.get_center().y - panel_size.y * 0.5
	)
	wanted_position.x = clampf(
		wanted_position.x,
		12.0,
		viewport_size.x - panel_size.x - 12.0
	)
	wanted_position.y = clampf(
		wanted_position.y,
		68.0,
		viewport_size.y - panel_size.y - 12.0
	)
	position = wanted_position


func _play_roll_open() -> void:
	if open_tween != null and open_tween.is_valid():
		open_tween.kill()
	pivot_offset = Vector2(size.x, size.y * 0.5)
	scale = Vector2(0.08, 1.0)
	modulate.a = 0.25
	open_tween = create_tween()
	open_tween.set_parallel(true)
	open_tween.set_trans(Tween.TRANS_QUAD)
	open_tween.set_ease(Tween.EASE_OUT)
	open_tween.tween_property(self, "scale", Vector2.ONE, 0.14)
	open_tween.tween_property(self, "modulate:a", 1.0, 0.10)


func _on_ability_pressed(ability_id: StringName) -> void:
	ability_chosen.emit(ability_id)


func _on_cancel_pressed() -> void:
	cancelled.emit()
