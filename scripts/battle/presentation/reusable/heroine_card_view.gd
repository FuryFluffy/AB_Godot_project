class_name HeroineCardView
extends PanelContainer


signal selected(battler_id: StringName)


@export var battler_id: StringName

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var mp_bar: ProgressBar = %MPBar
@onready var resolve_bar: ProgressBar = %ResolveBar
@onready var corruption_bar: ProgressBar = %CorruptionBar
@onready var action_pips: HBoxContainer = %ActionPips


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func set_portrait(texture: Texture2D) -> void:
	portrait.texture = texture


func display_state(state: BattlerState, is_selected: bool) -> void:
	if state == null or state.definition == null:
		visible = false
		return

	visible = true
	battler_id = state.definition.battler_id
	name_label.text = state.definition.display_name
	if state.is_defeated:
		name_label.text += " — DEFEATED"
	_set_bar(hp_bar, state.current_hp, state.get_max_hp())
	_set_bar(mp_bar, state.current_mp, state.get_max_mp())
	_set_bar(resolve_bar, state.current_resolve, 100)
	_set_bar(
		corruption_bar,
		state.current_corruption,
		100
	)
	_refresh_action_pips(
		state.current_actions,
		state.get_max_actions()
	)
	self_modulate = (
		Color(1.0, 0.92, 0.68)
		if is_selected
		else Color.WHITE
	)
	tooltip_text = (
		"%s\nHP %d/%d • MP %d/%d\nResolve %d • Corruption %d\n%s"
		% [
			state.definition.display_name,
			state.current_hp,
			state.get_max_hp(),
			state.current_mp,
			state.get_max_mp(),
			state.current_resolve,
			state.current_corruption,
			state.get_status_summary(),
		]
	)


func _set_bar(
	bar: ProgressBar,
	current: int,
	maximum: int
) -> void:
	bar.max_value = maxi(maximum, 1)
	bar.value = clampi(current, 0, maximum)


func _refresh_action_pips(current: int, maximum: int) -> void:
	while action_pips.get_child_count() > maximum:
		var surplus: Node = action_pips.get_child(
			action_pips.get_child_count() - 1
		)
		action_pips.remove_child(surplus)
		surplus.queue_free()
	while action_pips.get_child_count() < maximum:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(11, 11)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_pips.add_child(pip)
	for index: int in range(maximum):
		var pip: ColorRect = action_pips.get_child(index) as ColorRect
		pip.color = (
			Color(0.47843137, 0.08627451, 0.58431375)
			if index < current
			else Color(0.18, 0.16, 0.14)
		)


func _on_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		selected.emit(battler_id)
		accept_event()
