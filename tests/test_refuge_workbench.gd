extends "res://tests/test_inventory_transfers.gd"
## Stage 05 uses authored recipes/yields; salvage availability is fixture-only.
const REPAIR: StringName = &"refuge_repair_cloth_armor"
const CLOTH: StringName = &"mat_l01_servant_cloth"

func _run() -> void:
	_test_repair_sources_and_rollback()
	await _test_tabs_and_confirmation()
	print("Stage 05 Refuge Workbench: %d failures." % failures)
	quit(failures)

func _armor(hero: StringName) -> StringName:
	return StringName(run.refuge_ownership.equipment_loadouts_by_heroine[hero].slots.armor)

func _test_repair_sources_and_rollback() -> void:
	for source: String in ["equipped", "stash", "backpack"]:
		_fixture()
		var id: StringName = _armor(&"seraphine")
		run.refuge_ownership.equipment_loadouts_by_heroine[&"seraphine"].instances[String(id)].current_condition = 0
		if source != "equipped":
			run.refuge_ownership.unequip_owned_slot(&"seraphine", EquipmentDefinition.Slot.ARMOR)
			run.refuge_ownership.move_unequipped_equipment_to_stash(&"seraphine", id)
			if source == "backpack":
				run.refuge_ownership.move_stash_equipment_to_heroine(id, &"mira")
		var entry: Dictionary = controller.get_equipment_entry(id)
		_expect(entry.source_label == ("Equipped · Seraphine · Armor" if source == "equipped" else ("Stash" if source == "stash" else "Backpack · Mira · slot 1")), "Repair names source and equipped slot: " + source)
		var before: Dictionary = run.refuge_ownership.to_snapshot()
		var result: Dictionary = controller.execute_repair(REPAIR, id, before)
		_expect(not String(result.error).is_empty() and before == run.refuge_ownership.to_snapshot() and saves == 0, "Insufficient banked cloth changes nothing: " + source)
		run.refuge_ownership.banked_materials[String(CLOTH)] = 2
		before = run.refuge_ownership.to_snapshot()
		fail_save = true
		result = controller.execute_repair(REPAIR, id, before)
		_expect(String(result.error) == "Injected save failure" and before == run.refuge_ownership.to_snapshot(), "Repair/save rollback preserves condition, source and cost: " + source)
		fail_save = false
		result = controller.execute_repair(REPAIR, id, before)
		_expect(String(result.error).is_empty() and result.condition_after == 1 and run.refuge_ownership.get_banked_material_quantity(CLOTH) == 1 and controller.get_equipment_entry(id).source_label == entry.source_label, "Repair charges one cloth, restores one condition and retains exact source: " + source)
		var restored := RefugeOwnershipState.new()
		_expect(restored.restore_from_snapshot(JSON.parse_string(JSON.stringify(saved)), ITEMS, BATTLERS, HEROES).is_empty() and restored.to_snapshot() == run.refuge_ownership.to_snapshot(), "Repair survives JSON reload: " + source)
		var after: Dictionary = run.refuge_ownership.to_snapshot()
		result = controller.execute_repair(REPAIR, id, before)
		_expect(not String(result.error).is_empty() and run.refuge_ownership.to_snapshot() == after, "Stale repair cannot charge again: " + source)
		result = controller.execute_repair(REPAIR, id, after)
		_expect(String(result.error).is_empty() and result.condition_after == 2 and run.refuge_ownership.get_banked_material_quantity(CLOTH) == 0, "Second repair reaches the authored maximum: " + source)
		after = run.refuge_ownership.to_snapshot()
		var saves_before: int = saves
		result = controller.execute_repair(REPAIR, id, after)
		_expect(not String(result.error).is_empty() and run.refuge_ownership.to_snapshot() == after and saves == saves_before, "Fully repaired gear cannot be charged or saved again: " + source)

