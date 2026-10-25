class_name RunBackpackPanel
extends Control
## Same BackpackView and ordered-slot transaction in both run contexts. The
## existing HUD Item Bar remains the only bar; this panel never duplicates it.
signal closed
var controller: RunBackpackController
var bar: ItemBarView
var dock: RunHUDDock
var catalog: BattlerCatalogDefinition
var backpack: BackpackView
var frame: PanelContainer
var status: Label
var details: Label
var close_button: Button
var blockers: Array[Control] = []
var owner_id: StringName
var pending: Dictionary = {}
var context_request: Dictionary = {}
var context_quantity: int = 0
var menu: PopupMenu
var split: ConfirmationDialog
var amount: SpinBox
var origin: Control
var bar_inputs: Array[Callable] = []
var dragging: bool = false
var loot_column: VBoxContainer
var loot_rows: VBoxContainer
var loot_note: Label
var confirmation: ConfirmationDialog
var confirm_message: Label
var confirm_target: OptionButton
var confirm_amount: SpinBox
var confirm_request: Dictionary = {}
var confirm_kind: String = ""
var close_snapshot: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	for index: int in range(4):
		var blocker := Control.new()
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(blocker)
		blockers.append(blocker)
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", preload("res://scenes/battle/ui/reusable/styles/hud_frame_style.tres"))
	frame.theme = Theme.new()
	frame.theme.default_font_size = 22
	add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	frame.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "Backpacks"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(500, 64)
	content.add_child(status)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	content.add_child(body)
	loot_column = VBoxContainer.new()
	loot_column.custom_minimum_size.x = 300
	body.add_child(loot_column)
	var loot_title := Label.new()
	loot_title.text = "Loot"
	loot_column.add_child(loot_title)
	loot_note = Label.new()
	loot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loot_note.custom_minimum_size = Vector2(300, 90)
	loot_column.add_child(loot_note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_column.add_child(scroll)
	loot_rows = VBoxContainer.new()
	loot_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(loot_rows)
	loot_column.hide()
	backpack = preload("res://scenes/inventory/backpack_view.tscn").instantiate()
	body.add_child(backpack)
	backpack.heroine_selector.item_selected.connect(func(index: int) -> void:
		clear_pending()
		owner_id = StringName(backpack.heroine_selector.get_item_metadata(index))
		refresh()
	)
	backpack.grid.slot_selected.connect(func(entry: Dictionary) -> void:
		details.text = String(entry.get("details", ""))
		select_slot(RefugeInventoryTransfer.address(&"backpack", int(entry.slot_index), owner_id))
	)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(500, 54)
	content.add_child(details)
	menu = PopupMenu.new()
	menu.add_theme_font_size_override("font_size", 22)
	menu.add_theme_constant_override("v_separation", 12)
	add_child(menu)
	menu.id_pressed.connect(_context_action)
	split = ConfirmationDialog.new()
	split.title = "Split stack"
	split.ok_button_text = "Choose destination"
	add_child(split)
	amount = SpinBox.new()
	amount.min_value = 1
	amount.step = 1
	amount.custom_minimum_size = Vector2(260, 60)
	split.add_child(amount)
	split.confirmed.connect(func() -> void: _arm(int(amount.value)))
	split.canceled.connect(_restore_focus)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Review Loot action"
	confirmation.theme = Theme.new()
	confirmation.theme.default_font_size = 22
	add_child(confirmation)
	var options := VBoxContainer.new()
	confirmation.add_child(options)
	confirm_message = Label.new()
	confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_message.custom_minimum_size = Vector2(520, 96)
	options.add_child(confirm_message)
	confirm_target = OptionButton.new()
	options.add_child(confirm_target)
	confirm_amount = SpinBox.new()
	confirm_amount.min_value = 1
	confirm_amount.step = 1
	options.add_child(confirm_amount)
	confirmation.confirmed.connect(_confirm_loot_action)
	confirmation.canceled.connect(_restore_focus)
	get_viewport().size_changed.connect(_layout)
	hide()

func configure(service: RunBackpackController, item_bar: ItemBarView, hud_dock: RunHUDDock, battlers: BattlerCatalogDefinition) -> void:
	controller = service
	bar = item_bar
	dock = hud_dock
	catalog = battlers
	controller.changed.connect(refresh)
	for index: int in range(bar.slot_buttons.size()):
		var callback: Callable = func(event: InputEvent) -> void:
			if visible and _is_context(event):
				open_context(RefugeInventoryTransfer.address(&"item_bar", index), bar.slot_buttons[index])
				bar.slot_buttons[index].accept_event()
		bar.slot_buttons[index].gui_input.connect(callback)
		bar_inputs.append(callback)

func open_panel(preferred: StringName) -> bool:
	if controller == null or not controller.access_error().is_empty():
		return false
	owner_id = controller.actor_id() if controller.combat != null else preferred
	if not controller.heroine_ids.has(owner_id):
		owner_id = controller.heroine_ids[0]
	bar.management_mode = true
	show()
	refresh()
	close_button.grab_focus()
	return true

func close_panel() -> void:
	if controller is RunLootController and controller.has_fight_surplus():
		clear_pending()
		confirm_kind = "abandon"
		confirmation.ok_button_text = "Leave items behind"
		close_snapshot = controller.snapshot()
		confirm_message.text = "Leave these fight rewards behind?\nOnly this fight's uncollected surplus will be lost."
		confirm_target.hide()
		confirm_amount.hide()
		confirmation.popup_centered(Vector2i(560, 200))
		return
	_finish_close()

func _finish_close() -> void:
	clear_pending()
	confirmation.hide()
	if controller is RunLootController:
		(controller as RunLootController).sources = []
	bar.management_mode = false
	hide()
	for button: Button in bar.slot_buttons:
		button.set_drag_forwarding(Callable(), Callable(), Callable())
		button.focus_next = NodePath()
		button.focus_previous = NodePath()
		button.focus_neighbor_left = NodePath()
		button.focus_neighbor_right = NodePath()
		button.focus_neighbor_top = NodePath()
		button.focus_neighbor_bottom = NodePath()
	closed.emit()
	dock.backpack_button.grab_focus()

func clear_pending() -> void:
	if get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	pending = {}
	menu.hide()
	split.hide()

func cancel() -> bool:
	if not visible:
		return false
	if confirmation.visible:
		confirmation.hide()
		_restore_focus()
	elif split.visible:
		split.hide()
		_restore_focus()
	elif menu.visible:
		menu.hide()
		_restore_focus()
	elif not pending.is_empty() or get_viewport().gui_is_dragging():
		clear_pending()
		_restore_focus()
	else:
		close_panel()
	return true

func _process(_delta: float) -> void:
	if not visible or controller == null:
		return
	if not controller.access_error().is_empty():
		close_panel()
		return
	var now: bool = get_viewport().gui_is_dragging()
	if dragging and not now:
		pending = {}
	dragging = now

func refresh() -> void:
	if not visible:
		return
	var entries: Array[Dictionary] = []
	for id: StringName in controller.heroine_ids:
		var definition: BattlerDefinition = catalog.get_battler(id)
		entries.append({"heroine_id": id, "display_name": definition.display_name if definition != null else str(id)})
	owner_id = backpack.heroine_selector.present_heroines(entries, owner_id)
	backpack.present_slots(InventorySlotPresenter.run_backpack(controller.inventory, controller.equipment, owner_id))
	backpack.key_ring.clear()
	for id: Variant in controller.inventory.key_chain:
		var item: ItemDefinition = controller.inventory.catalog.get_item(StringName(id))
		backpack.key_ring.add_item("%s ×%d" % [item.display_name, int(controller.inventory.key_chain[id])], item.icon)
	if backpack.key_ring.item_count == 0:
		backpack.key_ring.add_item("No keys carried.")
	var error: String = controller.mutation_error(owner_id)
	status.text = error if not error.is_empty() else ("Each completed transfer or equipment replacement costs 1 Action." if controller.combat != null else "Drag items or open their context menu to move or split. Changes are free.")
	for index: int in range(backpack.grid.get_child_count()):
		var button := backpack.grid.get_child(index) as Button
		var address: Dictionary = RefugeInventoryTransfer.address(&"backpack", index, owner_id)
		_bind_drag(button, address)
		button.gui_input.connect(func(event: InputEvent) -> void:
			if _is_context(event):
				open_context(address, button)
				button.accept_event()
		)
	for index: int in range(bar.slot_buttons.size()):
		var slot: InventorySlotState = controller.item_bar.get_slot(index)
		bar.display_slot(index, "%d\n%s\n×%d" % [index + 1, "Empty" if slot.is_empty() else slot.item.display_name, slot.quantity], true, "Inventory destination" if slot.is_empty() else slot.item.description, false, null if slot.is_empty() else slot.item.icon)
		_bind_drag(bar.slot_buttons[index], RefugeInventoryTransfer.address(&"item_bar", index))
	_refresh_loot()
	_trap_focus()
	_layout.call_deferred()

func _layout() -> void:
	if dock == null:
		return
	var viewport: Vector2 = get_viewport_rect().size
	var bar_rect: Rect2 = bar.get_global_rect()
	# Four input shields leave precisely the existing Item Bar available.
	var regions: Array[Rect2] = [Rect2(0, 0, viewport.x, bar_rect.position.y), Rect2(0, bar_rect.end.y, viewport.x, viewport.y - bar_rect.end.y), Rect2(0, bar_rect.position.y, bar_rect.position.x, bar_rect.size.y), Rect2(bar_rect.end.x, bar_rect.position.y, viewport.x - bar_rect.end.x, bar_rect.size.y)]
	for index: int in range(blockers.size()):
		blockers[index].position = regions[index].position
		blockers[index].size = regions[index].size
	frame.custom_minimum_size.x = 560
	frame.reset_size()
	var available: float = viewport.y - (RunHUDDock.HEIGHT + 54) * dock.layout_scale
	var factor: float = minf(1.0, minf(available / frame.size.y, (viewport.x - 32) / frame.size.x))
	frame.scale = Vector2.ONE * factor
	frame.position = Vector2((viewport.x - frame.size.x * factor) * 0.5, 12)

func _is_context(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_MENU) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y)

