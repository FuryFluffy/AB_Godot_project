extends SceneTree


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)
const EQUIPMENT_CATALOG: EquipmentCatalogDefinition = preload(
	"res://data/equipment/layer_1_2_equipment_catalog.tres"
)
const HEROINE_IDS: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]


var failures: int = 0
var successful_saves: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_legacy_defaults_and_malformed_rollback()
	_test_party_order_inventory_transactions_and_save_rollback()
	_test_player_equipment_filter_and_services()
	_test_launch_item_bar_ownership()
	await _test_scene_construction_and_rendering()
	await _test_repair_ui_preserves_exact_target()
	await _test_salvage_confirmation_action()
	if failures == 0:
		print("Refuge management UI tests passed.")
	else:
		push_error("%d Refuge management UI test(s) failed." % failures)
	quit(failures)


func _test_legacy_defaults_and_malformed_rollback() -> void:
	var source: RefugeOwnershipState = _make_refuge()
	var legacy_snapshot: Dictionary = source.to_snapshot()
	legacy_snapshot.erase("prepared_item_bar_slots")
	var restored := RefugeOwnershipState.new()
	var restore_error: String = restored.restore_from_snapshot(
		legacy_snapshot,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)
	var empty_item_bar: bool = restored.prepared_item_bar_slots.size() == 6
	for slot: Dictionary in restored.prepared_item_bar_slots:
		empty_item_bar = (
			empty_item_bar
			and String(slot.get("item_id", "")).is_empty()
			and int(slot.get("quantity", -1)) == 0
		)
	_expect(
		restore_error.is_empty() and empty_item_bar,
		"A valid legacy v3 Refuge snapshot must receive six ordered empty Item Bar preparation slots."
	)
	var before_malformed: Dictionary = restored.to_snapshot()
	var malformed: Dictionary = before_malformed.duplicate(true)
	malformed["prepared_item_bar_slots"] = [
		{"slot_index": 0, "item_id": "shared_rusty_key", "quantity": 1},
	]
	var malformed_error: String = restored.restore_from_snapshot(
		malformed,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)
	_expect(
		not malformed_error.is_empty()
		and restored.to_snapshot() == before_malformed,
		"Malformed Item Bar preparation must reject transactionally without changing Refuge ownership."
	)


func _test_party_order_inventory_transactions_and_save_rollback() -> void:
	var run: RunState = _make_established_run()
	run.ensure_refuge_ownership_initialized()
	run.refuge_ownership.add_preparation_item(
		&"lysandra", &"l01_bandage_roll", 2
	)
	run.refuge_ownership.add_stash_item(&"l01_smelling_salts", 1)
	var initial_bar_quantity: int = _slot_quantity(
		run.refuge_ownership.prepared_item_bar_slots,
		&"l01_bandage_roll"
	)
	var controller := RefugeManagementController.new()
	var bind_error: String = controller.bind(
		run,
		BATTLER_CATALOG,
		_persist_success
	)
	var reorder: Dictionary = controller.reorder_party(&"mira", -1)
	var transfer_to_bar: Dictionary = controller.transfer_item(
		&"preparation",
		&"item_bar",
		&"lysandra",
		&"l01_bandage_roll",
		1
	)
	var transfer_to_stash: Dictionary = controller.transfer_item(
		&"item_bar",
		&"stash",
		&"lysandra",
		&"l01_bandage_roll",
		1
	)
	var expected_order: Array[StringName] = [
		&"mira", &"lysandra", &"seraphine",
	]
	_expect(
		bind_error.is_empty()
		and String(reorder.get("error", "")).is_empty()
		and String(transfer_to_bar.get("error", "")).is_empty()
		and String(transfer_to_stash.get("error", "")).is_empty()
		and run.refuge_ownership.selected_party_ids == expected_order
		and _slot_quantity(
			run.refuge_ownership.prepared_item_bar_slots,
			&"l01_bandage_roll"
		) == initial_bar_quantity
		and _slot_quantity(
			run.refuge_ownership.stash_item_stacks,
			&"l01_bandage_roll"
		) == 1
		and successful_saves == 3,
		"Party order and legal preparation/Item Bar/Stash transfers must commit through the persistence callback. bind=%s reorder=%s to_bar=%s to_stash=%s saves=%d order=%s bar=%d stash=%d"
		% [
			bind_error,
			String(reorder.get("error", "")),
			String(transfer_to_bar.get("error", "")),
			String(transfer_to_stash.get("error", "")),
			successful_saves,
			run.refuge_ownership.selected_party_ids,
			_slot_quantity(run.refuge_ownership.prepared_item_bar_slots, &"l01_bandage_roll"),
			_slot_quantity(run.refuge_ownership.stash_item_stacks, &"l01_bandage_roll"),
		]
	)
	var before_invalid: Dictionary = run.refuge_ownership.to_snapshot()
	var invalid_category: Dictionary = controller.transfer_item(
		&"stash",
		&"item_bar",
		&"lysandra",
		&"shared_rusty_key",
		1
	)
	var invalid_quantity: Dictionary = controller.transfer_item(
		&"preparation",
		&"item_bar",
		&"lysandra",
		&"l01_bandage_roll",
		99
	)
	_expect(
		not String(invalid_category.get("error", "")).is_empty()
		and not String(invalid_quantity.get("error", "")).is_empty()
		and run.refuge_ownership.to_snapshot() == before_invalid,
		"Category and quantity failures must leave every Refuge inventory domain unchanged."
	)
	var duplicate_order_error: String = (
		run.refuge_ownership.set_selected_party_order(
			[&"mira", &"mira", &"seraphine"]
		)
	)
	var unrecruited_order_error: String = (
		run.refuge_ownership.set_selected_party_order(
			[&"mira", &"lysandra", &"unrecruited"]
		)
	)
	_expect(
		not duplicate_order_error.is_empty()
		and not unrecruited_order_error.is_empty()
		and run.refuge_ownership.to_snapshot() == before_invalid,
		"Duplicate and unrecruited party orders must reject without changing the persisted selection."
	)
	var rollback_controller := RefugeManagementController.new()
	rollback_controller.bind(run, BATTLER_CATALOG, _persist_failure)
	var before_save_failure: Dictionary = run.refuge_ownership.to_snapshot()
	var rejected_save: Dictionary = rollback_controller.reorder_party(
		&"lysandra", -1
	)
	_expect(
		not String(rejected_save.get("error", "")).is_empty()
		and run.refuge_ownership.to_snapshot() == before_save_failure,
		"A failed durable save must roll a staged Refuge UI mutation back completely."
	)
	_test_full_item_bar_capacity_rollback()


