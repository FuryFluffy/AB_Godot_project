class_name RefugeRoomShell
extends Control
## Presentation and navigation only. All mutations are delegated to existing owners.

signal system_action_requested(action: StringName, slot_id: int)

const CANVAS_SIZE := Vector2(1344, 768)
const BACKGROUND = preload("res://assets/backgrounds/layer_2/sdxl_curated/07_Bloom_Refuge_Transformed.png")
const FRAME = preload("res://scenes/battle/ui/reusable/styles/hud_frame_style.tres")
const HOTSPOT = preload("res://scripts/refuge/ui/refuge_room_hotspot.gd")

var inventory_panel: InventoryPanelView
var inventory_bar: ItemBarView
var canvas: Control
var props: Control
var hotspots: Dictionary = {}
var stations: Array = []
var pages: Dictionary = {}
var modal: Control
var panel: PanelContainer
var content: VBoxContainer
var page_host: VBoxContainer
var title_label: Label
var close_button: Button
var system_page: VBoxContainer
var nested_page: VBoxContainer
var bloom_frame: PanelContainer
var active_station: StringName = &""
var origin_station: StringName = &"rest"
var nested_action: StringName = &""
var system_enabled: bool = false
var save_enabled: bool = false
var system_buttons: Dictionary = {}
var status_label: Label
var volume_slider: HSlider
var fullscreen_check: CheckBox
var scale_slider: HSlider
var settings_status: Label
var ui_scale: float = 1.0


func _ready() -> void:
	_build_room()
	_build_panel()
	resized.connect(_layout)
	ui_scale = float(UserSettingsStore.load_settings().get("refuge_ui_scale", 1.0))
	_apply_ui_scale()
	_layout.call_deferred()


func configure(service_pages: Control, bloom: Label, status: Label) -> void:
	status_label = status
	status.reparent(content)
	status.show()
	bloom.reparent(bloom_frame)
	bloom.show()
	var mapping := {"Loadouts": &"loadouts", "Stash": &"stash", "Workbench": &"repair", "Expedition": &"expedition"}
	for node_name: String in mapping:
		var page := service_pages.get_node(node_name) as Control
		page.reparent(page_host)
		page.hide()
		pages[mapping[node_name]] = page
	# Inventory presentation shares the existing ownership controls.
	inventory_panel = pages[&"stash"] as InventoryPanelView
	var backpacks: Control = inventory_panel.get_node("Backpacks")
	inventory_panel.configure(inventory_panel.get_node("Content"), backpacks, true)
	inventory_panel.backpacks_visibility_changed.connect(_inventory_tab_changed)
	(pages[&"repair"] as Control).get_node("Materials").reparent(inventory_panel.stash_page)
	for id: StringName in [&"rest", &"alchemy", &"crafting", &"records"]:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 14)
		page_host.add_child(page)
		pages[id] = page
		page.hide()
		match id:
			&"rest":
				_note(page, "Rest at the bed. Recovery services are not yet available.")
				_unavailable(page, "Restore Resolve")
				_unavailable(page, "Cleanse Corruption")
			&"alchemy", &"crafting":
				_note(page, "No production service is available yet. Banked Materials remain safe in Stash.")
				_unavailable(page, "Brew" if id == &"alchemy" else "Craft")
			&"records":
				_note(page, "The archive is not yet available.")
				for section: String in ["Lore", "Bestiary", "Run History", "Gallery"]:
					_unavailable(page, section)
	var expedition: Control = pages[&"expedition"]
	_button(expedition, "Party & preparation", _open_preparation)
	_unavailable(expedition, "Intel")
	_unavailable(expedition, "Level Up")


func configure_system(can_save: bool, has_application: bool) -> void:
	save_enabled = can_save
	system_enabled = has_application
	for action: StringName in system_buttons:
		(system_buttons[action] as Button).disabled = (
			not can_save if action == &"save"
			else not has_application and action != &"settings"
		)


func _build_room() -> void:
	var black := ColorRect.new()
	black.color = Color(0.015, 0.012, 0.018)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.name = "RoomCanvas"
	canvas.size = CANVAS_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var background := TextureRect.new()
	background.name = "OriginalBackground"
	background.texture = BACKGROUND
	background.size = CANVAS_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	props = Control.new()
	props.name = "Props"
	props.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(props)
	var placement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/refuge/placement.json"))
	for entry: Dictionary in placement.sprites:
		var sprite := TextureRect.new()
		sprite.name = String(entry.id)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.texture = load("res://assets/refuge/props/%s.png" % entry.id)
		sprite.position = Vector2(entry.top_left[0], entry.top_left[1])
		sprite.scale = Vector2.ONE * float(entry.uniform_scale)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		props.add_child(sprite)
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/refuge/hotspots.json"))
	stations = geometry.stations
	for station: Dictionary in stations:
		var hotspot := HOTSPOT.new() as RefugeRoomHotspot
		hotspot.configure(station)
		canvas.add_child(hotspot)
		hotspot.pressed.connect(open_station.bind(hotspot.station_id))
		hotspot.mouse_entered.connect(_highlight_station.bind(hotspot.station_id, true))
		hotspot.focus_entered.connect(_highlight_station.bind(hotspot.station_id, false))
		hotspots[hotspot.station_id] = hotspot
	for index: int in range(stations.size()):
		var station: Dictionary = stations[index]
		var hotspot: Control = hotspots[StringName(station.id)]
		for direction: String in station.neighbors:
			hotspot.set("focus_neighbor_" + direction, hotspot.get_path_to(hotspots[StringName(station.neighbors[direction])]))
		hotspot.focus_next = hotspot.get_path_to(hotspots[StringName(stations[(index + 1) % stations.size()].id)])
		hotspot.focus_previous = hotspot.get_path_to(hotspots[StringName(stations[(index + stations.size() - 1) % stations.size()].id)])
	bloom_frame = PanelContainer.new()
	bloom_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloom_frame.add_theme_stylebox_override("panel", FRAME)
	add_child(bloom_frame)
	bloom_frame.resized.connect(_layout)


