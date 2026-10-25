class_name RefugeRestView
extends VBoxContainer
## Presentation only until recovery effects, costs and eligibility are authored.

var screen: BloomRefugeScreen
var heroine_selector: HeroineSelector
var selected_heroine_id: StringName = &""
var entries: Array[Dictionary] = []
var values: Label
var restore_button: Button
var cleanse_button: Button
var enabled: bool = true


func configure(owner_screen: BloomRefugeScreen) -> void:
	screen = owner_screen
	add_theme_constant_override("separation", 18)
	_label("Choose a heroine")
	heroine_selector = HeroineSelector.new()
	heroine_selector.custom_minimum_size.y = 44
	add_child(heroine_selector)
	heroine_selector.item_selected.connect(_select_heroine)
	values = _label("")
	_label("Recovery services are not yet available.")
	restore_button = _service("Restore Resolve")
	cleanse_button = _service("Cleanse Corruption")
	refresh()


func refresh() -> void:
	if screen.management == null:
		entries.clear()
	else:
		entries = screen.management.get_rest_heroine_entries()
	selected_heroine_id = heroine_selector.present_heroines(entries, selected_heroine_id)
	heroine_selector.disabled = not enabled or entries.is_empty()
	# Never enable a charge/effect without an authoritative service definition.
	restore_button.disabled = true
	cleanse_button.disabled = true
	_present_values()


func handle_cancel() -> bool:
	if not heroine_selector.get_popup().visible:
		return false
	heroine_selector.get_popup().hide()
	heroine_selector.grab_focus()
	return true


func _select_heroine(index: int) -> void:
	if not enabled or index < 0 or index >= entries.size():
		return
	selected_heroine_id = StringName(entries[index].heroine_id)
	_present_values()


func _present_values() -> void:
	values.text = "No heroine available."
	for entry: Dictionary in entries:
		if StringName(entry.heroine_id) == selected_heroine_id:
			values.text = "%s\nResolve: %s\nCorruption: %s" % [entry.display_name, _value(entry.resolve), _value(entry.corruption)]
			return


func _value(value: Variant) -> String:
	return "Unavailable" if value == null else str(value)


func _service(title: String) -> Button:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	add_child(card)
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.disabled = true
	button.tooltip_text = "Recovery rules and costs are not available yet."
	card.add_child(button)
	var cost := Label.new()
	cost.text = "Cost: unavailable"
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(cost)
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label