func open_context(location: Dictionary, focus: Control) -> void:
	clear_pending()
	origin = focus
	var item: Dictionary = controller.payload(location)
	if item.is_empty() or BackpackPayload.is_empty(item):
		return
	context_request = controller.request(location)
	context_quantity = int(item.quantity)
	menu.clear()
	var error: String = controller.mutation_error(owner_id)
	var cost: String = " — 1 Action" if controller.combat != null else ""
	menu.add_item("Move / exchange" + cost, 1)
	menu.set_item_disabled(0, not error.is_empty())
	if context_quantity > 1:
		menu.add_item("Split…" + cost, 2)
		menu.set_item_disabled(menu.item_count - 1, not error.is_empty())
	if controller is RunLootController and not controller.sources.is_empty() and String(location.get("domain", "")) != "loot":
		menu.add_item("Use…", 3)
		menu.add_item("Discard…", 4)
	if controller.combat != null and item.has("equipment_instance_id"):
		for slot: EquipmentDefinition.Slot in [EquipmentDefinition.Slot.MAIN_HAND, EquipmentDefinition.Slot.ARMOR]:
			var result: Dictionary = controller.equip(context_request, slot, true)
			if String(result.error).is_empty():
				menu.add_item("Replace " + EquipmentDefinition.get_slot_label(slot) + cost, 10 + int(slot))
	menu.position = Vector2i(focus.get_global_rect().get_center())
	menu.popup()

