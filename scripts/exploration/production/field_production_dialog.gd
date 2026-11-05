class_name FieldProductionDialog
extends AcceptDialog
var view := RefugeProductionView.new()
var recipient := OptionButton.new()
var status_label := Label.new()
var owner_room: EventRoomScreen
var heroine_ids: Array[StringName] = []

func configure(room: EventRoomScreen) -> void:
	owner_room = room
	theme = Theme.new()
	theme.default_font_size = 22
	title = "Field Alchemy" if room.definition.field_station.station == RefugeRecipeDefinition.Station.ALCHEMY else "Field Workshop"
	exclusive = true
	transient = true
	get_ok_button().text = "Close"
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(recipient)
	for id: StringName in room.current_party_ids:
		heroine_ids.append(id)
		recipient.add_item("Output: %s's Backpack" % room.party_states[id].definition.display_name)
	recipient.select(maxi(heroine_ids.find(room.selected_heroine_id),0))
	content.add_child(view)
	content.add_child(status_label)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view.ownership_hint = "Current-run Materials → selected Backpack"
	view.success_destination = "Backpack"
	view.configure_context(room.definition.field_station.station,
		func() -> Dictionary: return room.run_inventory.get_snapshot(),
		func(kind: RefugeRecipeDefinition.Station) -> Array[Dictionary]: return room.field_entries.call(kind,heroine_ids[recipient.selected]),
		func(kind: RefugeRecipeDefinition.Station, id: StringName, expected: Dictionary) -> Dictionary: return room.field_commit.call(kind,id,heroine_ids[recipient.selected],expected),
		func(message: String, _error: bool) -> void: status_label.text = message)
	recipient.item_selected.connect(func(_index: int) -> void: view.refresh())
	close_requested.connect(hide)

func open_station() -> void:
	status_label.text = ""
	view.refresh()
	min_size = Vector2i(1100,820).min(Vector2i(owner_room.get_viewport().get_visible_rect().size)-Vector2i(64,80))
	popup_centered(min_size)
	view.recipes.grab_focus()
