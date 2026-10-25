class_name ExplorationHUD
extends CanvasLayer


@onready var party_strip: PanelContainer = $PartyStrip
@onready var item_bar: ItemBarView = $ItemBar
@onready var command_bar: ExplorationCommandBarView = $ExplorationCommandBar
@onready var hover_label: Label = $HoverLabel
@onready var dialogue_panel: DialoguePanel = $DialoguePanel

@onready var lysandra_card: HeroineCardView = (
	$PartyStrip/Cards/LysandraCard
)
@onready var mira_card: HeroineCardView = (
	$PartyStrip/Cards/MiraCard
)
@onready var seraphine_card: HeroineCardView = (
	$PartyStrip/Cards/SeraphineCard
)


signal backpack_requested
var party_panel: RunPartyPanel
var backpack_panel: RunBackpackPanel
var dock: RunHUDDock
var combat_log: CombatLogDrawer
var ability_panel: AbilityPanel
var selected_state: BattlerState
var last_dialogue_entry: String = ""

func _ready() -> void:
	combat_log = preload("res://scenes/battle/ui/reusable/components/combat_log_drawer.tscn").instantiate()
	add_child(combat_log)
	ability_panel = preload("res://scenes/battle/ui/reusable/components/ability_panel.tscn").instantiate()
	add_child(ability_panel)
	dock = RunHUDDock.new()
	add_child(dock)
	dock.configure(self, party_strip, item_bar, command_bar, combat_log, command_bar.log_button, "Log")
	dock.layout_changed.connect(_fit_dialogue_above_dock)
	_fit_dialogue_above_dock()
	command_bar.log_requested.connect(_toggle_log)
	combat_log.close_requested.connect(func() -> void: dock.set_log_open(false))
	ability_panel.attach_to_command(command_bar.ability_button)
	command_bar.ability_requested.connect(_show_abilities)
	ability_panel.cancelled.connect(_close_abilities)

func set_selected_state(state: BattlerState) -> void:
	if selected_state != state:
		ability_panel.close_panel()
	selected_state = state
	command_bar.set_selected_heroine(state != null and not state.is_defeated)

func _show_abilities() -> void:
	if selected_state == null or command_bar.ability_button.disabled:
		return
	if ability_panel.visible:
		_close_abilities()
	else:
		dock.set_log_open(false)
		ability_panel.present_exploration(selected_state)

func _toggle_log() -> void:
	ability_panel.close_panel()
	dock.set_log_open(not dock.log_open)

func _close_abilities() -> void:
	ability_panel.close_panel()
	command_bar.ability_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		backpack_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not (event.is_action_pressed(&"ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)):
		return
	if party_panel != null and party_panel.cancel():
		get_viewport().set_input_as_handled()
		return
	if backpack_panel != null and backpack_panel.is_slot_context_event(event):
		return
	if backpack_panel != null and backpack_panel.cancel():
		get_viewport().set_input_as_handled()
		return
	if ability_panel != null and ability_panel.visible:
		_close_abilities()
	elif dock.log_open:
		dock.set_log_open(false)
		dock.log_tab.grab_focus()
	else:
		return
	get_viewport().set_input_as_handled()

func record_dialogue(text: String) -> void:
	if text == last_dialogue_entry:
		return
	last_dialogue_entry = text
	combat_log.append_entry(text)


func get_party_card(
	battler_id: StringName
) -> HeroineCardView:
	match battler_id:
		&"lysandra":
			return lysandra_card
		&"mira":
			return mira_card
		&"seraphine":
			return seraphine_card
	return null


func set_active_party_ids(
	active_party_ids: Array[StringName]
) -> void:
	dock.set_active_party_ids(active_party_ids)


func set_dialogue_active(
	active: bool,
	mandatory: bool = false
) -> void:
	dialogue_panel.visible = active
	if active:
		ability_panel.close_panel()
	command_bar.set_dialogue_mode(
		active,
		mandatory
	)

	if not active:
		item_bar.set_locked(false)


func set_item_bar_locked(locked: bool) -> void:
	item_bar.set_locked(locked)


func _fit_dialogue_above_dock() -> void:
	# The shared DialoguePanel is also used outside runs. Reserve dock/log-tab
	# space only here, so dialogue Item Bar choices remain reachable.
	dialogue_panel.offset_bottom = -(RunHUDDock.HEIGHT + 48) * dock.layout_scale