func _context_action(id: int) -> void:
	if id == 1:
		_arm(context_quantity)
	elif id == 2:
		amount.max_value = context_quantity
		amount.value = maxi(1, context_quantity / 2)
		split.popup_centered(Vector2i(400, 160))
		amount.get_line_edit().grab_focus()
	elif id in [3, 4]:
		confirm_kind = "use" if id == 3 else "discard"
		confirm_request = context_request.duplicate(true)
		var carried: Dictionary = controller.payload(context_request.source)
		var item: ItemDefinition = controller.inventory.catalog.get_item(StringName(carried.get("item_id", "")))
		var name_text: String = item.display_name if item != null else "carried equipment"
		confirmation.ok_button_text = "Use item" if id == 3 else "Discard"
		confirm_message.text = ("Use one %s on:" if id == 3 else "Permanently discard %s? Choose quantity:") % name_text
		confirm_target.clear()
		for owner: StringName in controller.heroine_ids:
			var definition: BattlerDefinition = catalog.get_battler(owner)
			confirm_target.add_item(definition.display_name if definition != null else String(owner))
			confirm_target.set_item_metadata(confirm_target.item_count - 1, owner)
			if owner == owner_id:
				confirm_target.select(confirm_target.item_count - 1)
		confirm_target.visible = id == 3
		confirm_amount.visible = id == 4
		confirm_amount.max_value = context_quantity
		confirm_amount.value = context_quantity
		confirmation.popup_centered(Vector2i(560, 220))
	elif id >= 10:
		_finished(controller.equip(context_request, id - 10 as EquipmentDefinition.Slot))

