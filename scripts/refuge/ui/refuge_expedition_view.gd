class_name RefugeExpeditionView
extends VBoxContainer

const VISUALS = preload("res://data/presentation/battler_visual_profile_catalog.tres")
const MAP_ART = preload("res://scripts/map/map_art_library.gd")
const INTEL_CATALOG = preload("res://data/intel/intel_catalog.tres")

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
var intel_summary: Label
var intel_buttons: Dictionary = {}
var passage_purchase_selector: OptionButton
var departure_selector: OptionButton
var purchase_layer: int = 0

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
	intel_summary = _label(actions, "")
	_label(hub, "Departure")
	departure_selector = OptionButton.new()
	hub.add_child(departure_selector)
	departure_selector.item_selected.connect(func(index: int) -> void:
		var result: Dictionary = screen.management.select_passage(departure_selector.get_item_id(index))
		if not String(result.error).is_empty(): screen.show_status(String(result.error), true)
		screen._refresh_all()
	)
	_label(hub, "Unspent Bloom is discarded on departure. Unused paid Passages stay owned. Stash and banked Materials remain safe.")
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
	_label(page, "Buy now with Bloom. Closing preparation gives no refund. This Run Intel applies to the next expedition; a Passage waits until its layer is chosen.")
	_label(page, "Conqueror’s Passage purchase layer — requires its permanently defeated boss")
	passage_purchase_selector = OptionButton.new()
	page.add_child(passage_purchase_selector)
	passage_purchase_selector.item_selected.connect(func(index: int) -> void:
		purchase_layer = passage_purchase_selector.get_item_id(index)
		_refresh_intel()
	)
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
	_refresh_intel()

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
	intel_buttons.clear()
	var permanent: bool = intel_tabs.current_tab == 1
	var ownership: RefugeOwnershipState = screen.current_run_state.refuge_ownership if screen.current_run_state != null else null
	_refresh_passage_selectors(ownership)
	var summary: Array[String] = []
	if ownership != null:
		for layer: int in [1, 2]:
			if ownership.owns_passage(layer): summary.append("Passage Layer %d" % layer)
	for option: IntelOptionDefinition in INTEL_CATALOG.options:
		if ownership != null and (ownership.pending_intel.has(option.option_id) or ownership.permanent_intel.has(option.option_id)):
			summary.append(option.display_name)
		if option.permanent_only and not permanent:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",16)
		intel_list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = MAP_ART.texture("intel_assets","submit_unlock" if option.option_id == &"submit" else String(option.option_id))
		icon.custom_minimum_size = Vector2(56,56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label: Label = _label(row, option.display_name + "\n" + option.description)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if option.effect == IntelOptionDefinition.Effect.CASTLE_MEMORY and ownership != null:
			var departure_layer: int = ownership.selected_passage_layer if ownership.selected_passage_layer != 0 else 2
			if not ownership.castle_layouts.has("layer_%d" % departure_layer):
				label.text += " No saved layout for the current departure yet; it will generate a new one."
		var owned: bool = ownership != null and (ownership.permanent_intel.has(option.option_id) or (not permanent and ownership.pending_intel.has(option.option_id)))
		var passage: bool = option.effect == IntelOptionDefinition.Effect.CONQUEROR_PASSAGE
		var eligible: bool = not passage or (screen.current_run_state != null and screen.current_run_state.is_passage_eligible(purchase_layer))
		var permanent_owned: bool = ownership != null and ownership.permanent_intel.has(option.option_id)
		if passage and ownership != null:
			permanent_owned = ownership.permanent_passage_layers.has(purchase_layer)
			owned = permanent_owned or (not permanent and ownership.pending_passage_layers.has(purchase_layer))
			label.text = option.display_name + (" · Layer %d" % purchase_layer if eligible else "") + "\n" + option.description
		var price: int = option.price(permanent, purchase_layer)
		var title: String = "Owned permanently" if permanent_owned else "Bought for next run"
		if not owned:
			title = "%d Bloom" % price if eligible and option.available else "No eligible boss"
		var button: Button = _button(row,title,_purchase_intel.bind(option.option_id,permanent,price,purchase_layer if passage else 0))
		button.custom_minimum_size.x = 220
		button.disabled = not enabled or ownership == null or owned or not option.available or not eligible or screen.current_run_state.bloom < price
		intel_buttons[option.option_id] = button
	intel_summary.text = "Intel: " + (", ".join(summary) if not summary.is_empty() else "No purchases prepared.")

func _purchase_intel(id: StringName, permanent: bool, price: int, layer: int = 0) -> void:
	if not enabled or screen.management == null:
		return
	var result: Dictionary = screen.management.purchase_intel(id,permanent,price,layer)
	if not String(result.error).is_empty():
		screen.show_status(String(result.error),true)
		return
	screen._refresh_all()
	screen.show_status("Intel purchase saved." if result.get("changed",false) else "Already owned.")
	if intel_buttons.has(id):
		intel_tabs.grab_focus()


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


func _refresh_passage_selectors(ownership: RefugeOwnershipState) -> void:
	passage_purchase_selector.clear()
	departure_selector.clear()
	departure_selector.add_item("Layer 2 · Farthest Cell", 0)
	if ownership != null:
		for layer: int in [1, 2]:
			if not screen.current_run_state.is_passage_eligible(layer): continue
			passage_purchase_selector.add_item("Layer %d · defeated boss room" % layer, layer)
			if ownership.owns_passage(layer):
				departure_selector.add_item("Layer %d · Conqueror’s Passage" % layer, layer)
	if passage_purchase_selector.item_count == 0:
		purchase_layer = 0
		passage_purchase_selector.add_item("No eligible defeated boss", 0)
	elif passage_purchase_selector.get_item_index(purchase_layer) < 0:
		purchase_layer = passage_purchase_selector.get_item_id(0)
	passage_purchase_selector.select(passage_purchase_selector.get_item_index(purchase_layer))
	passage_purchase_selector.disabled = not enabled or purchase_layer == 0
	var selected: int = ownership.selected_passage_layer if ownership != null else 0
	departure_selector.select(maxi(0, departure_selector.get_item_index(selected)))
	departure_selector.disabled = not enabled or ownership == null
