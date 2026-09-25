class_name EventRoomScreen
extends Node2D


const REWARD_SOURCE_CATALOG: RewardSourceCatalogDefinition = preload(
	"res://data/rewards/reward_source_catalog.tres"
)
const ROOM_ENCOUNTER_HOTSPOT_SCRIPT: Script = preload(
	"res://scripts/exploration/interactions/room_encounter_hotspot.gd"
)

signal room_outcome_ready(outcome: EventRoomOutcome)
signal room_encounter_requested(trigger_id: StringName)
signal dialogue_story_request_ready(request: Dictionary)
signal story_dialogue_outcome_ready(outcome: StoryDialogueOutcome)


@export var world_item_scene: PackedScene
@export var world_event_scene: PackedScene
@export_group("Dialogue Development")
@export var developer_test_dialogue: DialogueDefinition
@export var developer_start_test_dialogue_on_room_entry: bool = false


@onready var room_host: Node2D = $RoomHost
@onready var exploration_hud: ExplorationHUD = $ExplorationHUD
@onready var item_bar: ItemBarView = exploration_hud.item_bar
@onready var hover_label: Label = exploration_hud.hover_label
@onready var lysandra_card: HeroineCardView = exploration_hud.lysandra_card
@onready var mira_card: HeroineCardView = exploration_hud.mira_card
@onready var seraphine_card: HeroineCardView = exploration_hud.seraphine_card
@onready var exploration_command_bar: ExplorationCommandBarView = (
	exploration_hud.command_bar
)


var definition: EventRoomDefinition
var instance_state: EventRoomInstanceState
var presentation: Node
var inventory: SixSlotInventoryState
var run_inventory: RunInventoryState
var run_equipment: RunEquipmentState

var available_item_catalog: ItemCatalogDefinition
var available_battler_catalog: BattlerCatalogDefinition
var available_lore_catalog: LoreCatalogDefinition
var persistent_knowledge_state: KnowledgeState

var active_pickups: Dictionary = {}
var active_locks: Dictionary = {}
var active_lore_pickups: Dictionary = {}
var active_room_events: Dictionary = {}
var active_encounter_hotspots: Dictionary = {}

var selected_item_slot_index: int = -1
var party_states: Dictionary = {}
var selected_heroine_id: StringName = &""

var current_layer_number: int = 1
var pending_bloom_delta: int = 0
var mode_controller: ExplorationModeController = ExplorationModeController.new()
var dialogue_runner: DialogueRunner
var dialogue_context: DialogueContext
var pending_dialogue_results: Array[Dictionary] = []
var narrative_context_snapshot: Dictionary = {}
var current_party_ids: Array[StringName] = []
var story_dialogue_mode: bool = false
var story_dialogue_id: StringName = &""
var story_source_node_id: StringName = &""
var story_present_actor_ids: Array[StringName] = []
var suspended_interaction_states: Dictionary = {}


func _ready() -> void:
	if not item_bar.slot_requested.is_connected(
		_on_item_slot_requested
	):
		item_bar.slot_requested.connect(
			_on_item_slot_requested
		)

	for card: HeroineCardView in [
		lysandra_card,
		mira_card,
		seraphine_card,
	]:
		if not card.selected.is_connected(
			_on_heroine_card_selected
		):
			card.selected.connect(
				_on_heroine_card_selected
			)
	if not exploration_command_bar.back_requested.is_connected(
		_on_back_requested
		):
			exploration_command_bar.back_requested.connect(
				_on_back_requested
			)

	if not exploration_hud.dialogue_panel.advance_requested.is_connected(
		_on_dialogue_advance_requested
	):
		exploration_hud.dialogue_panel.advance_requested.connect(
			_on_dialogue_advance_requested
		)
	if not exploration_hud.dialogue_panel.choice_requested.is_connected(
		_on_dialogue_choice_requested
	):
		exploration_hud.dialogue_panel.choice_requested.connect(
			_on_dialogue_choice_requested
		)


func prepare_room(
	room_definition: EventRoomDefinition,
	room_state: EventRoomInstanceState,
	item_catalog: ItemCatalogDefinition,
	battler_catalog: BattlerCatalogDefinition,
	lore_catalog: LoreCatalogDefinition,
	knowledge_state: KnowledgeState,
	layer_number: int,
	inventory_snapshot: Array[Dictionary],
	party_snapshot: Dictionary,
	new_narrative_context_snapshot: Dictionary = {},
	new_run_inventory_snapshot: Dictionary = {},
	new_run_equipment: RunEquipmentState = null
) -> String:
	story_dialogue_mode = false
	story_dialogue_id = &""
	story_source_node_id = &""
	story_present_actor_ids.clear()
	definition = room_definition
	instance_state = room_state

	if definition == null:
		return "EventRoomScreen received no room definition."

	if instance_state == null:
		return "EventRoomScreen received no room instance state."

	if item_catalog == null:
		return "EventRoomScreen received no item catalog."
	
	available_item_catalog = item_catalog
	
	if lore_catalog == null:
		return "EventRoomScreen received no lore catalog"
		
	available_lore_catalog = lore_catalog
	
	if knowledge_state == null:
		return "EventRoomScreen received no KnowledgeState"
		
	persistent_knowledge_state = knowledge_state
	current_layer_number = maxi(
		layer_number,
		1
	)
	
	pending_bloom_delta = 0
	pending_dialogue_results.clear()
	narrative_context_snapshot = (
		new_narrative_context_snapshot.duplicate(true)
	)
	current_party_ids = _party_ids_from_snapshot(party_snapshot)
	run_equipment = new_run_equipment

	if battler_catalog == null:
		return "EventRoomScreen received no battler catalog."
	available_battler_catalog = battler_catalog

	if world_item_scene == null:
		return "EventRoomScreen has no WorldItemPickup scene."

	var definition_error: String = (
		definition.validate_definition()
	)

	if not definition_error.is_empty():
		return definition_error

	var inventory_error: String = _prepare_inventory(
		item_catalog,
		inventory_snapshot,
		new_run_inventory_snapshot
	)

	if not inventory_error.is_empty():
		return inventory_error

	var party_error: String = _prepare_party_strip(
		battler_catalog,
		party_snapshot
	)

	if not party_error.is_empty():
		return party_error

	presentation = definition.presentation_scene.instantiate()
	room_host.add_child(presentation)
	_apply_definition_presentation_texture()

	active_locks.clear()
	active_lore_pickups.clear()
	active_room_events.clear()
	active_encounter_hotspots.clear()

	for child: Node in presentation.find_children(
		"*",
		"",
		true,
		false
	):
		if child is ExplorationInteractable:
			_connect_exploration_interactable(
				child as ExplorationInteractable
			)

		if child is RoomExitHotspot:
			var room_exit := child as RoomExitHotspot
			var exit_callback: Callable = (
				_on_exit_requested.bind(room_exit)
			)

			if not room_exit.exit_requested.is_connected(exit_callback):
				room_exit.exit_requested.connect(
					exit_callback
				)

		if child.get_script() == ROOM_ENCOUNTER_HOTSPOT_SCRIPT:
			var encounter_hotspot: Variant = child
			var hotspot_error: String = encounter_hotspot.validate_hotspot()
			if not hotspot_error.is_empty():
				return hotspot_error
			if active_encounter_hotspots.has(encounter_hotspot.trigger_id):
				return "Duplicate room encounter trigger ID: '%s'." % (
					encounter_hotspot.trigger_id
				)
			active_encounter_hotspots[encounter_hotspot.trigger_id] = (
				encounter_hotspot
			)
			if not encounter_hotspot.encounter_requested.is_connected(
				_on_room_encounter_requested
			):
				encounter_hotspot.encounter_requested.connect(
					_on_room_encounter_requested
				)

		if child is RoomLockHotspot:
			var room_lock := child as RoomLockHotspot

			var lock_error: String = (
				room_lock.validate_lock()
			)

			if not lock_error.is_empty():
				return lock_error

			if active_locks.has(room_lock.lock_id):
				return (
					"Duplicate Event-room lock ID: '%s'."
					% room_lock.lock_id
				)

			active_locks[room_lock.lock_id] = room_lock

			if not room_lock.interaction_requested.is_connected(
				_on_room_lock_interaction_requested
			):
				room_lock.interaction_requested.connect(
					_on_room_lock_interaction_requested
				)

			room_lock.apply_unlocked_state(
				_is_room_lock_unlocked(
					room_lock.lock_id
				)
			)
		if child is WorldLorePickup:
			var lore_pickup := child as WorldLorePickup

			var lore_pickup_error: String = (
				lore_pickup.validate_pickup()
			)

			if not lore_pickup_error.is_empty():
				return lore_pickup_error

			if active_lore_pickups.has(
				lore_pickup.lore_entry_id
			):
				return (
					"Duplicate Event-room lore pickup ID: '%s'."
					% lore_pickup.lore_entry_id
				)

			var lore_entry: LoreEntryDefinition = (
				_get_lore_entry(
					lore_pickup.lore_entry_id
				)
			)

			if lore_entry == null:
				return (
					"Unknown lore entry ID: '%s'."
					% lore_pickup.lore_entry_id
				)

			active_lore_pickups[
				lore_pickup.lore_entry_id
			] = lore_pickup

			if not lore_pickup.pickup_requested.is_connected(
				_on_world_lore_pickup_requested
			):
				lore_pickup.pickup_requested.connect(
					_on_world_lore_pickup_requested
				)

			lore_pickup.apply_discovered_state(
				persistent_knowledge_state.has_entry(
					lore_pickup.lore_entry_id
				)
			)

	var preparation_warnings: Array[String] = []
	var item_error: String = _prepare_room_items()

	if not item_error.is_empty():
		preparation_warnings.append(item_error)
		push_warning(item_error)
		
	var event_error: String = (
		_prepare_room_events()
	)
	
	if not event_error.is_empty():
		preparation_warnings.append(event_error)
		push_warning(event_error)

	instance_state.visit_count += 1

	selected_item_slot_index = -1
	selected_heroine_id = &""
	hover_label.text = (
		"Some optional room content could not be prepared. Check the Output panel."
		if not preparation_warnings.is_empty()
		else ""
	)

	_refresh_item_bar()
	_refresh_party_strip()
	if (
		definition.entry_dialogue != null
		and not definition.entry_dialogue.is_completed(
			_make_dialogue_context(current_party_ids)
		)
	):
		call_deferred("_start_room_entry_dialogue")
	elif (
		developer_start_test_dialogue_on_room_entry
		and developer_test_dialogue != null
	):
		call_deferred("_start_developer_test_dialogue")

	return ""


func _apply_definition_presentation_texture() -> void:
	if definition == null or definition.presentation_texture == null:
		return
	var background: Sprite2D = presentation.find_child(
		"Background",
		true,
		false
	) as Sprite2D
	if background != null and background.texture == null:
		background.texture = definition.presentation_texture


func set_room_encounter_resolved(resolved: bool) -> void:
	for hotspot_value: Variant in active_encounter_hotspots.values():
		var hotspot: Variant = hotspot_value
		if hotspot != null:
			hotspot.set_interaction_enabled(not resolved)


func _on_room_encounter_requested(trigger_id: StringName) -> void:
	if mode_controller.is_dialogue_active():
		return
	room_encounter_requested.emit(trigger_id)


