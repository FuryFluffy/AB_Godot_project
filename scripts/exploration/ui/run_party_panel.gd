class_name RunPartyPanel
extends Control
## Read-only inspection of existing states. Only the supplied order callback can
## mutate anything; sprite selection never selects a combat actor or field target.
const VISUALS = preload("res://data/presentation/battler_visual_profile_catalog.tres")
var states: Dictionary = {}
var order: Array[StringName] = []
var selected: StringName
var inventory: RunInventoryState
var equipment: RunEquipmentState
var commit_order: Callable
var access_guard: Callable
var dock: RunHUDDock
var origin: Button
var frame: PanelContainer
var cards: HBoxContainer
var details: RichTextLabel
var status: Label
var earlier: Button
var later: Button
var abilities: Button
var close_button: Button
var ability_panel: AbilityPanel
var card_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	frame = PanelContainer.new()
	frame.theme = Theme.new()
	frame.theme.default_font_size = 22
	frame.add_theme_stylebox_override("panel", preload("res://scenes/battle/ui/reusable/styles/hud_frame_style.tres"))
	add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	frame.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := Label.new()
	title.text = "Current Party"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button = _button(heading, "Close", close_panel)
	status = Label.new()
	status.text = "Select a heroine to inspect. Order changes apply immediately."
	content.add_child(status)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	content.add_child(body)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	body.add_child(cards)
	details = RichTextLabel.new()
	details.custom_minimum_size = Vector2(340, 460)
	details.focus_mode = Control.FOCUS_ALL
	details.selection_enabled = true
	body.add_child(details)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)
	earlier = _button(actions, "Move earlier", _move.bind(-1))
	later = _button(actions, "Move later", _move.bind(1))
	abilities = _button(actions, "Abilities", _show_abilities)
	ability_panel = preload("res://scenes/battle/ui/reusable/components/ability_panel.tscn").instantiate()
	add_child(ability_panel)
	ability_panel.attach_to_command(abilities)
	# Exploration abilities are read-only; Back is the only enabled control.
	for property: String in ["focus_next", "focus_previous", "focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom"]:
		ability_panel.cancel_button.set(property, NodePath("."))
	ability_panel.cancelled.connect(func() -> void:
		ability_panel.close_panel()
		abilities.grab_focus())
	get_viewport().size_changed.connect(_layout)
	hide()

func configure(current_states: Dictionary, current_order: Array[StringName], bags: RunInventoryState, gear: RunEquipmentState, commit: Callable, guard: Callable, hud_dock: RunHUDDock, button: Button) -> void:
	states = current_states
	order = current_order.duplicate()
	inventory = bags
	equipment = gear
	commit_order = commit
	access_guard = guard
	dock = hud_dock
	origin = button

func open_panel(preferred: StringName = &"") -> bool:
	if not _access_error().is_empty() or order.is_empty():
		return false
	selected = preferred if order.has(preferred) else order[0]
	status.text = "Select a heroine to inspect. Order changes apply immediately."
	show()
	refresh()
	(card_buttons[selected] as Button).grab_focus()
	return true

func close_panel() -> void:
	ability_panel.close_panel()
	hide()
	origin.grab_focus()

func cancel() -> bool:
	if not visible:
		return false
	if ability_panel.visible:
		ability_panel.close_panel()
		abilities.grab_focus()
	else:
		close_panel()
	return true

func _process(_delta: float) -> void:
	if visible and not _access_error().is_empty():
		close_panel()

func _access_error() -> String:
	return String(access_guard.call()) if access_guard.is_valid() else "Party is unavailable."

func refresh() -> void:
	for child: Node in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	card_buttons.clear()
	for id: StringName in order:
		var state: BattlerState = states.get(id)
		if state == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 460)
		button.toggle_mode = true
		button.set_pressed_no_signal(id == selected)
		button.tooltip_text = "Inspect " + state.definition.display_name
		cards.add_child(button)
		var box := VBoxContainer.new()
		button.add_child(box)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var art := TextureRect.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture = VISUALS.resolve_visual(id, &"idle", &"front").get("texture") as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(art)
		var caption := Label.new()
		caption.text = "%d. %s" % [order.find(id) + 1, state.definition.display_name]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(caption)
		button.pressed.connect(func() -> void:
			ability_panel.close_panel()
			selected = id
			refresh()
			(card_buttons[id] as Button).grab_focus())
		card_buttons[id] = button
	_present_details()
	var controls: Array[Control] = [close_button]
	for id: StringName in order:
		if card_buttons.has(id):
			controls.append(card_buttons[id])
	controls.append(details)
	for button: Button in [earlier, later, abilities]:
		if not button.disabled:
			controls.append(button)
	for i: int in range(controls.size()):
		var next: NodePath = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		var previous: NodePath = controls[i].get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
		controls[i].focus_next = next
		controls[i].focus_previous = previous
		controls[i].focus_neighbor_right = next
		controls[i].focus_neighbor_bottom = next
		controls[i].focus_neighbor_left = previous
		controls[i].focus_neighbor_top = previous
	_layout.call_deferred()

