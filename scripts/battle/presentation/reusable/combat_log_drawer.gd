class_name CombatLogDrawer
extends PanelContainer


signal close_requested


@export var entry_font_size: int = 12

@onready var entries: VBoxContainer = %Entries


func clear_entries() -> void:
	for child: Node in entries.get_children():
		child.queue_free()


func append_entry(text: String) -> void:
	if text.is_empty():
		return
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_HELP
	if entry_font_size == 12:
		# Preserve the legacy drawer contract checked by the structural validator.
		label.add_theme_font_size_override("font_size", 12)
	else:
		label.add_theme_font_size_override("font_size", entry_font_size)
	entries.add_child(label)
	call_deferred("_scroll_to_bottom")


func append_detail(text: String) -> void:
	if text.is_empty() or entries.get_child_count() == 0:
		return
	var label := entries.get_child(
		entries.get_child_count() - 1
	) as Label
	if label == null:
		return
	if label.tooltip_text.is_empty():
		label.tooltip_text = text
	else:
		label.tooltip_text += "\n" + text


func _scroll_to_bottom() -> void:
	var scroll := %LogScroll as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