func _test_full_item_bar_capacity_rollback() -> void:
	var run: RunState = _make_established_run()
	run.ensure_refuge_ownership_initialized()
	var full_slots: Array[Dictionary] = []
	var extra_item_id: StringName = &""
	for definition: ItemDefinition in ITEM_CATALOG.items:
		if (
			not definition.canonical_workbook_item
			or definition.content_category != ItemDefinition.ContentCategory.ACTIVE
			or not definition.combat_usable
		):
			continue
		if full_slots.size() < 6:
			full_slots.append({
				"slot_index": full_slots.size(),
				"item_id": String(definition.item_id),
				"quantity": 1,
			})
		else:
			extra_item_id = definition.item_id
			break
	var snapshot: Dictionary = run.refuge_ownership.to_snapshot()
	snapshot["prepared_item_bar_slots"] = full_slots
	var restore_error: String = run.refuge_ownership.restore_from_snapshot(
		snapshot,
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS
	)
	var preparation_error: String = run.refuge_ownership.add_preparation_item(
		&"lysandra",
		extra_item_id,
		1
	)
	var controller := RefugeManagementController.new()
	var bind_error: String = controller.bind(run, BATTLER_CATALOG)
	var before_full_move: Dictionary = run.refuge_ownership.to_snapshot()
	var full_move: Dictionary = controller.transfer_item(
		&"preparation",
		&"item_bar",
		&"lysandra",
		extra_item_id,
		1
	)
	_expect(
		full_slots.size() == 6
		and extra_item_id != &""
		and restore_error.is_empty()
		and preparation_error.is_empty()
		and bind_error.is_empty()
		and not String(full_move.get("error", "")).is_empty()
		and run.refuge_ownership.to_snapshot() == before_full_move,
		"A full six-slot Item Bar must reject a new stack without removing the source preparation item."
	)


