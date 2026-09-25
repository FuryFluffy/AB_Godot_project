class_name BloomRefugeScreen
extends Control


signal begin_layer_2_run_requested(run_seed: int)
signal start_new_story_requested(run_seed: int)


@onready var bloom_label: Label = %BloomValue
@onready var knowledge_label: Label = %KnowledgeValue
@onready var header_party_label: Label = %HeaderPartyOrder
@onready var party_label: Label = %PartySummary
@onready var seed_edit: LineEdit = %RunSeed
@onready var begin_button: Button = %BeginLayer2Run
@onready var new_story_button: Button = %StartNewStory
@onready var status_label: Label = %Status
@onready var party_list: ItemList = %PartyList
@onready var party_details: Label = %PartyDetails
@onready var heroine_equipment_list: ItemList = %HeroineEquipmentList
@onready var equipment_slot: OptionButton = %EquipmentSlot
@onready var inventory_heroine: OptionButton = %InventoryHeroine
@onready var preparation_grid: RefugeSlotGrid = %PreparationGrid
@onready var item_bar_grid: RefugeSlotGrid = %ItemBarGrid
@onready var stash_items: ItemList = %StashItems
@onready var stash_equipment_list: ItemList = %StashEquipmentList
@onready var material_list: ItemList = %MaterialList
@onready var recipe_list: ItemList = %RecipeList
@onready var recipe_details: Label = %RecipeDetails
@onready var repair_target: OptionButton = %RepairTarget
@onready var salvage_list: ItemList = %SalvageList
@onready var salvage_confirmation: ConfirmationDialog = %SalvageConfirmation
@onready var key_list: ItemList = %KeyList


var management: RefugeManagementController
var current_run_state: RunState
var current_battler_catalog: BattlerCatalogDefinition
var current_knowledge_state: KnowledgeState
var selected_heroine_id: StringName = &""
var selected_preparation_entry: Dictionary = {}
var selected_item_bar_entry: Dictionary = {}
var selected_stash_entry: Dictionary = {}
var pending_salvage_instance_id: StringName = &""
var repair_target_entries: Array[Dictionary] = []
var selected_recipe_id: StringName = &""
var selected_repair_target_instance_id: StringName = &""


func _ready() -> void:
	begin_button.pressed.connect(_on_begin_pressed)
	new_story_button.pressed.connect(_on_start_new_story_pressed)
	party_list.item_selected.connect(_on_party_selected)
	%MovePartyUp.pressed.connect(_on_move_party.bind(-1))
	%MovePartyDown.pressed.connect(_on_move_party.bind(1))
	%EquipSelected.pressed.connect(_on_equip_selected)
	%UnequipSlot.pressed.connect(_on_unequip_selected_slot)
	%MoveEquipmentToStash.pressed.connect(_on_move_equipment_to_stash)
	inventory_heroine.item_selected.connect(_on_inventory_heroine_selected)
	preparation_grid.slot_selected.connect(_on_preparation_slot_selected)
	item_bar_grid.slot_selected.connect(_on_item_bar_slot_selected)
	stash_items.item_selected.connect(_on_stash_item_selected)
	%PrepToBar.pressed.connect(
		_on_transfer_selected.bind(&"preparation", &"item_bar")
	)
	%BarToPrep.pressed.connect(
		_on_transfer_selected.bind(&"item_bar", &"preparation")
	)
	%PrepToStash.pressed.connect(
		_on_transfer_selected.bind(&"preparation", &"stash")
	)
	%StashToPrep.pressed.connect(
		_on_transfer_selected.bind(&"stash", &"preparation")
	)
	%BarToStash.pressed.connect(
		_on_transfer_selected.bind(&"item_bar", &"stash")
	)
	%StashToBar.pressed.connect(
		_on_transfer_selected.bind(&"stash", &"item_bar")
	)
	%MoveStashEquipmentToHeroine.pressed.connect(
		_on_move_stash_equipment_to_heroine
	)
	recipe_list.item_selected.connect(_on_recipe_selected)
	repair_target.item_selected.connect(_on_repair_target_selected)
	%RepairSelected.pressed.connect(_on_repair_selected)
	%SalvageSelected.pressed.connect(_on_review_salvage)
	salvage_confirmation.confirmed.connect(_on_salvage_confirmed)


