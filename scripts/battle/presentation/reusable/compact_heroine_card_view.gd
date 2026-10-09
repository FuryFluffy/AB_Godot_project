class_name CompactHeroineCardView
extends HeroineCardView

func _ready() -> void:
	super._ready()
	focus_mode = Control.FOCUS_ALL
	_ignore_child_pointer(self)

func _ignore_child_pointer(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_child_pointer(child)

func display_state(state: BattlerState, is_selected: bool) -> void:
	super.display_state(state, is_selected)
	if state == null or state.definition == null:
		return
	name_label.text = state.definition.display_name
	%HPValue.text = "%d/%d" % [state.current_hp, state.get_max_hp()]
	%MPValue.text = "%d/%d" % [state.current_mp, state.get_max_mp()]
	%ResolveValue.text = "R %d" % state.current_resolve
	%CorruptionValue.text = "C %d" % state.current_corruption
	for index: int in action_pips.get_child_count():
		(action_pips.get_child(index) as ColorRect).color = (
			Color("dfb95d") if index < state.current_actions else Color("302d29"))

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		selected.emit(battler_id)
		accept_event()
	else:
		super._on_gui_input(event)