func _test_player_equipment_filter_and_services() -> void:
	var run: RunState = _make_established_run()
	run.ensure_refuge_ownership_initialized()
	var controller := RefugeManagementController.new()
	controller.bind(run, BATTLER_CATALOG, _persist_success)
	var player_entries: Array[Dictionary] = controller.get_all_equipment_entries()
	var player_definition_ids: Dictionary = {}
	for entry: Dictionary in player_entries:
		if bool(entry.get("player_available", false)):
			player_definition_ids[StringName(entry.get("definition_id", ""))] = true
	_expect(
		player_definition_ids.size() == 5
		and player_definition_ids.has(&"lysandra_sword")
		and player_definition_ids.has(&"mira_dagger")
		and player_definition_ids.has(&"seraphine_staff")
		and player_definition_ids.has(&"lysandra_chain")
		and player_definition_ids.has(&"seraphine_cloth")
		and not player_definition_ids.has(&"red_wax_drip")
		and not player_definition_ids.has(&"chain_thrall_chain"),
		"Refuge choices must expose only owned explicitly authored heroine equipment, never enemy/fixture equipment. Got: %s"
		% [player_definition_ids]
	)
	var explicitly_available_count: int = 0
	for definition: EquipmentDefinition in EQUIPMENT_CATALOG.equipment:
		if definition.player_refuge_available:
			explicitly_available_count += 1
	_expect(
		explicitly_available_count == 6,
		"Exactly the six authored starting heroine definitions must carry the explicit Refuge availability rule."
	)
	var lysandra_loadout: Dictionary = (
		run.refuge_ownership.equipment_loadouts_by_heroine.get(
			&"lysandra", {}
		) as Dictionary
	)
	var slots: Dictionary = lysandra_loadout.get("slots", {}) as Dictionary
	var armor_id := StringName(slots.get("armor", ""))
	var instances: Dictionary = lysandra_loadout.get("instances", {}) as Dictionary
	var armor_snapshot: Dictionary = instances.get(armor_id, {}) as Dictionary
	armor_snapshot["current_condition"] = 0
	instances[armor_id] = armor_snapshot
	lysandra_loadout["instances"] = instances
	run.refuge_ownership.equipment_loadouts_by_heroine[&"lysandra"] = lysandra_loadout
	run.refuge_ownership.banked_materials["mat_l01_servant_cloth"] = 1
	var broken_entry: Dictionary = controller.get_equipment_entry(armor_id)
	var repair: Dictionary = controller.execute_repair(
		&"refuge_repair_cloth_armor",
		armor_id
	)
	var repaired_entry: Dictionary = controller.get_equipment_entry(armor_id)
	_expect(
		bool(broken_entry.get("broken", false))
		and int(broken_entry.get("condition", -1)) == 0
		and String(repair.get("error", "")).is_empty()
		and int(repaired_entry.get("condition", -1)) == 1
		and run.refuge_ownership.get_banked_material_quantity(
			&"mat_l01_servant_cloth"
		) == 0,
		"Refuge service view data must display broken condition and execute only the authored repair recipe with its exact Material input."
	)


func _test_launch_item_bar_ownership() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_established_run()
	run.ensure_refuge_ownership_initialized()
	var initial_bar_quantity: int = _slot_quantity(
		run.refuge_ownership.prepared_item_bar_slots,
		&"l01_bandage_roll"
	)
	run.refuge_ownership.add_preparation_item(
		&"lysandra", &"l01_bandage_roll", 1
	)
	var move_error: String = (
		run.refuge_ownership.move_preparation_item_to_item_bar(
			&"lysandra", &"l01_bandage_roll", 1
		)
	)
	var start_error: String = run.begin_next_layer_2_run(
		generator.generate_layer_2_run(80811)
	)
	_expect(
		move_error.is_empty()
		and start_error.is_empty()
		and _slot_quantity(
			run.run_inventory.get_item_bar_snapshot(),
			&"l01_bandage_roll"
		) == initial_bar_quantity + 1
		and _slot_quantity(
			run.refuge_ownership.prepared_item_bar_slots,
			&"l01_bandage_roll"
		) == 0,
		"Run launch must move the exact prepared six-slot Item Bar into run ownership without Refuge duplication. move=%s start=%s run=%d refuge=%d"
		% [
			move_error,
			start_error,
			_slot_quantity(run.run_inventory.get_item_bar_snapshot(), &"l01_bandage_roll"),
			_slot_quantity(run.refuge_ownership.prepared_item_bar_slots, &"l01_bandage_roll"),
		]
	)


