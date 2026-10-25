extends "res://tests/test_inventory_transfers.gd"

func _run() -> void:
	CampaignSaveSlotStore.set_test_save_directory("user://stage08_expedition_tests")
	_test_party_transaction()
	_test_subset_round_trip(false)
	_test_subset_round_trip(true)
	_test_floor_history()
	_test_legacy_active_snapshot()
	await _test_expedition_ui()
	CampaignSaveSlotStore.clear_test_save_directory()
	print("Stage 08 Refuge Expedition: %d failures." % failures)
	quit(failures)

func _test_party_transaction() -> void:
	_fixture()
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	var desired: Array[StringName] = [&"mira", &"lysandra"]
	fail_save = true
	var result: Dictionary = controller.apply_party_order(desired, HEROES)
	_expect(result.error == "Injected save failure" and run.refuge_ownership.to_snapshot() == before, "Party persistence failure rolls back ownership and selection.")
	fail_save = false
	_expect(String(controller.apply_party_order(desired, HEROES).error).is_empty() and run.refuge_ownership.selected_party_ids == desired, "One to three heroines can be saved in click order.")
	var count: int = saves
	_expect(String(controller.apply_party_order(desired, desired).error).is_empty() and saves == count, "Same party is a free no-op without saving.")
	_expect(not String(controller.apply_party_order(HEROES, HEROES).error).is_empty() and saves == count, "Stale Party draft cannot overwrite newer selection.")
	for invalid: Array in [[], [&"mira", &"mira"], [&"unknown"], [&"lysandra", &"mira", &"seraphine", &"unknown"]]:
		var ids: Array[StringName] = []
		ids.assign(invalid)
		_expect(not String(controller.apply_party_order(ids, desired).error).is_empty() and saves == count, "Invalid party remains free and unchanged.")

