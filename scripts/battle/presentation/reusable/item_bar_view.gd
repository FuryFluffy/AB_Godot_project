class_name ItemBarView
extends PanelContainer


signal slot_requested(slot_index: int)


var slot_buttons: Array[Button] = []
var slot_availability: Array[bool] = []
var commands_locked: bool = false


func _ready() -> void:
	for slot_index: int in range(6):
		var button := get_node(
			"Margin/Slots/Slot%d" % (slot_index + 1)
		) as Button
		button.pressed.connect(
			slot_requested.emit.bind(slot_index)
		)
		slot_buttons.append(button)
		slot_availability.append(false)


func display_slot(
	slot_index: int,
	label: String,
	enabled: bool,
	tooltip: String,
	selected: bool = false,
	icon: Texture2D = null,
	quantity: int = 0
) -> void:
	if slot_index < 0 or slot_index >= slot_buttons.size():
		return
	slot_availability[slot_index] = enabled
	enabled = enabled and not commands_locked
	var button: Button = slot_buttons[slot_index]
	if button is CombatItemSlotView:
		button.display_item(icon, quantity, enabled, selected, tooltip)
		return
	button.icon = icon
	button.text = _compact_slot_label(label, icon != null)
	button.disabled = not enabled
	button.tooltip_text = tooltip
	button.button_pressed = selected


func set_locked(locked: bool) -> void:
	commands_locked = locked
	for index: int in slot_buttons.size():
		slot_buttons[index].disabled = locked or not slot_availability[index]


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