func prepare_story_dialogue(
	new_story_dialogue_id: StringName,
	new_source_node_id: StringName,
	background_texture: Texture2D,
	dialogue: DialogueDefinition,
	item_catalog: ItemCatalogDefinition,
	battler_catalog: BattlerCatalogDefinition,
	lore_catalog: LoreCatalogDefinition,
	knowledge_state: KnowledgeState,
	layer_number: int,
	inventory_snapshot: Array[Dictionary],
	party_snapshot: Dictionary,
	new_narrative_context_snapshot: Dictionary,
	present_actor_ids: Array[StringName],
	new_run_inventory_snapshot: Dictionary = {},
	new_run_equipment: RunEquipmentState = null
) -> String:
	if new_story_dialogue_id == &"":
		return "Story dialogue requires a stable story ID."
	if new_source_node_id == &"":
		return "Story dialogue requires a source map node."
	if background_texture == null:
		return "Story dialogue requires a scene background."
	if dialogue == null:
		return "Story dialogue requires a DialogueDefinition."
	if item_catalog == null:
		return "Story dialogue received no item catalog."
	if battler_catalog == null:
		return "Story dialogue received no battler catalog."
	if lore_catalog == null:
		return "Story dialogue received no lore catalog."
	if knowledge_state == null:
		return "Story dialogue received no KnowledgeState."

	story_dialogue_mode = true
	story_dialogue_id = new_story_dialogue_id
	story_source_node_id = new_source_node_id
	story_present_actor_ids = present_actor_ids.duplicate()
	definition = null
	instance_state = null
	available_item_catalog = item_catalog
	available_battler_catalog = battler_catalog
	available_lore_catalog = lore_catalog
	persistent_knowledge_state = knowledge_state
	current_layer_number = maxi(layer_number, 1)
	pending_bloom_delta = 0
	pending_dialogue_results.clear()
	narrative_context_snapshot = (
		new_narrative_context_snapshot.duplicate(true)
	)
	current_party_ids = _party_ids_from_snapshot(party_snapshot)
	run_equipment = new_run_equipment

	var inventory_error: String = _prepare_inventory(
		item_catalog,
		inventory_snapshot,
		new_run_inventory_snapshot
	)
	if not inventory_error.is_empty():
		return inventory_error

	var party_error: String = _prepare_party_strip(
		battler_catalog,
		party_snapshot
	)
	if not party_error.is_empty():
		return party_error

	presentation = _make_story_background(background_texture)
	room_host.add_child(presentation)
	selected_item_slot_index = -1
	selected_heroine_id = &""
	hover_label.text = ""
	_refresh_item_bar()
	_refresh_party_strip()
	call_deferred(
		"_start_story_dialogue",
		dialogue
	)
	return ""


func _make_story_background(background_texture: Texture2D) -> Node2D:
	var backdrop := Node2D.new()
	backdrop.name = "CurrentSceneDialogueBackdrop"
	var background := Sprite2D.new()
	background.name = "Background"
	background.texture = background_texture
	background.centered = false
	var texture_size: Vector2 = background_texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var presentation_size := Vector2(1920.0, 1080.0)
		var cover_scale: float = maxf(
			presentation_size.x / texture_size.x,
			presentation_size.y / texture_size.y
		)
		background.scale = Vector2.ONE * cover_scale
		background.position = (
			presentation_size - texture_size * cover_scale
		) * 0.5
	backdrop.add_child(background)
	return backdrop


func _start_story_dialogue(dialogue: DialogueDefinition) -> void:
	if not story_dialogue_mode or dialogue == null:
		return
	var start_error: String = start_dialogue(
		dialogue,
		story_present_actor_ids
	)
	if not start_error.is_empty():
		hover_label.text = start_error


func _start_developer_test_dialogue() -> void:
	if mode_controller.is_dialogue_active():
		return
	var start_error: String = start_dialogue(
		developer_test_dialogue,
		current_party_ids
	)
	if not start_error.is_empty():
		hover_label.text = start_error


func _start_room_entry_dialogue() -> void:
	if (
		definition == null
		or definition.entry_dialogue == null
		or mode_controller.is_dialogue_active()
	):
		return
	var start_error: String = start_dialogue(
		definition.entry_dialogue,
		current_party_ids
	)
	if not start_error.is_empty():
		hover_label.text = start_error

func _get_lore_entry(
	lore_entry_id: StringName
) -> LoreEntryDefinition:
	if available_lore_catalog == null:
		return null

	return available_lore_catalog.get_entry(
		lore_entry_id
	)

func _connect_exploration_interactable(
	interactable: ExplorationInteractable
) -> void:
	if interactable == null:
		return

	if not (
		interactable
			.interaction_hover_changed
			.is_connected(
				_on_exploration_interaction_hover_changed
			)
	):
		interactable.interaction_hover_changed.connect(
			_on_exploration_interaction_hover_changed
		)
		
func _on_exploration_interaction_hover_changed(
	interactable: ExplorationInteractable,
	is_hovered: bool
) -> void:
	if not is_instance_valid(interactable):
		return

	if not is_hovered:
		_restore_selected_item_description()
		return

	var display_name: String = (
		_get_exploration_interactable_display_name(
			interactable
		)
	)

	var prompt: String = (
		interactable.get_interaction_prompt()
	)

	var lines := PackedStringArray()

	if not display_name.is_empty():
		lines.append(
			display_name
		)

	if not prompt.is_empty():
		lines.append(
			prompt
		)

	if interactable is WorldRoomEvent:
		var world_event := (
			interactable as WorldRoomEvent
		)

		if (
			world_event.event_definition != null
			and world_event.event_definition.target_rule
			== RoomEventDefinition.TargetRule
				.SELECTED_HEROINE
		):
			if selected_heroine_id == &"":
				lines.append(
					"Select a heroine from the Party Strip."
				)
			else:
				var selected_state := (
					party_states.get(
						selected_heroine_id
					)
					as BattlerState
				)

				if (
					selected_state != null
					and selected_state.definition != null
				):
					lines.append(
						"Target: %s"
						% selected_state
							.definition
							.display_name
					)

	if lines.is_empty():
		_restore_selected_item_description()
		return

	hover_label.text = "\n".join(
		lines
	)
	
func _get_exploration_interactable_display_name(
	interactable: ExplorationInteractable
) -> String:
	if interactable is WorldLorePickup:
		var lore_pickup := (
			interactable as WorldLorePickup
		)

		var lore_entry: LoreEntryDefinition = (
			_get_lore_entry(
				lore_pickup.lore_entry_id
			)
		)

		if lore_entry == null:
			return "Unknown lore entry."

		return lore_entry.title

	return interactable.get_interaction_display_name()

func _on_world_lore_pickup_requested(
	lore_entry_id: StringName
) -> void:
	var lore_pickup := active_lore_pickups.get(
		lore_entry_id
	) as WorldLorePickup

	if lore_pickup == null:
		return

	var lore_entry: LoreEntryDefinition = (
		_get_lore_entry(
			lore_entry_id
		)
	)

	if lore_entry == null:
		hover_label.text = (
			"That lore entry is missing."
		)
		return

	var discover_error: String = (
		persistent_knowledge_state.discover_entry(
			lore_entry_id
		)
	)

	if not discover_error.is_empty():
		hover_label.text = discover_error
		return

	active_lore_pickups.erase(
		lore_entry_id
	)

	lore_pickup.queue_free()

	hover_label.text = lore_entry.discovery_text

func _prepare_inventory(
	item_catalog: ItemCatalogDefinition,
	inventory_snapshot: Array[Dictionary],
	run_inventory_snapshot: Dictionary = {}
) -> String:
	run_inventory = RunInventoryState.new()
	var inventory_heroine_ids: Array[StringName] = []
	if not run_inventory_snapshot.is_empty():
		var backpacks_value: Variant = run_inventory_snapshot.get(
			"backpacks_by_heroine",
			{}
		)
		if backpacks_value is Dictionary:
			for heroine_key: Variant in (backpacks_value as Dictionary).keys():
				inventory_heroine_ids.append(StringName(heroine_key))
	if inventory_heroine_ids.is_empty():
		inventory_heroine_ids = current_party_ids.duplicate()
	if inventory_heroine_ids.is_empty():
		inventory_heroine_ids = [&"lysandra"]
	inventory_heroine_ids.sort()
	var domain_error: String = run_inventory.initialize(
		item_catalog,
		inventory_heroine_ids
	)
	if domain_error.is_empty() and not run_inventory_snapshot.is_empty():
		domain_error = run_inventory.restore_from_snapshot(
			run_inventory_snapshot
		)
	elif domain_error.is_empty():
		domain_error = run_inventory.restore_item_bar_snapshot(
			inventory_snapshot
		)
	if not domain_error.is_empty():
		return domain_error

	inventory = SixSlotInventoryState.new()

	var initialization_error: String = inventory.initialize(
		item_catalog
	)

	if not initialization_error.is_empty():
		return initialization_error

	var item_ids: Array[StringName] = []
	var quantities: Array[int] = []

	var presented_item_bar: Array[Dictionary] = (
		run_inventory.get_item_bar_snapshot()
	)
	for slot_index: int in range(
		SixSlotInventoryState.SLOT_COUNT
	):
		var slot_data: Dictionary = {}

		if slot_index < presented_item_bar.size():
			slot_data = presented_item_bar[slot_index]

		item_ids.append(
			StringName(
				slot_data.get(
					"item_id",
					""
				)
			)
		)

		quantities.append(
			int(
				slot_data.get(
					"quantity",
					0
				)
			)
		)

	var load_error: String = inventory.load_items(
		item_ids,
		quantities
	)

	if not load_error.is_empty():
		return load_error

	if not inventory.inventory_changed.is_connected(
		_refresh_item_bar
	):
		inventory.inventory_changed.connect(
			_refresh_item_bar
		)

	_refresh_item_bar()

	return ""


func _prepare_party_strip(
	battler_catalog: BattlerCatalogDefinition,
	party_snapshot: Dictionary
) -> String:
	party_states.clear()

	for battler_id: StringName in [
		&"lysandra",
		&"mira",
		&"seraphine",
	]:
		var battler_definition: BattlerDefinition = (
			battler_catalog.get_battler(
				battler_id
			)
		)

		if battler_definition == null:
			return (
				"Event-room Party Strip cannot find battler '%s'."
				% battler_id
			)

		var personal_loadout: PersonalEquipmentLoadoutState
		if run_equipment != null:
			personal_loadout = run_equipment.get_loadout(battler_id)
		var state := BattlerState.new(
			battler_definition,
			null,
			personal_loadout
		)

		var snapshot_value: Variant = party_snapshot.get(
			battler_id,
			party_snapshot.get(
				String(battler_id),
				{}
			)
		)

		var saved_state: Dictionary = {}
		var is_current_party_member: bool = (
			party_snapshot.has(battler_id)
			or party_snapshot.has(String(battler_id))
		)

		if not is_current_party_member:
			continue

		if snapshot_value is Dictionary:
			saved_state = (
				snapshot_value as Dictionary
			)

		if not saved_state.is_empty():
			state.current_hp = clampi(
				int(
					saved_state.get(
						"hp",
						state.current_hp
					)
				),
				0,
				state.get_max_hp()
			)

			state.current_mp = clampi(
				int(
					saved_state.get(
						"mp",
						state.current_mp
					)
				),
				0,
				state.get_max_mp()
			)

			state.current_resolve = clampi(
				int(
					saved_state.get(
						"resolve",
						state.current_resolve
					)
				),
				0,
				100
			)

			state.current_corruption = clampi(
				int(
					saved_state.get(
						"corruption",
						state.current_corruption
					)
				),
				0,
				100
			)

			state.item_guard_points = maxi(
				int(
					saved_state.get(
						"item_guard",
						0
					)
				),
				0
			)

			_restore_party_equipment_state(
				state,
				saved_state
			)

		state.is_defeated = (
			state.current_hp <= 0
		)

		# Actions are combat-only.
		state.current_actions = 0
		state.max_actions = 0

		party_states[battler_id] = state

	_refresh_party_strip()

	return ""


func start_dialogue(
	dialogue: DialogueDefinition,
	present_actor_ids: Array[StringName] = [],
	restored_session: DialogueSessionState = null
) -> String:
	if mode_controller.is_dialogue_active():
		return "Another dialogue is already active."

	dialogue_context = _make_dialogue_context(present_actor_ids)
	dialogue_runner = DialogueRunner.new()
	var start_error: String = dialogue_runner.start(
		dialogue,
		dialogue_context,
		restored_session
	)
	if not start_error.is_empty():
		dialogue_runner = null
		dialogue_context = null
		return start_error

	_set_room_interactions_enabled(false)
	var entry_result: DialogueResult = (
		dialogue_runner.consume_pending_transition_result()
	)
	if (
		not entry_result.outcomes.is_empty()
		or not entry_result.automatic_transition_ids.is_empty()
		or entry_result.completed
	):
		if entry_result.completed:
			# Let the owning preparation call finish before an all-automatic
			# dialogue emits its completion signal.
			call_deferred("_handle_dialogue_result", entry_result)
		else:
			_handle_dialogue_result(entry_result)
	else:
		_refresh_dialogue_presentation()
	return ""


func stop_dialogue() -> void:
	mode_controller.set_mode(
		ExplorationModeController.Mode.FREE_EXPLORATION
	)
	dialogue_runner = null
	dialogue_context = null
	exploration_hud.set_dialogue_active(false)
	_set_room_interactions_enabled(true)
	selected_item_slot_index = -1
	_refresh_item_bar()
	_refresh_party_strip()