func present(
	run_state: RunState,
	battler_catalog: BattlerCatalogDefinition,
	knowledge_state: KnowledgeState,
	_slot_save_available: bool,
	management_controller: RefugeManagementController = null
) -> String:
	if run_state == null or battler_catalog == null or knowledge_state == null:
		return "Bloom Refuge screen received incomplete campaign state."
	if not run_state.has_established_refuge():
		return "Bloom Refuge screen cannot open before the Refuge is established."
	current_run_state = run_state
	current_battler_catalog = battler_catalog
	current_knowledge_state = knowledge_state
	management = management_controller
	if management == null:
		management = RefugeManagementController.new()
		var bind_error: String = management.bind(run_state, battler_catalog)
		if not bind_error.is_empty():
			return bind_error
	if not management.state_changed.is_connected(_refresh_all):
		management.state_changed.connect(_refresh_all)
	seed_edit.text = str(run_state.run_seed)
	_initialize_equipment_slots()
	_refresh_all()
	show_status(
		"The farthest cell is warm. The door now locks from the inside."
	)
	return ""


func show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.modulate = (
		Color(1.0, 0.55, 0.55) if is_error else Color(0.88, 0.82, 0.68)
	)


func set_actions_enabled(enabled: bool) -> void:
	begin_button.disabled = not enabled
	new_story_button.disabled = not enabled
	seed_edit.editable = enabled
	for button: Button in [
		%MovePartyUp,
		%MovePartyDown,
		%EquipSelected,
		%UnequipSlot,
		%MoveEquipmentToStash,
		%PrepToBar,
		%BarToPrep,
		%PrepToStash,
		%StashToPrep,
		%BarToStash,
		%StashToBar,
		%MoveStashEquipmentToHeroine,
		%RepairSelected,
		%SalvageSelected,
	]:
		button.disabled = not enabled


func _refresh_all() -> void:
	if management == null:
		return
	bloom_label.text = "%d Bloom" % current_run_state.bloom
	knowledge_label.text = "%d entries discovered" % (
		current_knowledge_state.discovered_entries.size()
	)
	_refresh_party()
	_refresh_inventory()
	_refresh_materials_and_services()
	_refresh_key_chain()
	party_label.text = _make_party_summary()


func _refresh_party() -> void:
	var previous_heroine: StringName = selected_heroine_id
	party_list.clear()
	inventory_heroine.clear()
	var entries: Array[Dictionary] = management.get_party_entries()
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var heroine_id := StringName(entry.get("heroine_id", ""))
		party_list.add_item("%d. %s" % [
			index + 1,
			String(entry.get("display_name", heroine_id)),
		])
		party_list.set_item_metadata(index, entry)
		inventory_heroine.add_item(String(entry.get("display_name", heroine_id)))
		inventory_heroine.set_item_metadata(index, heroine_id)
	var party_names: Array[String] = []
	for entry: Dictionary in entries:
		party_names.append(String(entry.get("display_name", "Unknown")))
	header_party_label.text = "Party: %s" % " → ".join(party_names)
	if entries.is_empty():
		selected_heroine_id = &""
		party_details.text = "No recruited heroine is available."
		return
	var selected_index: int = 0
	for index: int in range(entries.size()):
		if StringName(entries[index].get("heroine_id", "")) == previous_heroine:
			selected_index = index
			break
	party_list.select(selected_index)
	inventory_heroine.select(selected_index)
	selected_heroine_id = StringName(entries[selected_index].get("heroine_id", ""))
	_show_party_entry(entries[selected_index])


func _show_party_entry(entry: Dictionary) -> void:
	var memento_value: Variant = entry.get("memento_id", null)
	var memento_text: String = (
		"Empty"
		if memento_value == null
		else _item_display_name(StringName(memento_value))
	)
	party_details.text = (
		"%s  •  Recruited / Active\nHP %d/%d   MP %d/%d   Resolve %d   Corruption %d\nMemento: %s"
		% [
			String(entry.get("display_name", selected_heroine_id)),
			int(entry.get("hp", 0)),
			int(entry.get("max_hp", 0)),
			int(entry.get("mp", 0)),
			int(entry.get("max_mp", 0)),
			int(entry.get("resolve", 0)),
			int(entry.get("corruption", 0)),
			memento_text,
		]
	)
	_refresh_heroine_equipment()


