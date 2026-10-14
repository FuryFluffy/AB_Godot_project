class_name ItemBarView
extends PanelContainer


signal slot_requested(slot_index: int)


var slot_buttons: Array[Button] = []


func _ready() -> void:
	for slot_index: int in range(6):
		var button := get_node(
			"Margin/Slots/Slot%d" % (slot_index + 1)
		) as Button
		button.pressed.connect(
			slot_requested.emit.bind(slot_index)
		)
		slot_buttons.append(button)


func display_slot(
	slot_index: int,
	label: String,
	enabled: bool,
	tooltip: String,
	selected: bool = false,
	icon: Texture2D = null
) -> void:
	if slot_index < 0 or slot_index >= slot_buttons.size():
		return
	var button: Button = slot_buttons[slot_index]
	button.icon = icon
	button.text = _compact_slot_label(label, icon != null)
	button.disabled = not enabled
	button.tooltip_text = tooltip
	button.button_pressed = selected


func set_locked(locked: bool) -> void:
	for button: Button in slot_buttons:
		button.disabled = locked


func _compact_slot_label(label: String, has_icon: bool) -> String:
	var lines := label.split("\n", false)
	if lines.is_empty():
		return "—"
	var slot_number: String = lines[0]
	if lines.size() < 2 or lines[1] == "Empty":
		return "%s\n—" % slot_number
	var quantity: String = lines[lines.size() - 1]
	if has_icon:
		return quantity
	var initials: String = ""
	for word: String in lines[1].split(" ", false):
		if word.is_empty():
			continue
		initials += word.left(1).to_upper()
		if initials.length() >= 2:
			break
	if initials.is_empty():
		initials = slot_number
	return "%s\n%s" % [initials, quantity]


func use_horizontal_layout() -> void:
	# Same six native buttons; the existing combat layout remains vertical until Stage 10.
	var slots := get_node("Margin/Slots") as GridContainer
	slots.columns = 6
	slots.add_theme_constant_override("h_separation", 6)
	for button: Button in slot_buttons:
		button.custom_minimum_size = Vector2(66, 66)
		button.add_theme_constant_override("icon_max_width", 40)
	custom_maximum_size = Vector2(442, 86)
	custom_minimum_size = Vector2(442, 86)
	reset_size()


func present_inventory(entries: Array[Dictionary], selected_index: int = -1) -> void:
	for index: int in range(slot_buttons.size()):
		var entry: Dictionary = entries[index] if index < entries.size() else {}
		var empty: bool = bool(entry.get("empty", true))
		display_slot(index, "%d\n%s\n×%d" % [index + 1, "Empty" if empty else entry.get("display_name", ""), int(entry.get("quantity", 0))], not empty, String(entry.get("details", "Empty slot")), index == selected_index, entry.get("icon", null))