func _arm(quantity: int) -> void:
	pending = {"request": context_request.duplicate(true), "quantity": quantity, "panel": self}
	status.text = "Choose a destination; Escape cancels." + (" A successful change costs 1 Action." if controller.combat != null else "")
	_restore_focus()

func select_slot(location: Dictionary) -> void:
	if not pending.is_empty() and location != pending.request.source:
		_drop(location, pending)

func _bind_drag(button: Button, location: Dictionary) -> void:
	button.set_drag_forwarding(func(_at: Vector2) -> Variant:
		if not visible or not controller.mutation_error(owner_id).is_empty():
			return null
		var item: Dictionary = controller.payload(location)
		if item.is_empty() or BackpackPayload.is_empty(item):
			return null
		origin = button
		var data: Dictionary = pending.duplicate(true) if not pending.is_empty() and pending.request.source == location else {"request": controller.request(location), "quantity": int(item.quantity), "panel": self}
		var label := Label.new()
		label.text = "Move ×%d%s" % [data.quantity, " · 1 Action" if controller.combat != null else ""]
		button.set_drag_preview(label)
		return data,
		func(_at: Vector2, data: Variant) -> bool:
			return _can_drop(location, data),
		func(_at: Vector2, data: Variant) -> void: _drop(location, data))

func _can_drop(location: Dictionary, data: Variant) -> bool:
	if not visible or not (data is Dictionary) or data.get("panel") != self or not controller.mutation_error(owner_id).is_empty():
		return false
	return String(controller.transfer(data.request, location, int(data.quantity), true).error).is_empty()

func _drop(location: Dictionary, data: Variant) -> void:
	if not visible or not (data is Dictionary) or data.get("panel") != self or not controller.mutation_error(owner_id).is_empty():
		return
	_finished(controller.transfer(data.request, location, int(data.quantity)))

func _finished(result: Dictionary) -> void:
	pending = {}
	refresh()
	status.text = String(result.error) if not String(result.error).is_empty() else ("Accepted %d; %d remain at source. Free bag space or select another heroine." % [int(result.get("moved", 0)), int(result.get("remaining", 0))])
	_restore_focus()