func _refresh_heroine_equipment() -> void:
	heroine_equipment_list.clear()
	for entry: Dictionary in management.get_equipment_entries_for_heroine(
		selected_heroine_id
	):
		var equipped_slot := StringName(entry.get("equipped_slot", ""))
		var location_text: String = (
			"Equipped: %s" % _slot_key_label(equipped_slot)
			if equipped_slot != &""
			else "Unequipped personal gear"
		)
		var condition: int = int(entry.get("condition", 0))
		var maximum: int = int(entry.get("condition_maximum", 0))
		var broken_text: String = " • BROKEN" if bool(entry.get("broken", false)) else ""
		var salvage_text: String = (
			" • Salvage %d"
			% int(entry.get("salvage_yield", 0))
			if bool(entry.get("salvageable", false))
			else " • Not salvageable"
		)
		heroine_equipment_list.add_item(
			"%s — %s — Condition %d/%d%s%s" % [
				String(entry.get("display_name", "Unknown equipment")),
				location_text,
				condition,
				maximum,
				broken_text,
				salvage_text,
			]
		)
		var index: int = heroine_equipment_list.item_count - 1
		heroine_equipment_list.set_item_metadata(index, entry)
	if heroine_equipment_list.item_count == 0:
		heroine_equipment_list.add_item("No authored player equipment is owned.")
		heroine_equipment_list.set_item_disabled(0, true)


func _refresh_inventory() -> void:
	selected_preparation_entry = {}
	selected_item_bar_entry = {}
	selected_stash_entry = {}
	preparation_grid.present(
		management.get_preparation_entries(selected_heroine_id),
		3
	)
	item_bar_grid.present(management.get_item_bar_entries(), 2)
	stash_items.clear()
	for entry: Dictionary in management.get_stash_item_entries():
		stash_items.add_item("%s ×%d" % [
			String(entry.get("display_name", "Unknown item")),
			int(entry.get("quantity", 0)),
		])
		var index: int = stash_items.item_count - 1
		stash_items.set_item_icon(index, entry.get("icon", null) as Texture2D)
		stash_items.set_item_metadata(index, entry)
	if stash_items.item_count == 0:
		stash_items.add_item("Stash has no item stacks.")
		stash_items.set_item_disabled(0, true)
	stash_equipment_list.clear()
	for entry: Dictionary in management.get_stash_equipment_entries():
		stash_equipment_list.add_item(
			"%s — Condition %d/%d%s" % [
				String(entry.get("display_name", "Unknown equipment")),
				int(entry.get("condition", 0)),
				int(entry.get("condition_maximum", 0)),
				" — BROKEN" if bool(entry.get("broken", false)) else "",
			]
		)
		var index: int = stash_equipment_list.item_count - 1
		stash_equipment_list.set_item_metadata(index, entry)
	if stash_equipment_list.item_count == 0:
		stash_equipment_list.add_item("Stash has no authored player equipment.")
		stash_equipment_list.set_item_disabled(0, true)


