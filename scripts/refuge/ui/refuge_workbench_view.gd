class_name RefugeWorkbenchView
extends VBoxContainer
## Presentation over the existing repair/salvage controls and ownership services.
var screen: BloomRefugeScreen
var tabs := TabBar.new()
var repair_page := VBoxContainer.new()
var salvage_page := VBoxContainer.new()
var repair_preview := Label.new()
var salvage_preview := Label.new()
var ownership_snapshot: Dictionary = {}
var repair_snapshot: Dictionary = {}
var enabled: bool = true

func configure(owner_screen: BloomRefugeScreen) -> void:
	screen = owner_screen
	add_theme_constant_override("separation", 16)
	add_child(tabs)
	tabs.add_tab("Repair")
	tabs.add_tab("Salvage")
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	tabs.custom_minimum_size.y = 44
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color(0.22, 0.15, 0.32, 0.9)
	selected.border_color = Color(0.64, 0.50, 0.72)
	selected.set_border_width_all(1)
	selected.content_margin_left = 16
	selected.content_margin_right = 16
	selected.content_margin_top = 8
	selected.content_margin_bottom = 8
	tabs.add_theme_stylebox_override("tab_selected", selected)
	screen.salvage_confirmation.theme = screen.room_shell.theme
	screen.salvage_confirmation.dialog_autowrap = true
	for page: VBoxContainer in [repair_page, salvage_page]:
		page.add_theme_constant_override("separation", 14)
		add_child(page)
	var services: Node = screen.room_shell.pages[&"repair"].get_node("Services")
	services.get_node("Header").hide()
	for control: Control in [screen.recipe_list, screen.repair_target, screen.recipe_details]:
		control.reparent(repair_page)
	repair_page.add_child(repair_preview)
	(screen.get_node("%RepairSelected") as Button).reparent(repair_page)
	services.get_node("SalvageHeader").text = "Salvage unused equipment"
	services.get_node("SalvageHeader").reparent(salvage_page)
	screen.salvage_list.reparent(salvage_page)
	screen.salvage_list.custom_minimum_size.y = 240
	salvage_page.add_child(salvage_preview)
	(screen.get_node("%SalvageSelected") as Button).reparent(salvage_page)
	for label: Label in [repair_preview, salvage_preview]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button: Button in [screen.get_node("%RepairSelected"), screen.get_node("%SalvageSelected")]:
		button.custom_minimum_size.y = 44
	tabs.tab_changed.connect(_tab_changed)
	screen.salvage_list.item_selected.connect(func(_index: int) -> void: update_salvage_preview())
	_tab_changed(0)

func _tab_changed(index: int) -> void:
	repair_page.visible = index == 0
	salvage_page.visible = index == 1
	screen.room_shell._trap_focus.call_deferred()

func update_repair_preview() -> void:
	repair_snapshot = ownership_snapshot.duplicate(true)
	screen.get_node("%RepairSelected").disabled = true
	var index: int = screen.repair_target.selected
	if index < 0 or index >= screen.repair_target_entries.size():
		repair_preview.text = "No damaged equipment matches this repair."
		return
	var entry: Dictionary = screen.repair_target_entries[index]
	var recipe: RefugeRecipeDefinition = screen.management.RECIPE_CATALOG.get_recipe(screen.selected_recipe_id)
	if recipe == null:
		return
	var after: int = mini(int(entry.condition_maximum), int(entry.condition) + recipe.condition_restore_amount)
	repair_preview.text = "%s\n%s\nCondition %d/%d → %d/%d\nThe equipment stays at its current location." % [entry.display_name, entry.source_label, entry.condition, entry.condition_maximum, after, entry.condition_maximum]
	for choice: Dictionary in screen.management.get_recipe_entries():
		if StringName(choice.recipe_id) == screen.selected_recipe_id:
			screen.get_node("%RepairSelected").disabled = not enabled or not bool(choice.can_pay)

func update_salvage_preview() -> void:
	var selected: PackedInt32Array = screen.salvage_list.get_selected_items()
	var button: Button = screen.get_node("%SalvageSelected")
	button.disabled = true
	salvage_preview.text = "Select unused equipment to inspect its Materials yield. Equipped equipment must be unequipped first."
	if selected.is_empty():
		return
	var value: Variant = screen.salvage_list.get_item_metadata(selected[0])
	if not value is Dictionary:
		return
	var entry: Dictionary = value
	salvage_preview.text = "%s\n%s\nCondition %d/%d\nYield: %d × %s → banked Materials" % [entry.display_name, entry.source_label, entry.condition, entry.condition_maximum, entry.salvage_yield, material_name(StringName(entry.salvage_material_id))]
	button.disabled = not enabled

func material_name(id: StringName) -> String:
	var definition: MaterialDefinition = screen.management.MATERIAL_CATALOG.get_material(id)
	return definition.display_name if definition != null else String(id)