func _restore_focus() -> void:
	if is_instance_valid(origin) and origin.is_visible_in_tree():
		origin.grab_focus()
	else:
		close_button.grab_focus()

func _trap_focus() -> void:
	var controls: Array[Control] = [close_button, backpack.heroine_selector]
	for child: Node in backpack.grid.get_children():
		controls.append(child as Control)
	controls.append(backpack.key_ring)
	if loot_column.visible:
		for child: Node in loot_rows.get_children():
			controls.append(child as Control)
	controls.append_array(bar.slot_buttons)
	for index: int in range(controls.size()):
		var next: NodePath = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		var previous: NodePath = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
		controls[index].focus_next = next
		controls[index].focus_previous = previous
		controls[index].focus_neighbor_right = next
		controls[index].focus_neighbor_bottom = next
		controls[index].focus_neighbor_left = previous
		controls[index].focus_neighbor_top = previous

func is_slot_context_event(event: InputEvent) -> bool:
	if not visible or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_RIGHT:
		return false
	for button: Control in bar.slot_buttons + backpack.grid.get_children() + loot_rows.get_children():
		if button.get_global_rect().has_point(event.position):
			return true
	return false

func _refresh_loot() -> void:
	var service := controller as RunLootController
	loot_column.visible = service != null and not service.sources.is_empty()
	for child: Node in loot_rows.get_children():
		loot_rows.remove_child(child)
		child.queue_free()
	if not loot_column.visible:
		return
	loot_note.text = "Choose a heroine, then collect. Drag to an empty bag slot or matching stack."
	loot_note.text += "\nClosing asks before leaving fight surplus." if service.has_fight_sources() else "\nRoom contents remain here when closed."
	for index: int in range(service.sources.size()):
		var record: Dictionary = service.sources[index]
		var item: ItemDefinition = service.inventory.catalog.get_item(StringName(record.get("item_id", "")))
		var button := Button.new()
		button.custom_minimum_size = Vector2(300, 76)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var name_text: String = item.display_name if item != null else "Equipment"
		if record.has("equipment_snapshot") and service.equipment != null:
			var definition: EquipmentDefinition = service.equipment.definitions_by_id.get(StringName(record.equipment_snapshot.definition_id))
			if definition != null:
				name_text = "%s · condition %d/%d" % [definition.display_name, int(record.equipment_snapshot.current_condition), definition.condition_maximum]
		var destination: String = "selected Backpack"
		if item != null and item.content_category == ItemDefinition.ContentCategory.KEY:
			destination = "shared Key-ring"
		elif item != null and item.content_category == ItemDefinition.ContentCategory.MATERIAL:
			destination = "run Materials"
		button.text = "%s ×%d\nCollect → %s" % [name_text, LootClaim.remaining(record), destination]
		button.icon = item.icon if item != null else null
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 44)
		button.disabled = LootClaim.remaining(record) == 0
		loot_rows.add_child(button)
		var address: Dictionary = RefugeInventoryTransfer.address(&"loot", index)
		_bind_drag(button, address)
		button.pressed.connect(func() -> void:
			_finished(service.collect(service.request(address), RefugeInventoryTransfer.address(&"backpack", -1, owner_id), LootClaim.remaining(record)))
		)
		button.gui_input.connect(func(event: InputEvent) -> void:
			if _is_context(event):
				open_context(address, button)
				button.accept_event()
		)

func _confirm_loot_action() -> void:
	var service := controller as RunLootController
	if service == null:
		return
	if confirm_kind == "abandon":
		var result: Dictionary = service.abandon_fight_surplus(close_snapshot)
		if String(result.error).is_empty():
			_finish_close()
		else:
			status.text = result.error
	else:
		var target: StringName = StringName(confirm_target.get_item_metadata(confirm_target.selected))
		_finished(service.manage_carried(confirm_request, 1 if confirm_kind == "use" else int(confirm_amount.value), target, confirm_kind == "use"))
