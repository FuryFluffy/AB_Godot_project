class_name RunHUDDock
extends Node
## Presentation only: keeps the same positions across combat and exploration.
## Gameplay availability remains with each context's existing controller.

const DESIGN_WIDTH := 1920.0
const HEIGHT := 212.0
var party: PanelContainer
var items: ItemBarView
var commands: Control
var backdrop: Panel
var backpack_button: Button
var log_tab: Button
var drawer: CombatLogDrawer
var active_ids: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
var preferred_party_order: Array[StringName] = []
var log_open: bool = false
var layout_scale: float = 1.0
var backpack_access: Callable
signal layout_changed

func configure(host: Node, party_view: PanelContainer, item_view: ItemBarView, command_view: Control, log_view: CombatLogDrawer, log_button: Button, label: String) -> void:
	party = party_view
	items = item_view
	commands = command_view
	drawer = log_view
	drawer.z_index = 110
	backdrop = Panel.new()
	backdrop.name = "RunDockBackground"
	backdrop.add_theme_stylebox_override("panel", preload("res://scenes/battle/ui/reusable/styles/hud_frame_style.tres"))
	host.add_child(backdrop)
	host.move_child(backdrop, 0)
	backpack_button = Button.new()
	backpack_button.name = "Backpack"
	backpack_button.text = "Backpack"
	backpack_button.add_theme_font_size_override("font_size", 16)
	backpack_button.disabled = true
	set_grapple_context(false)
	host.add_child(backpack_button)
	log_tab = Button.new()
	log_tab.name = "LogTab"
	log_tab.z_index = 110
	log_tab.text = label
	log_tab.add_theme_font_size_override("font_size", 18)
	log_tab.pressed.connect(log_button.pressed.emit)
	host.add_child(log_tab)
	log_button.hide()
	items.use_horizontal_layout()
	var button_frame: StyleBoxFlat = preload("res://scenes/battle/ui/reusable/styles/hud_frame_style.tres").duplicate()
	button_frame.content_margin_left = 3
	button_frame.content_margin_right = 3
	button_frame.content_margin_top = 3
	button_frame.content_margin_bottom = 3
	for button: Button in [backpack_button, log_tab] + items.slot_buttons:
		button.add_theme_stylebox_override("normal", button_frame)
		button.add_theme_stylebox_override("disabled", button_frame)
	for button: Button in items.slot_buttons:
		button.add_theme_font_size_override("font_size", 14)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

	for card: HeroineCardView in party.get_node("Cards").get_children():
		card.use_dock_layout()
	get_viewport().size_changed.connect(refresh_layout)
	refresh_layout()
	# Containers settle their minimum sizes after entering the tree.
	refresh_layout.call_deferred()

func set_active_party_ids(ids: Array[StringName]) -> void:
	ids = RunPartyOrder.resolve(preferred_party_order, ids)
	active_ids = ids.duplicate()
	var cards: Container = party.get_node("Cards")
	for card: HeroineCardView in cards.get_children():
		card.visible = ids.has(card.battler_id)
	for index: int in range(ids.size()):
		for card: HeroineCardView in cards.get_children():
			if card.battler_id == ids[index]:
				cards.move_child(card, index)
	refresh_layout()

func set_grapple_context(grappled: bool) -> void:
	if backpack_access.is_valid():
		_refresh_backpack_access()
	else:
		backpack_button.disabled = true
		backpack_button.tooltip_text = "Unavailable while grappled." if grappled else "Run Backpack access is not yet available."

func refresh_layout() -> void:
	if party == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	layout_scale = minf(1.0, viewport_size.x / DESIGN_WIDTH)
	var s: float = layout_scale
	var left: float = (viewport_size.x - DESIGN_WIDTH * s) * 0.5
	var top: float = viewport_size.y - HEIGHT * s
	backdrop.position = Vector2(0, top)
	backdrop.size = Vector2(viewport_size.x, HEIGHT * s)
	var count: int = active_ids.size()
	_place(party, Vector2(left + 12 * s, top + 8 * s), Vector2(16 + 276 * count + 6 * maxi(count - 1, 0), 196))
	_place(items, Vector2(left + 878 * s, top + 72 * s), Vector2(442, 86))
	_place(backpack_button, Vector2(left + 1334 * s, top + 72 * s), Vector2(96, 86))
	_place(commands, Vector2(left + 1444 * s, top + 64 * s), Vector2(464, 104))
	_place(log_tab, Vector2(left + 1698 * s, top - 38 * s), Vector2(210, 38))
	_place(drawer, log_position(log_open), Vector2(464, 260))
	layout_changed.emit()

func log_position(open: bool) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(log_tab.position.x + log_tab.size.x * layout_scale - 464 * layout_scale if open else viewport_size.x + 16, log_tab.position.y - 260 * layout_scale)

func set_log_open(open: bool) -> void:
	log_open = open
	log_tab.button_pressed = open
	log_tab.tooltip_text = "Close log" if open else "Open log"
	drawer.position = log_position(open)

func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.grow_horizontal = Control.GROW_DIRECTION_END
	control.grow_vertical = Control.GROW_DIRECTION_END
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.custom_maximum_size = Vector2(-1, -1)
	control.scale = Vector2.ONE * layout_scale
	control.position = at
	control.size = dimensions

func _process(_delta: float) -> void:
	if backpack_access.is_valid():
		_refresh_backpack_access()

func _refresh_backpack_access() -> void:
	var error: String = String(backpack_access.call())
	backpack_button.disabled = not error.is_empty()
	backpack_button.tooltip_text = error if not error.is_empty() else "Open Backpack (B)."
