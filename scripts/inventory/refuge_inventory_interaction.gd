class_name RefugeInventoryInteraction
extends Node
## Mouse drag and controller source/destination selection share one transaction.
## Enabled only by the Refuge screen; run/combat permissions remain Stage 11.

var screen: BloomRefugeScreen
var pending: Dictionary = {}
var context_request: Dictionary = {}
var context_quantity: int = 0
var menu := PopupMenu.new()
var heroines := PopupMenu.new()
var split := ConfirmationDialog.new()
var amount := SpinBox.new()
var was_dragging: bool = false
var enabled: bool = true
var origin_focus: Control

func configure(owner_screen: BloomRefugeScreen) -> void:
	screen = owner_screen
	add_child(menu)
	menu.add_theme_font_size_override("font_size", 22)
	menu.add_theme_constant_override("v_separation", 12)
	heroines.add_theme_font_size_override("font_size", 22)
	heroines.add_theme_constant_override("v_separation", 12)
	heroines.name = "BackpackOwners"
	menu.add_child(heroines)
	add_child(split)
	split.theme = Theme.new()
	split.theme.default_font_size = 24
	split.theme.set_font_size("title_font_size", "Window", 24)
	split.title = "Split stack"
	split.ok_button_text = "Choose destination"
	amount.add_theme_font_size_override("font_size", 24)
	amount.min_value = 1
	amount.step = 1
	amount.custom_minimum_size = Vector2(230, 48)
	split.add_child(amount)
	split.confirmed.connect(_split_confirmed)
	split.canceled.connect(_restore_focus)
	menu.id_pressed.connect(_context_action)
	heroines.id_pressed.connect(_named_transfer)
	screen.preparation_grid.slot_selected.connect(func(entry: Dictionary) -> void:
		_select(RefugeInventoryTransfer.address(&"backpack", int(entry.slot_index), screen.backpack_heroine_id))
	)
	screen.item_bar_grid.slot_requested.connect(func(index: int) -> void:
		_select(RefugeInventoryTransfer.address(&"item_bar", index))
	)
	for list: ItemList in [screen.stash_items, screen.stash_equipment_list]:
		list.allow_rmb_select = true
		list.item_clicked.connect(func(index: int, _at: Vector2, button: int) -> void:
			if button == MOUSE_BUTTON_RIGHT:
				_stash_context(list, index)
		)
		list.item_activated.connect(func(index: int) -> void: _stash_context(list, index))
		list.gui_input.connect(func(event: InputEvent) -> void:
			if _context_event(event) and not list.get_selected_items().is_empty():
				_stash_context(list, list.get_selected_items()[0])
				list.accept_event()
		)
	screen.room_shell.inventory_panel.backpacks_visibility_changed.connect(func(_backpacks: bool) -> void: cancel())
	set_process(true)

func _process(_delta: float) -> void:
	var dragging: bool = screen.get_viewport().gui_is_dragging()
	if was_dragging and not dragging:
		pending = {}
	was_dragging = dragging
	if not enabled or screen.room_shell.active_station != &"stash" or not screen.room_shell.modal.visible:
		cancel()

func bind_slots() -> void:
	for index: int in range(screen.preparation_grid.get_child_count()):
		_bind_button(screen.preparation_grid.get_child(index) as Button, RefugeInventoryTransfer.address(&"backpack", index, screen.backpack_heroine_id))
	for index: int in range(screen.item_bar_grid.slot_buttons.size()):
		var button: Button = screen.item_bar_grid.slot_buttons[index]
		button.disabled = false # Empty slots are valid controller/drop destinations.
		_bind_button(button, RefugeInventoryTransfer.address(&"item_bar", index))

func _bind_button(button: Button, location: Dictionary) -> void:
	button.set_drag_forwarding(
		func(_at: Vector2) -> Variant: return _drag(button, location),
		func(_at: Vector2, data: Variant) -> bool: return _can_drop(location, data),
		func(_at: Vector2, data: Variant) -> void: _drop(location, data)
	)
	# Bar buttons persist across refreshes; bind their context input only once.
	if not button.has_meta("inventory_context_bound"):
		button.set_meta("inventory_context_bound", true)
		button.gui_input.connect(func(event: InputEvent) -> void:
			if _context_event(event):
				open_context(location, button)
				button.accept_event()
		)

func _context_event(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_MENU) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y)

func _stash_context(list: ItemList, index: int) -> void:
	if list.is_item_disabled(index):
		return
	var entry: Dictionary = list.get_item_metadata(index)
	var location: Dictionary = RefugeInventoryTransfer.address(&"stash", int(entry.get("stack_index", index)))
	if list == screen.stash_equipment_list:
		location = RefugeInventoryTransfer.address(&"stash_equipment", -1, &"", StringName(entry.instance_id))
	open_context(location, list)