func _make_dialogue_context(
	present_actor_ids: Array[StringName]
) -> DialogueContext:
	var context := DialogueContext.new()
	context.current_party_ids = current_party_ids.duplicate()
	context.present_actor_ids = present_actor_ids.duplicate()
	context.heroine_states = _capture_party_snapshot()

	for slot_data: Dictionary in inventory.get_snapshot():
		var item_id := StringName(slot_data.get("item_id", ""))
		if item_id != &"":
			context.inventory_quantities[item_id] = int(
				slot_data.get("quantity", 0)
			)

	for entry_value: Variant in persistent_knowledge_state.discovered_entries.keys():
		context.knowledge_ids.append(StringName(entry_value))

	context.recruited_heroine_ids = DialogueContext._name_array(
		narrative_context_snapshot.get("recruited_heroine_ids", []) as Array
	)
	context.flags_by_scope = (
		narrative_context_snapshot.get("flags_by_scope", {
			&"run": {},
			&"save": {},
			&"persistent": {},
		}) as Dictionary
	).duplicate(true)
	context.choice_ids = DialogueContext._name_array(
		narrative_context_snapshot.get("choice_ids", []) as Array
	)
	context.resolved_interaction_ids = DialogueContext._name_array(
		narrative_context_snapshot.get(
			"resolved_interaction_ids",
			[]
		) as Array
	)
	context.campaign_item_ids = DialogueContext._name_array(
		narrative_context_snapshot.get("campaign_item_ids", []) as Array
	)
	return context