func _test_scene_construction_and_rendering() -> void:
	var packed := load(
		"res://scenes/refuge/bloom_refuge_screen.tscn"
	) as PackedScene
	_expect(packed != null, "Bloom Refuge management scene must load.")
	if packed == null:
		return
	var screen := packed.instantiate() as BloomRefugeScreen
	root.add_child(screen)
	await process_frame
	var run: RunState = _make_established_run()
	var knowledge := KnowledgeState.new()
	var present_error: String = screen.present(
		run,
		BATTLER_CATALOG,
		knowledge,
		false
	)
	await process_frame
	var tabs := screen.get_node("%ManagementTabs") as TabContainer
	var material_list := screen.get_node("%MaterialList") as ItemList
	var stash_list := screen.get_node("%StashItems") as ItemList
	var key_list := screen.get_node("%KeyList") as ItemList
	var item_bar_grid := screen.get_node("%ItemBarGrid") as RefugeSlotGrid
	var first_item_bar_slot := (
		item_bar_grid.get_child(0) as Button
		if item_bar_grid.get_child_count() > 0
		else null
	)
	_expect(
		present_error.is_empty()
		and tabs != null
		and tabs.get_tab_count() == 5
		and screen.get_node("%PreparationGrid") is RefugeSlotGrid
		and screen.get_node("%ItemBarGrid") is RefugeSlotGrid
		and (screen.get_node("%PartyList") as ItemList).item_count == 3
		and material_list.item_count == 4
		and (screen.get_node("%RecipeList") as ItemList).item_count == 1,
		"The scene must construct and safely render all five Refuge management areas from default ownership state."
	)
	_expect(
		material_list.fixed_icon_size == Vector2i(48, 48)
		and stash_list.fixed_icon_size == Vector2i(48, 48)
		and key_list.fixed_icon_size == Vector2i(48, 48)
		and first_item_bar_slot != null
		and first_item_bar_slot.expand_icon
		and first_item_bar_slot.get_theme_constant("icon_max_width") == 40,
		"Refuge Material, Stash, Key, preparation, and Item Bar art must remain compact."
	)
	screen.queue_free()
	await process_frame


func _test_repair_ui_preserves_exact_target() -> void:
	var run: RunState = _make_established_run()
	run.ensure_refuge_ownership_initialized()
	var target_ids: Dictionary = {}
	for heroine_id: StringName in [&"lysandra", &"seraphine"]:
		var loadout: Dictionary = (
			run.refuge_ownership.equipment_loadouts_by_heroine.get(
				heroine_id, {}
			) as Dictionary
		)
		var slots: Dictionary = loadout.get("slots", {}) as Dictionary
		var armor_id := StringName(slots.get("armor", ""))
		var instances: Dictionary = loadout.get("instances", {}) as Dictionary
		var armor: Dictionary = instances.get(armor_id, {}) as Dictionary
		armor["current_condition"] = 0
		instances[armor_id] = armor
		loadout["instances"] = instances
		run.refuge_ownership.equipment_loadouts_by_heroine[heroine_id] = loadout
		target_ids[heroine_id] = armor_id
	run.refuge_ownership.banked_materials["mat_l01_servant_cloth"] = 2
	var controller := RefugeManagementController.new()
	var bind_error: String = controller.bind(run, BATTLER_CATALOG)
	var packed := load(
		"res://scenes/refuge/bloom_refuge_screen.tscn"
	) as PackedScene
	var screen := packed.instantiate() as BloomRefugeScreen
	root.add_child(screen)
	await process_frame
	var present_error: String = screen.present(
		run,
		BATTLER_CATALOG,
		KnowledgeState.new(),
		false,
		controller
	)
	await process_frame
	var seraphine_armor_id := StringName(target_ids.get(&"seraphine", ""))
	var target_index: int = -1
	for index: int in range(screen.repair_target_entries.size()):
		if StringName(
			screen.repair_target_entries[index].get("instance_id", "")
		) == seraphine_armor_id:
			target_index = index
			break
	var target_selector := screen.get_node("%RepairTarget") as OptionButton
	var recipe_list := screen.get_node("%RecipeList") as ItemList
	var repair_button := screen.get_node("%RepairSelected") as Button
	if target_index >= 0:
		target_selector.select(target_index)
		target_selector.item_selected.emit(target_index)
		recipe_list.select(0)
		recipe_list.item_selected.emit(0)
	await process_frame
	var target_preserved_before_repair: bool = (
		screen.selected_repair_target_instance_id == seraphine_armor_id
	)
	if target_index >= 0:
		repair_button.pressed.emit()
	await process_frame
	var repaired: Dictionary = controller.get_equipment_entry(
		seraphine_armor_id
	)
	var selected_after: int = target_selector.selected
	var selected_entry_after: Dictionary = (
		screen.repair_target_entries[selected_after]
		if selected_after >= 0
		and selected_after < screen.repair_target_entries.size()
		else {}
	)
	_expect(
		bind_error.is_empty()
		and present_error.is_empty()
		and target_index >= 0
		and target_preserved_before_repair
		and int(repaired.get("condition", -1)) == 1
		and run.refuge_ownership.get_banked_material_quantity(
			&"mat_l01_servant_cloth"
		) == 1
		and StringName(selected_entry_after.get("instance_id", ""))
		== seraphine_armor_id
		and screen.status_label.text.contains("condition 0 → 1"),
		"Repair UI must retain and repair the exact selected Armor instance with explicit feedback."
	)
	screen.queue_free()
	await process_frame


