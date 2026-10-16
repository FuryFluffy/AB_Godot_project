class_name HeroineSelector
extends OptionButton
## Same named selector in Backpack and Loadouts; selection is presentation only.

func _ready() -> void:
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color(0.22, 0.15, 0.32, 0.9)
	selected.border_color = Color(0.64, 0.50, 0.72)
	selected.set_border_width_all(1)
	selected.set_corner_radius_all(4)
	get_popup().add_theme_stylebox_override("hover", selected)
	add_theme_stylebox_override("focus", selected)

func present_heroines(entries: Array[Dictionary], preferred: StringName) -> StringName:
	clear()
	var chosen: int = 0
	for entry: Dictionary in entries:
		add_item(String(entry.display_name))
		set_item_metadata(item_count - 1, entry.heroine_id)
		if StringName(entry.heroine_id) == preferred:
			chosen = item_count - 1
	if item_count == 0:
		return &""
	select(chosen)
	return StringName(get_item_metadata(chosen))
