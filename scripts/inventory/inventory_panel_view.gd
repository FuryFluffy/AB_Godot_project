class_name InventoryPanelView
extends VBoxContainer
## Reusable tab shell. Run context exposes only Backpacks; it never owns inventory.

signal backpacks_visibility_changed(visible: bool)
var stash_page: Control
var backpacks_page: Control
var tabs: HBoxContainer
var stash_tab: Button
var backpacks_tab: Button
var is_refuge: bool = true
var showing_backpacks: bool = false


func configure(stash: Control, backpacks: Control, refuge_context: bool) -> void:
	stash_page = stash
	backpacks_page = backpacks
	is_refuge = refuge_context
	if tabs == null:
		tabs = HBoxContainer.new()
		add_child(tabs)
		move_child(tabs, 0)
		stash_tab = _tab("Stash", false)
		backpacks_tab = _tab("Backpacks", true)
	stash_tab.visible = is_refuge
	show_backpacks(not is_refuge)


func _tab(label: String, backpacks: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44
	tabs.add_child(button)
	button.pressed.connect(show_backpacks.bind(backpacks))
	return button


func show_backpacks(value: bool) -> void:
	showing_backpacks = value or not is_refuge
	stash_page.visible = not showing_backpacks and is_refuge
	backpacks_page.visible = showing_backpacks
	stash_tab.set_pressed_no_signal(not showing_backpacks)
	backpacks_tab.set_pressed_no_signal(showing_backpacks)
	backpacks_visibility_changed.emit(showing_backpacks)