func _build_panel() -> void:
	modal = Control.new()
	modal.name = "Modal"
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.hide()
	panel = PanelContainer.new()
	panel.name = "StationPanel"
	var panel_style := FRAME.duplicate() as StyleBoxFlat
	panel_style.bg_color.a = 0.97
	panel.add_theme_stylebox_override("panel", panel_style)
	modal.add_child(panel)
	var padding := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(padding)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	padding.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	close_button = _button(header, "Close", handle_cancel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	content.add_child(scroll)
	page_host = VBoxContainer.new()
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page_host)
	system_page = VBoxContainer.new()
	system_page.add_theme_constant_override("separation", 12)
	page_host.add_child(system_page)
	system_page.hide()
	for entry: Array in [[&"save", "Save"], [&"load", "Load"], [&"main_menu", "Main Menu"], [&"settings", "Settings"], [&"quit", "Quit"]]:
		system_buttons[entry[0]] = _button(system_page, entry[1], _system_action.bind(entry[0]))
	nested_page = VBoxContainer.new()
	nested_page.add_theme_constant_override("separation", 12)
	page_host.add_child(nested_page)
	nested_page.hide()
	configure_system(false, false)


func open_station(id: StringName) -> void:
	if not pages.has(id):
		return
	origin_station = id
	active_station = id
	nested_action = &""
	_hide_pages()
	(pages[id] as Control).show()
	for station: Dictionary in stations:
		if StringName(station.id) == id:
			title_label.text = String(station.name)
	if id == &"stash":
		inventory_panel.show_backpacks(false)
	_open_panel()


func open_system() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is RefugeRoomHotspot:
		origin_station = (focused as RefugeRoomHotspot).station_id
	active_station = &"system"
	nested_action = &""
	_hide_pages()
	system_page.show()
	title_label.text = "System"
	_open_panel()


func _open_panel() -> void:
	for hotspot: RefugeRoomHotspot in hotspots.values():
		hotspot.hovered = false
		hotspot.disabled = true
		hotspot.focus_mode = Control.FOCUS_NONE
		hotspot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotspot.queue_redraw()
	modal.show()
	close_button.text = "Close"
	_layout()
	close_button.grab_focus()
	_trap_focus.call_deferred()


func handle_cancel() -> void:
	if not nested_action.is_empty():
		var previous: StringName = nested_action
		nested_action = &""
		nested_page.hide()
		system_page.show()
		title_label.text = "System"
		close_button.text = "Close"
		(system_buttons[previous] as Button).grab_focus()
		_trap_focus.call_deferred()
		return
	if modal.visible:
		modal.hide()
		_hide_pages()
		active_station = &""
		for hotspot: RefugeRoomHotspot in hotspots.values():
			hotspot.disabled = false
			hotspot.focus_mode = Control.FOCUS_ALL
			hotspot.mouse_filter = Control.MOUSE_FILTER_STOP
		(hotspots[origin_station] as Control).grab_focus()
		return
	open_system()


func _hide_pages() -> void:
	if inventory_bar != null:
		inventory_bar.hide()
	for child: Control in page_host.get_children():
		child.hide()


func _system_action(action: StringName) -> void:
	if action == &"save":
		if save_enabled:
			system_action_requested.emit(action, 0)
		return
	if action != &"settings" and not system_enabled:
		return
	for child: Node in nested_page.get_children():
		nested_page.remove_child(child)
		child.queue_free()
	nested_action = action
	system_page.hide()
	nested_page.show()
	close_button.text = "Back"
	title_label.text = (system_buttons[action] as Button).text
	match action:
		&"load":
			_note(nested_page, "Load returns to that campaign's Refuge. Any active descent in the chosen slot is abandoned, following Main Menu Load rules.")
			for summary: Dictionary in CampaignSaveSlotStore.list_slots():
				var slot_id: int = int(summary.get("slot_id", 0))
				_note(nested_page, "Slot %d · %s\n%s" % [slot_id, String(summary.get("status", "empty")), String(summary.get("location_label", ""))])
				var button := _button(nested_page, "Recover Slot %d" % slot_id if bool(summary.get("used_backup", false)) else "Load Slot %d" % slot_id, _request_load.bind(slot_id))
				button.disabled = not bool(summary.get("campaign_loadable", false))
		&"settings":
			_build_settings()
		&"main_menu", &"quit":
			_note(nested_page, "Return to the main menu?" if action == &"main_menu" else "Quit Abyssal Bloom?")
			_button(nested_page, "Confirm", func() -> void: system_action_requested.emit(action, 0))
			_button(nested_page, "Cancel", handle_cancel)
	close_button.grab_focus()
	_trap_focus.call_deferred()


