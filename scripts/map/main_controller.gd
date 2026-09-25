class_name AbyssalBloomMainController
extends Node


@export var combat_scene: PackedScene
@export var event_room_scene: PackedScene
@export var refuge_scene: PackedScene
@export var event_room_catalog: EventRoomCatalogDefinition
@export var map_screen: Control
@export var map_view: LayerMapView
@export var seed_edit: LineEdit
@export var progress_label: Label
@export var layer_title_label: Label
@export var node_title_label: Label
@export var node_detail_label: Label
@export var travel_button: Button
@export var resolve_node_button: Button
@export var new_run_button: Button
@export var return_to_refuge_button: Button
@export var combat_host: Node
@export var event_room_host: Node
@export var refuge_host: Node
@export var return_overlay: Control
@export var return_summary_label: Label
@export var return_to_map_button: Button
@export var boot_fallback: Control
@export var boot_status_label: Label
@export var developer_grant_weapon_techniques_on_new_run: bool = true
@export var item_catalog: ItemCatalogDefinition
@export var battler_catalog: BattlerCatalogDefinition
@export var lore_catalog: LoreCatalogDefinition
@export var dialogue_catalog: DialogueCatalogDefinition
@export var combat_stage_catalog: CombatStageCatalog


var generator: LayerMapGenerator = LayerMapGenerator.new()
var run_state: RunState = RunState.new()
var active_battle: CombatEncounter
var active_event_room: EventRoomScreen
var active_refuge: BloomRefugeScreen
var pending_outcome: EncounterOutcome
var knowledge_state: KnowledgeState = KnowledgeState.new()
var active_save_slot_id: int = 0
var autosave_blocking_error: String = ""
var dialogue_binding_error: String = ""
var active_stage_trigger: ExplorationStageTriggerState