func _refresh_materials_and_services() -> void:
	var previous_recipe_id: StringName = selected_recipe_id
	material_list.clear()
	for entry: Dictionary in management.get_material_entries():
		material_list.add_item("%s ×%d" % [
			String(entry.get("display_name", "Unknown Material")),
			int(entry.get("quantity", 0)),
		])
		var index: int = material_list.item_count - 1
		material_list.set_item_icon(index, entry.get("icon", null) as Texture2D)
	recipe_list.clear()
	for entry: Dictionary in management.get_recipe_entries():
		recipe_list.add_item(
			String(entry.get("display_name", "Unknown service"))
		)
		var index: int = recipe_list.item_count - 1
		recipe_list.set_item_metadata(index, entry)
	if recipe_list.item_count > 0:
		var recipe_index: int = 0
		for index: int in range(recipe_list.item_count):
			var recipe_value: Variant = recipe_list.get_item_metadata(index)
			if (
				recipe_value is Dictionary
				and StringName((recipe_value as Dictionary).get("recipe_id", ""))
				== previous_recipe_id
			):
				recipe_index = index
				break
		recipe_list.select(recipe_index)
		_show_recipe(recipe_list.get_item_metadata(recipe_index) as Dictionary)
	else:
		selected_recipe_id = &""
		selected_repair_target_instance_id = &""
		recipe_details.text = "No authored Refuge service is registered."
		repair_target.clear()
		%RepairSelected.disabled = true
	salvage_list.clear()
	for entry: Dictionary in management.get_salvage_entries():
		salvage_list.add_item(
			"%s — Condition %d/%d → %d × %s" % [
				String(entry.get("display_name", "Unknown equipment")),
				int(entry.get("condition", 0)),
				int(entry.get("condition_maximum", 0)),
				int(entry.get("salvage_yield", 0)),
				String(entry.get("salvage_material_id", "Material")),
			]
		)
		var index: int = salvage_list.item_count - 1
		salvage_list.set_item_metadata(index, entry)
	if salvage_list.item_count == 0:
		salvage_list.add_item("No authored player equipment can currently be salvaged.")
		salvage_list.set_item_disabled(0, true)
		%SalvageSelected.disabled = true
	else:
		%SalvageSelected.disabled = false


func _show_recipe(entry: Dictionary) -> void:
	var recipe_id := StringName(entry.get("recipe_id", ""))
	selected_recipe_id = recipe_id
	var previous_target_id: StringName = selected_repair_target_instance_id
	var disabled_reason: String = String(entry.get("disabled_reason", ""))
	recipe_details.text = "%s\nInputs: %s\nEffect: %s%s" % [
		String(entry.get("display_name", recipe_id)),
		String(entry.get("inputs_text", "None")),
		String(entry.get("effect_text", "No effect")),
		"" if disabled_reason.is_empty() else "\nUnavailable: %s" % disabled_reason,
	]
	repair_target_entries = management.get_repair_target_entries(recipe_id)
	repair_target.clear()
	var selected_target_index: int = 0
	for index: int in range(repair_target_entries.size()):
		var target: Dictionary = repair_target_entries[index]
		repair_target.add_item("%s — %d/%d" % [
			String(target.get("display_name", "Unknown equipment")),
			int(target.get("condition", 0)),
			int(target.get("condition_maximum", 0)),
		])
		if StringName(target.get("instance_id", "")) == previous_target_id:
			selected_target_index = index
	if repair_target_entries.is_empty():
		selected_repair_target_instance_id = &""
		repair_target.add_item("No damaged eligible authored equipment")
		repair_target.disabled = true
		%RepairSelected.disabled = true
	elif not bool(entry.get("can_pay", false)):
		repair_target.disabled = false
		%RepairSelected.disabled = true
	else:
		repair_target.disabled = false
		%RepairSelected.disabled = false
	if not repair_target_entries.is_empty():
		repair_target.select(selected_target_index)
		selected_repair_target_instance_id = StringName(
			repair_target_entries[selected_target_index].get("instance_id", "")
		)


func _refresh_key_chain() -> void:
	key_list.clear()
	for entry: Dictionary in management.get_key_entries():
		key_list.add_item("%s ×%d — %s" % [
			String(entry.get("display_name", "Unknown key")),
			int(entry.get("quantity", 0)),
			String(entry.get("persistence", "Unknown scope")),
		])
		var index: int = key_list.item_count - 1
		key_list.set_item_icon(index, entry.get("icon", null) as Texture2D)
	if key_list.item_count == 0:
		key_list.add_item("The shared Key Chain is empty.")
		key_list.set_item_disabled(0, true)


func _initialize_equipment_slots() -> void:
	equipment_slot.clear()
	for slot: EquipmentDefinition.Slot in [
		EquipmentDefinition.Slot.MAIN_HAND,
		EquipmentDefinition.Slot.OFF_HAND,
		EquipmentDefinition.Slot.ARMOR,
	]:
		equipment_slot.add_item(EquipmentDefinition.get_slot_label(slot), slot)


func _on_party_selected(index: int) -> void:
	var value: Variant = party_list.get_item_metadata(index)
	if not (value is Dictionary):
		return
	var entry := value as Dictionary
	selected_heroine_id = StringName(entry.get("heroine_id", ""))
	_show_party_entry(entry)
	for inventory_index: int in range(inventory_heroine.item_count):
		if StringName(inventory_heroine.get_item_metadata(inventory_index)) == selected_heroine_id:
			inventory_heroine.select(inventory_index)
			break
	_refresh_inventory()


