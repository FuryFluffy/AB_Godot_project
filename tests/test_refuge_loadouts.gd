extends "res://tests/test_inventory_transfers.gd"
## Reuse the isolated established-Refuge fixture and assertion/persistence helpers.

func _run() -> void:
	_test_exact_equipment_exchange()
	_test_nothing_and_stash()
	_test_memento_exchange()
	_test_exchange_rollback()
	await _test_loadouts_ui()
	print("Stage 04 Refuge Loadouts: %d failures." % failures)
	quit(failures)

func _current(hero: StringName, slot: StringName = &"main_hand") -> StringName:
	return StringName(run.refuge_ownership.equipment_loadouts_by_heroine[hero].slots[slot])

func _stored_weapon(owner: StringName, bag_owner: StringName = &"") -> StringName:
	var id: StringName = _current(owner)
	_expect(run.refuge_ownership.unequip_owned_slot(owner, EquipmentDefinition.Slot.MAIN_HAND).is_empty(), "Fixture unequips existing authored weapon.")
	_expect(run.refuge_ownership.move_unequipped_equipment_to_stash(owner, id).is_empty(), "Fixture stores existing weapon.")
	if bag_owner != &"":
		_expect(run.refuge_ownership.move_stash_equipment_to_heroine(id, bag_owner).is_empty(), "Fixture carries weapon in named bag.")
	return id

func _exchange(hero: StringName, slot: StringName, source: Dictionary) -> Dictionary:
	return controller.exchange_loadout(hero, slot, source, run.refuge_ownership.to_snapshot())

func _nothing() -> Dictionary:
	return {"domain": &"nothing"}

func _test_exact_equipment_exchange() -> void:
	_fixture()
	var outgoing: StringName = _current(&"lysandra")
	var incoming: StringName = _stored_weapon(&"mira", &"seraphine")
	var state: RefugeOwnershipState = run.refuge_ownership
	state.equipment_loadouts_by_heroine[&"lysandra"].instances[String(outgoing)].current_condition = 0
	state.equipment_loadouts_by_heroine[&"seraphine"].instances[String(incoming)].current_condition = 1
	var old_record: Dictionary = state.equipment_loadouts_by_heroine[&"lysandra"].instances[String(outgoing)].duplicate(true)
	var new_record: Dictionary = state.equipment_loadouts_by_heroine[&"seraphine"].instances[String(incoming)].duplicate(true)
	for index: int in range(15):
		state.preparation_slots_by_heroine[&"seraphine"][index] = _slot(index, M, 1)
	state.preparation_slots_by_heroine[&"seraphine"][7] = BackpackPayload.equipment_slot(7, incoming)
	var choices: Array[Dictionary] = controller.get_loadout_candidates(&"lysandra", &"main_hand")
	_expect(choices.size() == 2 and String(choices[1].source_label) == "Backpack · Seraphine · slot 8", "Candidate names source heroine and exact displayed slot; equipped items are absent.")
	var order: Array[StringName] = state.selected_party_ids.duplicate()
	var result: Dictionary = _exchange(&"lysandra", &"main_hand", choices[1].source)
	_expect(String(result.error).is_empty() and result.changed and saves == 1, "Full other-heroine bag exchange saves exactly once.")
	state = run.refuge_ownership
	_expect(_current(&"lysandra") == incoming and state.equipment_loadouts_by_heroine[&"lysandra"].instances[String(incoming)] == new_record, "Incoming instance and condition move to recipient registry.")
	_expect(state.preparation_slots_by_heroine[&"seraphine"][7].equipment_instance_id == String(outgoing) and state.equipment_loadouts_by_heroine[&"seraphine"].instances[String(outgoing)] == old_record, "Broken outgoing gear returns to exact vacated source and registry.")
	_expect(not state.equipment_loadouts_by_heroine[&"seraphine"].instances.has(String(incoming)) and not state.equipment_loadouts_by_heroine[&"lysandra"].instances.has(String(outgoing)), "Exchange leaves one registry owner per instance.")
	_expect(state.selected_party_ids == order and state.preparation_slots_by_heroine[&"seraphine"][6].item_id == M and state.preparation_slots_by_heroine[&"seraphine"][8].item_id == M, "Adjacent items and expedition order remain unchanged.")
	var restored := RefugeOwnershipState.new()
	_expect(restored.restore_from_snapshot(JSON.parse_string(JSON.stringify(saved)), ITEMS, BATTLERS, HEROES).is_empty() and restored.to_snapshot() == state.to_snapshot(), "Exchanged instance owners, conditions and exact bag slot survive JSON reload.")

