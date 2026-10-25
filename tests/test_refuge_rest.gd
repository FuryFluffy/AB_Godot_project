extends "res://tests/test_inventory_transfers.gd"


func _run() -> void:
	_fixture()
	run.party_snapshot[&"mira"].resolve = 37
	run.party_snapshot[&"mira"].corruption = 61
	var before: Dictionary = run.make_refuge_campaign_snapshot().duplicate(true)
	_expect(RefugeManagementController.new().get_rest_heroine_entries().is_empty(), "Unbound recovery presentation is empty.")
	var entries: Array[Dictionary] = controller.get_rest_heroine_entries()
	_expect(entries.size() == 3 and entries[1].resolve == 37 and entries[1].corruption == 61, "Bed reads recruited heroines and current values, not starting values.")
	entries[1].resolve = 999
	_expect(run.party_snapshot[&"mira"].resolve == 37, "Presentation entries cannot mutate campaign state.")
	var screen := load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	_expect(screen.present(run, BATTLERS, KnowledgeState.new(), false, controller).is_empty(), "Present established Refuge.")
	await process_frame
	var view: RefugeRestView = screen.rest_view
	screen.room_shell.open_station(&"rest")
	for index: int in range(HEROES.size()):
		view.heroine_selector.select(index)
		view.heroine_selector.item_selected.emit(index)
		_expect(view.selected_heroine_id == HEROES[index] and view.values.text.contains("Resolve: %s" % run.party_snapshot[HEROES[index]].resolve) and view.values.text.contains("Corruption: %s" % run.party_snapshot[HEROES[index]].corruption), "Every heroine displays her current values.")
		_expect(view.restore_button.disabled and view.cleanse_button.disabled, "Unauthored recovery never enables.")
		view.restore_button.pressed.emit()
		view.cleanse_button.pressed.emit()
	_expect(before == run.make_refuge_campaign_snapshot() and saves == 0, "Browsing and forced disabled signals cannot spend, recover, save or reorder party.")
	view.heroine_selector.select(1)
	view.heroine_selector.item_selected.emit(1)
	run.party_snapshot[&"mira"].resolve = 42
	controller.state_changed.emit()
	_expect(view.selected_heroine_id == &"mira" and view.values.text.contains("Resolve: 42"), "Refresh preserves selected target and reads changed state.")
	view.heroine_selector.show_popup()
	await process_frame
	screen.handle_cancel()
	_expect(not view.heroine_selector.get_popup().visible and screen.room_shell.active_station == &"rest", "First Cancel closes selector only.")
	screen.handle_cancel()
	_expect(not screen.room_shell.modal.visible and root.gui_get_focus_owner() == screen.room_shell.hotspots[&"rest"], "Second Cancel restores bed focus.")
	screen.set_actions_enabled(false)
	view._select_heroine(0)
	_expect(view.heroine_selector.disabled and view.selected_heroine_id == &"mira", "Action lock also disables target changes.")
	screen.set_actions_enabled(true)
	_expect(not view.heroine_selector.disabled and view.restore_button.disabled and view.cleanse_button.disabled, "Unlocking actions cannot activate unavailable recovery.")
	run.party_snapshot.erase(&"mira")
	view.refresh()
	_expect(view.values.text.contains("Resolve: Unavailable") and view.values.text.contains("Corruption: Unavailable"), "Missing campaign snapshot never fabricates current values.")
	run.refuge_ownership.known_heroine_ids = []
	view.refresh()
	_expect(view.heroine_selector.disabled and view.selected_heroine_id == &"" and view.values.text == "No heroine available.", "Empty roster has no stale target.")
	_expect(saves == 0, "Presentation never invokes persistence.")
	screen.queue_free()
	await process_frame
	print("Stage 07 Refuge Rest: %d failures." % failures)
	quit(failures)
