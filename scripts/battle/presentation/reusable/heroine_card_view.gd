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
var status_label: Label


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	focus_mode = Control.FOCUS_ALL
	var normal_frame: StyleBox = get_theme_stylebox("panel")
	var focus_frame: StyleBoxFlat = normal_frame.duplicate()
	focus_frame.border_color = Color(1.0, 0.92, 0.68)
	focus_entered.connect(func() -> void: add_theme_stylebox_override("panel", focus_frame))
	focus_exited.connect(func() -> void: add_theme_stylebox_override("panel", normal_frame))


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
	if status_label != null:
		var grid := hp_bar.get_parent()
		grid.get_node("HPLabel").text = "HP %d/%d" % [state.current_hp, state.get_max_hp()]
		grid.get_node("MPLabel").text = "MP %d/%d" % [state.current_mp, state.get_max_mp()]
		grid.get_node("ResLabel").text = "Resolve %d" % state.current_resolve
		grid.get_node("CorLabel").text = "Corrupt. %d" % state.current_corruption
		status_label.text = "Status: " + state.get_status_summary()
		status_label.tooltip_text = status_label.text
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
		(event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT)
		or event.is_action_pressed(&"ui_accept")
	):
		selected.emit(battler_id)
		accept_event()


func use_dock_layout() -> void:
	custom_maximum_size = Vector2(-1, -1)
	custom_minimum_size = Vector2(276, 180)
	size_flags_horizontal = Control.SIZE_FILL
	var frame: Control = portrait.get_parent()
	frame.custom_maximum_size = Vector2(-1, -1)
	frame.custom_minimum_size = Vector2(56, 80)
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 18)
	for label: Node in hp_bar.get_parent().get_children():
		if label is Label:
			label.add_theme_font_size_override("font_size", 16)
	var actions: Label = action_pips.get_parent().get_node("ActLabel")
	actions.add_theme_font_size_override("font_size", 16)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.custom_minimum_size.x = 1
	name_label.get_parent().add_child(status_label)
	_ignore_child_mouse(self)
	reset_size()


func _ignore_child_mouse(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_child_mouse(child)