func _request_load(slot_id: int) -> void:
	system_action_requested.emit(&"load", slot_id)


func _build_settings() -> void:
	var settings: Dictionary = UserSettingsStore.load_settings()
	_note(nested_page, "Master volume")
	volume_slider = HSlider.new()
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = float(settings.master_volume)
	nested_page.add_child(volume_slider)
	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.button_pressed = bool(settings.fullscreen)
	nested_page.add_child(fullscreen_check)
	_note(nested_page, "Refuge interface scale")
	scale_slider = HSlider.new()
	scale_slider.min_value = 1.0
	scale_slider.max_value = 1.3
	scale_slider.step = 0.1
	scale_slider.value = ui_scale
	nested_page.add_child(scale_slider)
	_button(nested_page, "Apply", _save_settings)
	settings_status = _note(nested_page, "Changes apply when confirmed.")


func _save_settings() -> void:
	var settings := {"master_volume": volume_slider.value, "fullscreen": fullscreen_check.button_pressed, "refuge_ui_scale": scale_slider.value}
	var error: String = UserSettingsStore.save_settings(settings)
	settings_status.text = "Settings saved." if error.is_empty() else error
	if error.is_empty():
		ui_scale = scale_slider.value
		_apply_ui_scale()
		_layout()


func _apply_ui_scale() -> void:
	theme = Theme.new()
	theme.default_font_size = roundi(22 * ui_scale)
	title_label.add_theme_font_size_override("font_size", roundi(28 * ui_scale))


func _layout() -> void:
	if canvas == null or panel == null:
		return
	var fit: float = minf(size.x / CANVAS_SIZE.x, size.y / CANVAS_SIZE.y)
	canvas.scale = Vector2.ONE * fit
	canvas.position = (size - CANVAS_SIZE * fit) * 0.5
	bloom_frame.position = Vector2(size.x - bloom_frame.size.x - 24, 20)
	var fraction: float = 0.43 if active_station in [&"stash", &"loadouts", &"repair", &"expedition"] else 0.33
	var width: float = minf(size.x - 40, maxf(480, size.x * fraction * ui_scale))
	var left: bool = origin_station in [&"alchemy", &"repair", &"loadouts", &"records", &"expedition"]
	panel.position = Vector2(20 if left else size.x - width - 20, 76)
	var bar_visible: bool = inventory_bar != null and inventory_bar.visible
	panel.size = Vector2(width, maxf(200, size.y - (190 if bar_visible else 100)))
	if inventory_bar != null:
		inventory_bar.size = inventory_bar.get_combined_minimum_size()
		inventory_bar.position = Vector2(size.x * 0.5 - inventory_bar.size.x * 0.15, size.y - inventory_bar.size.y - 16)


func _trap_focus() -> void:
	if not modal.visible:
		return
	var controls: Array[Control] = []
	_collect_focus(panel, controls)
	if inventory_bar != null:
		_collect_focus(inventory_bar, controls)
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[(index + controls.size() - 1) % controls.size()])

	if not controls.has(get_viewport().gui_get_focus_owner()):
		close_button.grab_focus()


func _collect_focus(node: Node, result: Array[Control]) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree():
			return
		if control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and (control as BaseButton).disabled):
			result.append(control)
	for child: Node in node.get_children():
		_collect_focus(child, result)


func _button(parent: Node, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _unavailable(parent: Node, label: String) -> void:
	var button := _button(parent, label + " — unavailable", func() -> void: pass)
	button.disabled = true


func _note(parent: Node, message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _highlight_station(id: StringName, pointer: bool) -> void:
	for other_id: StringName in hotspots:
		if other_id == id:
			continue
		var other: RefugeRoomHotspot = hotspots[other_id]
		other.hovered = false
		if pointer:
			other.release_focus()
		other.queue_redraw()


func _open_preparation() -> void:
	var origin: StringName = origin_station
	open_station(&"loadouts")
	origin_station = origin
	_layout()


func attach_inventory_bar(bar: ItemBarView) -> void:
	inventory_bar = bar
	bar.reparent(modal)
	bar.use_horizontal_layout()
	bar.resized.connect(_layout)
	bar.hide()


func _inventory_tab_changed(backpacks: bool) -> void:
	if active_station == &"stash":
		title_label.text = "Backpacks" if backpacks else "Stash"
	if inventory_bar != null:
		inventory_bar.visible = backpacks and active_station == &"stash"
	_layout.call_deferred()
	_trap_focus.call_deferred()
