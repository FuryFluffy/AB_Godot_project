class_name RefugeRecordsView
extends VBoxContainer
## Read-only archive projection. Discovery stays owned by KnowledgeState.

const LORE = preload("res://data/lore/lore_catalog.tres")
const DIALOGUE_PANEL = preload("res://scenes/exploration/components/dialogue_panel.tscn")
var catalog: LoreCatalogDefinition = LORE
var screen: BloomRefugeScreen
var tabs: TabBar
var browser: HBoxContainer
var entry_list: ItemList
var reading_frame: PanelContainer
var reading: RichTextLabel
var preview: TextureRect
var caption: Label
var image_button: Button
var replay_button: Button
var notice: Label
var viewer: VBoxContainer
var viewer_image: TextureRect
var replay_stage: Control
var replay_background: TextureRect
var dialogue_panel: DialoguePanel
var back_button: Button
var entries: Array[LoreEntryDefinition] = []
var selected_ids: Dictionary = {}
var nested_mode: StringName = &""
var replay := ArchiveReplaySession.new()
var enabled: bool = true


func configure(owner_screen: BloomRefugeScreen) -> void:
	screen = owner_screen
	add_theme_constant_override("separation", 14)
	tabs = TabBar.new()
	for title: String in ["Lore", "Bestiary", "Run History", "Gallery"]:
		tabs.add_tab(title)
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color("352744")
	selected_style.border_color = Color("b68be0")
	selected_style.set_border_width_all(2)
	selected_style.content_margin_left = 12
	selected_style.content_margin_right = 12
	tabs.add_theme_stylebox_override("tab_selected", selected_style)
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	add_child(tabs)
	browser = HBoxContainer.new()
	browser.add_theme_constant_override("separation", 18)
	add_child(browser)
	entry_list = ItemList.new()
	entry_list.custom_minimum_size = Vector2(220, 440)
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_list.size_flags_stretch_ratio = 0.36
	entry_list.add_theme_stylebox_override("selected", selected_style)
	entry_list.add_theme_stylebox_override("selected_focus", selected_style)
	entry_list.max_columns = 1
	entry_list.fixed_icon_size = Vector2i(160, 90)
	entry_list.icon_mode = ItemList.ICON_MODE_TOP
	entry_list.item_selected.connect(_select)
	browser.add_child(entry_list)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser.add_child(detail)
	reading_frame = PanelContainer.new()
	reading_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("d7c7a4")
	paper.border_color = Color("9c8054")
	paper.set_border_width_all(2)
	paper.content_margin_left = 24
	paper.content_margin_right = 24
	paper.content_margin_top = 24
	paper.content_margin_bottom = 24
	reading_frame.add_theme_stylebox_override("panel", paper)
	detail.add_child(reading_frame)
	reading = RichTextLabel.new()
	reading.custom_minimum_size.y = 360
	reading.bbcode_enabled = false
	reading.focus_mode = Control.FOCUS_ALL
	reading.add_theme_color_override("default_color", Color("30231c"))
	reading_frame.add_child(reading)
	preview = _image(detail, 260)
	caption = Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(caption)
	var actions := HBoxContainer.new()
	detail.add_child(actions)
	image_button = _button(actions, "View Image", _open_image)
	replay_button = _button(actions, "Replay Scene", _open_replay)
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	viewer = VBoxContainer.new()
	viewer.add_theme_constant_override("separation", 12)
	add_child(viewer)
	viewer_image = _image(viewer, 540)
	replay_stage = Control.new()
	replay_stage.custom_minimum_size.y = 580
	viewer.add_child(replay_stage)
	replay_background = _image(replay_stage, 0)
	replay_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_panel = DIALOGUE_PANEL.instantiate() as DialoguePanel
	replay_stage.add_child(dialogue_panel)
	# Reflow the existing dialogue presenter into the archive's contextual panel.
	var frame: Control = dialogue_panel.get_node("Frame")
	frame.offset_left = 0
	frame.offset_right = 0
	frame.offset_top = -300
	frame.offset_bottom = 0
	for actor: TextureRect in [dialogue_panel.left_actor, dialogue_panel.right_actor]:
		actor.anchor_top = 0
		actor.anchor_bottom = 1
		actor.offset_top = 0
		actor.offset_bottom = -300
		actor.offset_left = 0
		actor.offset_right = 0
	dialogue_panel.left_actor.anchor_left = 0
	dialogue_panel.left_actor.anchor_right = 0.5
	dialogue_panel.right_actor.anchor_left = 0.5
	dialogue_panel.right_actor.anchor_right = 1
	dialogue_panel.portrait.custom_minimum_size = Vector2(100, 150)
	dialogue_panel.dialogue_text.scroll_active = true
	dialogue_panel.dialogue_text.focus_mode = Control.FOCUS_ALL
	dialogue_panel.choice_scroll.follow_focus = true
	dialogue_panel.advance_requested.connect(func() -> void:
		if enabled:
			replay.advance()
			_present_replay()
	)
	dialogue_panel.choice_requested.connect(func(id: StringName) -> void:
		if enabled:
			replay.choose(id)
			_present_replay()
	)
	back_button = _button(viewer, "Back to Gallery", _close_viewer)
	viewer.hide()
	refresh()


