class_name RefugeSlotGrid
extends GridContainer


signal slot_selected(entry: Dictionary)


var entries: Array[Dictionary] = []
var selected_slot_index: int = -1


func present(next_entries: Array[Dictionary], column_count: int) -> void:
	entries = next_entries.duplicate(true)
	columns = maxi(column_count, 1)
	selected_slot_index = -1
	for child: Node in get_children():
		child.queue_free()
	for entry: Dictionary in entries:
		var button := Button.new()
		var slot_index: int = int(entry.get("slot_index", get_child_count()))
		var item_id := StringName(entry.get("item_id", ""))
		var quantity: int = int(entry.get("quantity", 0))
		button.custom_minimum_size = Vector2(112.0, 58.0)
		button.text = (
			"%02d  Empty" % (slot_index + 1)
			if item_id == &""
			else "%02d  %s ×%d" % [
				slot_index + 1,
				String(entry.get("display_name", item_id)),
				quantity,
			]
		)
		button.tooltip_text = (
			"Empty slot"
			if item_id == &""
			else "%s\nStable ID: %s\nQuantity: %d" % [
				String(entry.get("display_name", item_id)),
				item_id,
				quantity,
			]
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = entry.get("icon", null) as Texture2D
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.disabled = item_id == &""
		button.pressed.connect(_select_slot.bind(slot_index))
		add_child(button)


func get_selected_entry() -> Dictionary:
	for entry: Dictionary in entries:
		if int(entry.get("slot_index", -1)) == selected_slot_index:
			return entry.duplicate(true)
	return {}


func _select_slot(slot_index: int) -> void:
	selected_slot_index = slot_index
	var entry: Dictionary = get_selected_entry()
	if not entry.is_empty():
		slot_selected.emit(entry)
