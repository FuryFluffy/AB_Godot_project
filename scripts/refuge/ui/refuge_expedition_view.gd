class_name RefugeExpeditionView
extends VBoxContainer

const VISUALS = preload("res://data/presentation/battler_visual_profile_catalog.tres")
const INTEL: Array[Array] = [
	["Scouting", "Identify adjacent room types through discovery."],
	["Battle Sense", "Identify Normal and Elite Combat nodes."],
	["Smell of a Coin", "Identify a Treasury and reveal an actual route to it."],
	["Pathfinding", "Reveal the layer's node connections."],
	["Sanctuary Sense", "Identify Rest nodes."],
	["Danger Sense", "Identify Trap rooms, without disarming trapped items."],
	["Artisan’s Eye", "Identify Alchemy and Workshop nodes."],
	["Castle Memory", "Reuse the last layout and its discovered map knowledge."],
	["Conqueror’s Passage", "Start at an eligible permanently defeated boss. Floor access alone is insufficient."],
]

var screen: BloomRefugeScreen
var section: StringName = &"hub"
var enabled: bool = true
var draft: Array[StringName] = []
var baseline: Array[StringName] = []
var initialized: bool = false
var views: Dictionary = {}
var navigation: Dictionary = {}
var floor_map: RefugeFloorProgressView
var floor_label: Label
var party_summary: Label
var draft_summary: Label
var cards: HBoxContainer
var heroine_buttons: Dictionary = {}
var apply_button: Button
var reset_button: Button
var progress_selector: HeroineSelector
var progress_tabs: TabBar
var progress_list: ItemList
var progress_detail: Label
var progress_rows: Array[Dictionary] = []
var progress_heroine: StringName = &""
var upgrade_button: Button
var intel_tabs: TabBar
var intel_list: VBoxContainer

func configure(owner_screen: BloomRefugeScreen) -> void:
	screen = owner_screen
	add_theme_constant_override("separation", 14)
	for id: StringName in [&"hub", &"party", &"intel", &"level"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		add_child(box)
		views[id] = box
	_build_hub()
	_build_party()
	_build_intel()
	_build_progression()
	show_section(&"hub")

func _build_hub() -> void:
	var hub: VBoxContainer = views[&"hub"]
	floor_label = _label(hub, "")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	hub.add_child(columns)
	floor_map = RefugeFloorProgressView.new()
	floor_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(floor_map)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 12)
	columns.add_child(actions)
	for entry: Array in [[&"party", "Party"], [&"intel", "Intel"], [&"level", "Level Up"]]:
		navigation[entry[0]] = _button(actions, entry[1], show_section.bind(entry[0]))
	party_summary = _label(actions, "")
	_label(actions, "Intel: unavailable\nNo Intel purchases are active.")
	_label(hub, "Departure: Layer 2 · Farthest Cell\nUnspent Bloom is discarded on departure. Stash and banked Materials remain safe.")
	# Keep the existing seed and run-launch signal, validation and application owner.
	screen.seed_edit.get_parent().reparent(hub)
	screen.seed_edit.get_parent().show()
	screen.begin_button.text = "Explore"
	views[&"hub"].visibility_changed.connect(_hub_visibility_changed)

func _build_party() -> void:
	var page: VBoxContainer = views[&"party"]
	_label(page, "Select one to three heroines in party order. Select again to remove.")
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	page.add_child(cards)
	draft_summary = _label(page, "")
	var actions := HBoxContainer.new()
	page.add_child(actions)
	_button(actions, "Back", show_section.bind(&"hub"))
	reset_button = _button(actions, "Reset Draft", _reset_draft)
	apply_button = _button(actions, "Apply Party", _apply_party)

func _build_intel() -> void:
	var page: VBoxContainer = views[&"intel"]
	intel_tabs = TabBar.new()
	intel_tabs.add_tab("This Run")
	intel_tabs.add_tab("Permanent")
	page.add_child(intel_tabs)
	_label(page, "Intel services and prices are not available yet.")
	intel_list = VBoxContainer.new()
	intel_list.add_theme_constant_override("separation", 14)
	page.add_child(intel_list)
	intel_tabs.tab_changed.connect(func(_index: int) -> void: _refresh_intel())
	_button(page, "Back", show_section.bind(&"hub"))
	_refresh_intel()