func refresh() -> void:
	if nested_mode != &"":
		if nested_mode == &"replay":
			_present_replay()
		return
	entries.clear()
	entry_list.clear()
	var section: int = tabs.current_tab
	if section in [0, 3] and screen.current_knowledge_state != null:
		for entry: LoreEntryDefinition in catalog.entries:
			if entry == null or not screen.current_knowledge_state.has_entry(entry.lore_id):
				continue
			if section == 3 and entry.archive_image == null and entry.archive_replay == null:
				continue
			entries.append(entry)
	for entry: LoreEntryDefinition in entries:
		entry_list.add_item(entry.title, entry.archive_image if section == 3 else null)
		entry_list.set_item_tooltip(entry_list.item_count - 1, entry.title)
	var selected: int = 0
	for index: int in range(entries.size()):
		if entries[index].lore_id == selected_ids.get(section, &""):
			selected = index
	notice.text = [
		"No discovered lore is available." if entries.is_empty() else "%d discovered record%s" % [entries.size(), "" if entries.size() == 1 else "s"],
		"Bestiary is not yet available.",
		"Run History is not yet available.",
		"No Gallery media is available for discovered records." if entries.is_empty() else "Select an entry to view its available media."
	][section]
	if not entries.is_empty():
		entry_list.select(selected)
	_select(selected)


func _selected() -> LoreEntryDefinition:
	var selected: PackedInt32Array = entry_list.get_selected_items()
	if selected.is_empty() or selected[0] >= entries.size():
		return null
	var entry: LoreEntryDefinition = entries[selected[0]]
	# Recheck discovery before media entry, including stale UI selections.
	if screen.current_knowledge_state == null or not screen.current_knowledge_state.has_entry(entry.lore_id):
		return null
	return entry


func _select(_index: int) -> void:
	var entry: LoreEntryDefinition = _selected()
	reading_frame.visible = tabs.current_tab == 0
	preview.visible = tabs.current_tab == 3 and entry != null and entry.archive_image != null
	preview.texture = entry.archive_image if entry != null else null
	caption.text = entry.title if entry != null and tabs.current_tab == 3 else ""
	image_button.visible = tabs.current_tab == 3 and entry != null and entry.archive_image != null
	replay_button.visible = tabs.current_tab == 3 and entry != null and entry.archive_replay != null
	image_button.disabled = not enabled
	var reason: String = ArchiveReplaySession.unavailable_reason(entry)
	replay_button.disabled = not enabled or not reason.is_empty()
	replay_button.tooltip_text = reason
	if entry != null:
		selected_ids[tabs.current_tab] = entry.lore_id
		reading.text = entry.title + "\n\n" + (entry.archive_text if not entry.archive_text.is_empty() else "Archive text is not available for this record.")
	else:
		reading.text = "Collected lore will appear here."
	reading.scroll_to_line(0)
	screen.room_shell._trap_focus.call_deferred()


func _open_image() -> void:
	var entry: LoreEntryDefinition = _selected()
	if not enabled or entry == null or entry.archive_image == null:
		return
	viewer_image.texture = entry.archive_image
	_open_viewer(&"image")


func _open_replay() -> void:
	var entry: LoreEntryDefinition = _selected()
	if not enabled or entry == null:
		return
	var error: String = replay.start(entry)
	if not error.is_empty():
		notice.text = error
		return
	replay_background.texture = entry.archive_replay.background_override
	_open_viewer(&"replay")
	_present_replay()


func _open_viewer(mode: StringName) -> void:
	nested_mode = mode
	browser.hide()
	tabs.hide()
	notice.hide()
	viewer.show()
	viewer_image.visible = mode == &"image"
	replay_stage.visible = mode == &"replay"
	screen.room_shell.close_button.text = "Back"
	back_button.grab_focus()
	screen.room_shell._trap_focus.call_deferred()


func _present_replay() -> void:
	if replay.runner == null:
		return
	if not replay.runner.last_error.is_empty():
		var message: String = replay.runner.last_error
		_close_viewer()
		notice.text = "Replay ended: " + message
		return
	if replay.runner.session.completed:
		_close_viewer()
		return
	dialogue_panel.present(replay.runner)
	dialogue_panel.continue_button.disabled = not enabled
	if dialogue_panel.continue_button.visible:
		dialogue_panel.continue_button.grab_focus()
	else:
		for child: Node in dialogue_panel.choice_list.get_children():
			if child is Button:
				var button := child as Button
				button.disabled = button.disabled or not enabled
				if not button.disabled:
					button.grab_focus()
					break
	screen.room_shell._trap_focus.call_deferred()


func _close_viewer() -> void:
	replay.close()
	nested_mode = &""
	viewer.hide()
	viewer_image.texture = null
	replay_background.texture = null
	dialogue_panel.hide()
	browser.show()
	tabs.show()
	notice.show()
	screen.room_shell.close_button.text = "Close"
	refresh()
	entry_list.grab_focus()


func handle_cancel() -> bool:
	if not is_visible_in_tree() or nested_mode == &"":
		return false
	_close_viewer()
	return true


func _image(parent: Node, height: float) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size.y = height
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(image)
	return image


func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button
