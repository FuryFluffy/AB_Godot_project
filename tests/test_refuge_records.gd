extends "res://tests/test_inventory_transfers.gd"

const MEDIA = preload("res://tests/fixtures/refuge_archive_fixture.gd")

func _run() -> void:
	_test_isolated_replay()
	await _test_records_ui()
	print("Stage 09 Refuge Records: %d failures." % failures)
	quit(failures)

func _test_isolated_replay() -> void:
	_fixture()
	var knowledge := KnowledgeState.new()
	knowledge.discovered_entries = {"butler_records": true}
	var before: Dictionary = _campaign(knowledge).duplicate(true)
	var context := DialogueContext.from_snapshot(run.narrative_state.to_snapshot())
	context.current_party_ids = HEROES.duplicate()
	context.heroine_states = run.party_snapshot # Deliberately aliased source.
	context.inventory_quantities = {&"l01_bandage_roll": 2}
	var entry := LoreEntryDefinition.new()
	entry.archive_replay_context = context.to_snapshot()
	var original: Dictionary = entry.archive_replay_context.duplicate(true)
	var graph := DialogueDefinition.new()
	graph.dialogue_id = &"stage09_isolation_fixture"
	graph.start_node_id = &"start"
	var start := DialogueNodeDefinition.new()
	start.node_id = &"start"
	start.text = "Isolation fixture"
	for kind: int in [DialogueOutcomeDefinition.Kind.SET_FLAG, DialogueOutcomeDefinition.Kind.ADD_ITEM, DialogueOutcomeDefinition.Kind.CONSUME_ITEM, DialogueOutcomeDefinition.Kind.MODIFY_HEROINE_STAT, DialogueOutcomeDefinition.Kind.GRANT_BLOOM, DialogueOutcomeDefinition.Kind.GRANT_KNOWLEDGE, DialogueOutcomeDefinition.Kind.RESOLVE_INTERACTION, DialogueOutcomeDefinition.Kind.RECRUIT_HEROINE, DialogueOutcomeDefinition.Kind.GRANT_CAMPAIGN_ITEM]:
		var outcome := DialogueOutcomeDefinition.new()
		outcome.kind = kind as DialogueOutcomeDefinition.Kind
		outcome.subject_id = &"lysandra" if kind == DialogueOutcomeDefinition.Kind.MODIFY_HEROINE_STAT else &"l01_bandage_roll" if kind == DialogueOutcomeDefinition.Kind.CONSUME_ITEM else &"fixture_reward"
		outcome.key = &"hp"
		outcome.scope = &"persistent"
		start.entry_outcomes.append(outcome)
	var choice := DialogueChoiceDefinition.new()
	choice.choice_id = &"fixture_choice"
	choice.text = "Continue fixture"
	choice.next_node_id = &"branch"
	start.choices.append(choice)
	var branch := DialogueNodeDefinition.new()
	branch.node_id = &"branch"
	branch.text = "Automatic branch fixture"
	var automatic := DialogueAutomaticTransitionDefinition.new()
	automatic.transition_id = &"fixture_auto"
	automatic.next_node_id = &"end"
	var condition := DialogueConditionDefinition.new()
	condition.kind = DialogueConditionDefinition.Kind.FLAG_SET
	condition.scope = &"persistent"
	condition.subject_id = &"fixture_reward"
	automatic.conditions = DialogueConditionGroup.new()
	automatic.conditions.conditions.append(condition)
	branch.automatic_transitions.append(automatic)
	var end := DialogueNodeDefinition.new()
	end.node_id = &"end"
	end.text = "Finished fixture"
	graph.nodes = [start, branch, end]
	entry.archive_replay = graph
	var session := ArchiveReplaySession.new()
	for repeat: int in range(2):
		_expect(session.start(entry).is_empty(), "Start isolated replay with reward-bearing entry outcomes.")
		_expect(session.runner.context.pending_bloom == 1 and session.runner.context.get_item_quantity(&"l01_bandage_roll") == 1, "Rewards and consumption affect only the playback context.")
		session.choose(&"fixture_choice")
		_expect(session.runner.get_current_node() == end and session.runner.context.choice_ids.has(&"fixture_choice"), "Choice and automatic branch see replay-local flags.")
		session.advance()
		_expect(session.runner.session.completed, "Replay completes through existing runner.")
		session.close()
		_expect(session.runner == null and entry.archive_replay_context == original and _campaign(knowledge) == before and saves == 0, "Repeated replay leaves campaign, discovery, stats, ownership, rewards and authoring context unchanged; no save.")
	for kind: int in [DialogueOutcomeDefinition.Kind.START_BATTLE, DialogueOutcomeDefinition.Kind.REQUEST_SCENE, DialogueOutcomeDefinition.Kind.CONSUME_ROOM_ITEM]:
		var unsupported := DialogueOutcomeDefinition.new()
		unsupported.kind = kind as DialogueOutcomeDefinition.Kind
		unsupported.subject_id = &"fixture"
		choice.outcomes.append(unsupported)
		_expect(not session.start(entry).is_empty() and session.runner == null, "Unsupported external gameplay in a branch gates the entire replay.")
		choice.outcomes.clear()
	start.item_policy = DialogueNodeDefinition.ItemPolicy.NORMAL_USE
	_expect(not session.start(entry).is_empty(), "Ordinary item-use scenes remain unavailable.")
	start.item_policy = DialogueNodeDefinition.ItemPolicy.DISABLED
	entry.archive_replay_context = {"heroine_states": {"lysandra": "invalid"}}
	_expect(not session.start(entry).is_empty(), "Malformed authored replay context rejects safely.")
	entry.archive_replay_context = {}
	_expect(not session.start(entry).is_empty(), "Missing replay context cannot invent a historical starting state.")

