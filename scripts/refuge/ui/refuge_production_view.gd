class_name RefugeProductionView
extends HBoxContainer
## Same selection/commit flow with two distinct native compositions.
var screen: BloomRefugeScreen
var station: RefugeRecipeDefinition.Station
var recipes := ItemList.new()
var workspace := VBoxContainer.new()
var composition := VBoxContainer.new()
var result_box := HBoxContainer.new()
var result_icon := TextureRect.new()
var result_label := Label.new()
var action_button := Button.new()
var notice := Label.new()
var entries: Array[Dictionary] = []
var expected_snapshot: Dictionary = {}
var selected_recipe: StringName = &""
var enabled: bool = true

func configure(owner_screen: BloomRefugeScreen, kind: RefugeRecipeDefinition.Station) -> void:
	screen = owner_screen
	station = kind
	add_theme_constant_override("separation", 22)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 210
	add_child(column)
	column.add_child(_label("Recipes"))
	recipes.custom_minimum_size = Vector2(210, 330)
	recipes.fixed_icon_size = Vector2i(36, 36)
	recipes.allow_reselect = true
	column.add_child(recipes)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 16)
	add_child(workspace)
	workspace.add_child(_label("Alchemy Table" if _alchemy() else "Crafting Workbench"))
	workspace.add_child(composition)
	composition.add_theme_constant_override("separation", 14)
	workspace.add_child(result_box)
	result_box.add_theme_constant_override("separation", 12)
	result_icon.custom_minimum_size = Vector2(80, 100)
	result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_box.add_child(result_icon)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_box.add_child(result_label)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace.add_child(notice)
	action_button.text = "Brew" if _alchemy() else "Craft"
	action_button.custom_minimum_size.y = 48
	workspace.add_child(action_button)
	var selected: StyleBoxFlat = _frame(Color(0.22, 0.15, 0.32) if _alchemy() else Color(0.25, 0.17, 0.08))
	recipes.add_theme_stylebox_override("selected", selected)
	recipes.add_theme_stylebox_override("selected_focus", selected)
	action_button.add_theme_stylebox_override("normal", selected)
	recipes.item_selected.connect(_preview)
	action_button.pressed.connect(_produce)

func refresh() -> void:
	if screen == null or screen.management == null:
		return
	expected_snapshot = screen.current_run_state.refuge_ownership.to_snapshot()
	entries = screen.management.get_production_entries(station)
	recipes.clear()
	var selection: int = 0
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		recipes.add_item(entry.name, entry.output_icon)
		recipes.set_item_tooltip(index, entry.name)
		if StringName(entry.recipe_id) == selected_recipe:
			selection = index
	if entries.is_empty():
		recipes.add_item("No recipes available")
		recipes.set_item_disabled(0, true)
		_clear_composition()
		composition.add_child(_label("No recipes are available for this station yet."))
		result_icon.texture = null
		result_label.text = "Final Item\nNo result selected"
		notice.text = "Banked Materials → Stash"
		action_button.disabled = true
		selected_recipe = &""
	else:
		recipes.select(selection)
		_preview(selection)

func _preview(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	var entry: Dictionary = entries[index]
	selected_recipe = StringName(entry.recipe_id)
	_clear_composition()
	var inputs: Array = entry.inputs
	if _alchemy():
		composition.add_child(_label("Materials · Owned / Required"))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		composition.add_child(grid)
		for input: Dictionary in inputs:
			grid.add_child(_ingredient(input, true))
		var flow := Convergence.new()
		flow.custom_minimum_size.y = 72
		composition.add_child(flow)
	else:
		var assembly := HBoxContainer.new()
		assembly.add_theme_constant_override("separation", 14)
		composition.add_child(assembly)
		var parchment := PanelContainer.new()
		parchment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parchment.add_theme_stylebox_override("panel", _frame(Color(0.62, 0.51, 0.34)))
		assembly.add_child(parchment)
		var sketch := VBoxContainer.new()
		parchment.add_child(sketch)
		var caption := _label("Assembly preview")
		caption.modulate = Color(0.15, 0.10, 0.06)
		sketch.add_child(caption)
		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(130, 180)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = entry.output_icon
		sketch.add_child(art)
		var checklist := VBoxContainer.new()
		checklist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		assembly.add_child(checklist)
		checklist.add_child(_label("Materials · Owned / Required"))
		for input: Dictionary in inputs:
			checklist.add_child(_ingredient(input, false))
	result_icon.texture = entry.output_icon
	result_label.text = "Final Item\n%s ×%d" % [entry.output_name, entry.quantity]
	notice.text = "Result goes to Stash. Uses banked Materials." if entry.can_pay else "Insufficient banked Materials."
	action_button.disabled = not enabled or not bool(entry.can_pay)
	screen.room_shell._trap_focus.call_deferred()

func _ingredient(input: Dictionary, alchemy: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _frame(Color(0.09, 0.07, 0.13) if alchemy else Color(0.12, 0.10, 0.07)))
	var box := VBoxContainer.new()
	panel.add_child(box)
	if alchemy:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(60, 65)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = input.icon
		box.add_child(icon)
	var text: String = "%s\n%d / %d%s" % [input.name, input.owned, input.required, " · Ready" if int(input.owned) >= int(input.required) else " · Missing"]
	box.add_child(_label(text))
	return panel

func _produce() -> void:
	if not enabled or action_button.disabled or selected_recipe == &"":
		return
	var result: Dictionary = screen.management.produce_item(station, selected_recipe, expected_snapshot)
	if not String(result.error).is_empty():
		screen.show_status(String(result.error), true)
		refresh()
		return
	screen.show_status("Created %d item(s) in Stash." % int(result.quantity))
	refresh()

func _clear_composition() -> void:
	for child: Node in composition.get_children():
		composition.remove_child(child)
		child.queue_free()

func _alchemy() -> bool:
	return station == RefugeRecipeDefinition.Station.ALCHEMY

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _frame(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.55, 0.43, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

class Convergence extends Control:
	func _draw() -> void:
		var destination := Vector2(size.x * 0.5, size.y - 10)
		for fraction: float in [0.25, 0.75]:
			draw_line(Vector2(size.x * fraction, 0), destination, Color(0.62, 0.45, 0.75), 2, true)
		draw_circle(destination, 6, Color(0.62, 0.45, 0.75), false, 2, true)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