func _test_nothing_and_stash() -> void:
	_fixture()
	var outgoing: StringName = _current(&"lysandra")
	var incoming: StringName = _stored_weapon(&"mira")
	var source: Dictionary = RefugeInventoryTransfer.address(&"stash_equipment", -1, &"", incoming)
	var result: Dictionary = _exchange(&"lysandra", &"main_hand", source)
	_expect(String(result.error).is_empty() and _current(&"lysandra") == incoming and run.refuge_ownership.stash_equipment_instances.has(outgoing), "Stash replacement returns outgoing gear to Stash.")
	result = _exchange(&"lysandra", &"main_hand", _nothing())
	_expect(String(result.error).is_empty() and _current(&"lysandra") == &"" and run.refuge_ownership.stash_equipment_instances.has(incoming), "Nothing clears equipment to Stash without destroying it.")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	var count: int = saves
	result = _exchange(&"lysandra", &"main_hand", _nothing())
	_expect(not result.changed and before == run.refuge_ownership.to_snapshot() and saves == count, "Nothing on empty is a no-op without a save.")
	_expect(controller.get_loadout_candidates(&"lysandra", &"off_hand").size() == 1, "No fabricated player Off Hand/shield candidates.")
	_expect(not String(_exchange(&"lysandra", &"armor", source).error).is_empty(), "Weapon cannot enter Armor.")
	# Same-owner bag replacement: registry aliasing must conserve both records.
	_exchange(&"lysandra", &"main_hand", source)
	run.refuge_ownership.move_stash_equipment_to_heroine(outgoing, &"lysandra")
	result = _exchange(&"lysandra", &"main_hand", _bag(0))
	_expect(String(result.error).is_empty() and _current(&"lysandra") == outgoing and run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][0].equipment_instance_id == String(incoming), "Own Backpack exchange retains both instances in one registry and exact source slot.")
	# Duplicate definitions remain distinct instance candidates; reserves are excluded.
	var record: Dictionary = run.refuge_ownership.equipment_loadouts_by_heroine[&"lysandra"].instances[String(incoming)].duplicate(true)
	record.instance_id = "fixture:second-copy"
	run.refuge_ownership.stash_equipment_instances[&"fixture:second-copy"] = record
	var candidates: Array[Dictionary] = controller.get_loadout_candidates(&"lysandra", &"main_hand")
	_expect(candidates.size() == 3 and candidates[1].instance_id != candidates[2].instance_id, "Two copies of one definition are distinct stored candidates.")
	var armor_id: StringName = _current(&"lysandra", &"armor")
	_expect(run.refuge_ownership.unequip_owned_slot(&"lysandra", EquipmentDefinition.Slot.ARMOR).is_empty(), "Unequip fixture armor: %s" % armor_id)
	_expect(controller.get_loadout_candidates(&"lysandra", &"armor").size() == 1, "Legacy personal reserves are not silently treated as Backpack contents.")
	var stash_error: String = run.refuge_ownership.move_unequipped_equipment_to_stash(&"lysandra", armor_id)
	_expect(stash_error.is_empty(), "Store fixture armor: %s" % stash_error)
	var armor_choices: Array[Dictionary] = controller.get_loadout_candidates(&"mira", &"armor")
	var armor_result: Dictionary = _exchange(&"mira", &"armor", armor_choices[1].source) if armor_choices.size() == 2 else {"error": "Candidate count %d" % armor_choices.size()}
	_expect(String(armor_result.error).is_empty(), "Authored Armor uses the same exchange service: %s" % armor_result.error)

func _test_memento_exchange() -> void:
	_fixture()
	var other: StringName = &""
	for item: ItemDefinition in ITEMS.items:
		if item.canonical_workbook_item and item.content_category == ItemDefinition.ContentCategory.MEMENTO and item.item_id != StringName(M):
			other = item.item_id
			break
	_expect(other != &"", "Fixture uses a second authored Memento.")
	run.refuge_ownership.assign_memento(&"lysandra", StringName(M))
	run.refuge_ownership.add_stash_item(other, 1)
	var choices: Array[Dictionary] = controller.get_loadout_candidates(&"lysandra", &"memento")
	_expect(choices.size() == 2, "Stored Memento is an eligible candidate.")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	fail_save = true
	var rejected: Dictionary = _exchange(&"lysandra", &"memento", choices[1].source)
	_expect(String(rejected.error) == "Injected save failure" and run.refuge_ownership.to_snapshot() == before, "Memento save failure rolls back equipped ID and source/destination Stash stacks.")
	fail_save = false
	var result: Dictionary = _exchange(&"lysandra", &"memento", choices[1].source)
	_expect(String(result.error).is_empty() and run.refuge_ownership.memento_slots_by_heroine[&"lysandra"] == other, "Memento Stash exchange equips existing Stable ID.")
	var stacks: Array = run.refuge_ownership.stash_item_stacks
	_expect(stacks.size() == 1 and stacks[0].item_id == M and stacks[0].quantity == 1, "Previous Memento returns to Stash once.")
	run.refuge_ownership.move_stash_item_to_preparation(&"mira", StringName(M), 1)
	for index: int in range(1, 15):
		run.refuge_ownership.preparation_slots_by_heroine[&"mira"][index] = _slot(index, A, 4)
	result = _exchange(&"lysandra", &"memento", _bag(0, &"mira"))
	_expect(String(result.error).is_empty() and run.refuge_ownership.memento_slots_by_heroine[&"lysandra"] == StringName(M) and run.refuge_ownership.preparation_slots_by_heroine[&"mira"][0].item_id == String(other), "Memento displacement uses the exact other-heroine slot even in a full bag.")
	result = _exchange(&"lysandra", &"memento", _nothing())
	_expect(String(result.error).is_empty() and run.refuge_ownership.memento_slots_by_heroine[&"lysandra"] == null, "Nothing returns Memento to Stash.")
	var count: int = saves
	result = _exchange(&"lysandra", &"memento", _nothing())
	_expect(not result.changed and saves == count, "Empty Memento Nothing does not persist.")
	run.refuge_ownership.assign_memento(&"seraphine", other)
	_expect(controller.get_loadout_candidates(&"lysandra", &"memento").size() == 2, "Memento already equipped elsewhere is excluded; Nothing and unassigned Stash Memento remain.")
	var restored := RefugeOwnershipState.new()
	var encoded: String = JSON.stringify(saved)
	_expect(restored.restore_from_snapshot(JSON.parse_string(encoded), ITEMS, BATTLERS, HEROES).is_empty(), "Equipment and Memento exchanges JSON round-trip through existing ownership schema.")