func _test_records_ui() -> void:
	_fixture()
	var knowledge := KnowledgeState.new()
	knowledge.discovered_entries = {"unknown_stale_id": true}
	var screen := load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	var configured_catalog := RefugeRecordsView.LORE.duplicate(true) as LoreCatalogDefinition
	_expect(screen.present(run, BATTLERS, knowledge, false, controller, configured_catalog).is_empty(), "Present Records with production owners.")
	var view: RefugeRecordsView = screen.records_view
	_expect(view.catalog == configured_catalog, "Records uses the campaign-configured lore catalog.")
	screen.room_shell.open_station(&"records")
	await process_frame
	_expect(view.tabs.tab_count == 4 and view.entries.is_empty() and not view.reading.text.contains("Butler"), "Unknown/undiscovered IDs reveal no authored title or lore.")
	knowledge.discovered_entries["butler_records"] = true
	view.refresh()
	_expect(view.entries.size() == 1 and view.reading.text.contains(view.catalog.entries[0].archive_text), "Discovered lore displays its exact authored archive text.")
	var original_text: String = configured_catalog.entries[0].archive_text
	configured_catalog.entries[0].archive_text = (original_text + "\n").repeat(60)
	view.refresh()
	await process_frame
	await process_frame
	_expect(view.reading.get_v_scroll_bar().max_value > view.reading.get_v_scroll_bar().page, "Long archive text scrolls within the reading pane.")
	configured_catalog.entries[0].archive_text = original_text
	var restored_knowledge := KnowledgeState.new()
	_expect(restored_knowledge.restore_from_snapshot(knowledge.to_snapshot()).is_empty(), "Discovery survives existing snapshot restoration.")
	screen.current_knowledge_state = restored_knowledge
	view.refresh()
	_expect(view.entries.size() == 1, "Restored discovery feeds the same read-only archive.")
	screen.current_knowledge_state = knowledge
	var before: Dictionary = _campaign(knowledge).duplicate(true)
	for section: int in [1, 2, 3]:
		view.tabs.current_tab = section
		_expect(view.entries.is_empty() and not view.image_button.visible and not view.replay_button.visible, "Unauthored categories expose no media actions or invented records.")
	_expect(before == _campaign(knowledge) and saves == 0, "All production category browsing is read-only.")
	view.catalog = MEDIA.catalog()
	for entry: LoreEntryDefinition in view.catalog.entries:
		knowledge.discovered_entries[String(entry.lore_id)] = true
	before = _campaign(knowledge).duplicate(true)
	view.refresh()
	_expect(view.entries.size() == 3 and view.image_button.visible and not view.replay_button.visible, "Image-only entry exposes only View Image.")
	view._open_image()
	_expect(view.nested_mode == &"image" and view.viewer_image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Larger image viewer preserves aspect ratio.")
	screen.handle_cancel()
	await process_frame
	_expect(view.nested_mode == &"" and view.entry_list.get_selected_items()[0] == 0 and root.gui_get_focus_owner() == view.entry_list, "Cancel restores Gallery selection and focus before closing station.")
	view.entry_list.select(1)
	view._select(1)
	_expect(not view.image_button.visible and view.replay_button.visible and not view.replay_button.disabled, "Scene-only entry exposes only Replay Scene.")
	view._open_replay()
	_expect(view.nested_mode == &"replay" and view.replay.runner != null, "Replay opens with existing DialoguePanel.")
	view.dialogue_panel.advance_requested.emit()
	await process_frame
	_expect(view.nested_mode == &"" and root.gui_get_focus_owner() == view.entry_list, "Completion returns to selected Gallery entry.")
	view.entry_list.select(2)
	view._select(2)
	_expect(view.image_button.visible and view.replay_button.visible, "Combined entry exposes both actions.")
	view._open_replay()
	screen.set_actions_enabled(false)
	_expect(view.dialogue_panel.continue_button.disabled, "Action lock disables an already-open replay.")
	screen.set_actions_enabled(true)
	screen.handle_cancel()
	_expect(view.replay.runner == null and view.entry_list.get_selected_items()[0] == 2, "Interrupted replay discards session and preserves selected entry.")
	view.tabs.current_tab = 0
	view.tabs.current_tab = 3
	_expect(view.entry_list.get_selected_items()[0] == 2, "Category browsing retains stable selected entry ID.")
	screen.set_actions_enabled(false)
	view._open_image()
	view._open_replay()
	_expect(view.nested_mode == &"" and view.image_button.disabled and view.replay_button.disabled, "Action lock rejects media entry.")
	screen.set_actions_enabled(true)
	knowledge.discovered_entries.erase(String(view.entries[2].lore_id))
	view._open_image()
	view._open_replay()
	_expect(view.nested_mode == &"", "Stale selection rechecks discovery before image/replay.")
	knowledge.discovered_entries[String(view.entries[2].lore_id)] = true
	_expect(before == _campaign(knowledge) and saves == 0, "UI images, completion and cancellation preserve complete live campaign and knowledge.")
	screen.handle_cancel()
	_expect(not screen.room_shell.modal.visible and root.gui_get_focus_owner() == screen.room_shell.hotspots[&"records"], "Final cancel restores books hotspot focus.")
	screen.queue_free()
	await process_frame

func _campaign(knowledge: KnowledgeState) -> Dictionary:
	return {"campaign": run.make_refuge_campaign_snapshot(), "knowledge": knowledge.to_snapshot()}