func open_context(location: Dictionary, focus: Control) -> void:
	cancel()
	if not enabled:
		return
	origin_focus = focus
	var item: Dictionary = RefugeInventoryTransfer.payload(screen.current_run_state.refuge_ownership, location)
	if item.is_empty() or BackpackPayload.is_empty(item):
		return
	context_request = screen.management.inventory_request(location)
	context_quantity = int(item.quantity)
	menu.clear()
	heroines.clear()
	if String(location.domain) in ["stash", "stash_equipment"]:
		for entry: Dictionary in screen.management.get_backpack_heroine_entries():
			heroines.add_item(String(entry.display_name))
			heroines.set_item_metadata(heroines.item_count - 1, entry.heroine_id)
		menu.add_submenu_item("Move to Backpack", "BackpackOwners")
	else:
		menu.add_item("Move to Stash", 1)
		menu.add_item("Move / exchange — choose slot", 2)
	if context_quantity > 1 and String(location.domain) in ["backpack", "item_bar"]:
		menu.add_item("Split…", 3)
	menu.position = Vector2i(focus.get_global_rect().get_center())
	menu.popup()

func _context_action(id: int) -> void:
	match id:
		1: _commit(context_request, RefugeInventoryTransfer.address(&"stash"), context_quantity, true)
		2: _arm(context_request, context_quantity)
		3:
			amount.max_value = context_quantity
			amount.value = maxi(1, context_quantity / 2)
			split.popup_centered(Vector2i(420, 180))
			amount.get_line_edit().grab_focus()

func _split_confirmed() -> void:
	_arm(context_request, int(amount.value))

func _arm(request: Dictionary, quantity: int) -> void:
	pending = {"request": request.duplicate(true), "quantity": quantity, "interaction": self}
	screen.show_status("Moving %d. Choose a slot or drag the source; Escape cancels." % quantity)
	_restore_focus()

func _named_transfer(index: int) -> void:
	if index < 0 or index >= heroines.item_count:
		return
	_commit(context_request, RefugeInventoryTransfer.address(&"backpack", -1, StringName(heroines.get_item_metadata(index))), context_quantity, true)

func _select(location: Dictionary) -> void:
	if pending.is_empty():
		return
	# Clicking the armed source keeps it available for drag; Escape cancels.
	if pending.request.source == location:
		return
	_drop(location, pending.duplicate(true))

func _drag(button: Button, location: Dictionary) -> Variant:
	if not enabled:
		return null
	var item: Dictionary = RefugeInventoryTransfer.payload(screen.current_run_state.refuge_ownership, location)
	if item.is_empty() or BackpackPayload.is_empty(item):
		return null
	var data: Dictionary = pending.duplicate(true) if not pending.is_empty() and pending.request.source == location else {"request": screen.management.inventory_request(location), "quantity": int(item.quantity), "interaction": self}
	var preview := Label.new()
	preview.text = "Move ×%d" % int(data.quantity)
	button.set_drag_preview(preview)
	return data

func _can_drop(location: Dictionary, data: Variant) -> bool:
	if not enabled or not (data is Dictionary) or data.get("interaction") != self:
		return false
	if data.request.get("snapshot", {}) != screen.current_run_state.refuge_ownership.to_snapshot():
		return false
	var staged := RefugeOwnershipState.new()
	var error: String = staged.restore_from_snapshot(data.request.snapshot, screen.management.ITEM_CATALOG, screen.current_battler_catalog, screen.current_run_state.refuge_ownership.known_heroine_ids)
	if not error.is_empty():
		return false
	return String(RefugeInventoryTransfer.apply(staged, data.request.source, location, int(data.quantity)).error).is_empty()

func _drop(location: Dictionary, data: Variant) -> void:
	if not enabled or not (data is Dictionary) or data.get("interaction") != self:
		return
	_commit(data.request, location, int(data.quantity), false)

func quick(source: Dictionary, target: Dictionary) -> void:
	var item: Dictionary = RefugeInventoryTransfer.payload(screen.current_run_state.refuge_ownership, source)
	_commit(screen.management.inventory_request(source), target, int(item.get("quantity", 0)), true)

func _commit(request: Dictionary, target: Dictionary, quantity: int, quick_move: bool) -> void:
	if not enabled:
		return
	var result: Dictionary = screen.management.transfer_inventory(request, target, quantity, quick_move)
	pending = {}
	if not String(result.get("error", "")).is_empty():
		screen.show_status(String(result.error), true)
	else:
		screen.show_status("Moved %d; %d remain at source." % [int(result.get("moved", 0)), int(result.get("remaining", 0))])
	_restore_focus()
	screen.room_shell._trap_focus.call_deferred()

func cancel() -> bool:
	if screen.get_viewport().gui_is_dragging():
		screen.get_viewport().gui_cancel_drag()
		pending = {}
		_restore_focus()
		return true
	var handled: bool = split.visible or menu.visible or heroines.visible or not pending.is_empty()
	if split.visible:
		split.hide()
	elif menu.visible or heroines.visible:
		heroines.hide()
		menu.hide()
	else:
		pending = {}
	if handled:
		_restore_focus()
	return handled

func _restore_focus() -> void:
	if is_instance_valid(origin_focus) and origin_focus.is_visible_in_tree():
		origin_focus.grab_focus()
	elif screen.preparation_grid.is_visible_in_tree() and screen.preparation_grid.get_child_count() > 0:
		(screen.preparation_grid.get_child(0) as Control).grab_focus()