func _build_progression() -> void:
	var page: VBoxContainer = views[&"level"]
	progress_selector = HeroineSelector.new()
	page.add_child(progress_selector)
	progress_selector.item_selected.connect(func(index: int) -> void:
		progress_heroine = StringName(progress_selector.get_item_metadata(index))
		_refresh_progression()
	)
	progress_tabs = TabBar.new()
	for title: String in ["Stats", "Skills", "Heroine Upgrades"]:
		progress_tabs.add_tab(title)
	page.add_child(progress_tabs)
	progress_tabs.tab_changed.connect(func(_index: int) -> void: _refresh_progression())
	progress_list = ItemList.new()
	progress_list.custom_minimum_size.y = 300
	page.add_child(progress_list)
	progress_detail = _label(page, "")
	progress_list.item_selected.connect(_select_progression)
	_label(page, "Cost: unavailable")
	upgrade_button = _button(page, "Upgrade — unavailable", Callable())
	upgrade_button.disabled = true
	_button(page, "Back", show_section.bind(&"hub"))

func refresh() -> void:
	if screen.management == null:
		return
	var ownership: RefugeOwnershipState = screen.current_run_state.refuge_ownership
	if not initialized or draft == baseline:
		baseline = ownership.selected_party_ids.duplicate()
		draft = baseline.duplicate()
		initialized = true
	if heroine_buttons.is_empty():
		for entry: Dictionary in screen.management.get_backpack_heroine_entries():
			_make_heroine_card(StringName(entry.heroine_id), String(entry.display_name))
	var accessed: Array[StringName] = screen.current_run_state.campaign_lifecycle.accessed_layer_ids
	floor_map.present(accessed)
	var deepest: int = 0
	for number: int in range(1, 11):
		if accessed.has(StringName("layer_%d" % number)):
			deepest = number
	floor_label.text = "Deepest floor reached: %d" % deepest
	party_summary.text = "Applied party\n" + _names(ownership.selected_party_ids)
	if draft != ownership.selected_party_ids:
		party_summary.text += "\nUnapplied draft — open Party."
	_refresh_draft()
	progress_heroine = progress_selector.present_heroines(screen.management.get_backpack_heroine_entries(), progress_heroine)
	progress_selector.disabled = not enabled
	_refresh_progression()

func _make_heroine_card(id: StringName, title: String) -> void:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(240, 530)
	button.toggle_mode = true
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.18, 0.10, 0.23, 0.7)
	selected_style.border_color = Color(0.68, 0.48, 0.80)
	selected_style.set_border_width_all(2)
	selected_style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("pressed", selected_style)
	button.add_theme_stylebox_override("hover_pressed", selected_style)
	button.tooltip_text = title + " · select or remove from draft"
	button.pressed.connect(_toggle_heroine.bind(id))
	cards.add_child(button)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = VISUALS.resolve_visual(id, &"idle", &"front").get("texture") as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	var caption := _label(box, title)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", selected_style)
	button.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -64
	badge.offset_right = -22
	badge.offset_top = 18
	badge.offset_bottom = 60
	badge.custom_minimum_size = Vector2(42, 42)
	var number := _label(badge, "")
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heroine_buttons[id] = {"button": button, "caption": caption, "name": title, "badge": badge, "number": number}

func _toggle_heroine(id: StringName) -> void:
	if not enabled:
		return
	if draft.has(id):
		draft.erase(id)
	elif draft.size() < 3 and heroine_buttons.has(id):
		draft.append(id)
	_refresh_draft()

func _refresh_draft() -> void:
	for id: StringName in heroine_buttons:
		var record: Dictionary = heroine_buttons[id]
		var index: int = draft.find(id)
		record.caption.text = String(record.name)
		record.button.set_pressed_no_signal(index >= 0)
		record.badge.visible = index >= 0
		record.number.text = str(index + 1)
		record.button.modulate = Color.WHITE if index >= 0 else Color(0.60, 0.60, 0.65)
		record.button.disabled = not enabled
	draft_summary.text = "%d / 3 selected\n%s" % [draft.size(), _names(draft)]
	apply_button.disabled = not enabled or draft.is_empty() or draft == baseline
	reset_button.disabled = not enabled or draft == baseline
	screen.begin_button.disabled = not can_explore()

func can_explore() -> bool:
	return enabled and initialized and not draft.is_empty() and draft == screen.current_run_state.refuge_ownership.selected_party_ids

func _apply_party() -> void:
	if not enabled or draft.is_empty():
		return
	var result: Dictionary = screen.management.apply_party_order(draft, baseline)
	if not String(result.get("error", "")).is_empty():
		screen.show_status(String(result.error), true)
		return
	baseline = draft.duplicate()
	screen._refresh_all()
	screen.show_status("Party preparation saved.")