func _on_move_party(offset: int) -> void:
	_apply_result(management.reorder_party(selected_heroine_id, offset), "Party order saved.")


func _on_inventory_heroine_selected(index: int) -> void:
	selected_heroine_id = StringName(inventory_heroine.get_item_metadata(index))
	for party_index: int in range(party_list.item_count):
		var value: Variant = party_list.get_item_metadata(party_index)
		if value is Dictionary and StringName((value as Dictionary).get("heroine_id", "")) == selected_heroine_id:
			party_list.select(party_index)
			_show_party_entry(value as Dictionary)
			break
	_refresh_inventory()


func _on_preparation_slot_selected(entry: Dictionary) -> void:
	selected_preparation_entry = entry.duplicate(true)


func _on_item_bar_slot_selected(entry: Dictionary) -> void:
	selected_item_bar_entry = entry.duplicate(true)


func _on_stash_item_selected(index: int) -> void:
	var value: Variant = stash_items.get_item_metadata(index)
	selected_stash_entry = value.duplicate(true) if value is Dictionary else {}


func _on_transfer_selected(source: StringName, destination: StringName) -> void:
	var entry: Dictionary = {}
	match source:
		&"preparation":
			entry = selected_preparation_entry
		&"item_bar":
			entry = selected_item_bar_entry
		&"stash":
			entry = selected_stash_entry
	if entry.is_empty():
		show_status("Select a source item before transferring it.", true)
		return
	var item_id := StringName(entry.get("item_id", ""))
	_apply_result(
		management.transfer_item(
			source,
			destination,
			selected_heroine_id,
			item_id,
			1
		),
		"Moved one %s." % String(entry.get("display_name", item_id))
	)


func _on_equip_selected() -> void:
	var selected: PackedInt32Array = heroine_equipment_list.get_selected_items()
	if selected.is_empty():
		show_status("Select an owned equipment instance first.", true)
		return
	var entry: Dictionary = heroine_equipment_list.get_item_metadata(selected[0]) as Dictionary
	var slot: EquipmentDefinition.Slot = equipment_slot.get_selected_id()
	_apply_result(
		management.equip_instance(
			selected_heroine_id,
			slot,
			StringName(entry.get("instance_id", ""))
		),
		"Equipment loadout saved."
	)


func _on_unequip_selected_slot() -> void:
	var slot: EquipmentDefinition.Slot = equipment_slot.get_selected_id()
	_apply_result(
		management.unequip_slot(selected_heroine_id, slot),
		"Equipment unequipped and retained by the heroine."
	)


func _on_move_equipment_to_stash() -> void:
	var selected: PackedInt32Array = heroine_equipment_list.get_selected_items()
	if selected.is_empty():
		show_status("Select an unequipped equipment instance first.", true)
		return
	var entry: Dictionary = heroine_equipment_list.get_item_metadata(selected[0]) as Dictionary
	_apply_result(
		management.move_heroine_equipment_to_stash(
			selected_heroine_id,
			StringName(entry.get("instance_id", ""))
		),
		"Equipment moved to the safe Stash."
	)


func _on_move_stash_equipment_to_heroine() -> void:
	var selected: PackedInt32Array = stash_equipment_list.get_selected_items()
	if selected.is_empty():
		show_status("Select a Stash equipment instance first.", true)
		return
	var entry: Dictionary = stash_equipment_list.get_item_metadata(selected[0]) as Dictionary
	_apply_result(
		management.move_stash_equipment_to_heroine(
			StringName(entry.get("instance_id", "")),
			selected_heroine_id
		),
		"Equipment moved to the selected heroine."
	)


func _on_recipe_selected(index: int) -> void:
	var value: Variant = recipe_list.get_item_metadata(index)
	if value is Dictionary:
		_show_recipe(value as Dictionary)


func _on_repair_target_selected(index: int) -> void:
	if index < 0 or index >= repair_target_entries.size():
		selected_repair_target_instance_id = &""
		return
	selected_repair_target_instance_id = StringName(
		repair_target_entries[index].get("instance_id", "")
	)