func _test_tabs_and_confirmation() -> void:
	_fixture()
	var definition: EquipmentDefinition = controller.EQUIPMENT_CATALOG.get_equipment(&"red_wax_drip")
	var previous: bool = definition.player_refuge_available
	definition.player_refuge_available = true # Isolated process only; no production Resource change.
	var instance := EquipmentInstance.new()
	_expect(instance.initialize(&"fixture:workbench:wax", definition, 0).is_empty(), "Seed authored salvage fixture.")
	run.refuge_ownership.stash_equipment_instances[instance.instance_id] = instance.to_snapshot()
	run.refuge_ownership.move_stash_equipment_to_heroine(instance.instance_id, &"mira")
	var armor_id: StringName = _armor(&"seraphine")
	run.refuge_ownership.equipment_loadouts_by_heroine[&"seraphine"].instances[String(armor_id)].current_condition = 0
	var screen := load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	await process_frame
	_expect(screen.present(run, BATTLERS, KnowledgeState.new(), false, controller).is_empty(), "Bind Workbench to production controller.")
	screen.room_shell.open_station(&"repair")
	var view: RefugeWorkbenchView = screen.workbench_view
	_expect(view.tabs.tab_count == 2 and view.repair_page.visible and not view.salvage_page.visible and screen.get_node("%RepairSelected").disabled, "Repair defaults selected; unaffordable repair is disabled.")
	_expect(view.repair_preview.text.contains("Seraphine") and view.repair_preview.text.contains("0/2 → 1/2") and screen.recipe_details.text.contains("banked 0"), "Repair preview uses actual named target, cap and cost.")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	view.tabs.current_tab = 1
	await process_frame
	screen.salvage_list.select(0)
	screen.salvage_list.item_selected.emit(0)
	_expect(view.salvage_preview.text.contains("Mira") and view.salvage_preview.text.contains("1 × Red Wax"), "Salvage preview names bag and authored yield.")
	screen.get_node("%SalvageSelected").pressed.emit()
	_expect(screen.salvage_confirmation.visible and screen.salvage_confirmation.dialog_text.contains("Mira") and screen.salvage_confirmation.dialog_text.contains("1 × Red Wax"), "Destruction confirmation identifies exact source and yield.")
	screen.handle_cancel()
	_expect(not screen.salvage_confirmation.visible and screen.room_shell.modal.visible and before == run.refuge_ownership.to_snapshot() and saves == 0, "Cancel closes confirmation first without mutation.")
	# Save failure restores the exact bag reference, instance and banked Materials.
	fail_save = true
	screen.get_node("%SalvageSelected").pressed.emit()
	screen.salvage_confirmation.hide()
	screen.salvage_confirmation.confirmed.emit()
	_expect(before == run.refuge_ownership.to_snapshot() and saves == 1, "Salvage persistence failure rolls back all ownership and Materials.")
	fail_save = false
	# Moving the candidate while the dialog is open invalidates its saved preview.
	screen.get_node("%SalvageSelected").pressed.emit()
	run.refuge_ownership.equip_owned_instance(&"mira", EquipmentDefinition.Slot.MAIN_HAND, instance.instance_id)
	var equipped: Dictionary = run.refuge_ownership.to_snapshot()
	screen.salvage_confirmation.hide()
	screen.salvage_confirmation.confirmed.emit()
	_expect(equipped == run.refuge_ownership.to_snapshot() and saves == 1, "Stale salvage confirmation cannot destroy newly equipped equipment.")
	_expect(controller.get_salvage_entries().is_empty() and not String(controller.salvage_equipment(instance.instance_id).error).is_empty(), "Equipped equipment absent from Salvage and rejected by controller.")
	_expect(not String(run.refuge_ownership.salvage_owned_equipment(instance.instance_id).error).is_empty() and equipped == run.refuge_ownership.to_snapshot(), "Ownership service independently rejects equipped salvage.")
	run.refuge_ownership.unequip_owned_slot(&"mira", EquipmentDefinition.Slot.MAIN_HAND)
	run.refuge_ownership.move_unequipped_equipment_to_stash(&"mira", instance.instance_id)
	run.refuge_ownership.move_stash_equipment_to_heroine(instance.instance_id, &"mira")
	screen._refresh_all()
	screen.salvage_list.select(0)
	screen.get_node("%SalvageSelected").pressed.emit()
	screen.salvage_confirmation.hide()
	screen.salvage_confirmation.confirmed.emit()
	_expect(run.refuge_ownership.get_banked_material_quantity(&"mat_l01_red_wax") == 1 and controller.get_equipment_entry(instance.instance_id).is_empty() and saves == 2, "Confirmed salvage destroys only the selected instance and banks displayed yield once.")
	_expect(BackpackPayload.is_empty(run.refuge_ownership.preparation_slots_by_heroine[&"mira"][0]), "Salvage clears its exact Backpack reference.")
	var restored := RefugeOwnershipState.new()
	_expect(restored.restore_from_snapshot(JSON.parse_string(JSON.stringify(saved)), ITEMS, BATTLERS, HEROES).is_empty() and restored.to_snapshot() == run.refuge_ownership.to_snapshot(), "Salvaged instance removal and banked yield survive JSON reload together.")
	screen.salvage_confirmation.confirmed.emit()
	_expect(saves == 2 and run.refuge_ownership.get_banked_material_quantity(&"mat_l01_red_wax") == 1, "Duplicate confirmation does not credit twice.")
	screen.handle_cancel()
	_expect(not screen.room_shell.modal.visible and root.gui_get_focus_owner() == screen.room_shell.hotspots[&"repair"], "Workbench Cancel restores tools hotspot focus.")
	screen.queue_free()
	await process_frame
	definition.player_refuge_available = previous