func _test_salvage_confirmation_action() -> void:
	var definition: EquipmentDefinition = EQUIPMENT_CATALOG.get_equipment(
		&"red_wax_drip"
	)
	var previous_availability: bool = definition.player_refuge_available
	definition.player_refuge_available = true
	var run: RunState = _make_established_run()
	run.ensure_refuge_ownership_initialized()
	var instance := EquipmentInstance.new()
	var instance_error: String = instance.initialize(
		&"ui:salvage:red_wax",
		definition,
		0
	)
	run.refuge_ownership.stash_equipment_instances[instance.instance_id] = (
		instance.to_snapshot()
	)
	var packed := load(
		"res://scenes/refuge/bloom_refuge_screen.tscn"
	) as PackedScene
	var screen := packed.instantiate() as BloomRefugeScreen
	root.add_child(screen)
	await process_frame
	var present_error: String = screen.present(
		run,
		BATTLER_CATALOG,
		KnowledgeState.new(),
		false
	)
	await process_frame
	var salvage_ui := screen.get_node("%SalvageList") as ItemList
	var review_button := screen.get_node("%SalvageSelected") as Button
	var confirmation := screen.get_node("%SalvageConfirmation") as ConfirmationDialog
	var before_review: Dictionary = run.refuge_ownership.to_snapshot()
	if salvage_ui.item_count > 0:
		salvage_ui.select(0)
		review_button.pressed.emit()
	await process_frame
	var confirmation_opened: bool = confirmation.visible
	confirmation.hide()
	var cancel_preserved: bool = run.refuge_ownership.to_snapshot() == before_review
	if salvage_ui.item_count > 0:
		review_button.pressed.emit()
	confirmation.confirmed.emit()
	await process_frame
	_expect(
		instance_error.is_empty()
		and present_error.is_empty()
		and salvage_ui.item_count > 0
		and confirmation_opened
		and cancel_preserved
		and not run.refuge_ownership.stash_equipment_instances.has(
			&"ui:salvage:red_wax"
		)
		and run.refuge_ownership.get_banked_material_quantity(
			&"mat_l01_red_wax"
		) == 1,
		"The UI must review salvage in a confirmation dialog, preserve state on cancellation, and destroy only the confirmed instance for its exact yield."
	)
	screen.queue_free()
	await process_frame
	definition.player_refuge_available = previous_availability


func _make_refuge() -> RefugeOwnershipState:
	var refuge := RefugeOwnershipState.new()
	var error: String = refuge.initialize_default(
		ITEM_CATALOG,
		BATTLER_CATALOG,
		HEROINE_IDS,
		_make_party_snapshot()
	)
	_expect(error.is_empty(), "Refuge fixture must initialize.")
	return refuge


func _make_established_run() -> RunState:
	var generator := LayerMapGenerator.new()
	var run := RunState.new()
	run.initialize(
		27072026,
		generator.generate_bloom_refuge_holding_state(27072026),
		[],
		_make_party_snapshot()
	)
	run.opening_completed = true
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = HEROINE_IDS.duplicate()
	run.campaign_lifecycle.restore_legacy_refuge(27072026)
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	var save_flags: Dictionary = run.narrative_state.flags_by_scope.get(
		&"save", {}
	) as Dictionary
	save_flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	save_flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	return run


func _make_party_snapshot() -> Dictionary:
	return {
		&"lysandra": _heroine_snapshot(10, 4, 73, 8),
		&"mira": _heroine_snapshot(9, 6, 69, 12),
		&"seraphine": _heroine_snapshot(8, 8, 81, 4),
	}


func _heroine_snapshot(
	hp: int,
	mp: int,
	resolve: int,
	corruption: int
) -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"resolve": resolve,
		"corruption": corruption,
		"item_guard": 0,
		"weapon_damage": 0,
		"weapon_broken": false,
		"armor_damage": 0,
		"armor_broken": false,
		"shield_damage": 0,
		"shield_broken": false,
	}


func _slot_quantity(
	slots: Array,
	item_id: StringName
) -> int:
	var total: int = 0
	for value: Variant in slots:
		var slot: Dictionary = value as Dictionary
		if StringName(slot.get("item_id", "")) == item_id:
			total += int(slot.get("quantity", 0))
	return total


func _persist_success() -> String:
	successful_saves += 1
	return ""


func _persist_failure() -> String:
	return "Intentional persistence failure."


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
