class_name EnemyHudView
extends VBoxContainer


@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_value: Label = %HPValue
@onready var action_pips: HBoxContainer = %ActionPips


func display_state(state: BattlerState) -> void:
	if state == null or state.definition == null or state.is_defeated:
		hide()
		return
	show()
	name_label.text = state.definition.display_name
	hp_bar.max_value = maxi(state.get_max_hp(), 1)
	hp_bar.value = state.current_hp
	hp_value.text = "%d/%d" % [
		state.current_hp,
		state.get_max_hp(),
	]
	var maximum_actions: int = state.get_max_actions()
	while action_pips.get_child_count() > maximum_actions:
		var surplus: Node = action_pips.get_child(
			action_pips.get_child_count() - 1
		)
		action_pips.remove_child(surplus)
		surplus.queue_free()
	while action_pips.get_child_count() < maximum_actions:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 6)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_pips.add_child(pip)
	for index: int in range(maximum_actions):
		var pip: ColorRect = action_pips.get_child(index) as ColorRect
		pip.color = (
			Color(0.96, 0.79, 0.42)
			if index < state.current_actions
			else Color(0.18, 0.16, 0.14)
		)