func _reset_draft() -> void:
	baseline = screen.current_run_state.refuge_ownership.selected_party_ids.duplicate()
	draft = baseline.duplicate()
	refresh()

func _names(ids: Array[StringName]) -> String:
	var names: Array[String] = []
	for id: StringName in ids:
		var definition: BattlerDefinition = screen.current_battler_catalog.get_battler(id)
		names.append("%d. %s" % [names.size() + 1, definition.display_name])
	return " → ".join(names) if not names.is_empty() else "No heroine selected"

func show_section(id: StringName) -> void:
	section = id
	for key: StringName in views:
		(views[key] as Control).visible = key == id
	screen.room_shell.expedition_party_open = id == &"party"
	if screen.room_shell.active_station == &"expedition":
		screen.room_shell.title_label.text = {&"hub": "Expedition", &"party": "Party", &"intel": "Intel", &"level": "Level Up"}[id]
		screen.room_shell.close_button.text = "Close" if id == &"hub" else "Back"
	screen.room_shell._layout.call_deferred()
	screen.room_shell._trap_focus.call_deferred()
	if id == &"hub" and navigation.has(&"party"):
		(navigation[&"party"] as Button).grab_focus()

func handle_cancel() -> bool:
	if screen.room_shell.active_station != &"expedition":
		return false
	if progress_selector.get_popup().visible:
		progress_selector.get_popup().hide()
		progress_selector.grab_focus()
		return true
	if section != &"hub":
		var previous: StringName = section
		show_section(&"hub")
		(navigation[previous] as Button).grab_focus()
		return true
	return false

func _hub_visibility_changed() -> void:
	if section == &"hub" and (views[&"hub"] as Control).is_visible_in_tree():
		refresh()

func _refresh_intel() -> void:
	for child: Node in intel_list.get_children():
		intel_list.remove_child(child)
		child.queue_free()
	var options: Array[Array] = INTEL.duplicate(true)
	if intel_tabs.current_tab == 1:
		options.append(["Submit during Struggle", "Unlock Submit while retaining Struggle eligibility rules."])
	for entry: Array in options:
		var option: Label = _label(intel_list, "%s\n%s\nCost: unavailable · Not purchasable" % [entry[0], entry[1]])
		option.focus_mode = Control.FOCUS_ALL

func _refresh_progression() -> void:
	if screen.current_battler_catalog == null or progress_heroine == &"":
		return
	var definition: BattlerDefinition = screen.current_battler_catalog.get_battler(progress_heroine)
	var progression := HeroineProgressionState.new(progress_heroine, screen.current_run_state.heroine_progression_snapshot.get(progress_heroine, {}))
	progress_rows.clear()
	match progress_tabs.current_tab:
		0:
			for attribute: String in ["might", "agility", "endurance", "intellect", "personality"]:
				_row(attribute.capitalize(), str(definition.attributes.get(attribute)), "Authored base attribute.")
			_row("Max HP", str(definition.max_hp), "Authored maximum health.")
			_row("Max MP", str(definition.max_mp), "Authored maximum magic points.")
			_row("Actions", str(definition.base_actions), "Authored base Actions per round.")
		1:
			for skill: SkillEntry in definition.skills:
				_row(String(SkillEntry.Skill.keys()[skill.skill]).capitalize(), "%d · %s" % [skill.level, String(SkillEntry.Tier.keys()[skill.tier]).capitalize()], "Authored skill level and tier.")
			for family: Variant in progression.weapon_family_ranks:
				_row(String(family).capitalize() + " weapon rank", str(progression.get_weapon_family_rank(StringName(family))), "Persistent weapon-family progression.")
		2:
			for ability: AbilityDefinition in definition.abilities + definition.unlockable_abilities:
				var unlocked: bool = not ability.requires_progression_unlock or progression.has_unlocked_ability(ability.ability_id)
				_row(ability.display_name, "Unlocked" if unlocked else "Locked", ability.description)
	progress_list.clear()
	for row: Dictionary in progress_rows:
		progress_list.add_item("%s · %s" % [row.name, row.value])
	if not progress_rows.is_empty():
		progress_list.select(0)
		_select_progression(0)
	else:
		progress_detail.text = "No authored entries available."
	upgrade_button.disabled = true

func _row(title: String, value: String, detail: String) -> void:
	progress_rows.append({"name": title, "value": value, "detail": detail})

func _select_progression(index: int) -> void:
	var row: Dictionary = progress_rows[index]
	progress_detail.text = "%s\nCurrent: %s\n%s\nNo paid upgrade is available." % [row.name, row.value, row.detail]

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	parent.add_child(button)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button