func _test_subset_round_trip(defeated: bool) -> void:
	_fixture()
	var desired: Array[StringName] = [&"mira"]
	if not defeated:
		desired.append(&"lysandra")
	run.refuge_ownership.set_selected_party_order(desired)
	for id: StringName in HEROES:
		run.refuge_ownership.add_preparation_item(id, StringName(A), 2)
	run.refuge_ownership.add_stash_item(StringName(M), 1)
	run.refuge_ownership.assign_memento(&"seraphine", StringName(M))
	run.party_snapshot[&"seraphine"].resolve = 43
	run.party_snapshot[&"seraphine"].corruption = 27
	_expect(run.refuge_ownership.restore_from_snapshot(run.refuge_ownership.to_snapshot(), ITEMS, BATTLERS, HEROES).is_empty(), "Normalize existing legacy loadout fields before comparison.")
	var inactive_before: Dictionary = run.party_snapshot[&"seraphine"].duplicate(true)
	var record_before: Dictionary = run.refuge_ownership.to_snapshot().heroine_records.seraphine.duplicate(true)
	run.bloom = 19
	var generator := LayerMapGenerator.new()
	_expect(CampaignSaveSlotStore.save_refuge_slot(1, run, KnowledgeState.new()).is_empty(), "Production slot stores selected party at Refuge.")
	_expect(run.begin_next_layer_2_run(generator.generate_layer_2_run(808)).is_empty(), "Selected party departs through existing Layer 2 boundary.")
	_expect(run.bloom == 0 and run._make_current_party_ids() == desired and run.run_inventory.backpacks_by_heroine.size() == desired.size() and run.run_equipment.loadouts_by_heroine.size() == desired.size(), "Only ordered active heroines deploy; existing Bloom discard retained.")
	_expect(run.inactive_party_snapshot[&"seraphine"] == inactive_before and run.refuge_ownership.equipment_loadouts_by_heroine.has(&"seraphine") and not run.run_inventory.backpacks_by_heroine.has(&"seraphine"), "Inactive state and gear stay in Refuge without duplicate bags.")
	_expect(RefugeProductionProvider.new(run.refuge_ownership).fork() == null, "Retained inactive gear cannot unlock Refuge production during a run.")
	var slot_error: String = CampaignSaveSlotStore.save_active_run_slot(1, run, KnowledgeState.new(), "post_node")
	_expect(slot_error.is_empty(), "Production slot validates and atomically stores subset safe point: " + slot_error)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(run.make_active_run_snapshot("post_node", KnowledgeState.new())))
	var restored := RunState.new()
	var error: String = restored.restore_active_run_snapshot(snapshot, BATTLERS)
	_expect(error.is_empty(), "Subset active safe point restores: " + error)
	if not error.is_empty():
		return
	_expect(restored._make_current_party_ids() == desired and restored.party_snapshot.keys()[0] == &"mira", "JSON sorting cannot change committed party order.")
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed.run_snapshot.inactive_party_snapshot = {}
	_expect(not RunState.new().restore_active_run_snapshot(malformed, BATTLERS).is_empty(), "Missing inactive heroine snapshot rejects.")
	malformed = snapshot.duplicate(true)
	malformed.run_snapshot.inactive_party_snapshot.mira = inactive_before
	_expect(not RunState.new().restore_active_run_snapshot(malformed, BATTLERS).is_empty(), "An active heroine cannot also be stored as inactive.")
	var travel: String = restored.travel_to(&"l2_c1_n0")
	_expect(travel.is_empty() and restored.prepare_pending_node_seed().is_empty(), "Selected party can enter a node with a stable seed.")
	var encounter: EncounterDefinition = restored.make_encounter_definition()
	_expect(encounter != null and encounter.party_ids == desired, "Encounter receives committed party order.")
	_expect(CampaignSaveSlotStore.save_active_run_slot(1, restored, KnowledgeState.new(), "pre_node").is_empty(), "Production slot accepts subset pre-node safe point.")
	var pre: Dictionary = JSON.parse_string(JSON.stringify(restored.make_active_run_snapshot("pre_node", KnowledgeState.new())))
	var resumed := RunState.new()
	_expect(resumed.restore_active_run_snapshot(pre, BATTLERS).is_empty() and resumed.pending_node_seed == restored.pending_node_seed and resumed._make_current_party_ids() == desired, "Interrupted-node reload preserves selected party and content seed.")
	# Exercise the existing Event-room return boundary with the selected set.
	for node: MapNodeState in restored.graph.nodes.values():
		if not node.requires_event_room():
			continue
		restored.current_node_id = node.node_id
		restored.pending_node_id = &""
		var event := EventRoomOutcome.new()
		event.source_node_id = node.node_id
		event.inventory_snapshot = restored.inventory_snapshot.duplicate(true)
		event.run_inventory_snapshot = restored.get_run_inventory_snapshot()
		event.party_snapshot = restored.party_snapshot.duplicate(true)
		event.clear_node = false
		_expect(restored.apply_event_room_outcome(event).is_empty(), "Event-room outcome preserves subset inventory ownership.")
		break
	if defeated:
		var outcome := EncounterOutcome.new()
		outcome.result = EncounterOutcome.Result.DEFEAT
		outcome.party_snapshot = restored.party_snapshot.duplicate(true)
		outcome.party_snapshot[&"mira"].hp = 0
		outcome.party_snapshot[&"mira"].resolve = 55
		outcome.inventory_snapshot = restored.inventory_snapshot.duplicate(true)
		error = restored.apply_post_refuge_defeat(outcome, generator.generate_bloom_refuge_holding_state(808), BATTLERS)
	else:
		error = restored.return_current_run_to_refuge(generator.generate_bloom_refuge_holding_state(808), BATTLERS)
	_expect(error.is_empty(), "Subset return/defeat succeeds: " + error)
	_expect(restored.party_snapshot.size() == 3, "Every heroine reunites at Refuge.")
	_expect(restored.party_snapshot[&"seraphine"] == JSON.parse_string(JSON.stringify(inactive_before)), "Inactive HP/MP/Resolve/Corruption survive JSON reload unchanged.")
	_expect(restored.refuge_ownership.to_snapshot().heroine_records.seraphine == record_before, "Inactive gear, Memento and bag survive unchanged.")
	_expect(restored.refuge_ownership.selected_party_ids == desired and restored.inactive_party_snapshot.is_empty(), "Reunion retains party selection and clears deployment-only state.")
	var returned := RunState.new()
	_expect(returned.restore_refuge_campaign_snapshot(restored.make_refuge_campaign_snapshot(), generator.generate_bloom_refuge_holding_state(808), BATTLERS).is_empty(), "Reunited campaign remains compatible with Refuge save/load.")

