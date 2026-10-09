class_name BottomDockHUD
extends ReusableCombatHUD

const DOCK_HEIGHT: float = 136.0
var active_ids: Array[StringName] = []

func _ready() -> void:
	super._ready()
	log_animation.stop()
	combat_log.hide()
	combat_log.entry_font_size = 20
	combat_log.custom_maximum_size = Vector2(-1, -1)
	combat_log.custom_minimum_size = Vector2(360, 280)
	ability_panel.reserved_bottom_height = DOCK_HEIGHT + 44.0
	ability_panel.open_above_command = true
	struggle_panel.reserved_bottom_height = DOCK_HEIGHT + 44.0
	struggle_panel.open_above_command = true
	reaction_exchange.reserved_bottom_height = DOCK_HEIGHT + 44.0
	reaction_exchange.compact_frame_size = Vector2(560, 220)
	struggle_panel.panel_width = 480.0
	for panel: Control in [reaction_exchange, struggle_panel]:
		_set_readable_fonts(panel)
	root.resized.connect(_layout_dock)
	_layout_dock()

func _set_readable_fonts(node: Node) -> void:
	if node is Label or node is Button:
		node.add_theme_font_size_override("font_size", 18)
	for child: Node in node.get_children():
		_set_readable_fonts(child)

func display_heroine(id: StringName, state: BattlerState, selected: bool) -> void:
	if not active_ids.has(id):
		return
	super.display_heroine(id, state, selected)

func set_active_party_ids(ids: Array[StringName]) -> void:
	active_ids = ids.duplicate()
	for card: HeroineCardView in [lysandra_card, mira_card, seraphine_card]:
		card.visible = ids.has(card.battler_id)
	_layout_dock()

func _layout_dock() -> void:
	if not is_node_ready():
		return
	var count: int = 0
	for card: HeroineCardView in [lysandra_card, mira_card, seraphine_card]:
		if card.visible:
			count += 1
	var width: float = count * 288.0 + maxi(count - 1, 0) * 6.0 + 16.0
	var y: float = root.size.y - DOCK_HEIGHT + 8.0
	for control: Control in [party_strip, item_bar, command_bar, combat_log]:
		control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	party_strip.position = Vector2(8, y)
	party_strip.size = Vector2(width, 120)
	item_bar.position = Vector2(20 + width, y)
	item_bar.size = Vector2(584, 120)
	command_bar.position = Vector2(616 + width, y)
	command_bar.size = Vector2(392, 120)
	command_bar.log_button.position = Vector2(command_bar.position.x, y - 44)
	command_bar.log_button.size = Vector2(164, 36)
	combat_log.position = Vector2(12, y - 332)
	combat_log.size = Vector2(minf(800, command_bar.position.x - 444), 280)

func toggle_log() -> void:
	log_is_open = not log_is_open
	combat_log.visible = log_is_open
	_layout_dock()

func close_log() -> void:
	log_is_open = false
	combat_log.hide()