func _test_exchange_rollback() -> void:
	_fixture()
	var incoming: StringName = _stored_weapon(&"mira", &"seraphine")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	fail_save = true
	var result: Dictionary = _exchange(&"lysandra", &"main_hand", _bag(0, &"seraphine"))
	_expect(String(result.error) == "Injected save failure" and before == run.refuge_ownership.to_snapshot() and saves == 1, "Save failure rolls back equipped slot, both registry owners and source bag.")
	result = _exchange(&"lysandra", &"main_hand", _nothing())
	_expect(String(result.error) == "Injected save failure" and before == run.refuge_ownership.to_snapshot(), "Nothing-to-Stash also rolls back on save failure.")
	var expected: Dictionary = before.duplicate(true)
	run.refuge_ownership.equipment_loadouts_by_heroine[&"seraphine"].instances[String(incoming)].current_condition = 0
	before = run.refuge_ownership.to_snapshot()
	result = controller.exchange_loadout(&"lysandra", &"main_hand", _bag(0, &"seraphine"), expected)
	_expect(not String(result.error).is_empty() and before == run.refuge_ownership.to_snapshot() and saves == 2, "Stale preview cannot equip changed gear or save.")
	result = _exchange(&"lysandra", &"main_hand", RefugeInventoryTransfer.address(&"stash_equipment", -1, &"", _current(&"seraphine")))
	_expect(not String(result.error).is_empty() and before == run.refuge_ownership.to_snapshot(), "Equipped items are not stored candidates.")

func _test_loadouts_ui() -> void:
	_fixture()
	_stored_weapon(&"mira", &"seraphine")
	var screen := load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	await process_frame
	_expect(screen.present(run, BATTLERS, KnowledgeState.new(), false, controller).is_empty(), "Loadouts screen binds to production controller.")
	screen.room_shell.open_station(&"loadouts")
	await process_frame
	var view: RefugeLoadoutsView = screen.loadouts_view
	_expect(view.rows.get_child_count() == 4 and view.selector.item_count == 3 and screen.party_list.get_parent().get_parent() == screen.room_shell.pages[&"expedition"], "Loadouts has four equipment rows and shared selector; party ordering belongs to Expedition.")
	_expect(screen.room_shell.panel.position.x > screen.room_shell.size.x * 0.5, "Loadouts opens on the approved right side of the room.")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	view.selector.select(2)
	view.selector.item_selected.emit(2)
	_expect(view.heroine_id == &"seraphine" and run.refuge_ownership.to_snapshot() == before and saves == 0, "Loadouts browsing cannot change expedition or ownership.")
	view.selector.select(0)
	view.selector.item_selected.emit(0)
	view.open_choices(&"main_hand")
	view.candidate_list.select(1)
	view.candidate_list.item_selected.emit(1)
	_expect(saves == 0 and run.refuge_ownership.to_snapshot() == before and view.destination_hint.text.contains("Seraphine"), "Candidate preview is free and names the displacement destination.")
	screen.room_shell.close_button.pressed.emit()
	_expect(not view.chooser.visible and screen.room_shell.modal.visible and root.gui_get_focus_owner() == view.change_buttons[&"main_hand"], "Close/Back dismisses candidate menu first and restores Change focus.")
	view.open_choices(&"main_hand")
	view.candidate_list.select(1)
	view._preview(1)
	view.equip_button.pressed.emit()
	_expect(saves == 1 and not view.chooser.visible, "Explicit Equip commits once and returns to rows.")
	screen.handle_cancel()
	_expect(not screen.room_shell.modal.visible and root.gui_get_focus_owner() == screen.room_shell.hotspots[&"loadouts"], "Main Loadouts Cancel returns to weapon stand.")
	screen.queue_free()
	await process_frame