func _test_floor_history() -> void:
	var state := CampaignLifecycleState.new()
	state.initialize_new(42)
	state.begin_refugeless_ascent(&"test")
	_expect(state.accessed_layer_ids == [&"layer_1"] and state.refugeless_layer_seeds.size() == 10, "Generated ten-layer seed manifest does not imply access.")
	state.mark_layer_accessed(&"layer_2")
	_expect(state.defeated_boss_ids.is_empty(), "Reaching Layer 2 grants no boss defeat or Passage eligibility.")
	state.establish_refuge()
	state.begin_refuge_run(99)
	state.finish_active_run()
	var restored := CampaignLifecycleState.new()
	_expect(restored.restore_from_snapshot(JSON.parse_string(JSON.stringify(state.to_snapshot()))).is_empty() and restored.accessed_layer_ids == state.accessed_layer_ids, "Access history persists across run end and JSON reload.")
	var legacy: Dictionary = state.to_snapshot()
	legacy.erase("accessed_layer_ids")
	_expect(restored.restore_from_snapshot(legacy).is_empty() and restored.accessed_layer_ids == [&"layer_1", &"layer_2"], "Legacy Refuge infers only established Layer 1–2 access.")
	var before: Dictionary = restored.to_snapshot()
	for invalid: Variant in [null, 2, ["layer_2", "layer_2"], ["layer_11"], [7]]:
		var bad: Dictionary = state.to_snapshot()
		bad.accessed_layer_ids = invalid
		_expect(not restored.restore_from_snapshot(bad).is_empty() and restored.to_snapshot() == before, "Malformed explicit floor history rejects without committing.")

func _test_expedition_ui() -> void:
	_fixture()
	var screen := load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	_expect(screen.present(run, BATTLERS, KnowledgeState.new(), false, controller).is_empty(), "Expedition view binds existing campaign.")
	await process_frame
	screen.room_shell.open_station(&"expedition")
	var view: RefugeExpeditionView = screen.expedition_view
	var before: Dictionary = run.make_refuge_campaign_snapshot().duplicate(true)
	view.show_section(&"party")
	view._toggle_heroine(&"lysandra")
	view._toggle_heroine(&"seraphine")
	view._toggle_heroine(&"lysandra")
	_expect(view.draft == [&"mira", &"lysandra"] and not view.can_explore() and screen.begin_button.disabled, "Draft click order disables Explore until applied.")
	screen.handle_cancel()
	_expect(view.section == &"hub" and view.draft == [&"mira", &"lysandra"] and before == run.make_refuge_campaign_snapshot() and saves == 0, "Back preserves draft without saving, charging or mutating roster.")
	view.show_section(&"party")
	fail_save = true
	view._apply_party()
	_expect(run.refuge_ownership.selected_party_ids == HEROES and not view.can_explore(), "Failed Apply retains draft and original party.")
	fail_save = false
	view._apply_party()
	_expect(view.can_explore() and run.refuge_ownership.selected_party_ids == [&"mira", &"lysandra"], "Apply commits draft and enables Explore.")
	var order: Array[StringName] = run.refuge_ownership.selected_party_ids.duplicate()
	screen.inventory_heroine.select(2)
	screen._on_inventory_heroine_selected(2)
	_expect(screen.backpack_heroine_id == &"seraphine" and run.refuge_ownership.selected_party_ids == order, "Inspecting an inactive heroine Backpack never selects her for the run.")
	for hero: StringName in HEROES:
		view.progress_heroine = hero
		for tab: int in range(3):
			view.progress_tabs.current_tab = tab
			view._refresh_progression()
			_expect(not view.progress_rows.is_empty() and view.upgrade_button.disabled, "Every heroine exposes authored progression with no paid shell.")
	view.show_section(&"intel")
	view.intel_tabs.current_tab = 1
	_expect(view.intel_list.get_child_count() == 10 and run.refuge_ownership.selected_party_ids == order, "Permanent Intel includes Submit and cannot change roster.")
	screen.handle_cancel()
	screen.handle_cancel()
	_expect(not screen.room_shell.modal.visible and root.gui_get_focus_owner() == screen.room_shell.hotspots[&"expedition"], "Nested Back then Close restores map hotspot.")
	screen.set_actions_enabled(false)
	_expect(not view.can_explore() and screen.begin_button.disabled and view.apply_button.disabled, "Screen action lock protects Apply and Explore.")
	screen.queue_free()
	await process_frame


func _test_legacy_active_snapshot() -> void:
	_fixture()
	var generator := LayerMapGenerator.new()
	_expect(run.begin_next_layer_2_run(generator.generate_layer_2_run(1808)).is_empty(), "Full roster starts before legacy compatibility probe.")
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(run.make_active_run_snapshot("post_node", KnowledgeState.new())))
	legacy.run_snapshot.erase("inactive_party_snapshot")
	legacy.run_snapshot.campaign_lifecycle.erase("accessed_layer_ids")
	var restored := RunState.new()
	_expect(restored.restore_active_run_snapshot(legacy, BATTLERS).is_empty() and restored.inactive_party_snapshot.is_empty() and restored.campaign_lifecycle.accessed_layer_ids == [&"layer_1", &"layer_2"], "Legacy full-roster v3 active snapshot loads with safe absent-field defaults.")