func _present_details() -> void:
	var state: BattlerState = states.get(selected)
	if state == null:
		return
	earlier.disabled = order.find(selected) <= 0
	later.disabled = order.find(selected) >= order.size() - 1
	var lines: Array[String] = [state.definition.display_name,
		"HP %d/%d · MP %d/%d" % [state.current_hp, state.get_max_hp(), state.current_mp, state.get_max_mp()],
		"Resolve %d · Corruption %d" % [state.current_resolve, state.current_corruption],
		"Status: " + state.get_status_summary(), "", "Attributes"]
	for attribute: String in ["might", "agility", "endurance", "intellect", "personality"]:
		lines.append("%s: %d" % [attribute.capitalize(), state.definition.attributes.get(attribute)])
	lines.append("\nSkills")
	for skill: SkillEntry in state.definition.skills:
		lines.append("%s: %d · %s" % [String(SkillEntry.Skill.keys()[skill.skill]).capitalize(), skill.level, String(SkillEntry.Tier.keys()[skill.tier]).capitalize()])
	if state.progression != null:
		for family: Variant in state.progression.weapon_family_ranks:
			lines.append("%s rank: %d" % [String(family).capitalize(), state.progression.get_weapon_family_rank(StringName(family))])
	lines.append("\nEquipment")
	var loadout: PersonalEquipmentLoadoutState = equipment.get_loadout(selected) if equipment != null else state.equipment_loadout_state
	for slot: EquipmentDefinition.Slot in [EquipmentDefinition.Slot.MAIN_HAND, EquipmentDefinition.Slot.OFF_HAND, EquipmentDefinition.Slot.ARMOR]:
		var instance: EquipmentInstance = loadout.get_equipped_instance(slot) if loadout != null else null
		lines.append("%s: %s" % [EquipmentDefinition.get_slot_label(slot), "%s (%d/%d)%s" % [instance.definition.display_name, instance.current_condition, instance.definition.condition_maximum, " · Broken" if instance.is_broken() else ""] if instance != null else "None"])
	lines.append("Shield: " + (state.shield_state.definition.display_name if state.shield_state != null else "None"))
	var memento: ItemDefinition = inventory.catalog.get_item(inventory.get_memento_id(selected)) if inventory != null else null
	lines.append("Memento: " + (memento.display_name if memento != null else "None"))
	details.text = "\n".join(lines)
	details.scroll_to_line(0)

func _move(direction: int) -> void:
	if not _access_error().is_empty() or not commit_order.is_valid():
		return
	var index: int = order.find(selected)
	var target: int = index + direction
	if index < 0 or target < 0 or target >= order.size():
		return
	var next: Array[StringName] = order.duplicate()
	next[index] = next[target]
	next[target] = selected
	var error: String = String(commit_order.call(next, order))
	if not error.is_empty():
		status.text = error
		return
	ability_panel.close_panel()
	order = next
	refresh()
	status.text = "Party display order updated."
	(card_buttons[selected] as Button).grab_focus()

func _show_abilities() -> void:
	var state: BattlerState = states.get(selected)
	if state != null:
		ability_panel.present_exploration(state)

func _layout() -> void:
	if dock == null:
		return
	frame.reset_size()
	var viewport: Vector2 = get_viewport_rect().size
	var available: float = viewport.y - (RunHUDDock.HEIGHT + 54) * dock.layout_scale - 12
	var factor: float = minf(1.0, minf(available / frame.size.y, (viewport.x - 32) / frame.size.x))
	frame.scale = Vector2.ONE * factor
	frame.position = Vector2((viewport.x - frame.size.x * factor) * 0.5, 12)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.pressed.connect(action)
	parent.add_child(button)
	return button