func _ready() -> void:
	map_screen.visible = false
	return_overlay.visible = false
	boot_fallback.visible = true
	boot_status_label.text = "Waiting for the main menu..."
	map_view.map_node_pressed.connect(_on_map_node_pressed)
	travel_button.pressed.connect(_on_travel_pressed)
	resolve_node_button.pressed.connect(_on_resolve_node_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	return_to_refuge_button.pressed.connect(_on_return_to_refuge_pressed)
	return_to_map_button.pressed.connect(_on_return_to_map_pressed)
	combat_host.process_mode = Node.PROCESS_MODE_INHERIT
	event_room_host.process_mode = Node.PROCESS_MODE_INHERIT
	refuge_host.process_mode = Node.PROCESS_MODE_INHERIT


func start_new_campaign(seed: int, slot_id: int) -> String:
	if seed <= 0:
		return "A new campaign requires a positive whole-number seed."
	if not CampaignSaveSlotStore.is_valid_slot_id(slot_id):
		return "A new campaign requires a valid save slot."
	active_save_slot_id = slot_id
	knowledge_state = KnowledgeState.new()
	run_state = RunState.new()
	return _start_new_run(seed)


func load_campaign_slot(slot_id: int) -> String:
	if not CampaignSaveSlotStore.is_valid_slot_id(slot_id):
		return "Invalid campaign save slot."
	active_save_slot_id = slot_id
	knowledge_state = KnowledgeState.new()
	run_state = RunState.new()
	return _load_campaign_from_slot(slot_id)


func continue_active_run_slot(slot_id: int) -> String:
	if not CampaignSaveSlotStore.is_valid_slot_id(slot_id):
		return "Invalid campaign save slot."
	var read_result: Dictionary = CampaignSaveSlotStore.read_document_for_load(slot_id)
	var read_error: String = String(read_result.get("error", ""))
	if not read_error.is_empty():
		return read_error
	var envelope_value: Variant = read_result.get("document", {})
	if not (envelope_value is Dictionary):
		return "Campaign save did not contain a valid v3 envelope."
	var active_value: Variant = (envelope_value as Dictionary).get(
		"active_run_snapshot",
		null
	)
	if not (active_value is Dictionary):
		return "That campaign slot has no resumable active-run safe point."
	var staged_run := RunState.new()
	var restore_error: String = staged_run.restore_active_run_snapshot(
		(active_value as Dictionary).duplicate(true),
		battler_catalog
	)
	if not restore_error.is_empty():
		return restore_error
	var run_snapshot: Dictionary = (active_value as Dictionary).get(
		"run_snapshot",
		{}
	) as Dictionary
	var knowledge_value: Variant = run_snapshot.get("knowledge_state", null)
	if not (knowledge_value is Dictionary):
		return "Active-run safe point contains invalid knowledge state."
	var staged_knowledge := KnowledgeState.new()
	var knowledge_error: String = staged_knowledge.restore_from_snapshot(
		(knowledge_value as Dictionary).duplicate(true)
	)
	if not knowledge_error.is_empty():
		return knowledge_error

	_retire_active_battle()
	_retire_active_event_room()
	_retire_active_refuge()
	active_save_slot_id = slot_id
	run_state = staged_run
	knowledge_state = staged_knowledge
	autosave_blocking_error = ""
	run_state.run_changed.connect(_refresh_map)
	map_view.bind_map(run_state.graph, run_state)
	boot_fallback.visible = false
	return_overlay.visible = false
	pending_outcome = null
	if String((active_value as Dictionary).get("safe_point_kind", "")) == "pre_node":
		_enter_pending_node_content()
	else:
		map_screen.visible = true
		_refresh_map()
	return ""


func _start_new_run(
	seed: int,
	recovery_party_snapshot: Dictionary = {},
	recovery_narrative_snapshot: Dictionary = {},
	recovery_lifecycle_snapshot: Dictionary = {}
) -> String:
	_retire_active_battle()
	_retire_active_event_room()
	_retire_active_refuge()
	if run_state.run_changed.is_connected(_refresh_map):
		run_state.run_changed.disconnect(_refresh_map)
	var graph: LayerMapGraph = (
		generator.generate_layer_1(
			seed
		)
	)
	if graph == null:
		var generation_error: String = generator.last_generation_error
		if generation_error.is_empty():
			generation_error = "Layer 1 authored-map generation failed."
		boot_status_label.text = generation_error
		boot_fallback.visible = true
		return generation_error

	var generated_item_rules: Array[GeneratedRoomItemPlacementRule] = (
		generator
			.make_layer_1_generated_room_item_rules()
	)

	var error: String = run_state.initialize(
		seed,
		graph,
		generated_item_rules,
		recovery_party_snapshot,
		recovery_narrative_snapshot,
		recovery_lifecycle_snapshot
	)
	if not error.is_empty():
		push_error("Layer 1 map generation failed: %s" % error)
		boot_status_label.text = (
			"Layer 1 map generation failed:\n%s\nCheck the Output panel."
			% error
		)
		return error
	if developer_grant_weapon_techniques_on_new_run:
		run_state.grant_developer_weapon_techniques()
	run_state.run_changed.connect(_refresh_map)
	map_view.bind_map(graph, run_state)
	map_screen.visible = false
	return_overlay.visible = false
	return_to_refuge_button.visible = false
	new_run_button.visible = true
	pending_outcome = null
	_refresh_map()
	boot_fallback.visible = false
	_launch_opening_battle()
	return ""


func _refresh_map() -> void:
	layer_title_label.text = run_state.graph.display_name
	progress_label.text = run_state.get_progress_text()
	map_view.refresh()
	return_to_refuge_button.visible = (
		run_state.has_established_refuge()
		and run_state.graph.layer_id != &"bloom_refuge"
	)
	new_run_button.visible = run_state.is_tutorial_pre_refuge()
	var selected: MapNodeState = run_state.graph.get_map_node(
		run_state.selected_node_id
	)
	if selected == null:
		node_title_label.text = "Select a node"
		node_detail_label.text = (
			"The last resolved safe point could not be written.\n%s"
			% autosave_blocking_error
			if not autosave_blocking_error.is_empty()
			else ""
		)
		travel_button.disabled = true
		resolve_node_button.visible = false
		return

	node_title_label.text = selected.display_name
	var map_state: MapNodeState.MapState = (
		run_state.get_node_map_state(selected.node_id)
	)
	node_detail_label.text = (
		"%s | Column %d | %s\n%s"
		% [
			selected.get_type_label(),
			selected.column,
			_state_label(map_state),
			_node_behavior_text(selected),
		]
	)
	travel_button.disabled = not run_state.can_travel_to(
		selected.node_id
	) or not autosave_blocking_error.is_empty()
	travel_button.text = (
		"Travel to %s" % selected.get_type_label()
		if not travel_button.disabled
		else "Select a connected node or reachable cleared passage"
	)
	resolve_node_button.visible = (
		run_state.pending_node_id == selected.node_id
		and not selected.requires_battle()
		and not selected.requires_event_room()
		and not selected.cleared
	)
	if not autosave_blocking_error.is_empty():
		node_detail_label.text += (
			"\nThe last resolved safe point could not be written.\n%s"
			% autosave_blocking_error
		)


func _on_map_node_pressed(node_id: StringName) -> void:
	run_state.select_node(node_id)


func _on_travel_pressed() -> void:
	var target: MapNodeState = run_state.graph.get_map_node(run_state.selected_node_id)
	var target_was_visited: bool = target.visited if target != null else false
	var lifecycle_before: Dictionary = run_state.make_campaign_lifecycle_snapshot()
	var travel_error: String = run_state.travel_to(
		run_state.selected_node_id
	)
	if not travel_error.is_empty():
		node_detail_label.text = travel_error
		return
	if run_state.is_at_refugeless_farthest_cell():
		_launch_farthest_cell_refuge_establishment()
		return
	if run_state.pending_node_id != &"":
		var seed_error: String = run_state.prepare_pending_node_seed()
		var save_error: String = seed_error
		if save_error.is_empty():
			save_error = _save_active_run_safe_point("pre_node")
		if not save_error.is_empty():
			var rollback_error: String = run_state.rollback_pending_node_entry(
				run_state.current_node_id,
				target_was_visited,
				lifecycle_before
			)
			var displayed_error: String = (
				save_error if rollback_error.is_empty()
				else "%s\n%s" % [save_error, rollback_error]
			)
			_refresh_map()
			node_detail_label.text = displayed_error
			return
		_enter_pending_node_content()
		return
	_write_post_node_safe_point()
	if target != null and target.requires_event_room():
		_launch_event_room(target)
		return
	_refresh_map()


func _enter_pending_node_content() -> void:
	var node: MapNodeState = run_state.graph.get_map_node(
		run_state.current_node_id
	)
	if node == null or run_state.pending_node_id != node.node_id:
		node_detail_label.text = "The pending map node is unavailable."
		return
	if node.requires_battle() and not node.cleared:
		if run_state.requires_seraphine_recruitment_prelude():
			_launch_seraphine_recruitment_prelude()
		else:
			_launch_pending_battle()
	elif node.requires_event_room():
		_launch_event_room(node)
	else:
		map_screen.visible = true
		_refresh_map()


func _on_resolve_node_pressed() -> void:
	var node: MapNodeState = run_state.graph.get_map_node(
		run_state.pending_node_id
	)
	if (
		node == null 
		or node.requires_battle()
		or node.requires_event_room()
	):
		return
	var reward: int = (
		5 if node.node_type == MapNodeState.NodeType.ITEM else 2
	)
	var item_reward_text: String = ""
	var reward_claimed: bool = true
	if node.node_type == MapNodeState.NodeType.ITEM:
		var reward_result: Dictionary = run_state.resolve_pending_node_reward()
		var item_error: String = String(reward_result.get("error", ""))
		reward_claimed = bool(reward_result.get("claimed", false))
		var record: Dictionary = reward_result.get("record", {}) as Dictionary
		item_reward_text = (
			" + %d %s"
			% [record.get("quantity", 0), record.get("item_id", "item")]
			if item_error.is_empty()
			else " (item reward deferred: %s)" % item_error
		)
	var error: String = run_state.complete_pending_node(
		reward,
		reward_claimed
	)
	if not error.is_empty():
		node_detail_label.text = error
		return
	_write_post_node_safe_point()
	node_detail_label.text = (
		"Node cleared. First-clear reward: %d Bloom%s."
		% [reward, item_reward_text]
	)
	_refresh_map()


func _launch_pending_battle() -> void:
	var encounter: EncounterDefinition = (
		run_state.make_encounter_definition()
	)
	_launch_encounter(encounter)


func _launch_opening_battle() -> void:
	var encounter: EncounterDefinition = (
		run_state.make_opening_encounter_definition()
	)
	_launch_encounter(encounter)


func _launch_encounter(
	encounter: EncounterDefinition,
	requested_trigger_type: StringName = &"",
	requested_trigger_id: StringName = &""
) -> void:
	if encounter == null or combat_scene == null:
		_show_battle_launch_error("Encounter definition is unavailable.")
		return
	var stage_trigger: ExplorationStageTriggerState
	if combat_stage_catalog != null:
		var stage_binding: CombatStageBindingDefinition = (
			combat_stage_catalog.get_binding(
				encounter.encounter_id,
				encounter.authored_room_id
			)
		)
		if stage_binding == null:
			_show_battle_launch_error(
				"No combat-stage binding exists for encounter '%s'."
				% encounter.encounter_id
			)
			return
		if (
			requested_trigger_id != &""
			and requested_trigger_id != stage_binding.trigger_id
		):
			_show_battle_launch_error(
				"Combat-stage binding expected trigger '%s', not '%s'."
				% [stage_binding.trigger_id, requested_trigger_id]
			)
			return
		encounter.combat_stage_id = stage_binding.combat_stage_id
		stage_trigger = ExplorationStageTriggerState.new()
		var trigger_error: String = stage_trigger.configure(stage_binding)
		if not trigger_error.is_empty():
			_show_battle_launch_error(trigger_error)
			return
		if stage_binding.trigger_type == &"delayed_on_enter":
			_show_battle_launch_error(
				"Delayed combat-stage bindings require an exploration-room host."
			)
			return
		var activation_type: StringName = (
			requested_trigger_type
			if requested_trigger_type != &""
			else stage_binding.trigger_type
		)
		if not stage_trigger.activate(activation_type):
			_show_battle_launch_error(
				"Combat-stage trigger '%s' did not fire." % stage_binding.trigger_id
			)
			return
	_retire_active_battle()
	active_stage_trigger = stage_trigger
	active_battle = combat_scene.instantiate() as CombatEncounter
	if active_battle == null:
		_show_battle_launch_error("CombatEncounter could not be instantiated.")
		return
	active_battle.base_seed = encounter.encounter_seed
	active_battle.prepare_run_encounter(
		encounter,
		run_state.party_snapshot,
		run_state.inventory_snapshot,
		run_state.heroine_progression_snapshot,
		run_state.run_equipment
	)
	active_battle.encounter_outcome_ready.connect(
		_on_encounter_outcome_ready
	)
	if requested_trigger_type == &"interaction":
		_retire_active_event_room()
	combat_host.add_child(active_battle)
	map_screen.visible = false
	return_overlay.visible = false


func _show_battle_launch_error(message: String) -> void:
	node_detail_label.text = message
	boot_status_label.text = "%s\nCheck the Output panel." % message
	boot_fallback.visible = true

func _launch_event_room(
	node: MapNodeState
) -> void:
	if node == null:
		node_detail_label.text = (
			"Event-room map node is unavailable."
		)
		return

	if event_room_scene == null:
		node_detail_label.text = (
			"EventRoomScreen scene is not assigned."
		)
		return

	if event_room_catalog == null:
		node_detail_label.text = (
			"Event-room catalogue is not assigned."
		)
		return
		
	if lore_catalog == null:
		node_detail_label.text = "Lore catalogue is not assigned"
		return

	if event_room_host == null:
		node_detail_label.text = (
			"EventRoomHost is not assigned."
		)
		return

	var definition: EventRoomDefinition = (
		event_room_catalog.get_room(
			node.room_definition_id
		)
	)
	if definition == null and generator.room_catalog != null:
		var registered_room: LayerRoomDefinition = (
			generator.room_catalog.get_room(node.room_definition_id)
		)
		if registered_room != null:
			definition = registered_room.exploration_definition

	if definition == null:
		node_detail_label.text = (
			"Unknown Event-room definition: %s."
			% node.room_definition_id
		)
		return

	_retire_active_event_room()

	active_event_room = (
		event_room_scene.instantiate()
		as EventRoomScreen
	)

	if active_event_room == null:
		node_detail_label.text = (
			"EventRoomScreen could not be instantiated."
		)
		return

	active_event_room.room_outcome_ready.connect(
		_on_event_room_outcome_ready
	)
	active_event_room.room_encounter_requested.connect(
		_on_event_room_encounter_requested
	)

	event_room_host.add_child(active_event_room)

	var room_state: EventRoomInstanceState
	room_state = run_state.get_event_room_state(
		node.node_id,
		definition.room_id
	)
	var narrative_snapshot: Dictionary = (
		run_state.get_narrative_state_snapshot()
	)
	if narrative_snapshot.is_empty():
		var retreat_error: String = ""
		if run_state.pending_node_id == node.node_id:
			retreat_error = run_state.retreat_from_pending_event_room(
				node.node_id
			)
		node_detail_label.text = (
			"The run narrative state is unavailable."
			if retreat_error.is_empty()
			else "The run narrative state is unavailable.\n%s" % retreat_error
		)
		_retire_active_event_room()
		_refresh_map()
		return

	var preparation_error: String
	preparation_error = active_event_room.prepare_room(
		definition,
		room_state,
		item_catalog,
		battler_catalog,
		lore_catalog,
		knowledge_state,
		run_state.graph.layer_number,
		run_state.inventory_snapshot,
		run_state.party_snapshot,
		narrative_snapshot,
		run_state.get_run_inventory_snapshot(),
		run_state.run_equipment
	)

	if not preparation_error.is_empty():
		push_error(preparation_error)
		var retreat_error: String = ""
		if run_state.pending_node_id == node.node_id:
			retreat_error = run_state.retreat_from_pending_event_room(
				node.node_id
			)
		node_detail_label.text = (
			preparation_error
			if retreat_error.is_empty()
			else "%s\n%s" % [preparation_error, retreat_error]
		)
		_retire_active_event_room()
		_refresh_map()
		return
	active_event_room.set_room_encounter_resolved(
		node.cleared
		or (
			node.encounter_id != &""
			and run_state.completed_encounters.has(node.encounter_id)
		)
	)

	map_screen.visible = false
	return_overlay.visible = false


func _on_event_room_encounter_requested(trigger_id: StringName) -> void:
	var node: MapNodeState = run_state.graph.get_map_node(
		run_state.current_node_id
	) if run_state.graph != null else null
	if (
		node == null
		or node.cleared
		or run_state.pending_node_id != node.node_id
		or not node.requires_event_room()
		or not node.has_encounter_content()
	):
		node_detail_label.text = (
			"This room has no unresolved authored encounter."
		)
		return
	var encounter: EncounterDefinition = run_state.make_encounter_definition()
	if encounter == null:
		node_detail_label.text = "The room encounter could not be prepared."
		return
	_launch_encounter(encounter, &"interaction", trigger_id)


func _on_event_room_outcome_ready(
	outcome: EventRoomOutcome
) -> void:
	var apply_error: String = (
		run_state.apply_event_room_outcome(outcome)
	)
	
	if not apply_error.is_empty():
		push_error(apply_error)
		return
	_write_post_node_safe_point()
		
	_retire_active_event_room()
	map_screen.visible = true
	return_overlay.visible = false
	_refresh_map()

func _on_encounter_outcome_ready(
	outcome: EncounterOutcome
) -> void:
	pending_outcome = outcome
	var is_opening: bool = (
		run_state.is_opening_encounter_outcome(outcome)
	)
	if is_opening:
		return_to_map_button.text = (
			"Enter the Layer 1 Map"
			if outcome.result == EncounterOutcome.Result.VICTORY
			else "Return to the Beginning"
		)
		return_summary_label.text = (
			"Victory\nThe way into the Lower Castle is open."
			if outcome.result == EncounterOutcome.Result.VICTORY
			else "Defeat\nLysandra must overcome the Hollow Servant."
		)
		return_overlay.visible = true
		return
	if run_state.is_mira_recruitment_encounter_outcome(outcome):
		return_to_map_button.text = (
			"Speak with Mira"
			if outcome.result == EncounterOutcome.Result.VICTORY
			else "Return to the Beginning"
		)
		return_summary_label.text = (
			"Victory\nThe Corrupted Butler falls. Mira is still standing."
			if outcome.result == EncounterOutcome.Result.VICTORY
			else (
				"Defeat\nThe run has failed. Mira remains unrecruited. "
				+ "Lysandra will recover at the beginning of Layer 1."
			)
		)
		return_overlay.visible = true
		return
	if run_state.is_seraphine_recruitment_encounter_outcome(outcome):
		return_to_map_button.text = (
			"Speak with Seraphine"
			if outcome.result == EncounterOutcome.Result.VICTORY
			else "Return to the Beginning"
		)
		return_summary_label.text = (
			"Victory\nThe false prayer falls silent. Seraphine's ward holds."
			if outcome.result == EncounterOutcome.Result.VICTORY
			else (
				"Defeat\nThe run has failed. Seraphine remains unrecruited. "
				+ "The recruited party will recover at the beginning of Layer 1."
			)
		)
		return_overlay.visible = true
		return
	if run_state.is_blood_nun_encounter_outcome(outcome):
		return_to_map_button.text = (
			"Hear the Blood Nun"
			if outcome.result == EncounterOutcome.Result.VICTORY
			else "Return to the Beginning"
		)
		return_summary_label.text = (
			"Victory\nThe Processing Chapel falls silent."
			if outcome.result == EncounterOutcome.Result.VICTORY
			else (
				"Defeat\nThe run has failed. The recruited party will "
				+ "recover at the beginning of Layer 1."
			)
		)
		return_overlay.visible = true
		return
	if run_state.is_jailer_first_encounter_outcome(outcome):
		if outcome.result == EncounterOutcome.Result.DEFEAT:
			if run_state.has_established_refuge():
				return_to_map_button.text = "Return to the Bloom Refuge"
				return_summary_label.text = (
					"Defeat\nThe Jailer ends this run. The party will recover "
					+ "in the Bloom Refuge."
				)
			else:
				return_to_map_button.text = "Awaken in the Farthest Cell"
				return_summary_label.text = (
					"Defeat\nThe Jailer has kept what reached his landing."
					+ " Something deeper in the Dungeon is changing."
				)
		else:
			return_to_map_button.text = "Descend Toward the Farthest Cell"
			return_summary_label.text = (
				"Victory\nThe Jailer has fallen. The Refuge remains unborn. "
				+ "Cross Layer 2 from its Dungeon exit toward the Farthest Cell."
			)
		return_overlay.visible = true
		return
	if outcome.result == EncounterOutcome.Result.DEFEAT:
		if run_state.is_refugeless_ascent():
			return_to_map_button.text = "Awaken in the Farthest Cell"
			return_summary_label.text = (
				"Defeat\nThe Refuge-less ascent is over. The Castle draws "
				+ "the fallen party to Layer 2."
			)
		elif run_state.has_established_refuge():
			return_to_map_button.text = "Return to the Bloom Refuge"
			return_summary_label.text = (
				"Defeat\nThe run has ended. The party will recover in the "
				+ "Bloom Refuge with Resolve and Corruption consequences retained."
			)
		else:
			return_to_map_button.text = "Return to the Beginning"
			return_summary_label.text = (
				"Defeat\nThe run has failed. The recruited party will recover "
				+ "at the beginning of Layer 1."
			)
		return_overlay.visible = true
		return
	return_to_map_button.text = "Return to Layer 1 Map"
	return_summary_label.text = (
		"%s\n%s"
		% [
			"Victory" if outcome.result == EncounterOutcome.Result.VICTORY
			else "Defeat",
			"Return to the Layer 1 map. Party and inventory state will persist.",
		]
	)
	return_overlay.visible = true


func _on_return_to_map_pressed() -> void:
	if pending_outcome == null:
		return
	if run_state.is_opening_encounter_outcome(pending_outcome):
		if pending_outcome.result == EncounterOutcome.Result.DEFEAT:
			_restart_failed_run_from_beginning()
			return
		var opening_error: String = (
			run_state.apply_opening_encounter_outcome(
				pending_outcome
			)
		)
		if not opening_error.is_empty():
			return_summary_label.text = opening_error
			return
		_retire_active_battle()
		pending_outcome = null
		return_overlay.visible = false
		return_to_map_button.text = "Return to Layer 1 Map"
		map_screen.visible = true
		_refresh_map()
		return
	if (
		run_state.is_mira_recruitment_encounter_outcome(
			pending_outcome
		)
		and pending_outcome.result == EncounterOutcome.Result.VICTORY
	):
		_launch_mira_recruitment_aftermath()
		return
	if (
		run_state.is_mira_recruitment_encounter_outcome(
			pending_outcome
		)
		and pending_outcome.result == EncounterOutcome.Result.DEFEAT
	):
		_restart_failed_run_from_beginning()
		return
	if (
		run_state.is_seraphine_recruitment_encounter_outcome(
			pending_outcome
		)
		and pending_outcome.result == EncounterOutcome.Result.VICTORY
	):
		_launch_seraphine_recruitment_aftermath()
		return
	if (
		run_state.is_seraphine_recruitment_encounter_outcome(
			pending_outcome
		)
		and pending_outcome.result == EncounterOutcome.Result.DEFEAT
	):
		_restart_failed_run_from_beginning()
		return
	if run_state.is_blood_nun_encounter_outcome(pending_outcome):
		if pending_outcome.result == EncounterOutcome.Result.DEFEAT:
			_restart_failed_run_from_beginning()
		else:
			_launch_blood_nun_aftermath()
		return
	if run_state.is_jailer_first_encounter_outcome(pending_outcome):
		if pending_outcome.result == EncounterOutcome.Result.DEFEAT:
			if run_state.has_established_refuge():
				_return_failed_run_to_refuge()
			else:
				_launch_refuge_origin()
			return
		_launch_jailer_victory_aftermath()
		return
	if pending_outcome.result == EncounterOutcome.Result.DEFEAT:
		if run_state.is_refugeless_ascent():
			_launch_refuge_origin()
		else:
			_restart_failed_run_from_beginning()
		return
	var apply_error: String = run_state.apply_encounter_outcome(
		pending_outcome
	)
	if not apply_error.is_empty():
		return_summary_label.text = apply_error
		return
	_write_post_node_safe_point()
	_retire_active_battle()
	pending_outcome = null
	return_overlay.visible = false
	map_screen.visible = true
	_refresh_map()


func _restart_failed_run_from_beginning() -> void:
	if pending_outcome == null:
		return
	if run_state.has_established_refuge():
		_return_failed_run_to_refuge()
		return
	var clear_error: String = CampaignSaveSlotStore.clear_active_run_snapshot(
		active_save_slot_id
	)
	if not clear_error.is_empty():
		return_summary_label.text = clear_error
		return
	var recovery_party_snapshot: Dictionary = (
		run_state.make_full_wipe_recovery_party_snapshot(
			pending_outcome,
			battler_catalog
		)
	)
	if recovery_party_snapshot.is_empty():
		return_summary_label.text = (
			"The failed run could not prepare its Refuge recovery state."
		)
		return
	var retry_seed: int = run_state.run_seed
	var recovery_lifecycle_snapshot: Dictionary = (
		run_state.make_campaign_lifecycle_snapshot()
	)
	var recovery_narrative_snapshot: Dictionary = (
		run_state.make_full_wipe_recovery_narrative_snapshot()
	)
	if recovery_narrative_snapshot.is_empty():
		return_summary_label.text = (
			"The failed run could not preserve its narrative state."
		)
		return
	pending_outcome = null
	_retire_active_battle()
	_start_new_run(
		retry_seed,
		recovery_party_snapshot,
		recovery_narrative_snapshot,
		recovery_lifecycle_snapshot
	)


func _launch_mira_recruitment_aftermath() -> void:
	if pending_outcome == null:
		return
	if event_room_scene == null:
		return_summary_label.text = "Dialogue screen scene is unavailable."
		return
	var dialogue: DialogueDefinition = _get_production_dialogue(
		RunState.MIRA_RECRUITMENT_STORY_ID,
		&"encounter_aftermath",
		RunState.MIRA_RECRUITMENT_ENCOUNTER_ID
	)
	if dialogue == null:
		return_summary_label.text = dialogue_binding_error
		return
	var narrative_snapshot: Dictionary = (
		run_state.get_narrative_state_snapshot()
	)
	if narrative_snapshot.is_empty():
		return_summary_label.text = "The run narrative state is unavailable."
		return
	var background_texture: Texture2D = _resolve_story_background(
		dialogue,
		pending_outcome
	)
	if background_texture == null:
		return_summary_label.text = "Mira recruitment scene background is unavailable."
		return

	_retire_active_event_room()
	active_event_room = event_room_scene.instantiate() as EventRoomScreen
	if active_event_room == null:
		return_summary_label.text = "Dialogue screen could not be instantiated."
		return
	active_event_room.story_dialogue_outcome_ready.connect(
		_on_mira_recruitment_story_outcome_ready
	)
	event_room_host.add_child(active_event_room)
	var present_actor_ids: Array[StringName] = [
		&"lysandra",
		&"mira",
	]

	var preparation_error: String = (
		active_event_room.prepare_story_dialogue(
			RunState.MIRA_RECRUITMENT_STORY_ID,
			pending_outcome.source_node_id,
			background_texture,
			dialogue,
			item_catalog,
			battler_catalog,
			lore_catalog,
			knowledge_state,
			run_state.graph.layer_number,
			pending_outcome.inventory_snapshot,
			pending_outcome.party_snapshot,
			narrative_snapshot,
			present_actor_ids,
			run_state.make_run_inventory_snapshot_with_item_bar(
				pending_outcome.inventory_snapshot
			),
			run_state.run_equipment
		)
	)
	if not preparation_error.is_empty():
		return_summary_label.text = preparation_error
		_retire_active_event_room()
		return

	_retire_active_battle()
	return_overlay.visible = false
	map_screen.visible = false


func _on_mira_recruitment_story_outcome_ready(
	story_outcome: StoryDialogueOutcome
) -> void:
	var apply_error: String = run_state.apply_mira_recruitment_aftermath(
		pending_outcome,
		story_outcome
	)
	if not apply_error.is_empty():
		node_detail_label.text = apply_error
		return

	_write_post_node_safe_point()
	_retire_active_event_room()
	pending_outcome = null
	return_overlay.visible = false
	return_to_map_button.text = "Return to Layer 1 Map"
	map_screen.visible = true
	_refresh_map()


func _launch_seraphine_recruitment_prelude() -> void:
	if event_room_scene == null:
		node_detail_label.text = "Dialogue screen scene is unavailable."
		return
	var dialogue: DialogueDefinition = _get_production_dialogue(
		RunState.SERAPHINE_RECRUITMENT_PRELUDE_STORY_ID,
		&"encounter_prelude",
		RunState.SERAPHINE_RECRUITMENT_ENCOUNTER_ID
	)
	if dialogue == null:
		node_detail_label.text = dialogue_binding_error
		return
	var narrative_snapshot: Dictionary = (
		run_state.get_narrative_state_snapshot()
	)
	if narrative_snapshot.is_empty():
		node_detail_label.text = "The run narrative state is unavailable."
		return
	var encounter: EncounterDefinition = run_state.make_encounter_definition()
	var background_texture: Texture2D = _resolve_story_background(
		dialogue,
		null,
		encounter
	)
	if background_texture == null:
		node_detail_label.text = "Seraphine recruitment scene background is unavailable."
		return

	_retire_active_event_room()
	active_event_room = event_room_scene.instantiate() as EventRoomScreen
	if active_event_room == null:
		node_detail_label.text = "Dialogue screen could not be instantiated."
		return
	active_event_room.story_dialogue_outcome_ready.connect(
		_on_seraphine_recruitment_prelude_ready
	)
	event_room_host.add_child(active_event_room)
	var present_actor_ids: Array[StringName] = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	var preparation_error: String = active_event_room.prepare_story_dialogue(
		RunState.SERAPHINE_RECRUITMENT_PRELUDE_STORY_ID,
		run_state.pending_node_id,
		background_texture,
		dialogue,
		item_catalog,
		battler_catalog,
		lore_catalog,
		knowledge_state,
		run_state.graph.layer_number,
		run_state.inventory_snapshot,
		run_state.party_snapshot,
		narrative_snapshot,
		present_actor_ids,
		run_state.get_run_inventory_snapshot(),
		run_state.run_equipment
	)
	if not preparation_error.is_empty():
		node_detail_label.text = preparation_error
		_retire_active_event_room()
		return

	map_screen.visible = false
	return_overlay.visible = false


func _on_seraphine_recruitment_prelude_ready(
	story_outcome: StoryDialogueOutcome
) -> void:
	var apply_error: String = (
		run_state.apply_seraphine_recruitment_prelude(story_outcome)
	)
	if not apply_error.is_empty():
		node_detail_label.text = apply_error
		return

	_retire_active_event_room()
	_launch_pending_battle()


func _launch_seraphine_recruitment_aftermath() -> void:
	if pending_outcome == null:
		return
	if event_room_scene == null:
		return_summary_label.text = "Dialogue screen scene is unavailable."
		return
	var dialogue: DialogueDefinition = _get_production_dialogue(
		RunState.SERAPHINE_RECRUITMENT_AFTERMATH_STORY_ID,
		&"encounter_aftermath",
		RunState.SERAPHINE_RECRUITMENT_ENCOUNTER_ID
	)
	if dialogue == null:
		return_summary_label.text = dialogue_binding_error
		return
	var narrative_snapshot: Dictionary = (
		run_state.get_narrative_state_snapshot()
	)
	if narrative_snapshot.is_empty():
		return_summary_label.text = "The run narrative state is unavailable."
		return
	var background_texture: Texture2D = _resolve_story_background(
		dialogue,
		pending_outcome
	)
	if background_texture == null:
		return_summary_label.text = "Seraphine recruitment scene background is unavailable."
		return

	_retire_active_event_room()
	active_event_room = event_room_scene.instantiate() as EventRoomScreen
	if active_event_room == null:
		return_summary_label.text = "Dialogue screen could not be instantiated."
		return
	active_event_room.story_dialogue_outcome_ready.connect(
		_on_seraphine_recruitment_aftermath_ready
	)
	event_room_host.add_child(active_event_room)
	var present_actor_ids: Array[StringName] = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	var preparation_error: String = active_event_room.prepare_story_dialogue(
		RunState.SERAPHINE_RECRUITMENT_AFTERMATH_STORY_ID,
		pending_outcome.source_node_id,
		background_texture,
		dialogue,
		item_catalog,
		battler_catalog,
		lore_catalog,
		knowledge_state,
		run_state.graph.layer_number,
		pending_outcome.inventory_snapshot,
		pending_outcome.party_snapshot,
		narrative_snapshot,
		present_actor_ids,
		run_state.make_run_inventory_snapshot_with_item_bar(
			pending_outcome.inventory_snapshot
		),
		run_state.run_equipment
	)
	if not preparation_error.is_empty():
		return_summary_label.text = preparation_error
		_retire_active_event_room()
		return

	_retire_active_battle()
	return_overlay.visible = false
	map_screen.visible = false


func _on_seraphine_recruitment_aftermath_ready(
	story_outcome: StoryDialogueOutcome
) -> void:
	var apply_error: String = (
		run_state.apply_seraphine_recruitment_aftermath(
			pending_outcome,
			story_outcome
		)
	)
	if not apply_error.is_empty():
		node_detail_label.text = apply_error
		return

	_write_post_node_safe_point()
	_retire_active_event_room()
	pending_outcome = null
	return_overlay.visible = false
	return_to_map_button.text = "Return to Layer 1 Map"
	map_screen.visible = true
	_refresh_map()


func _launch_blood_nun_aftermath() -> void:
	if pending_outcome == null:
		return
	if event_room_scene == null:
		return_summary_label.text = "Dialogue screen scene is unavailable."
		return
	var dialogue: DialogueDefinition = _get_production_dialogue(
		RunState.BLOOD_NUN_AFTERMATH_STORY_ID,
		&"encounter_aftermath",
		RunState.BLOOD_NUN_ENCOUNTER_ID
	)
	if dialogue == null:
		return_summary_label.text = dialogue_binding_error
		return
	var narrative_snapshot: Dictionary = (
		run_state.get_narrative_state_snapshot()
	)
	if narrative_snapshot.is_empty():
		return_summary_label.text = "The run narrative state is unavailable."
		return
	var background_texture: Texture2D = _resolve_story_background(
		dialogue,
		pending_outcome
	)
	if background_texture == null:
		return_summary_label.text = "Blood Nun aftermath background is unavailable."
		return

	_retire_active_event_room()
	active_event_room = event_room_scene.instantiate() as EventRoomScreen
	if active_event_room == null:
		return_summary_label.text = "Dialogue screen could not be instantiated."
		return
	active_event_room.story_dialogue_outcome_ready.connect(
		_on_blood_nun_aftermath_ready
	)
	event_room_host.add_child(active_event_room)
	var present_actor_ids: Array[StringName] = [
		&"lysandra",
		&"mira",
		&"seraphine",
		&"blood_nun",
	]
	var preparation_error: String = active_event_room.prepare_story_dialogue(
		RunState.BLOOD_NUN_AFTERMATH_STORY_ID,
		pending_outcome.source_node_id,
		background_texture,
		dialogue,
		item_catalog,
		battler_catalog,
		lore_catalog,
		knowledge_state,
		run_state.graph.layer_number,
		pending_outcome.inventory_snapshot,
		pending_outcome.party_snapshot,
		narrative_snapshot,
		present_actor_ids,
		run_state.make_run_inventory_snapshot_with_item_bar(
			pending_outcome.inventory_snapshot
		),
		run_state.run_equipment
	)
	if not preparation_error.is_empty():
		return_summary_label.text = preparation_error
		_retire_active_event_room()
		return

	_retire_active_battle()
	return_overlay.visible = false
	map_screen.visible = false


func _on_blood_nun_aftermath_ready(
	story_outcome: StoryDialogueOutcome
) -> void:
	var route_choice_id: StringName = (
		run_state.get_blood_nun_route_choice(story_outcome)
	)
	if route_choice_id == &"":
		node_detail_label.text = "The Blood Nun aftermath selected no route."
		return
	var destination_seed: int = run_state.get_refugeless_world_seed()
	var destination_graph: LayerMapGraph = (
		generator.generate_layer_3_entry(destination_seed)
		if route_choice_id == RunState.BLOOD_NUN_GO_UP_CHOICE_ID
		else generator.generate_layer_2_entry(destination_seed)
	)
	if destination_graph == null:
		node_detail_label.text = (
			generator.last_generation_error
			if not generator.last_generation_error.is_empty()
			else "The destination Layer map could not be generated."
		)
		return
	var apply_error: String = run_state.apply_blood_nun_aftermath(
		pending_outcome,
		story_outcome,
		destination_graph
	)
	if not apply_error.is_empty():
		node_detail_label.text = apply_error
		return

	_retire_active_event_room()
	pending_outcome = null
	return_overlay.visible = false
	return_to_map_button.text = "Return to Map"
	map_view.bind_map(run_state.graph, run_state)
	if not _write_post_node_safe_point():
		map_screen.visible = true
		_refresh_map()
		return
	if route_choice_id == RunState.BLOOD_NUN_GO_DOWN_CHOICE_ID:
		var lifecycle_before: Dictionary = run_state.make_campaign_lifecycle_snapshot()
		var target: MapNodeState = run_state.graph.get_map_node(
			RunState.JAILER_FIRST_NODE_ID
		)
		var target_was_visited: bool = target.visited if target != null else false
		var jailer_entry_error: String = (
			run_state.begin_immediate_jailer_encounter()
		)
		if jailer_entry_error.is_empty():
			jailer_entry_error = run_state.prepare_pending_node_seed()
		if jailer_entry_error.is_empty():
			jailer_entry_error = _save_active_run_safe_point("pre_node")
		if not jailer_entry_error.is_empty():
			if run_state.pending_node_id == RunState.JAILER_FIRST_NODE_ID:
				run_state.rollback_pending_node_entry(
					RunState.JAILER_FIRST_NODE_ID,
					target_was_visited,
					lifecycle_before
				)
			map_screen.visible = true
			_refresh_map()
			node_detail_label.text = jailer_entry_error
			return
		map_screen.visible = false
		_enter_pending_node_content()
		return
	map_screen.visible = true
	_refresh_map()


func _launch_jailer_victory_aftermath() -> void:
	if pending_outcome == null or event_room_scene == null:
		return_summary_label.text = "Jailer victory dialogue screen is unavailable."
		return
	var dialogue: DialogueDefinition = _get_production_dialogue(
		RunState.JAILER_VICTORY_STORY_ID,
		&"encounter_victory",
		RunState.JAILER_FIRST_ENCOUNTER_ID
	)
	if dialogue == null:
		return_summary_label.text = dialogue_binding_error
		return
	var narrative_snapshot: Dictionary = run_state.get_narrative_state_snapshot()
	if narrative_snapshot.is_empty():
		return_summary_label.text = "The run narrative state is unavailable."
		return
	var background_texture: Texture2D = _resolve_story_background(
		dialogue,
		pending_outcome
	)
	if background_texture == null:
		return_summary_label.text = "Jailer victory background is unavailable."
		return

	_retire_active_event_room()
	active_event_room = event_room_scene.instantiate() as EventRoomScreen
	if active_event_room == null:
		return_summary_label.text = "Dialogue screen could not be instantiated."
		return
	active_event_room.story_dialogue_outcome_ready.connect(
		_on_jailer_victory_aftermath_ready
	)
	event_room_host.add_child(active_event_room)
	var preparation_error: String = active_event_room.prepare_story_dialogue(
		RunState.JAILER_VICTORY_STORY_ID,
		pending_outcome.source_node_id,
		background_texture,
		dialogue,
		item_catalog,
		battler_catalog,
		lore_catalog,
		knowledge_state,
		2,
		pending_outcome.inventory_snapshot,
		pending_outcome.party_snapshot,
		narrative_snapshot,
		[&"lysandra", &"mira", &"seraphine", &"jailer"],
		run_state.make_run_inventory_snapshot_with_item_bar(
			pending_outcome.inventory_snapshot
		),
		run_state.run_equipment
	)
	if not preparation_error.is_empty():
		return_summary_label.text = preparation_error
		_retire_active_event_room()
		return
	_retire_active_battle()
	return_overlay.visible = false
	map_screen.visible = false


func _on_jailer_victory_aftermath_ready(
	story_outcome: StoryDialogueOutcome
) -> void:
	var reverse_layer_2_graph: LayerMapGraph = (
		generator.generate_refugeless_reverse_layer_2(
			run_state.get_refugeless_layer_seed(2),
			run_state.get_defeated_boss_ids()
		)
	)
	if reverse_layer_2_graph == null:
		active_event_room.show_story_holding_message(
			generator.last_generation_error
			if not generator.last_generation_error.is_empty()
			else "The reverse Layer 2 route could not be generated."
		)
		return
	var apply_error: String = run_state.apply_jailer_victory(
		pending_outcome,
		story_outcome,
		reverse_layer_2_graph
	)
	if not apply_error.is_empty():
		active_event_room.show_story_holding_message(apply_error)
		return
	_write_post_node_safe_point()
	_retire_active_event_room()
	pending_outcome = null
	return_overlay.visible = false
	map_view.bind_map(run_state.graph, run_state)
	map_screen.visible = true
	_refresh_map()


func _launch_farthest_cell_refuge_establishment() -> void:
	if event_room_scene == null:
		node_detail_label.text = "Farthest Cell dialogue screen is unavailable."
		return
	var dialogue: DialogueDefinition = _get_production_dialogue(
		RunState.FARTHEST_CELL_REFUGE_STORY_ID,
		&"map_arrival",
		RunState.LAYER_2_FARTHEST_CELL_NODE_ID
	)
	if dialogue == null:
		node_detail_label.text = dialogue_binding_error
		return
	var background_texture: Texture2D = _resolve_story_background(dialogue)
	if background_texture == null:
		node_detail_label.text = "Farthest Cell background is unavailable."
		return

	_retire_active_event_room()
	active_event_room = event_room_scene.instantiate() as EventRoomScreen
	if active_event_room == null:
		node_detail_label.text = "Dialogue screen could not be instantiated."
		return
	active_event_room.story_dialogue_outcome_ready.connect(
		_on_farthest_cell_refuge_establishment_ready
	)
	event_room_host.add_child(active_event_room)
	var preparation_error: String = active_event_room.prepare_story_dialogue(
		RunState.FARTHEST_CELL_REFUGE_STORY_ID,
		RunState.LAYER_2_FARTHEST_CELL_NODE_ID,
		background_texture,
		dialogue,
		item_catalog,
		battler_catalog,
		lore_catalog,
		knowledge_state,
		2,
		run_state.inventory_snapshot,
		run_state.party_snapshot,
		run_state.get_narrative_state_snapshot(),
		[&"lysandra", &"mira", &"seraphine"],
		run_state.get_run_inventory_snapshot(),
		run_state.run_equipment
	)
	if not preparation_error.is_empty():
		node_detail_label.text = preparation_error
		_retire_active_event_room()
		return
	map_screen.visible = false
	return_overlay.visible = false


func _on_farthest_cell_refuge_establishment_ready(
	story_outcome: StoryDialogueOutcome
) -> void:
	var refuge_graph: LayerMapGraph = (
		generator.generate_bloom_refuge_holding_state(run_state.run_seed)
	)
	var apply_error: String = run_state.establish_refuge_at_farthest_cell(
		refuge_graph,
		battler_catalog,
		story_outcome
	)
	if not apply_error.is_empty():
		active_event_room.show_story_holding_message(apply_error)
		return
	map_view.bind_map(run_state.graph, run_state)
	_retire_active_event_room()
	var save_error: String = _save_active_refuge()
	_show_refuge_hub(
		"Bloom Refuge established at the Farthest Cell and campaign saved."
		if save_error.is_empty()
		else save_error,
		not save_error.is_empty()
	)


func _launch_refuge_origin() -> void:
	if pending_outcome == null:
		return
	if event_room_scene == null:
		return_summary_label.text = "Dialogue screen scene is unavailable."
		return
	var defeated_by_jailer: bool = (
		pending_outcome.encounter_id == RunState.JAILER_FIRST_ENCOUNTER_ID
	)
	var dialogue_id: StringName = (
		RunState.REFUGE_ORIGIN_STORY_ID
		if defeated_by_jailer
		else RunState.UPPER_ROUTE_REFUGE_ORIGIN_DIALOGUE_ID
	)
	var trigger_id: StringName = (
		RunState.JAILER_FIRST_ENCOUNTER_ID
		if defeated_by_jailer
		else &"refugeless_ascent_non_jailer"
	)
	var origin_dialogue: DialogueDefinition = _get_production_dialogue(
		dialogue_id,
		&"refugeless_defeat",
		trigger_id
	)
	if origin_dialogue == null:
		return_summary_label.text = dialogue_binding_error
		return
	var narrative_snapshot: Dictionary = (
		run_state.get_narrative_state_snapshot()
	)
	if narrative_snapshot.is_empty():
		return_summary_label.text = "The run narrative state is unavailable."
		return
	var recovered_party_snapshot: Dictionary = (
		run_state.make_full_wipe_recovery_party_snapshot(
			pending_outcome,
			battler_catalog
		)
	)
	if recovered_party_snapshot.size() != 3:
		return_summary_label.text = (
			"The Refuge-less defeat could not recover the complete recruited party."
		)
		return
	var background_texture: Texture2D = _resolve_story_background(
		origin_dialogue,
		pending_outcome
	)
	if background_texture == null:
		return_summary_label.text = "Bloom Refuge background is unavailable."
		return

	_retire_active_event_room()
	active_event_room = event_room_scene.instantiate() as EventRoomScreen
	if active_event_room == null:
		return_summary_label.text = "Dialogue screen could not be instantiated."
		return
	active_event_room.story_dialogue_outcome_ready.connect(
		_on_refuge_origin_ready
	)
	event_room_host.add_child(active_event_room)
	var present_actor_ids: Array[StringName] = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	if defeated_by_jailer:
		present_actor_ids.append(&"jailer")
	var preparation_error: String = active_event_room.prepare_story_dialogue(
		RunState.REFUGE_ORIGIN_STORY_ID,
		pending_outcome.source_node_id,
		background_texture,
		origin_dialogue,
		item_catalog,
		battler_catalog,
		lore_catalog,
		knowledge_state,
		2,
		pending_outcome.inventory_snapshot,
		recovered_party_snapshot,
		narrative_snapshot,
		present_actor_ids,
		run_state.make_run_inventory_snapshot_with_item_bar(
			pending_outcome.inventory_snapshot
		),
		run_state.run_equipment
	)
	if not preparation_error.is_empty():
		return_summary_label.text = preparation_error
		_retire_active_event_room()
		return

	_retire_active_battle()
	return_overlay.visible = false
	map_screen.visible = false


func _on_refuge_origin_ready(
	story_outcome: StoryDialogueOutcome
) -> void:
	var refuge_graph: LayerMapGraph = (
		generator.generate_bloom_refuge_holding_state(run_state.run_seed)
	)
	var apply_error: String = (
		run_state.apply_refugeless_defeat_and_refuge_origin(
			pending_outcome,
			story_outcome,
			refuge_graph,
			battler_catalog
		)
	)
	if not apply_error.is_empty():
		if active_event_room != null:
			active_event_room.show_story_holding_message(apply_error)
		return

	pending_outcome = null
	return_overlay.visible = false
	map_view.bind_map(run_state.graph, run_state)
	map_screen.visible = false
	_retire_active_event_room()
	var save_error: String = _save_active_refuge()
	_show_refuge_hub(
		"Bloom Refuge established and campaign saved."
		if save_error.is_empty()
		else save_error,
		not save_error.is_empty()
	)


func _show_refuge_hub(
	status_message: String = "",
	is_error: bool = false
) -> void:
	if refuge_scene == null or refuge_host == null:
		push_error("Bloom Refuge scene is unavailable.")
		return
	_retire_active_battle()
	_retire_active_event_room()
	_retire_active_refuge()
	active_refuge = refuge_scene.instantiate() as BloomRefugeScreen
	if active_refuge == null:
		push_error("Bloom Refuge screen could not be instantiated.")
		return
	active_refuge.begin_layer_2_run_requested.connect(
		_on_begin_layer_2_run_requested
	)
	active_refuge.start_new_story_requested.connect(
		_on_refuge_start_new_story_requested
	)
	refuge_host.add_child(active_refuge)
	map_screen.visible = false
	return_overlay.visible = false
	var refuge_management := RefugeManagementController.new()
	var management_error: String = refuge_management.bind(
		run_state,
		battler_catalog,
		_save_active_refuge
	)
	if not management_error.is_empty():
		active_refuge.show_status(management_error, true)
		return
	var present_error: String = active_refuge.present(
		run_state,
		battler_catalog,
		knowledge_state,
		CampaignSaveSlotStore.has_loadable_slot(active_save_slot_id),
		refuge_management
	)
	if not present_error.is_empty():
		active_refuge.show_status(present_error, true)
		return
	if not status_message.is_empty():
		active_refuge.show_status(status_message, is_error)


func _load_campaign_from_slot(slot_id: int) -> String:
	var read_result: Dictionary = (
		CampaignSaveSlotStore.read_document_for_load(slot_id)
	)
	var read_error: String = String(read_result.get("error", ""))
	if not read_error.is_empty():
		return read_error
	var envelope_value: Variant = read_result.get("document", {})
	if not (envelope_value is Dictionary):
		return "Campaign save did not contain a valid v3 envelope."
	var envelope := envelope_value as Dictionary
	var metadata_value: Variant = envelope.get("metadata", {})
	if not (metadata_value is Dictionary):
		return "Save Envelope v3 did not contain valid metadata."
	var saved_seed: int = maxi(
		int((metadata_value as Dictionary).get("campaign_seed", 1)),
		1
	)
	var refuge_graph: LayerMapGraph = (
		generator.generate_bloom_refuge_holding_state(saved_seed)
	)
	var load_error: String = CampaignSaveSlotStore.restore_envelope(
		envelope,
		slot_id,
		run_state,
		knowledge_state,
		refuge_graph,
		battler_catalog
	)
	if not load_error.is_empty():
		return load_error
	if envelope.get("active_run_snapshot", null) is Dictionary:
		var clear_error: String = _save_active_refuge()
		if not clear_error.is_empty():
			return clear_error
	if not run_state.run_changed.is_connected(_refresh_map):
		run_state.run_changed.connect(_refresh_map)
	map_view.bind_map(run_state.graph, run_state)
	boot_fallback.visible = false
	_show_refuge_hub(
		"Campaign recovered from the previous safe backup."
		if bool(read_result.get("used_backup", false))
		else "Campaign loaded at the Bloom Refuge."
	)
	return ""


func _save_active_refuge(discard_unspent_bloom: bool = false) -> String:
	if not CampaignSaveSlotStore.is_valid_slot_id(active_save_slot_id):
		return "The campaign has no active production save slot."
	return CampaignSaveSlotStore.save_refuge_slot(
		active_save_slot_id,
		run_state,
		knowledge_state,
		discard_unspent_bloom
	)


func _save_active_run_safe_point(safe_point_kind: String) -> String:
	if not CampaignSaveSlotStore.is_valid_slot_id(active_save_slot_id):
		return "The active run has no production save slot."
	return CampaignSaveSlotStore.save_active_run_slot(
		active_save_slot_id,
		run_state,
		knowledge_state,
		safe_point_kind
	)


func _write_post_node_safe_point() -> bool:
	var save_error: String = _save_active_run_safe_point("post_node")
	autosave_blocking_error = save_error
	if not save_error.is_empty():
		node_detail_label.text = (
			"The node resolved, but its safe point could not be written.\n%s"
			% save_error
		)
		_refresh_map()
		return false
	return true


func _on_begin_layer_2_run_requested(next_seed: int) -> void:
	var next_graph: LayerMapGraph = generator.generate_layer_2_run(
		next_seed,
		run_state.get_defeated_boss_ids()
	)
	if next_graph == null:
		if active_refuge != null:
			active_refuge.show_status(
				generator.last_generation_error
				if not generator.last_generation_error.is_empty()
				else "Layer 2 authored-map generation failed.",
				true
			)
		return
	# Validate the complete in-memory transition before replacing the durable
	# Refuge boundary with its zero-Bloom departure state.
	var validation_error: String = run_state.validate_next_layer_2_run(
		next_graph
	)
	if not validation_error.is_empty():
		if active_refuge != null:
			active_refuge.show_status(validation_error, true)
		return
	var departure_save_error: String = _save_active_refuge(true)
	if not departure_save_error.is_empty():
		if active_refuge != null:
			active_refuge.show_status(departure_save_error, true)
		return
	var begin_error: String = run_state.begin_next_layer_2_run(next_graph)
	if not begin_error.is_empty():
		if active_refuge != null:
			active_refuge.show_status(begin_error, true)
		return
	_retire_active_refuge()
	map_view.bind_map(run_state.graph, run_state)
	map_screen.visible = true
	return_overlay.visible = false
	_refresh_map()


func _on_refuge_start_new_story_requested(next_seed: int) -> void:
	# This is a non-destructive development affordance. The Refuge save remains
	# available on disk while the complete Layer 1 sequence is replayed.
	_start_new_run(next_seed)


func _on_return_to_refuge_pressed() -> void:
	var refuge_graph: LayerMapGraph = (
		generator.generate_bloom_refuge_holding_state(run_state.run_seed)
	)
	var return_error: String = run_state.return_current_run_to_refuge(
		refuge_graph,
		battler_catalog
	)
	if not return_error.is_empty():
		node_detail_label.text = return_error
		return
	var save_error: String = _save_active_refuge()
	map_view.bind_map(run_state.graph, run_state)
	_show_refuge_hub(
		"Returned to the Bloom Refuge. HP and MP restored; campaign saved."
		if save_error.is_empty()
		else save_error,
		not save_error.is_empty()
	)


func _return_failed_run_to_refuge() -> void:
	if pending_outcome == null:
		return
	var refuge_graph: LayerMapGraph = (
		generator.generate_bloom_refuge_holding_state(run_state.run_seed)
	)
	var recovery_error: String = run_state.apply_post_refuge_defeat(
		pending_outcome,
		refuge_graph,
		battler_catalog
	)
	if not recovery_error.is_empty():
		return_summary_label.text = recovery_error
		return
	pending_outcome = null
	_retire_active_battle()
	var save_error: String = _save_active_refuge()
	map_view.bind_map(run_state.graph, run_state)
	_show_refuge_hub(
		(
			"The defeated party recovered at the Bloom Refuge. HP and MP are "
			+ "full; Resolve and Corruption persist. Campaign saved."
		)
		if save_error.is_empty()
		else save_error,
		not save_error.is_empty()
	)


func _on_new_run_pressed() -> void:
	if run_state.run_changed.is_connected(_refresh_map):
		run_state.run_changed.disconnect(_refresh_map)
	_start_new_run(_parse_seed())


func _retire_active_battle() -> void:
	if active_stage_trigger != null and active_stage_trigger.armed:
		active_stage_trigger.cancel()
	active_stage_trigger = null
	if active_battle == null:
		return
	# Remove old CanvasLayers immediately instead of leaving them interactive
	# until queue_free() is processed at the end of the frame.
	var parent: Node = active_battle.get_parent()
	if parent != null:
		parent.remove_child(active_battle)
	active_battle.queue_free()
	active_battle = null

func _retire_active_event_room() -> void:
	if active_event_room == null:
		return
		
	var parent: Node = active_event_room.get_parent()
	if parent != null:
		parent.remove_child(active_event_room)
		
	active_event_room.queue_free()
	active_event_room = null


func _retire_active_refuge() -> void:
	if active_refuge == null:
		return
	var parent: Node = active_refuge.get_parent()
	if parent != null:
		parent.remove_child(active_refuge)
	active_refuge.queue_free()
	active_refuge = null


func _resolve_story_background(
	dialogue: DialogueDefinition,
	_outcome: EncounterOutcome = null,
	encounter: EncounterDefinition = null
) -> Texture2D:
	if dialogue != null and dialogue.background_override != null:
		return dialogue.background_override
	if active_battle != null:
		var active_texture: Texture2D = (
			active_battle.get_scene_background_texture()
		)
		if active_texture != null:
			return active_texture
	if encounter == null:
		encounter = run_state.make_encounter_definition()
	if (
		encounter == null
		or encounter.template == null
		or encounter.template.battlefield_scene == null
	):
		return null
	var battlefield := encounter.template.battlefield_scene.instantiate()
	if battlefield == null:
		return null
	var background := battlefield.get_node_or_null(
		"BackgroundLayer/BackgroundArt"
	) as Sprite2D
	if background == null:
		background = battlefield.find_child(
			"BackgroundArt",
			true,
			false
		) as Sprite2D
	var texture: Texture2D = background.texture if background != null else null
	battlefield.free()
	return texture


func _get_production_dialogue(
	dialogue_id: StringName,
	trigger_kind: StringName,
	trigger_id: StringName
) -> DialogueDefinition:
	dialogue_binding_error = ""
	if dialogue_catalog == null:
		dialogue_binding_error = "The production dialogue catalog is unavailable."
		return null
	var catalog_error: String = dialogue_catalog.validate_definition()
	if not catalog_error.is_empty():
		dialogue_binding_error = catalog_error
		return null
	var dialogue: DialogueDefinition = dialogue_catalog.get_dialogue(dialogue_id)
	if dialogue == null:
		dialogue_binding_error = "Production dialogue '%s' is unavailable." % dialogue_id
		return null
	if not dialogue.matches_trigger(trigger_kind, trigger_id):
		dialogue_binding_error = (
			"Production dialogue '%s' is bound to the wrong trigger."
			% dialogue_id
		)
		return null
	return dialogue

func _parse_seed() -> int:
	var text: String = seed_edit.text.strip_edges()
	if text.is_valid_int():
		return maxi(text.to_int(), 1)
	return 27072026


func _state_label(map_state: MapNodeState.MapState) -> String:
	match map_state:
		MapNodeState.MapState.AVAILABLE:
			return "Available"
		MapNodeState.MapState.SELECTED:
			return "Selected"
		MapNodeState.MapState.VISITED:
			return "Visited"
		MapNodeState.MapState.CLEARED:
			return "Cleared"
	return "Locked"


func _node_behavior_text(node: MapNodeState) -> String:
	if not node.travel_enabled:
		return node.locked_reason
	if run_state.graph.layer_id == &"layer_3":
		if node.node_type == MapNodeState.NodeType.START:
			return (
				"The Refuge-less campaign continues upward into the harder "
				+ "Layer 3 route."
			)
		return "Layer 3 encounter content is authored in a later milestone."
	if run_state.graph.layer_id == &"layer_2":
		if node.node_type == MapNodeState.NodeType.START:
			return "Ordinary Layer 2 runs begin here, at the farthest cell."
		if node.node_type == MapNodeState.NodeType.BOSS:
			return "The Jailer remains at Layer 2's exit end."
		return (
			"This registered Dungeon room is part of the seeded route; "
			+ "room-specific content remains inactive unless authored."
		)
	if node.node_type == MapNodeState.NodeType.BOSS:
		return "Major Boss: Blood Nun with one Prayer-Rag support unit."
	if node.encounter_id == &"layer_1_corrupted_butler_opening":
		return "Opening Special: Corrupted Butler alone."
	if node.encounter_id == RunState.SERAPHINE_RECRUITMENT_ENCOUNTER_ID:
		return "Recruitment Special: Seraphine's ward in the Ruined Chapel."
	if node.node_type == MapNodeState.NodeType.ELITE:
		return "Elite battle: Red-Wax pair or the hard three-Standard chapel formation."
	if node.node_type == MapNodeState.NodeType.BATTLE:
		return "Regular battle: one or two Layer 1 Standard enemies."
	if (
		node.authored_room_id == &"dining_service_hall"
		and node.has_encounter_content()
	):
		return "Exploration room: follow the service route to its ordinary battle."
	if node.requires_event_room():
		return "Event room: enter the room and interact with its content"
	if node.node_type == MapNodeState.NodeType.ITEM:
		return "Temporary supply-node resolution; first-clear reward only."
	if node.node_type == MapNodeState.NodeType.START:
		return "Generated Layer 1 routes begin here after the Refuge."
	return "Temporary non-combat resolution; room content is deferred."