func _on_repair_selected() -> void:
	var selected_recipes: PackedInt32Array = recipe_list.get_selected_items()
	if selected_recipes.is_empty() or repair_target_entries.is_empty():
		show_status("Select an authored service and damaged target first.", true)
		return
	var recipe: Dictionary = recipe_list.get_item_metadata(
		selected_recipes[0]
	) as Dictionary
	var target_index: int = repair_target.selected
	if target_index < 0 or target_index >= repair_target_entries.size():
		show_status("Select a valid repair target.", true)
		return
	var target: Dictionary = repair_target_entries[target_index]
	selected_repair_target_instance_id = StringName(
		target.get("instance_id", "")
	)
	var result: Dictionary = management.execute_repair(
		StringName(recipe.get("recipe_id", "")),
		selected_repair_target_instance_id
	)
	_apply_result(
		result,
		"Repaired %s: condition %d → %d. Saved." % [
			String(target.get("display_name", selected_repair_target_instance_id)),
			int(result.get("condition_before", target.get("condition", 0))),
			int(result.get("condition_after", target.get("condition", 0))),
		]
	)


func _on_review_salvage() -> void:
	var selected: PackedInt32Array = salvage_list.get_selected_items()
	if selected.is_empty():
		show_status("Select an equipment instance to salvage.", true)
		return
	var entry: Dictionary = salvage_list.get_item_metadata(selected[0]) as Dictionary
	pending_salvage_instance_id = StringName(entry.get("instance_id", ""))
	salvage_confirmation.dialog_text = (
		"Destroy %s (%d/%d condition) for %d × %s?\nThis cannot be undone."
		% [
			String(entry.get("display_name", pending_salvage_instance_id)),
			int(entry.get("condition", 0)),
			int(entry.get("condition_maximum", 0)),
			int(entry.get("salvage_yield", 0)),
			String(entry.get("salvage_material_id", "Material")),
		]
	)
	salvage_confirmation.popup_centered()


func _on_salvage_confirmed() -> void:
	if pending_salvage_instance_id == &"":
		return
	var instance_id: StringName = pending_salvage_instance_id
	pending_salvage_instance_id = &""
	_apply_result(
		management.salvage_equipment(instance_id),
		"Equipment salvaged and Materials banked."
	)


func _apply_result(result: Dictionary, success_message: String) -> void:
	var error: String = String(result.get("error", ""))
	if not error.is_empty():
		show_status(error, true)
		return
	show_status(success_message)
	_refresh_all()


func _on_begin_pressed() -> void:
	var seed_text: String = seed_edit.text.strip_edges()
	if not seed_text.is_valid_int() or seed_text.to_int() <= 0:
		show_status("Enter a positive whole-number run seed.", true)
		return
	begin_layer_2_run_requested.emit(seed_text.to_int())


func _on_start_new_story_pressed() -> void:
	var seed_text: String = seed_edit.text.strip_edges()
	if not seed_text.is_valid_int() or seed_text.to_int() <= 0:
		show_status("Enter a positive whole-number run seed.", true)
		return
	start_new_story_requested.emit(seed_text.to_int())


func _make_party_summary() -> String:
	var lines: Array[String] = []
	for entry: Dictionary in management.get_party_entries():
		lines.append("%d. %s — HP %d/%d, MP %d/%d, Resolve %d, Corruption %d" % [
			int(entry.get("order_index", 0)) + 1,
			String(entry.get("display_name", entry.get("heroine_id", ""))),
			int(entry.get("hp", 0)),
			int(entry.get("max_hp", 0)),
			int(entry.get("mp", 0)),
			int(entry.get("max_mp", 0)),
			int(entry.get("resolve", 0)),
			int(entry.get("corruption", 0)),
		])
	return "\n".join(lines)


func _item_display_name(item_id: StringName) -> String:
	var definition: ItemDefinition = RefugeManagementController.ITEM_CATALOG.get_item(
		item_id
	)
	return definition.display_name if definition != null else String(item_id)


func _slot_key_label(slot_key: StringName) -> String:
	match slot_key:
		&"main_hand":
			return "Main Hand"
		&"off_hand":
			return "Off Hand"
		&"armor":
			return "Armor"
	return "Unknown slot"
