class_name RefugeLoadoutsView
extends VBoxContainer
## Four rows over existing equipment/Memento owners. Candidate browsing is free.

var screen: BloomRefugeScreen
var selector := HeroineSelector.new()
var rows := VBoxContainer.new()
var chooser := VBoxContainer.new()
var candidate_list := ItemList.new()
var destination_hint := Label.new()
var equip_button := Button.new()
var back_button := Button.new()
var heading := Label.new()
var heroine_id: StringName = &"lysandra"
var slot_key: StringName = &""
var choices: Array[Dictionary] = []
var expected_snapshot: Dictionary = {}
var change_buttons: Dictionary = {}
var enabled: bool = true

func configure(owner_screen: BloomRefugeScreen) -> void:
	screen = owner_screen
	var normal: StyleBoxFlat = _frame(Color(0.07, 0.065, 0.08, 0.88))
	var selected: StyleBoxFlat = _frame(Color(0.22, 0.15, 0.32, 0.9))
	selected.border_color = Color(0.64, 0.50, 0.72)
	theme = Theme.new()
	theme.set_color("font_color", "Label", Color(0.91, 0.87, 0.79))
	for type_name: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, normal)
		for style_name: String in ["hover", "pressed", "focus"]:
			theme.set_stylebox(style_name, type_name, selected)
	for style_name: String in ["selected", "selected_focus", "cursor"]:
		theme.set_stylebox(style_name, "ItemList", selected)
	add_theme_constant_override("separation", 12)
	selector.custom_minimum_size.y = 44
	add_child(selector)
	add_child(rows)
	rows.add_theme_constant_override("separation", 12)
	add_child(chooser)
	chooser.add_theme_constant_override("separation", 12)
	chooser.add_child(heading)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidate_list.custom_minimum_size = Vector2(0, 280)
	candidate_list.allow_reselect = true
	candidate_list.fixed_icon_size = Vector2i(42, 42)
	chooser.add_child(candidate_list)
	destination_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chooser.add_child(destination_hint)
	var actions := HBoxContainer.new()
	chooser.add_child(actions)
	for button: Button in [back_button, equip_button]:
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	back_button.text = "Back"
	equip_button.text = "Equip"
	selector.item_selected.connect(_select_heroine)
	candidate_list.item_selected.connect(_preview)
	back_button.pressed.connect(close_choices)
	equip_button.pressed.connect(_commit)
	visibility_changed.connect(_visibility_changed)
	chooser.hide()

func refresh() -> void:
	if screen.management == null:
		return
	heroine_id = selector.present_heroines(screen.management.get_backpack_heroine_entries(), heroine_id)
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	change_buttons.clear()
	for entry: Dictionary in screen.management.get_equipped_entries(heroine_id):
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.065, 0.08, 0.88)
		style.border_color = Color(0.40, 0.32, 0.22, 0.75)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", style)
		rows.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var icon_slot := PanelContainer.new()
		icon_slot.custom_minimum_size = Vector2(60, 60)
		icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_slot.add_theme_stylebox_override("panel", _frame(Color(0.025, 0.025, 0.035, 0.7)))
		row.add_child(icon_slot)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = entry.icon
		icon_slot.add_child(icon)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		for value: String in [String(entry.label), String(entry.display_name), String(entry.condition_text)]:
			if value.is_empty():
				continue
			var label := Label.new()
			label.text = value
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details.add_child(label)
		panel.tooltip_text = String(entry.get("description", entry.condition_text))
		var change := Button.new()
		change.text = "Change"
		change.custom_minimum_size = Vector2(110, 44)
		change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		change.disabled = not enabled
		change.pressed.connect(open_choices.bind(StringName(entry.slot)))
		row.add_child(change)
		change_buttons[StringName(entry.slot)] = change

func _select_heroine(index: int) -> void:
	heroine_id = StringName(selector.get_item_metadata(index))
	close_choices()
	refresh()
	screen.room_shell._trap_focus.call_deferred()
	selector.grab_focus()

func open_choices(slot: StringName) -> void:
	if not enabled:
		return
	slot_key = slot
	expected_snapshot = screen.current_run_state.refuge_ownership.to_snapshot()
	choices = screen.management.get_loadout_candidates(heroine_id, slot)
	candidate_list.clear()
	for entry: Dictionary in choices:
		var text: String = "%s — %s" % [entry.display_name, entry.source_label]
		if not String(entry.condition_text).is_empty():
			text += " · " + String(entry.condition_text)
		candidate_list.add_item(text, entry.get("icon", null))
		candidate_list.set_item_tooltip(candidate_list.item_count - 1, text + "\n" + String(entry.get("description", "")))
	heading.text = "%s · %s" % [selector.get_item_text(selector.selected), "Memento" if slot == &"memento" else EquipmentDefinition.get_slot_label(RefugeLoadoutExchange.KEYS.find(slot))]
	rows.hide()
	selector.hide()
	chooser.show()
	equip_button.disabled = true
	destination_hint.text = "Choose an item to preview where the current item will return."
	back_button.text = "Back"
	screen.room_shell.close_button.text = "Back"
	screen.room_shell._trap_focus.call_deferred()
	candidate_list.grab_focus()

func _preview(index: int) -> void:
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	var nothing: bool = String(choice.source.domain) == "nothing"
	destination_hint.text = "The current item returns to %s. Ownership changes only when you confirm." % ("Stash" if nothing or String(choice.source.domain) in ["stash", "stash_equipment"] else String(choice.source_label))
	equip_button.text = "Unequip to Stash" if nothing else "Equip"
	equip_button.disabled = not enabled

func _commit() -> void:
	if not enabled or candidate_list.get_selected_items().is_empty():
		return
	var index: int = candidate_list.get_selected_items()[0]
	var result: Dictionary = screen.management.exchange_loadout(heroine_id, slot_key, choices[index].source, expected_snapshot)
	if not String(result.error).is_empty():
		screen.show_status(String(result.error), true)
		return
	close_choices()
	screen.show_status("Loadout updated." if bool(result.get("changed", false)) else "Loadout unchanged.")

func close_choices() -> void:
	chooser.hide()
	rows.show()
	selector.show()
	if screen.room_shell.active_station == &"loadouts":
		screen.room_shell.close_button.text = "Close"
		var button: Button = change_buttons.get(slot_key)
		if is_instance_valid(button):
			button.grab_focus()
		screen.room_shell._trap_focus.call_deferred()
	expected_snapshot = {}

func handle_cancel() -> bool:
	if not is_visible_in_tree():
		return false
	if selector.get_popup().visible:
		selector.get_popup().hide()
		selector.grab_focus()
		return true
	if chooser.visible:
		close_choices()
		return true
	return false

func _visibility_changed() -> void:
	if not is_visible_in_tree() and is_instance_valid(screen):
		close_choices()

func _frame(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.52, 0.41, 0.27, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