func _party_ids_from_snapshot(snapshot: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		if snapshot.has(heroine_id) or snapshot.has(String(heroine_id)):
			result.append(heroine_id)
	return result


func _set_room_interactions_enabled(enabled: bool) -> void:
	if presentation == null:
		return
	if not enabled:
		suspended_interaction_states.clear()
	for child: Node in presentation.find_children("*", "", true, false):
		if child is ExplorationInteractable:
			var interactable := child as ExplorationInteractable
			if not enabled:
				suspended_interaction_states[interactable.get_instance_id()] = (
					interactable.is_interaction_enabled()
				)
				interactable.set_interaction_enabled(false)
			else:
				interactable.set_interaction_enabled(
					bool(
						suspended_interaction_states.get(
							interactable.get_instance_id(),
							false
						)
					)
				)
	if enabled:
		suspended_interaction_states.clear()
		# Reassert authored lock/exit coupling after restoring the captured
		# interaction states. A locked exit must never become pickable merely
		# because a dialogue mode ended.
		for lock_value: Variant in active_locks.values():
			var room_lock := lock_value as RoomLockHotspot
			if room_lock != null:
				room_lock.apply_unlocked_state(room_lock.is_unlocked)


func _refresh_dialogue_presentation() -> void:
	if dialogue_runner == null:
		return
	var node: DialogueNodeDefinition = dialogue_runner.get_current_node()
	if node == null:
		stop_dialogue()
		return

	var presented_choices: Array[Dictionary] = (
		dialogue_runner.get_presented_choices()
	)
	var mode := ExplorationModeController.Mode.DIALOGUE
	if not presented_choices.is_empty():
		mode = ExplorationModeController.Mode.CHOICE_SELECTION
	elif node.item_policy in [
		DialogueNodeDefinition.ItemPolicy.DIALOGUE_ITEMS,
		DialogueNodeDefinition.ItemPolicy.REQUIRED_ITEM,
	]:
		mode = ExplorationModeController.Mode.DIALOGUE_ITEM_SELECTION
	mode_controller.set_mode(mode)
	exploration_hud.set_dialogue_active(true, node.mandatory)
	exploration_hud.dialogue_panel.present(dialogue_runner)
	_refresh_item_bar()


func _on_dialogue_advance_requested() -> void:
	if dialogue_runner == null:
		return
	_handle_dialogue_result(dialogue_runner.advance())


func _on_dialogue_choice_requested(choice_id: StringName) -> void:
	if dialogue_runner == null:
		return
	_handle_dialogue_result(dialogue_runner.choose(choice_id))


func _handle_dialogue_result(result: DialogueResult) -> void:
	if result == null:
		return
	if not result.error_message.is_empty():
		hover_label.text = result.error_message
		return
	if not result.outcomes.is_empty():
		var apply_error: String = _apply_dialogue_outcomes(result.outcomes)
		if not apply_error.is_empty():
			hover_label.text = apply_error
			return
	if (
		not result.outcomes.is_empty()
		or result.selected_choice_id != &""
		or result.selected_item_id != &""
		or not result.automatic_transition_ids.is_empty()
		or result.completed
	):
		pending_dialogue_results.append(result.to_snapshot())
	if result.completed:
		stop_dialogue()
		if story_dialogue_mode:
			_emit_story_dialogue_outcome()
		return
	_refresh_dialogue_presentation()


func _apply_dialogue_outcomes(
	outcomes: Array[DialogueOutcomeDefinition]
) -> String:
	for outcome: DialogueOutcomeDefinition in outcomes:
		match outcome.kind:
			DialogueOutcomeDefinition.Kind.ADD_ITEM:
				var add_error: String = _route_carried_item_reward(
					outcome.subject_id,
					outcome.integer_value
				)
				if not add_error.is_empty():
					return add_error
			DialogueOutcomeDefinition.Kind.CONSUME_ITEM:
				var consume_error: String = _consume_dialogue_item(
					outcome.subject_id,
					outcome.integer_value
				)
				if not consume_error.is_empty():
					return consume_error
			DialogueOutcomeDefinition.Kind.MODIFY_HEROINE_STAT:
				_apply_dialogue_stat_delta(outcome)
			DialogueOutcomeDefinition.Kind.MODIFY_ACTIVE_PARTY_STAT:
				for heroine_id: StringName in current_party_ids:
					var party_outcome: DialogueOutcomeDefinition = outcome.duplicate()
					party_outcome.subject_id = heroine_id
					_apply_dialogue_stat_delta(party_outcome)
			DialogueOutcomeDefinition.Kind.RESTORE_ACTIVE_PARTY_FULL:
				_restore_active_party_full()
			DialogueOutcomeDefinition.Kind.CONSUME_ROOM_ITEM:
				var room_item_error: String = _consume_room_item(
					outcome.subject_id,
					outcome.integer_value
				)
				if not room_item_error.is_empty():
					return room_item_error
			DialogueOutcomeDefinition.Kind.GRANT_CAMPAIGN_ITEM:
				var campaign_item: ItemDefinition = (
					available_item_catalog.get_item(outcome.subject_id)
					if available_item_catalog != null
					else null
				)
				if (
					campaign_item == null
					or campaign_item.content_category
					!= ItemDefinition.ContentCategory.STORY
				):
					return "Unknown campaign Story item '%s'." % outcome.subject_id
			DialogueOutcomeDefinition.Kind.GRANT_BLOOM:
				pending_bloom_delta += outcome.integer_value
			DialogueOutcomeDefinition.Kind.GRANT_KNOWLEDGE:
				var knowledge_error: String = (
					persistent_knowledge_state.discover_entry(
						outcome.subject_id
					)
				)
				if not knowledge_error.is_empty():
					return knowledge_error
			DialogueOutcomeDefinition.Kind.RECRUIT_HEROINE:
				if outcome.boolean_value:
					var recruit_error: String = _add_recruited_heroine_to_party(
						outcome.subject_id
					)
					if not recruit_error.is_empty():
						return recruit_error
			DialogueOutcomeDefinition.Kind.START_BATTLE, DialogueOutcomeDefinition.Kind.REQUEST_SCENE:
				dialogue_story_request_ready.emit(outcome.to_snapshot())
	_refresh_item_bar()
	_refresh_party_strip()
	return ""


func _add_recruited_heroine_to_party(heroine_id: StringName) -> String:
	if current_party_ids.has(heroine_id):
		return ""
	if available_battler_catalog == null:
		return "Dialogue recruitment has no battler catalog."
	var battler: BattlerDefinition = available_battler_catalog.get_battler(
		heroine_id
	)
	if battler == null:
		return "Dialogue recruitment cannot find heroine '%s'." % heroine_id
	var personal_loadout: PersonalEquipmentLoadoutState
	if run_equipment != null:
		personal_loadout = run_equipment.get_loadout(heroine_id)
	var state := BattlerState.new(battler, null, personal_loadout)
	state.current_actions = 0
	state.max_actions = 0
	party_states[heroine_id] = state
	current_party_ids.append(heroine_id)
	return ""


func _consume_dialogue_item(
	item_id: StringName,
	quantity: int
) -> String:
	for slot_index: int in range(SixSlotInventoryState.SLOT_COUNT):
		var slot: InventorySlotState = inventory.get_slot(slot_index)
		if slot != null and not slot.is_empty() and slot.item.item_id == item_id:
			var consume_error: String = inventory.consume(slot_index, quantity)
			if not consume_error.is_empty():
				return consume_error
			return _sync_run_inventory_item_bar()
	return "Dialogue item '%s' is no longer in the Item Bar." % item_id


func _apply_dialogue_stat_delta(outcome: DialogueOutcomeDefinition) -> void:
	var state := party_states.get(outcome.subject_id) as BattlerState
	if state == null:
		return
	match outcome.key:
		&"hp":
			state.current_hp = clampi(
				state.current_hp + outcome.integer_value,
				0,
				state.get_max_hp()
			)
		&"mp":
			state.current_mp = clampi(
				state.current_mp + outcome.integer_value,
				0,
				state.get_max_mp()
			)
		&"resolve":
			state.current_resolve = clampi(
				state.current_resolve + outcome.integer_value,
				0,
				100
			)
		&"corruption":
			state.current_corruption = clampi(
				state.current_corruption + outcome.integer_value,
				0,
				100
			)


func _restore_active_party_full() -> void:
	for heroine_id: StringName in current_party_ids:
		var state := party_states.get(heroine_id) as BattlerState
		if state == null:
			continue
		if state.is_defeated:
			state.revive(state.get_max_hp())
		else:
			state.current_hp = state.get_max_hp()
		state.current_mp = state.get_max_mp()
		# Event rooms render exploration party cards. BattlerState.revive()
		# restores the saved combat action allowance by design, so explicitly
		# return the revived state to the exploration-only contract here.
		state.current_actions = 0
		state.max_actions = 0


func _consume_room_item(item_id: StringName, quantity: int) -> String:
	if instance_state == null or quantity <= 0:
		return "Room-item consumption requires an active room and positive quantity."
	var assignments: Array = (
		instance_state.local_state.get("item_spawns", []) as Array
	).duplicate(true)
	var eligible_indices: Array[int] = []
	for assignment_index: int in range(assignments.size()):
		var assignment := assignments[assignment_index] as Dictionary
		if bool(assignment.get("collected", false)):
			continue
		var item: ItemDefinition = _get_assignment_item(assignment)
		if item != null and item.item_id == item_id:
			eligible_indices.append(assignment_index)
	if eligible_indices.size() < quantity:
		return "The room no longer contains %s ×%d." % [item_id, quantity]
	for consumed_index: int in range(quantity):
		var assignment_index: int = eligible_indices[consumed_index]
		var assignment := assignments[assignment_index] as Dictionary
		assignment["collected"] = true
		assignment["claimed"] = true
		assignment["deferred"] = false
		assignments[assignment_index] = assignment
		var spawn_id := StringName(assignment.get("spawn_id", ""))
		var pickup := active_pickups.get(spawn_id) as WorldItemPickup
		if pickup != null:
			active_pickups.erase(spawn_id)
			pickup.queue_free()
	instance_state.local_state["item_spawns"] = assignments.duplicate(true)
	return ""


func _restore_party_equipment_state(
	state: BattlerState,
	snapshot: Dictionary
) -> void:
	if state.weapon_state != null:
		state.weapon_state.durability_damage = maxi(
			int(
				snapshot.get(
					"weapon_damage",
					0
				)
			),
			0
		)

		state.weapon_state.is_broken = bool(
			snapshot.get(
				"weapon_broken",
				false
			)
		)

	if state.armor_state != null:
		state.armor_state.absorbed_damage = maxi(
			int(
				snapshot.get(
					"armor_damage",
					0
				)
			),
			0
		)

		state.armor_state.is_broken = bool(
			snapshot.get(
				"armor_broken",
				false
			)
		)

	if state.shield_state != null:
		state.shield_state.absorbed_damage = maxi(
			int(
				snapshot.get(
					"shield_damage",
					0
				)
			),
			0
		)

		state.shield_state.is_broken = bool(
			snapshot.get(
				"shield_broken",
				false
			)
		)


func _refresh_party_strip() -> void:
	exploration_hud.set_active_party_ids(current_party_ids)
	for battler_id: StringName in [
		&"lysandra",
		&"mira",
		&"seraphine",
	]:
		var state := party_states.get(
			battler_id
		) as BattlerState

		var card: HeroineCardView = (
			_get_party_card(
				battler_id
			)
		)

		if card == null:
			continue

		card.display_state(
			state,
			selected_heroine_id == battler_id
		)


func _get_party_card(
	battler_id: StringName
) -> HeroineCardView:
	return exploration_hud.get_party_card(battler_id)


func _on_heroine_card_selected(
	battler_id: StringName
) -> void:
	if selected_item_slot_index >= 0:
		_try_use_selected_item_on(
			battler_id
		)
		return

	if selected_heroine_id == battler_id:
		selected_heroine_id = &""
	else:
		selected_heroine_id = battler_id

	_refresh_party_strip()


func _refresh_item_bar() -> void:
	if inventory == null or item_bar == null:
		return

	for slot_index: int in range(
		SixSlotInventoryState.SLOT_COUNT
	):
		var slot: InventorySlotState = (
			inventory.get_slot(
				slot_index
			)
		)

		if slot == null or slot.is_empty():
			item_bar.display_slot(
				slot_index,
				"%d\nEmpty" % (
					slot_index + 1
				),
				false,
				"Empty Item Bar slot.",
				false
			)

			continue

		var item: ItemDefinition = slot.item
		var dialogue_enabled: bool = _is_item_enabled_for_dialogue(
			item.item_id
		)

		item_bar.display_slot(
			slot_index,
			"%d\n%s\n×%d" % [
				slot_index + 1,
				item.display_name,
				slot.quantity,
			],
			dialogue_enabled,
			item.description,
			selected_item_slot_index == slot_index,
			item.icon
		)


func _is_item_enabled_for_dialogue(item_id: StringName) -> bool:
	if not mode_controller.is_dialogue_active() or dialogue_runner == null:
		return true
	var node: DialogueNodeDefinition = dialogue_runner.get_current_node()
	if node == null:
		return false
	match node.item_policy:
		DialogueNodeDefinition.ItemPolicy.NORMAL_USE:
			return true
		DialogueNodeDefinition.ItemPolicy.DIALOGUE_ITEMS, DialogueNodeDefinition.ItemPolicy.REQUIRED_ITEM:
			for option: DialogueItemOptionDefinition in node.item_options:
				if option.item_id == item_id:
					return true
	return false


func _on_item_slot_requested(
	slot_index: int
) -> void:
	if inventory == null:
		return

	var slot: InventorySlotState = inventory.get_slot(
		slot_index
	)

	if slot == null or slot.is_empty():
		selected_item_slot_index = -1
		selected_heroine_id = &""

		hover_label.text = (
			"That Item Bar slot is empty."
		)

		_refresh_item_bar()
		_refresh_party_strip()

		return

	if mode_controller.is_dialogue_active() and dialogue_runner != null:
		var dialogue_node: DialogueNodeDefinition = (
			dialogue_runner.get_current_node()
		)
		if dialogue_node == null:
			return
		if dialogue_node.item_policy in [
			DialogueNodeDefinition.ItemPolicy.DIALOGUE_ITEMS,
			DialogueNodeDefinition.ItemPolicy.REQUIRED_ITEM,
		]:
			var item_result: DialogueResult = dialogue_runner.select_item(
				slot.item.item_id,
				selected_heroine_id
			)
			if item_result.selected_item_id == &"":
				hover_label.text = (
					"That item is not a valid answer here, or its "
					+ "required heroine is not selected."
				)
				return
			_handle_dialogue_result(item_result)
			return
		if dialogue_node.item_policy == DialogueNodeDefinition.ItemPolicy.DISABLED:
			hover_label.text = "Items cannot be used at this dialogue point."
			return

	if selected_item_slot_index == slot_index:
		selected_item_slot_index = -1
		selected_heroine_id = &""
		hover_label.text = ""

		_refresh_item_bar()
		_refresh_party_strip()

		return

	selected_item_slot_index = slot_index
	selected_heroine_id = &""

	var item: ItemDefinition = slot.item

	if (
		item.item_type
		== ItemDefinition.ItemType.KEY
	):
		hover_label.text = (
			"%s ×%d\n%s\n"
			+ "Use it on an environmental interaction."
		) % [
			item.display_name,
			slot.quantity,
			item.description,
		]
	else:
		hover_label.text = (
			"%s ×%d\n%s\n"
			+ "Select a heroine from the Party Strip."
		) % [
			item.display_name,
			slot.quantity,
			item.description,
		]

	_refresh_item_bar()
	_refresh_party_strip()


func _try_use_selected_item_on(
	target_id: StringName
) -> void:
	if (
		inventory == null
		or selected_item_slot_index < 0
	):
		return

	var slot: InventorySlotState = inventory.get_slot(
		selected_item_slot_index
	)

	if slot == null or slot.is_empty():
		selected_item_slot_index = -1

		hover_label.text = (
			"The selected item slot is now empty."
		)

		_refresh_item_bar()

		return

	var target := party_states.get(
		target_id
	) as BattlerState

	if (
		target == null
		or target.definition == null
	):
		hover_label.text = (
			"The selected heroine is unavailable."
		)

		return

	var item: ItemDefinition = slot.item

	var validation_error: String = (
		_validate_exploration_item_use(
			item,
			target
		)
	)

	if not validation_error.is_empty():
		hover_label.text = validation_error
		return

	var effect_logs: Array[String] = []

	for effect: ItemEffectDefinition in item.effects:
		var effect_log: String = (
			_apply_exploration_item_effect(
				target,
				effect
			)
		)

		if not effect_log.is_empty():
			effect_logs.append(
				effect_log
			)

	if effect_logs.is_empty():
		hover_label.text = (
			"%s would have no effect on %s."
			% [
				item.display_name,
				target.definition.display_name,
			]
		)

		return

	if item.consumes_on_use:
		var consume_error: String = inventory.consume(
			selected_item_slot_index,
			1
		)

		if not consume_error.is_empty():
			hover_label.text = consume_error
			return

	var effect_summary: String = ""

	for effect_log: String in effect_logs:
		if not effect_summary.is_empty():
			effect_summary += "\n"

		effect_summary += effect_log

	selected_heroine_id = target_id
	selected_item_slot_index = -1

	_refresh_party_strip()
	_refresh_item_bar()

	hover_label.text = (
		"%s used on %s.\n%s"
		% [
			item.display_name,
			target.definition.display_name,
			effect_summary,
		]
	)


func _validate_exploration_item_use(
	item: ItemDefinition,
	target: BattlerState
) -> String:
	if item == null:
		return (
			"The selected item slot is empty."
		)

	if (
		target == null
		or target.definition == null
	):
		return "Select a valid heroine."

	if (
		target.definition.faction
		!= BattlerDefinition.Faction.HEROINE
	):
		return (
			"Exploration items require a heroine target."
		)

	match item.item_type:
		ItemDefinition.ItemType.PASSIVE:
			return (
				"%s is passive and cannot be activated."
				% item.display_name
			)

		ItemDefinition.ItemType.KEY:
			return (
				"%s must be used on an "
				+ "environmental interaction."
			) % item.display_name

	if item.performs_attack:
		return (
			"%s can only be used through "
			+ "the battle Attack system."
		) % item.display_name

	if item.target_rule not in [
		ItemDefinition.TargetRule.SELF,
		ItemDefinition.TargetRule.SELF_OR_ADJACENT_HEROINE,
		ItemDefinition.TargetRule.ANY_HEROINE,
	]:
		return (
			"%s requires a battle or "
			+ "environmental target."
		) % item.display_name

	if item.effects.is_empty():
		return (
			"%s has no active effects."
			% item.display_name
		)

	if (
		target.is_defeated
		and not _item_has_effect_kind(
			item,
			ItemEffectDefinition.Kind.REVIVE
		)
	):
		return (
			"%s is defeated and requires "
			+ "a revival item."
		) % target.definition.display_name

	if not _has_applicable_exploration_effect(
		item,
		target
	):
		return (
			"%s would have no effect on %s."
			% [
				item.display_name,
				target.definition.display_name,
			]
		)

	return ""


func _item_has_effect_kind(
	item: ItemDefinition,
	kind: ItemEffectDefinition.Kind
) -> bool:
	for effect: ItemEffectDefinition in item.effects:
		if (
			effect != null
			and effect.kind == kind
		):
			return true

	return false


func _has_applicable_exploration_effect(
	item: ItemDefinition,
	target: BattlerState
) -> bool:
	for effect: ItemEffectDefinition in item.effects:
		if _is_exploration_effect_applicable(
			target,
			effect
		):
			return true

	return false


func _is_exploration_effect_applicable(
	target: BattlerState,
	effect: ItemEffectDefinition
) -> bool:
	if target == null or effect == null:
		return false

	match effect.kind:
		ItemEffectDefinition.Kind.HEAL_HP:
			return (
				not target.is_defeated
				and effect.amount > 0
				and target.current_hp
				< target.get_max_hp()
			)

		ItemEffectDefinition.Kind.RESTORE_MP:
			return (
				not target.is_defeated
				and effect.amount > 0
				and target.current_mp
				< target.get_max_mp()
			)

		ItemEffectDefinition.Kind.CHANGE_RESOLVE:
			return (
				(
					effect.amount > 0
					and target.current_resolve < 100
				)
				or (
					effect.amount < 0
					and target.current_resolve > 0
				)
			)

		ItemEffectDefinition.Kind.CHANGE_CORRUPTION:
			return (
				(
					effect.amount > 0
					and target.current_corruption < 100
				)
				or (
					effect.amount < 0
					and target.current_corruption > 0
				)
			)

		ItemEffectDefinition.Kind.REVIVE:
			return target.is_defeated

		ItemEffectDefinition.Kind.ADD_GUARD:
			return (
				not target.is_defeated
				and effect.amount > 0
				and target.item_guard_points < 99
			)

		ItemEffectDefinition.Kind.REPAIR_WEAPON:
			return (
				target.weapon_state != null
				and (
					target.weapon_state.is_broken
					or target.weapon_state.durability_damage > 0
				)
			)

		ItemEffectDefinition.Kind.REPAIR_ARMOR:
			return (
				target.armor_state != null
				and (
					target.armor_state.is_broken
					or target.armor_state.absorbed_damage > 0
				)
			)

		ItemEffectDefinition.Kind.REPAIR_SHIELD:
			return (
				target.shield_state != null
				and (
					target.shield_state.is_broken
					or target.shield_state.absorbed_damage > 0
				)
			)

	return false


func _apply_exploration_item_effect(
	target: BattlerState,
	effect: ItemEffectDefinition
) -> String:
	if not _is_exploration_effect_applicable(
		target,
		effect
	):
		return ""

	var display_name: String = (
		target.definition.display_name
	)

	match effect.kind:
		ItemEffectDefinition.Kind.HEAL_HP:
			var restored_hp: int = target.heal(
				effect.amount
			)

			if restored_hp > 0:
				return (
					"%s restored %d HP."
					% [
						display_name,
						restored_hp,
					]
				)

		ItemEffectDefinition.Kind.RESTORE_MP:
			var restored_mp: int = target.restore_mp(
				effect.amount
			)

			if restored_mp > 0:
				return (
					"%s restored %d MP."
					% [
						display_name,
						restored_mp,
					]
				)

		ItemEffectDefinition.Kind.CHANGE_RESOLVE:
			var resolve_change: int = (
				target.change_resolve(
					effect.amount
				)
			)

			if resolve_change != 0:
				return (
					"%s's Resolve changed by %d."
					% [
						display_name,
						resolve_change,
					]
				)

		ItemEffectDefinition.Kind.CHANGE_CORRUPTION:
			var corruption_change: int = (
				target.change_corruption(
					effect.amount
				)
			)

			if corruption_change != 0:
				return (
					"%s's Corruption changed by %d."
					% [
						display_name,
						corruption_change,
					]
				)

		ItemEffectDefinition.Kind.REVIVE:
			if target.revive(
				maxi(
					effect.amount,
					1
				)
			):
				return (
					"%s was revived."
					% display_name
				)

		ItemEffectDefinition.Kind.ADD_GUARD:
			var guard_added: int = (
				target.add_item_guard(
					effect.amount
				)
			)

			if guard_added > 0:
				return (
					"%s gained %d Item Guard."
					% [
						display_name,
						guard_added,
					]
				)

		ItemEffectDefinition.Kind.REPAIR_WEAPON:
			var weapon_repaired: int = (
				target.repair_weapon(
					effect.amount
				)
			)

			if weapon_repaired > 0:
				return (
					"%s repaired %d Weapon damage."
					% [
						display_name,
						weapon_repaired,
					]
				)

		ItemEffectDefinition.Kind.REPAIR_ARMOR:
			var armor_repaired: int = (
				target.repair_armor(
					effect.amount
				)
			)

			if armor_repaired > 0:
				return (
					"%s repaired %d Armor damage."
					% [
						display_name,
						armor_repaired,
					]
				)

		ItemEffectDefinition.Kind.REPAIR_SHIELD:
			var shield_repaired: int = (
				target.repair_shield(
					effect.amount
				)
			)

			if shield_repaired > 0:
				return (
					"%s repaired %d Shield damage."
					% [
						display_name,
						shield_repaired,
					]
				)

	return ""

func _prepare_room_items() -> String:
	active_pickups.clear()

	var generated_requests: Array = (
		instance_state.local_state.get(
			"generated_item_requests",
			[]
		) as Array
	)

	if (
		definition.loot_profile == null
		and generated_requests.is_empty()
	):
		return ""

	var world_item_layer := (
		presentation.get_node_or_null(
			"WorldItemLayer"
		) as Node2D
	)

	if world_item_layer == null:
		return (
			"Event room '%s' has no WorldItemLayer."
			% definition.room_id
		)

	var anchors: Array[RoomItemSpawnAnchor] = []

	for child: Node in presentation.find_children(
		"*",
		"",
		true,
		false
	):
		if child is RoomItemSpawnAnchor:
			anchors.append(
				child as RoomItemSpawnAnchor
			)

	anchors.sort_custom(
		func(
			left: RoomItemSpawnAnchor,
			right: RoomItemSpawnAnchor
		) -> bool:
			return (
				String(left.anchor_id)
				< String(right.anchor_id)
			)
	)

	for anchor: RoomItemSpawnAnchor in anchors:
		var anchor_error: String = (
			anchor.validate_anchor()
		)

		if not anchor_error.is_empty():
			return anchor_error

	var assignments: Array = (
		instance_state.local_state.get(
			"item_spawns",
			[]
		) as Array
	)

	if assignments.is_empty():
		assignments = []

		if definition.loot_profile != null:
			var loot_error: String = (
				_append_loot_profile_assignments(
					assignments,
					anchors
				)
			)

			if not loot_error.is_empty():
				return loot_error

		var generated_error: String = (
			_append_generated_item_assignments(
				assignments,
				anchors
			)
		)

		if not generated_error.is_empty():
			return generated_error

		instance_state.local_state[
			"item_spawns"
		] = assignments.duplicate(true)

	return _spawn_assigned_items(
		assignments,
		anchors,
		world_item_layer
	)



func _append_generated_item_assignments(
	assignments: Array,
	anchors: Array[RoomItemSpawnAnchor]
) -> String:
	var requests: Array = (
		instance_state.local_state.get(
			"generated_item_requests",
			[]
		) as Array
	)

	if requests.is_empty():
		return ""

	if available_item_catalog == null:
		return (
			"Event room cannot resolve generated items "
			+ "without an Item Catalog."
		)

	var used_anchor_ids: Dictionary = {}

	for assignment_value: Variant in assignments:
		if not (assignment_value is Dictionary):
			continue

		var existing_assignment := (
			assignment_value as Dictionary
		)

		var existing_anchor_id := StringName(
			existing_assignment.get(
				"anchor_id",
				""
			)
		)

		if existing_anchor_id != &"":
			used_anchor_ids[existing_anchor_id] = true

	var available_anchors: Array[RoomItemSpawnAnchor] = []

	for anchor: RoomItemSpawnAnchor in anchors:
		if not used_anchor_ids.has(anchor.anchor_id):
			available_anchors.append(anchor)

	var rng := RandomNumberGenerator.new()
	rng.seed = instance_state.generation_seed + 7919

	var seen_assignment_ids: Dictionary = {}

	for request_value: Variant in requests:
		if not (request_value is Dictionary):
			return (
				"Event room contains an invalid "
				+ "generated item request."
			)

		var request := request_value as Dictionary

		var assignment_id := StringName(
			request.get(
				"assignment_id",
				""
			)
		)

		var item_id := StringName(
			request.get(
				"item_id",
				""
			)
		)

		var required_anchor_tag := StringName(
			request.get(
				"required_anchor_tag",
				""
			)
		)

		var quantity: int = int(
			request.get(
				"quantity",
				1
			)
		)

		if assignment_id == &"":
			return (
				"A generated room item requires "
				+ "an assignment_id."
			)

		if seen_assignment_ids.has(assignment_id):
			return (
				"Duplicate generated room item assignment: '%s'."
				% assignment_id
			)

		seen_assignment_ids[assignment_id] = true

		if item_id == &"":
			return (
				"Generated room item '%s' has no item_id."
				% assignment_id
			)

		if required_anchor_tag == &"":
			return (
				"Generated room item '%s' has no anchor tag."
				% assignment_id
			)

		if quantity <= 0:
			return (
				"Generated room item '%s' has invalid quantity."
				% assignment_id
			)

		var item: ItemDefinition = (
			available_item_catalog.get_item(
				item_id
			)
		)

		if item == null:
			return (
				"Generated room item '%s' references "
				+ "unknown item '%s'."
			) % [
				assignment_id,
				item_id,
			]

		if item.icon == null:
			return (
				"Generated room item '%s' has no world texture."
				% assignment_id
			)

		var selected_anchor: RoomItemSpawnAnchor = (
			_take_random_matching_anchor(
				available_anchors,
				required_anchor_tag,
				rng
			)
		)

		if selected_anchor == null:
			return (
				"Generated room item '%s' requires "
				+ "an available '%s' anchor."
			) % [
				assignment_id,
				required_anchor_tag,
			]

		var generated_assignment: Dictionary = {
				"spawn_id": (
					"generated_%s"
					% String(assignment_id)
				),
				"anchor_id": String(
					selected_anchor.anchor_id
				),
				"entry_id": "",
				"item_id": String(item_id),
				"quantity": quantity,
				"collected": false,
			}
		for record_key: String in [
			"source_id",
			"source_channel",
			"binding_id",
			"entry_id",
			"resolution_seed",
			"base_weight",
			"effective_weight",
			"current_layer",
			"once_only",
			"claimed",
			"deferred",
		]:
			if request.has(record_key):
				generated_assignment[record_key] = request[record_key]
		assignments.append(generated_assignment)

	return ""

func _get_loot_profile_entry(
	entry_id: StringName,
	source_id: StringName = &""
) -> RoomItemPoolEntryDefinition:
	if (
		entry_id == &""
		or definition == null
		or definition.loot_profile == null
	):
		return null

	return definition.loot_profile.get_entry(
		entry_id,
		source_id
	)

func _get_assignment_world_visual_scale(
	assignment: Dictionary
) -> Vector2:
	var entry_id := StringName(
		assignment.get(
			"entry_id",
			""
		)
	)

	if entry_id != &"":
		var entry: RoomItemPoolEntryDefinition = (
			_get_loot_profile_entry(
				entry_id,
				StringName(assignment.get("source_id", ""))
			)
		)

		if entry != null:
			return entry.world_visual_scale

	return Vector2.ONE

func _get_assignment_item(
	assignment: Dictionary
) -> ItemDefinition:
	var entry_id := StringName(
		assignment.get(
			"entry_id",
			""
		)
	)

	if entry_id != &"":
		var entry: RoomItemPoolEntryDefinition = (
			_get_loot_profile_entry(
				entry_id,
				StringName(assignment.get("source_id", ""))
			)
		)

		if entry != null:
			return entry.item

	var item_id := StringName(
		assignment.get(
			"item_id",
			""
		)
	)

	if (
		item_id == &""
		or available_item_catalog == null
	):
		return null

	return available_item_catalog.get_item(
		item_id
	)

func _get_assignment_world_texture(
	assignment: Dictionary
) -> Texture2D:
	var entry_id := StringName(
		assignment.get(
			"entry_id",
			""
		)
	)

	if entry_id != &"":
		var entry: RoomItemPoolEntryDefinition = (
			_get_loot_profile_entry(
				entry_id,
				StringName(assignment.get("source_id", ""))
			)
		)

		if entry != null:
			return entry.world_texture

	var item: ItemDefinition = (
		_get_assignment_item(
			assignment
		)
	)

	if item == null:
		return null

	return item.icon

func _append_loot_profile_assignments(
	assignments: Array,
	anchors: Array[RoomItemSpawnAnchor]
) -> String:
	if definition.loot_profile == null:
		return ""

	var available_anchors: Array[RoomItemSpawnAnchor] = anchors.duplicate()

	var ordered_sources: Array[RoomLootSourceDefinition] = definition.loot_profile.sources.duplicate()

	ordered_sources.sort_custom(
		func(
			left: RoomLootSourceDefinition,
			right: RoomLootSourceDefinition
		) -> bool:
			if left.priority != right.priority:
				return left.priority < right.priority

			return (
				String(left.source_id)
				< String(right.source_id)
			)
	)

	for source: RoomLootSourceDefinition in (
		ordered_sources
	):
		if source == null:
			continue

		var rng := RandomNumberGenerator.new()

		rng.seed = StableSeedMixer.make_seed(
			instance_state.generation_seed,
			&"room_loot_source",
			source.source_id
		)

		if rng.randf() >= source.activation_chance:
			continue

		var source_error: String = (
			_append_loot_source_assignments(
				assignments,
				available_anchors,
				source,
				rng
			)
		)

		if not source_error.is_empty():
			return source_error

	return ""

func _append_loot_source_assignments(
	assignments: Array,
	available_anchors: Array[
		RoomItemSpawnAnchor
	],
	source: RoomLootSourceDefinition,
	rng: RandomNumberGenerator
) -> String:
	if source.pool == null:
		return (
			"Room loot source '%s' has no item pool."
			% source.source_id
		)
	var source_errors: Array[String] = (
		RewardSourceResolver.collect_validation_errors(
			source,
			available_item_catalog,
			current_layer_number
		)
	)
	if not source_errors.is_empty():
		var source_error_lines := PackedStringArray()
		for source_error: String in source_errors:
			source_error_lines.append(source_error)
		return "\n".join(source_error_lines)

	var ordered_entries: Array[RoomItemPoolEntryDefinition] = source.pool.entries.duplicate()

	ordered_entries.sort_custom(
		func(
			left: RoomItemPoolEntryDefinition,
			right: RoomItemPoolEntryDefinition
		) -> bool:
			return (
				String(left.entry_id)
				< String(right.entry_id)
			)
	)

	var selected_entry_ids: Dictionary = {}

	# Guaranteed entries are additional to the
	# source's normal minimum/maximum draws.
	for entry: RoomItemPoolEntryDefinition in (
		ordered_entries
	):
		if (
			entry == null
			or not entry.guaranteed_once
		):
			continue

		var guaranteed_anchor := (
			_take_random_matching_anchor(
				available_anchors,
				entry.required_anchor_tag,
				rng
			)
		)

		if guaranteed_anchor == null:
			return (
				(
					"Event room '%s' has no available "
					+ "'%s' anchor for guaranteed entry "
					+ "'%s' from source '%s'."
				)
				% [
					definition.room_id,
					entry.required_anchor_tag,
					entry.entry_id,
					source.source_id,
				]
			)

		assignments.append(
			_make_item_assignment(
				entry,
				guaranteed_anchor,
				source.source_id
			)
		)

		selected_entry_ids[entry.entry_id] = true

	var requested_draws: int = rng.randi_range(
		source.minimum_draws,
		source.maximum_draws
	)

	var completed_draws: int = 0

	for _draw_index: int in range(
		requested_draws
	):
		var eligible_entries: Array[RoomItemPoolEntryDefinition] = []

		for entry: RoomItemPoolEntryDefinition in (
			ordered_entries
		):
			if (
				entry == null
				or entry.guaranteed_once
			):
				continue

			if (
				not source.allow_duplicate_entries
				and selected_entry_ids.has(
					entry.entry_id
				)
			):
				continue

			var has_compatible_anchor: bool = false

			for anchor: RoomItemSpawnAnchor in (
				available_anchors
			):
				if anchor.accepts_tag(
					entry.required_anchor_tag
				):
					has_compatible_anchor = true
					break

			if has_compatible_anchor:
				eligible_entries.append(entry)

		if eligible_entries.is_empty():
			break

		var eligible_entry_ids: Array[StringName] = []
		for eligible_entry: RoomItemPoolEntryDefinition in eligible_entries:
			eligible_entry_ids.append(eligible_entry.entry_id)
		var binding_id := StringName(
			"%s:%s:draw_%d"
			% [
				instance_state.source_node_id,
				source.source_id,
				_draw_index,
			]
		)
		var resolution: Dictionary = RewardSourceResolver.resolve(
			source,
			available_item_catalog,
			current_layer_number,
			instance_state.generation_seed,
			binding_id,
			eligible_entry_ids
		)
		var resolution_error: String = String(resolution.get("error", ""))
		if not resolution_error.is_empty():
			return resolution_error
		var resolution_record: Dictionary = (
			resolution.get("record", {}) as Dictionary
		)
		var selected_entry: RoomItemPoolEntryDefinition = source.pool.get_entry(
			StringName(resolution_record.get("entry_id", ""))
		)

		if selected_entry == null:
			break

		var selected_anchor := (
			_take_random_matching_anchor(
				available_anchors,
				selected_entry.required_anchor_tag,
				rng
			)
		)

		if selected_anchor == null:
			break

		assignments.append(
			_make_item_assignment(
				selected_entry,
				selected_anchor,
				source.source_id,
				resolution_record
			)
		)

		selected_entry_ids[
			selected_entry.entry_id
		] = true

		completed_draws += 1

	if completed_draws < source.minimum_draws:
		return (
			(
				"Event room '%s' completed only %d of "
				+ "%d required draws from loot source "
				+ "'%s'. Check its entries and anchors."
			)
			% [
				definition.room_id,
				completed_draws,
				source.minimum_draws,
				source.source_id,
			]
		)

	return ""

func _take_random_matching_anchor(
	available_anchors: Array[RoomItemSpawnAnchor],
	required_tag: StringName,
	rng: RandomNumberGenerator
) -> RoomItemSpawnAnchor:
	var matching_anchors: Array[RoomItemSpawnAnchor] = []

	for anchor: RoomItemSpawnAnchor in (
		available_anchors
	):
		if anchor.accepts_tag(
			required_tag
		):
			matching_anchors.append(
				anchor
			)

	if matching_anchors.is_empty():
		return null

	var selected_anchor: RoomItemSpawnAnchor = (
		matching_anchors[
			rng.randi_range(
				0,
				matching_anchors.size() - 1
			)
		]
	)

	available_anchors.erase(
		selected_anchor
	)

	return selected_anchor

func _make_item_assignment(
	entry: RoomItemPoolEntryDefinition,
	anchor: RoomItemSpawnAnchor,
	source_id: StringName,
	resolution_record: Dictionary = {}
) -> Dictionary:
	var assignment: Dictionary = {
		"spawn_id": String(
			anchor.anchor_id
		),
		"anchor_id": String(
			anchor.anchor_id
		),
		"source_id": String(
			source_id
		),
		"entry_id": String(
			entry.entry_id
		),
		"item_id": String(
			entry.item.item_id
		),
		"quantity": entry.quantity,
		"collected": false,
	}
	for record_key: Variant in resolution_record.keys():
		assignment[record_key] = resolution_record[record_key]
	return assignment

func _spawn_assigned_items(
	assignments: Array,
	anchors: Array[RoomItemSpawnAnchor],
	world_item_layer: Node2D
) -> String:
	var anchors_by_id: Dictionary = {}

	for anchor: RoomItemSpawnAnchor in anchors:
		anchors_by_id[anchor.anchor_id] = anchor

	for assignment_value: Variant in assignments:
		if not (assignment_value is Dictionary):
			return "Event room contains an invalid item assignment."

		var assignment := assignment_value as Dictionary
		var assignment_source_id := StringName(
			assignment.get("source_id", "")
		)
		if assignment_source_id != &"" and assignment.has("resolution_seed"):
			var resolution_error: String = (
				RewardSourceResolver.validate_resolution_record(
					assignment,
					REWARD_SOURCE_CATALOG,
					available_item_catalog
				)
			)
			if not resolution_error.is_empty():
				return resolution_error

		if bool(
			assignment.get(
				"collected",
				false
			)
		):
			continue

		var spawn_id := StringName(
			assignment.get(
				"spawn_id",
				""
			)
		)

		var anchor_id := StringName(
			assignment.get(
				"anchor_id",
				""
			)
		)

		var anchor := anchors_by_id.get(
			anchor_id
		) as RoomItemSpawnAnchor

		if anchor == null:
			return (
				"Missing room item anchor: %s."
				% anchor_id
			)

		var item: ItemDefinition = (
			_get_assignment_item(
				assignment
			)
		)

		if item == null:
			return (
				"Missing item definition for room assignment '%s'."
				% spawn_id
			)

		var world_texture: Texture2D = (
			_get_assignment_world_texture(
				assignment
			)
		)

		if world_texture == null:
			return (
				"Missing world texture for room assignment '%s'."
				% spawn_id
			)

		var pickup := (
			world_item_scene.instantiate()
			as WorldItemPickup
		)

		if pickup == null:
			return (
				"WorldItemPickup could not be instantiated."
			)

		world_item_layer.add_child(
			pickup
		)

		pickup.position = (
			world_item_layer.to_local(
				anchor.global_position
			)
		)
		
		var final_visual_scale: Vector2 = (
			anchor.item_visual_scale
			* _get_assignment_world_visual_scale(
				assignment
			)
		)

		var configuration_error: String = (
			pickup.configure(
				spawn_id,
				item,
				world_texture,
				int(
					assignment.get(
						"quantity",
						1
					)
				),
				final_visual_scale,
				anchor.item_visual_rotation_degrees,
				anchor.pickup_size,
				anchor.item_z_index
			)
		)

		if not configuration_error.is_empty():
			pickup.queue_free()
			return configuration_error

		_connect_exploration_interactable(
			pickup
		)

		pickup.pickup_requested.connect(
			_on_world_item_pickup_requested
		)

		active_pickups[spawn_id] = pickup

	return ""

func _prepare_room_events() -> String:
	active_room_events.clear()

	if definition.event_profile == null:
		return ""

	if world_event_scene == null:
		return (
			"EventRoomScreen has no WorldRoomEvent scene."
		)

	var world_event_layer := (
		presentation.get_node_or_null(
			"WorldEventLayer"
		) as Node2D
	)

	if world_event_layer == null:
		return (
			"Event room '%s' has no WorldEventLayer."
			% definition.room_id
		)

	var anchors: Array[RoomEventSpawnAnchor] = []

	for child: Node in presentation.find_children(
		"*",
		"",
		true,
		false
	):
		if child is RoomEventSpawnAnchor:
			anchors.append(
				child as RoomEventSpawnAnchor
			)

	anchors.sort_custom(
		func(
			left: RoomEventSpawnAnchor,
			right: RoomEventSpawnAnchor
		) -> bool:
			return (
				String(left.anchor_id)
				< String(right.anchor_id)
			)
	)

	for anchor: RoomEventSpawnAnchor in anchors:
		var anchor_error: String = (
			anchor.validate_anchor()
		)

		if not anchor_error.is_empty():
			return anchor_error

	var assignments: Array = (
		instance_state.local_state.get(
			"event_spawns",
			[]
		) as Array
	)

	if assignments.is_empty():
		assignments = []

		var generation_error: String = (
			_append_event_profile_assignments(
				assignments,
				anchors
			)
		)

		if not generation_error.is_empty():
			return generation_error

		instance_state.local_state[
			"event_spawns"
		] = assignments.duplicate(true)

	return _spawn_assigned_room_events(
		assignments,
		anchors,
		world_event_layer
	)

func _append_event_source_assignments(
	assignments: Array,
	available_anchors: Array[
		RoomEventSpawnAnchor
	],
	source: RoomEventSourceDefinition,
	rng: RandomNumberGenerator
) -> String:
	if source.pool == null:
		return (
			"Room event source '%s' has no pool."
			% source.source_id
		)

	var ordered_entries: Array[RoomEventPoolEntryDefinition] = source.pool.entries.duplicate()

	ordered_entries.sort_custom(
		func(
			left: RoomEventPoolEntryDefinition,
			right: RoomEventPoolEntryDefinition
		) -> bool:
			return (
				String(left.entry_id)
				< String(right.entry_id)
			)
	)

	var selected_entry_ids: Dictionary = {}

	var requested_draws: int = rng.randi_range(
		source.minimum_draws,
		source.maximum_draws
	)

	var completed_draws: int = 0

	for _draw_index: int in range(
		requested_draws
	):
		var eligible_entries: Array[RoomEventPoolEntryDefinition] = []

		for entry: RoomEventPoolEntryDefinition in (
			ordered_entries
		):
			if entry == null:
				continue

			if (
				not source.allow_duplicate_entries
				and selected_entry_ids.has(
					entry.entry_id
				)
			):
				continue

			var has_compatible_anchor: bool = false

			for anchor: RoomEventSpawnAnchor in (
				available_anchors
			):
				if anchor.accepts_tag(
					entry.required_anchor_tag
				):
					has_compatible_anchor = true
					break

			if has_compatible_anchor:
				eligible_entries.append(
					entry
				)

		if eligible_entries.is_empty():
			break

		var selected_entry := (
			_pick_weighted_event_entry(
				eligible_entries,
				rng
			)
		)

		if selected_entry == null:
			break

		var selected_anchor := (
			_take_random_matching_event_anchor(
				available_anchors,
				selected_entry.required_anchor_tag,
				rng
			)
		)

		if selected_anchor == null:
			break

		assignments.append(
			{
				"spawn_id": String(
					selected_anchor.anchor_id
				),
				"anchor_id": String(
					selected_anchor.anchor_id
				),
				"source_id": String(
					source.source_id
				),
				"entry_id": String(
					selected_entry.entry_id
				),
				"event_id": String(
					selected_entry
						.room_event
						.event_id
				),
				"resolved": false,
			}
		)

		selected_entry_ids[
			selected_entry.entry_id
		] = true

		completed_draws += 1

	if completed_draws < source.minimum_draws:
		return (
			(
				"Event room '%s' completed only %d "
				+ "of %d required draws from "
				+ "event source '%s'."
			)
			% [
				definition.room_id,
				completed_draws,
				source.minimum_draws,
				source.source_id,
			]
		)

	return ""

func _take_random_matching_event_anchor(
	available_anchors: Array[
		RoomEventSpawnAnchor
	],
	required_tag: StringName,
	rng: RandomNumberGenerator
) -> RoomEventSpawnAnchor:
	var matching: Array[RoomEventSpawnAnchor] = []

	for anchor: RoomEventSpawnAnchor in (
		available_anchors
	):
		if anchor.accepts_tag(
			required_tag
		):
			matching.append(
				anchor
			)

	if matching.is_empty():
		return null

	matching.sort_custom(
		func(
			left: RoomEventSpawnAnchor,
			right: RoomEventSpawnAnchor
		) -> bool:
			return (
				String(left.anchor_id)
				< String(right.anchor_id)
			)
	)

	var selected: RoomEventSpawnAnchor = (
		matching[
			rng.randi_range(
				0,
				matching.size() - 1
			)
		]
	)

	available_anchors.erase(
		selected
	)

	return selected

func _pick_weighted_event_entry(
	entries: Array[
		RoomEventPoolEntryDefinition
	],
	rng: RandomNumberGenerator
) -> RoomEventPoolEntryDefinition:
	if entries.is_empty():
		return null

	var total_weight: int = 0

	for entry: RoomEventPoolEntryDefinition in entries:
		total_weight += entry.weight

	if total_weight <= 0:
		return null

	var roll: int = rng.randi_range(
		1,
		total_weight
	)

	var running_weight: int = 0

	for entry: RoomEventPoolEntryDefinition in entries:
		running_weight += entry.weight

		if roll <= running_weight:
			return entry

	return entries.back()
	
func _get_event_profile_entry(
	entry_id: StringName
) -> RoomEventPoolEntryDefinition:
	if (
		entry_id == &""
		or definition == null
		or definition.event_profile == null
	):
		return null

	return definition.event_profile.get_entry(
		entry_id
	)
	
func _spawn_assigned_room_events(
	assignments: Array,
	anchors: Array[
		RoomEventSpawnAnchor
	],
	world_event_layer: Node2D
) -> String:
	var anchors_by_id: Dictionary = {}

	for anchor: RoomEventSpawnAnchor in anchors:
		anchors_by_id[
			anchor.anchor_id
		] = anchor

	for assignment_value: Variant in assignments:
		if not (
			assignment_value is Dictionary
		):
			return (
				"Event room contains an invalid "
				+ "room-event assignment."
			)

		var assignment := (
			assignment_value as Dictionary
		)

		var spawn_id := StringName(
			assignment.get(
				"spawn_id",
				""
			)
		)

		var anchor_id := StringName(
			assignment.get(
				"anchor_id",
				""
			)
		)

		var entry_id := StringName(
			assignment.get(
				"entry_id",
				""
			)
		)

		var entry: RoomEventPoolEntryDefinition = (
			_get_event_profile_entry(
				entry_id
			)
		)

		if entry == null:
			return (
				"Missing room-event entry '%s'."
				% entry_id
			)

		var anchor := (
			anchors_by_id.get(
				anchor_id
			)
			as RoomEventSpawnAnchor
		)

		if anchor == null:
			return (
				"Missing room-event anchor '%s'."
				% anchor_id
			)

		var world_event := (
			world_event_scene.instantiate()
			as WorldRoomEvent
		)

		if world_event == null:
			return (
				"WorldRoomEvent could not "
				+ "be instantiated."
			)

		world_event_layer.add_child(
			world_event
		)

		world_event.position = (
			world_event_layer.to_local(
				anchor.global_position
			)
		)

		var final_visual_scale: Vector2 = (
			entry.world_visual_scale
			* anchor.event_visual_scale
		)

		var configuration_error: String = (
			world_event.configure(
				spawn_id,
				entry.room_event,
				entry.world_texture,
				final_visual_scale,
				anchor
					.event_visual_rotation_degrees,
				anchor.interaction_size,
				anchor.event_z_index
			)
		)

		if not configuration_error.is_empty():
			world_event.queue_free()
			return configuration_error

		_connect_exploration_interactable(
			world_event
		)

		world_event.activation_requested.connect(
			_on_world_room_event_activation_requested
		)

		world_event.apply_resolved_state(
			bool(
				assignment.get(
					"resolved",
					false
				)
			)
		)

		active_room_events[
			spawn_id
		] = world_event

	return ""

func _get_room_event_entry_for_spawn(
	spawn_id: StringName
) -> RoomEventPoolEntryDefinition:
	var assignments: Array = (
		instance_state.local_state.get(
			"event_spawns",
			[]
		) as Array
	)

	for assignment_value: Variant in assignments:
		if not (
			assignment_value is Dictionary
		):
			continue

		var assignment := (
			assignment_value as Dictionary
		)

		if StringName(
			assignment.get(
				"spawn_id",
				""
			)
		) != spawn_id:
			continue

		return _get_event_profile_entry(
			StringName(
				assignment.get(
					"entry_id",
					""
				)
			)
		)

	return null
	
func _on_world_room_event_activation_requested(
	spawn_id: StringName
) -> void:
	var assignments: Array = (
		instance_state.local_state.get(
			"event_spawns",
			[]
		) as Array
	)

	for assignment_index: int in range(
		assignments.size()
	):
		var assignment_value: Variant = (
			assignments[assignment_index]
		)

		if not (
			assignment_value is Dictionary
		):
			continue

		var assignment := (
			assignment_value as Dictionary
		)

		if StringName(
			assignment.get(
				"spawn_id",
				""
			)
		) != spawn_id:
			continue

		if bool(
			assignment.get(
				"resolved",
				false
			)
		):
			return

		var entry: RoomEventPoolEntryDefinition = (
			_get_event_profile_entry(
				StringName(
					assignment.get(
						"entry_id",
						""
					)
				)
			)
		)

		if (
			entry == null
			or entry.room_event == null
		):
			hover_label.text = (
				"That room event is no longer defined."
			)
			return

		var target_state: BattlerState = null
		var target_id: StringName = &""

		if (
			entry.room_event.target_rule
			== RoomEventDefinition
				.TargetRule
				.SELECTED_HEROINE
		):
			if selected_heroine_id == &"":
				hover_label.text = (
					"Select a heroine from "
					+ "the Party Strip first."
				)
				return

			target_id = selected_heroine_id

			target_state = (
				party_states.get(
					target_id
				)
				as BattlerState
			)

			if (
				target_state == null
				or target_state.definition == null
			):
				hover_label.text = (
					"The selected heroine "
					+ "is unavailable."
				)
				return

		var resolution: Dictionary = (
			_resolve_room_event(
				spawn_id,
				entry.room_event,
				target_id,
				target_state
			)
		)

		if not bool(
			resolution.get(
				"succeeded",
				false
			)
		):
			hover_label.text = String(
				resolution.get(
					"error",
					"Room event resolution failed."
				)
			)
			return

		assignment[
			"resolved"
		] = true

		assignment[
			"outcome_id"
		] = String(
			resolution.get(
				"outcome_id",
				""
			)
		)

		assignment[
			"target_id"
		] = String(
			target_id
		)

		assignment[
			"result"
		] = resolution.duplicate(true)

		assignments[
			assignment_index
		] = assignment

		instance_state.local_state[
			"event_spawns"
		] = assignments.duplicate(true)

		var world_event := (
			active_room_events.get(
				spawn_id
			)
			as WorldRoomEvent
		)

		if world_event != null:
			world_event.apply_resolved_state(
				true
			)

			if (
				entry.room_event
					.remove_on_resolve
			):
				active_room_events.erase(
					spawn_id
				)

				world_event.queue_free()

		_refresh_party_strip()

		hover_label.text = String(
			resolution.get(
				"message",
				""
			)
		)

		return
		
func _select_room_event_outcome(
	spawn_id: StringName,
	room_event: RoomEventDefinition
) -> RoomEventOutcomeDefinition:
	if (
		room_event == null
		or room_event.outcomes.is_empty()
	):
		return null

	var ordered_outcomes: Array[RoomEventOutcomeDefinition] = room_event.outcomes.duplicate()

	ordered_outcomes.sort_custom(
		func(
			left: RoomEventOutcomeDefinition,
			right: RoomEventOutcomeDefinition
		) -> bool:
			return (
				String(left.outcome_id)
				< String(right.outcome_id)
			)
	)

	var stable_id := StringName(
		"%s|%s"
		% [
			String(spawn_id),
			String(room_event.event_id),
		]
	)

	var outcome_seed: int = (
		StableSeedMixer.make_seed(
			instance_state.generation_seed,
			&"room_event_outcome",
			stable_id
		)
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = outcome_seed

	var total_weight: int = 0

	for outcome: RoomEventOutcomeDefinition in (
		ordered_outcomes
	):
		if outcome != null:
			total_weight += outcome.weight

	if total_weight <= 0:
		return null

	var roll: int = rng.randi_range(
		1,
		total_weight
	)

	var running_weight: int = 0

	for outcome: RoomEventOutcomeDefinition in (
		ordered_outcomes
	):
		if outcome == null:
			continue

		running_weight += outcome.weight

		if roll <= running_weight:
			return outcome

	return null

func _resolve_room_event(
	spawn_id: StringName,
	room_event: RoomEventDefinition,
	target_id: StringName,
	target_state: BattlerState
) -> Dictionary:
	var selected_outcome: RoomEventOutcomeDefinition = (
		_select_room_event_outcome(
			spawn_id,
			room_event
		)
	)

	if selected_outcome == null:
		return {
			"succeeded": false,
			"error": (
				"Room event '%s' could not "
				+ "select a valid outcome."
			) % room_event.event_id,
		}

	var message_lines := PackedStringArray()

	if not selected_outcome.message.is_empty():
		message_lines.append(
			selected_outcome.message
		)

	var effect_results: Array[Dictionary] = []

	for effect_index: int in range(
		selected_outcome.effects.size()
	):
		var effect: RoomEventEffectDefinition = (
			selected_outcome.effects[
				effect_index
			]
		)

		if effect == null:
			return {
				"succeeded": false,
				"error": (
					"Room event '%s' contains "
					+ "a missing effect."
				) % room_event.event_id,
			}

		var effect_result: Dictionary = (
			_apply_room_event_effect(
				spawn_id,
				selected_outcome,
				effect_index,
				effect,
				target_state
			)
		)

		if not bool(
			effect_result.get(
				"succeeded",
				false
			)
		):
			return effect_result

		effect_results.append(
			effect_result.duplicate(true)
		)

		var effect_message: String = String(
			effect_result.get(
				"message",
				""
			)
		)

		if not effect_message.is_empty():
			message_lines.append(
				effect_message
			)

	return {
		"succeeded": true,
		"outcome_id": String(
			selected_outcome.outcome_id
		),
		"target_id": String(target_id),
		"effects": effect_results,
		"message": "\n".join(
			message_lines
		),
	}
	
func _apply_room_event_effect(
	spawn_id: StringName,
	selected_outcome: RoomEventOutcomeDefinition,
	effect_index: int,
	effect: RoomEventEffectDefinition,
	target_state: BattlerState
) -> Dictionary:
	match effect.kind:
		RoomEventEffectDefinition.Kind.HEAL_HP:
			if target_state == null:
				return _room_event_effect_target_error()

			var restored_hp: int = (
				target_state.heal(
					effect.amount
				)
			)

			return {
				"succeeded": true,
				"kind": "heal_hp",
				"amount": restored_hp,
				"message": (
					"%s restored %d HP."
					% [
						target_state
							.definition
							.display_name,
						restored_hp,
					]
					if restored_hp > 0
					else (
						"%s was already at maximum HP."
						% target_state
							.definition
							.display_name
					)
				),
			}

		RoomEventEffectDefinition.Kind.CHANGE_RESOLVE:
			if target_state == null:
				return _room_event_effect_target_error()

			var resolve_change: int = (
				target_state.change_resolve(
					effect.amount
				)
			)

			return {
				"succeeded": true,
				"kind": "change_resolve",
				"amount": resolve_change,
				"message": (
					"%s's Resolve changed by %+d."
					% [
						target_state
							.definition
							.display_name,
						resolve_change,
					]
				),
			}

		RoomEventEffectDefinition.Kind.CHANGE_CORRUPTION:
			if target_state == null:
				return _room_event_effect_target_error()

			var corruption_change: int = (
				target_state.change_corruption(
					effect.amount
				)
			)

			return {
				"succeeded": true,
				"kind": "change_corruption",
				"amount": corruption_change,
				"message": (
					"%s's Corruption changed by %+d."
					% [
						target_state
							.definition
							.display_name,
						corruption_change,
					]
				),
			}

		RoomEventEffectDefinition.Kind.ROLL_BLOOM_D10_PER_LAYER:
			var dice_count: int = (
				current_layer_number
				* effect.amount
			)

			var stable_id := StringName(
				"%s|%s|%d"
				% [
					String(spawn_id),
					String(
						selected_outcome
							.outcome_id
					),
					effect_index,
				]
			)

			var dice_seed: int = (
				StableSeedMixer.make_seed(
					instance_state.generation_seed,
					&"room_event_bloom_dice",
					stable_id
				)
			)

			var roll_result: RollResult = (
				DiceResolver.new().roll_attribute(
					dice_count,
					dice_seed
				)
			)

			var bloom_gained: int = 0

			for die_value: int in (
				roll_result.get_all_rolls()
			):
				bloom_gained += die_value

			pending_bloom_delta += (
				bloom_gained
			)

			var base_roll_text := (
				PackedStringArray()
			)

			for die_value: int in (
				roll_result.base_rolls
			):
				base_roll_text.append(
					str(die_value)
				)

			var message: String = (
				"Rolled %dd10: [%s]."
				% [
					dice_count,
					", ".join(
						base_roll_text
					),
				]
			)

			if not (
				roll_result
					.explosion_rolls
					.is_empty()
			):
				var explosion_text := (
					PackedStringArray()
				)

				for die_value: int in (
					roll_result
						.explosion_rolls
				):
					explosion_text.append(
						str(die_value)
					)

				message += (
					"\nExplosions: [%s]."
					% ", ".join(
						explosion_text
					)
				)

			message += (
				"\nGained %d Bloom."
				% bloom_gained
			)

			return {
				"succeeded": true,
				"kind": "roll_bloom_d10_per_layer",
				"dice_count": dice_count,
				"base_rolls": (
					roll_result
						.base_rolls
						.duplicate()
				),
				"explosion_rolls": (
					roll_result
						.explosion_rolls
						.duplicate()
				),
				"bloom_gained": bloom_gained,
				"message": message,
			}

	return {
		"succeeded": false,
		"error": "Unknown room-event effect kind.",
	}
	
func _room_event_effect_target_error() -> Dictionary:
	return {
		"succeeded": false,
		"error": ("This room event effect required a heroine target"),
	}

func _append_event_profile_assignments(
	assignments: Array,
	anchors: Array[
		RoomEventSpawnAnchor
	]
) -> String:
	var available_anchors: Array[RoomEventSpawnAnchor] = anchors.duplicate()

	var ordered_sources: Array[RoomEventSourceDefinition] = definition.event_profile.sources.duplicate()

	ordered_sources.sort_custom(
		func(
			left: RoomEventSourceDefinition,
			right: RoomEventSourceDefinition
		) -> bool:
			if left.priority != right.priority:
				return (
					left.priority
					< right.priority
				)

			return (
				String(left.source_id)
				< String(right.source_id)
			)
	)

	for source: RoomEventSourceDefinition in (
		ordered_sources
	):
		if source == null:
			continue

		var rng := RandomNumberGenerator.new()

		rng.seed = StableSeedMixer.make_seed(
			instance_state.generation_seed,
			&"room_event_source",
			source.source_id
		)

		if rng.randf() >= source.activation_chance:
			continue

		var source_error: String = (
			_append_event_source_assignments(
				assignments,
				available_anchors,
				source,
				rng
			)
		)

		if not source_error.is_empty():
			return source_error

	return ""

func _restore_selected_item_description() -> void:
	if (
		inventory == null
		or selected_item_slot_index < 0
	):
		hover_label.text = ""
		return

	var slot: InventorySlotState = inventory.get_slot(
		selected_item_slot_index
	)

	if slot == null or slot.is_empty():
		selected_item_slot_index = -1
		hover_label.text = ""

		_refresh_item_bar()

		return

	if (
		slot.item.item_type
		== ItemDefinition.ItemType.KEY
	):
		hover_label.text = (
			"%s ×%d\n%s\n"
			+ "Use it on an environmental interaction."
		) % [
			slot.item.display_name,
			slot.quantity,
			slot.item.description,
		]
	else:
		hover_label.text = (
			"%s ×%d\n%s\n"
			+ "Select a heroine from the Party Strip."
		) % [
			slot.item.display_name,
			slot.quantity,
			slot.item.description,
		]


func _on_world_item_pickup_requested(
	world_item_id: StringName
) -> void:
	var assignments: Array = (
		instance_state.local_state.get(
			"item_spawns",
			[]
		) as Array
	)

	for assignment_index: int in range(
		assignments.size()
	):
		var assignment: Dictionary = (
			assignments[
				assignment_index
			] as Dictionary
		)

		if StringName(
			assignment.get(
				"spawn_id",
				""
			)
		) != world_item_id:
			continue

		if bool(
			assignment.get(
				"collected",
				false
			)
		):
			return

		var item : ItemDefinition = (
			_get_assignment_item(
				assignment
			)
		)
		
		if item == null:
			hover_label.text = "That room item is no longer defined"
			
			return

		var quantity: int = int(
			assignment.get(
				"quantity",
				1
			)
		)

		var inventory_error: String = _route_carried_item_reward(
			item.item_id,
			quantity
		)

		if not inventory_error.is_empty():
			if assignment.has("resolution_seed"):
				assignment["deferred"] = true
				assignment["claimed"] = false
				assignments[assignment_index] = assignment
				instance_state.local_state[
					"item_spawns"
				] = assignments.duplicate(true)
				print(
					"Reward deferred: source=%s binding=%s item=%s quantity=%d reason=%s"
					% [
						assignment.get("source_id", ""),
						assignment.get("binding_id", ""),
						item.item_id,
						quantity,
						inventory_error,
					]
				)
			hover_label.text = inventory_error
			return

		assignment["collected"] = true
		if assignment.has("resolution_seed"):
			assignment["claimed"] = true
			assignment["deferred"] = false
			print(
				"Reward claimed: source=%s binding=%s item=%s quantity=%d domain=%s"
				% [
					assignment.get("source_id", ""),
					assignment.get("binding_id", ""),
					item.item_id,
					quantity,
					run_inventory.get_runtime_domain(item.item_id),
				]
			)
		assignments[assignment_index] = assignment

		instance_state.local_state[
			"item_spawns"
		] = assignments.duplicate(true)

		var pickup := active_pickups.get(
			world_item_id
		) as WorldItemPickup

		if pickup != null:
			active_pickups.erase(
				world_item_id
			)

			pickup.queue_free()

		var domain_label: String = _get_carried_domain_label(
			run_inventory.get_runtime_domain(item.item_id)
		)
		hover_label.text = "Added %s ×%d to the %s." % [
			item.display_name,
			quantity,
			domain_label,
		]

		selected_item_slot_index = -1
		selected_heroine_id = &""

		_refresh_item_bar()
		_refresh_party_strip()

		return


func _is_room_lock_unlocked(
	lock_id: StringName
) -> bool:
	var stored_value: Variant = (
		instance_state.local_state.get(
			"locks",
			{}
		)
	)

	if not (
		stored_value is Dictionary
	):
		return false

	var lock_states := (
		stored_value as Dictionary
	)

	return bool(
		lock_states.get(
			String(lock_id),
			false
		)
	)


func _store_room_lock_unlocked(
	lock_id: StringName
) -> void:
	var stored_value: Variant = (
		instance_state.local_state.get(
			"locks",
			{}
		)
	)

	var lock_states: Dictionary = {}

	if stored_value is Dictionary:
		lock_states = (
			stored_value as Dictionary
		).duplicate(true)

	lock_states[String(lock_id)] = true

	instance_state.local_state[
		"locks"
	] = lock_states


func _on_room_lock_interaction_requested(
	lock_id: StringName
) -> void:
	var room_lock := active_locks.get(
		lock_id
	) as RoomLockHotspot

	if (
		room_lock == null
		or room_lock.is_unlocked
	):
		return
	var unlock_error: String = _try_unlock_room_lock(room_lock)
	if not unlock_error.is_empty():
		hover_label.text = unlock_error
		return

	selected_item_slot_index = -1
	selected_heroine_id = &""

	_refresh_item_bar()
	_refresh_party_strip()

	hover_label.text = (
		room_lock.success_message
	)


func _try_unlock_room_lock(room_lock: RoomLockHotspot) -> String:
	if room_lock == null:
		return "The room lock is unavailable."
	if run_inventory == null:
		return "The shared Key Chain is unavailable."
	if instance_state == null:
		return "The room state is unavailable."
	if run_inventory.get_key_quantity(room_lock.required_item_id) <= 0:
		return room_lock.locked_message
	if room_lock.consume_required_item:
		var consume_error: String = run_inventory.consume_key(
			room_lock.required_item_id,
			1
		)
		if not consume_error.is_empty():
			return consume_error
	_store_room_lock_unlocked(room_lock.lock_id)
	room_lock.apply_unlocked_state(true)
	return ""


func _capture_party_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}

	for battler_id: StringName in [
		&"lysandra",
		&"mira",
		&"seraphine",
	]:
		var state := party_states.get(
			battler_id
		) as BattlerState

		if state == null:
			continue

		snapshot[battler_id] = {
			"hp": state.current_hp,
			"mp": state.current_mp,
			"resolve": state.current_resolve,
			"corruption": state.current_corruption,
			"item_guard": state.item_guard_points,

			"weapon_damage": (
				state.weapon_state.durability_damage
				if state.weapon_state != null
				else 0
			),

			"weapon_broken": (
				state.weapon_state.is_broken
				if state.weapon_state != null
				else false
			),

			"armor_damage": (
				state.armor_state.absorbed_damage
				if state.armor_state != null
				else 0
			),

			"armor_broken": (
				state.armor_state.is_broken
				if state.armor_state != null
				else false
			),

			"shield_damage": (
				state.shield_state.absorbed_damage
				if state.shield_state != null
				else 0
			),

			"shield_broken": (
				state.shield_state.is_broken
				if state.shield_state != null
				else false
			),
		}

	return snapshot


func _on_exit_requested(
	room_exit: RoomExitHotspot = null
) -> void:
	for lock_value: Variant in active_locks.values():
		var room_lock := lock_value as RoomLockHotspot
		if (
			room_lock != null
			and room_lock.get_exit_hotspot() == room_exit
			and not room_lock.is_unlocked
		):
			hover_label.text = room_lock.locked_message
			return
	_emit_room_outcome(true)


func _on_back_requested() -> void:
	if mode_controller.is_dialogue_active():
		var node: DialogueNodeDefinition = (
			dialogue_runner.get_current_node()
			if dialogue_runner != null
			else null
		)
		if node != null and not node.mandatory:
			stop_dialogue()
			return
		if story_dialogue_mode:
			return
	if story_dialogue_mode:
		return
	_emit_room_outcome(false)


func _emit_story_dialogue_outcome() -> void:
	if not story_dialogue_mode:
		return
	var outcome := StoryDialogueOutcome.new()
	var inventory_error: String = _sync_run_inventory_item_bar()
	if not inventory_error.is_empty():
		hover_label.text = inventory_error
		return
	outcome.story_id = story_dialogue_id
	outcome.source_node_id = story_source_node_id
	outcome.inventory_snapshot = inventory.get_snapshot()
	outcome.run_inventory_snapshot = run_inventory.get_snapshot()
	outcome.party_snapshot = _capture_party_snapshot()
	outcome.bloom_delta = pending_bloom_delta
	outcome.dialogue_result_snapshots = (
		pending_dialogue_results.duplicate(true)
	)
	story_dialogue_outcome_ready.emit(outcome)


func show_story_holding_message(message: String) -> void:
	# A story-only screen may become a temporary lifecycle boundary after its
	# dialogue commits. Keep the authored backdrop, Party Strip, and Item Bar
	# visible without allowing the ordinary Event-room Back action to emit an
	# invalid room outcome.
	if not story_dialogue_mode:
		return
	hover_label.text = message


func _emit_room_outcome(
	clear_node: bool
) -> void:
	var inventory_error: String = _sync_run_inventory_item_bar()
	if not inventory_error.is_empty():
		hover_label.text = inventory_error
		return
	var outcome := EventRoomOutcome.new()

	outcome.source_node_id = (
		instance_state.source_node_id
	)

	outcome.room_state_snapshot = (
		instance_state.to_snapshot()
	)

	outcome.inventory_snapshot = (
		inventory.get_snapshot()
	)
	outcome.run_inventory_snapshot = run_inventory.get_snapshot()

	outcome.party_snapshot = (
		_capture_party_snapshot()
	)
	
	outcome.bloom_delta = (
		pending_bloom_delta
	)
	outcome.dialogue_result_snapshots = (
		pending_dialogue_results.duplicate(true)
	)

	outcome.clear_node = clear_node

	room_outcome_ready.emit(
		outcome
	)


func _route_carried_item_reward(
	item_id: StringName,
	quantity: int,
	owner_heroine_id: StringName = &""
) -> String:
	if run_inventory == null:
		return "Run inventory is unavailable."
	var sync_error: String = _sync_run_inventory_item_bar()
	if not sync_error.is_empty():
		return sync_error
	var route_error: String = run_inventory.route_reward(
		item_id,
		quantity,
		owner_heroine_id
	)
	if not route_error.is_empty():
		return route_error
	return _load_presented_item_bar_from_run_inventory()


func _sync_run_inventory_item_bar() -> String:
	if run_inventory == null or inventory == null:
		return "Run inventory or Item Bar is unavailable."
	return run_inventory.restore_item_bar_snapshot(
		inventory.get_snapshot()
	)


func _load_presented_item_bar_from_run_inventory() -> String:
	var item_ids: Array[StringName] = []
	var quantities: Array[int] = []
	for slot_data: Dictionary in run_inventory.get_item_bar_snapshot():
		item_ids.append(StringName(slot_data.get("item_id", "")))
		quantities.append(int(slot_data.get("quantity", 0)))
	return inventory.load_items(item_ids, quantities)


func _get_carried_domain_label(domain: StringName) -> String:
	match domain:
		RunInventoryState.DOMAIN_ITEM_BAR:
			return "Item Bar"
		RunInventoryState.DOMAIN_BACKPACK:
			return "Backpack"
		RunInventoryState.DOMAIN_KEY_CHAIN:
			return "Key Chain"
		RunInventoryState.DOMAIN_MATERIAL_POUCH:
			return "Material Pouch"
		RunInventoryState.DOMAIN_MEMENTO:
			return "Memento slot"
	return "carried inventory"
