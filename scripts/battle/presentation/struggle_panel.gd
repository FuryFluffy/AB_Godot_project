class_name StrugglePanel
extends Control


signal confirmed(
	track_id: StringName,
	attribute: AttributeSet.Attribute
)
signal cancelled


@export var prompt_label: Label
@export var track_option: OptionButton
@export var might_button: Button
@export var agility_button: Button
@export var endurance_button: Button
@export var command_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 64.0, 1.0) var command_gap: float = 10.0
@export_range(240.0, 720.0, 1.0) var panel_width: float = 420.0

@onready var frame: PanelContainer = %Frame

var active_heroine: BattlerState
var active_grappler: BattlerState
var active_tracks: Array[GrappleTrackState] = []
var active_battlers: Dictionary = {}
var command_anchor: Control
var open_tween: Tween
var open_generation: int = 0


func _ready() -> void:
	assert(prompt_label != null)
	assert(track_option != null)
	assert(might_button != null)
	assert(agility_button != null)
	assert(endurance_button != null)
	might_button.pressed.connect(
		_on_attribute_pressed.bind(AttributeSet.Attribute.MIGHT)
	)
	agility_button.pressed.connect(
		_on_attribute_pressed.bind(AttributeSet.Attribute.AGILITY)
	)
	endurance_button.pressed.connect(
		_on_attribute_pressed.bind(AttributeSet.Attribute.ENDURANCE)
	)
	track_option.item_selected.connect(_on_track_selected)
	hide()


func attach_to_command(control: Control) -> void:
	command_anchor = control


func present(
	heroine: BattlerState,
	tracks: Array[GrappleTrackState],
	battlers: Dictionary
) -> void:
	active_heroine = heroine
	active_tracks = tracks.duplicate()
	# Own a snapshot so closing this panel cannot mutate the encounter registry.
	active_battlers = battlers.duplicate()
	track_option.clear()
	for index: int in range(active_tracks.size()):
		var track: GrappleTrackState = active_tracks[index]
		var grappler: BattlerState = (
			active_battlers.get(track.grappler_id) as BattlerState
		)
		var grappler_name: String = String(track.grappler_id)
		if grappler != null and grappler.definition != null:
			grappler_name = grappler.definition.display_name
		var role: String = "Main" if track.is_main else "Secondary"
		track_option.add_item(
			"%s — %s, Stage %d/%d" % [
				grappler_name,
				role,
				track.get_stage_number(),
				track.get_stage_count(),
			],
			index
		)
	track_option.visible = active_tracks.size() > 1
	track_option.select(0)
	_select_active_track()
	_refresh_choices()
	open_generation += 1
	var expected_generation: int = open_generation
	if open_tween != null and open_tween.is_valid():
		open_tween.kill()
	scale = Vector2.ONE
	# Make the newly visible containers participate in layout without flashing
	# their stale editor/previous-open dimensions for a frame.
	modulate.a = 0.0
	show()
	call_deferred("_finish_open", expected_generation)


func close_panel() -> void:
	open_generation += 1
	if open_tween != null and open_tween.is_valid():
		open_tween.kill()
	active_heroine = null
	active_grappler = null
	active_tracks.clear()
	active_battlers = {}
	scale = Vector2.ONE
	modulate.a = 1.0
	hide()


func _on_attribute_pressed(attribute: AttributeSet.Attribute) -> void:
	if not _can_struggle():
		return
	confirmed.emit(_get_selected_track_id(), attribute)


func _on_track_selected(_index: int) -> void:
	_select_active_track()
	_refresh_choices()
	call_deferred("_refit_after_layout", open_generation)


func _finish_open(expected_generation: int) -> void:
	# Visibility, label text and the optional track selector all affect a
	# Container's minimum size. Godot applies those changes over the following
	# layout passes, so measure only after two complete frames.
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible or expected_generation != open_generation:
		return
	_fit_to_content()
	_play_roll_open()


func _refit_after_layout(expected_generation: int) -> void:
	await get_tree().process_frame
	if not visible or expected_generation != open_generation:
		return
	_fit_to_content()


func _fit_to_content() -> void:
	if frame == null:
		return
	# Measure the visible content on the inner Frame, then make both the
	# floating-window root and Frame exactly that size. The HUD parent can no
	# longer stretch the content container after this calculation.
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	custom_minimum_size = Vector2(panel_width, 0.0)
	frame.custom_minimum_size = Vector2(panel_width, 0.0)
	frame.queue_sort()
	frame.reset_size()
	var content_size: Vector2 = frame.get_combined_minimum_size()
	content_size.x = maxf(panel_width, content_size.x)
	custom_minimum_size = content_size
	size = content_size
	frame.position = Vector2.ZERO
	frame.size = content_size
	_position_next_to_command()


func _select_active_track() -> void:
	active_grappler = null
	var index: int = track_option.get_selected_id()
	if index < 0 or index >= active_tracks.size():
		return
	active_grappler = (
		active_battlers.get(active_tracks[index].grappler_id)
		as BattlerState
	)


func _get_selected_track_id() -> StringName:
	var index: int = track_option.get_selected_id()
	if index < 0 or index >= active_tracks.size():
		return &""
	return active_tracks[index].track_id


func _can_struggle() -> bool:
	return (
		active_heroine != null
		and not active_heroine.is_defeated
		and active_heroine.current_actions > 0
		and not active_heroine.is_stunned()
		and active_grappler != null
	)


func _refresh_choices() -> void:
	if (
		active_heroine == null
		or active_heroine.definition == null
		or active_grappler == null
		or active_grappler.definition == null
	):
		prompt_label.text = "No valid Grapple track."
		_set_choice_enabled(false)
		return

	prompt_label.text = "Against %s — choose an Attribute" % (
		active_grappler.definition.display_name
	)
	_set_choice_enabled(_can_struggle())
	_refresh_attribute_button(
		might_button,
		"Might",
		AttributeSet.Attribute.MIGHT
	)
	_refresh_attribute_button(
		agility_button,
		"Agility",
		AttributeSet.Attribute.AGILITY
	)
	_refresh_attribute_button(
		endurance_button,
		"Endurance",
		AttributeSet.Attribute.ENDURANCE
	)


func _set_choice_enabled(enabled: bool) -> void:
	for button: Button in [
		might_button,
		agility_button,
		endurance_button,
	]:
		button.disabled = not enabled


func _refresh_attribute_button(
	button: Button,
	attribute_name: String,
	attribute: AttributeSet.Attribute
) -> void:
	var heroine_pool: int = (
		active_heroine.definition.attributes.get_value(attribute)
	)
	var additional_grapplers: int = maxi(
		active_heroine.active_grapple_track_ids.size() - 1,
		0
	)
	var enemy_pool: int = (
		active_grappler.definition.attributes.get_value(attribute)
		+ additional_grapplers
	)
	button.text = "%s\n%dd10 vs %dd10" % [
		attribute_name,
		heroine_pool,
		enemy_pool,
	]
	button.tooltip_text = (
		"Choose %s and Struggle immediately.\n"
		+ "Heroine: %dd10 | Enemy: %dd10%s"
	) % [
		attribute_name,
		heroine_pool,
		enemy_pool,
		(
			" (includes +%dd10 for additional grapplers)"
			% additional_grapplers
			if additional_grapplers > 0
			else ""
		),
	]


func _position_next_to_command() -> void:
	if command_anchor == null or not command_anchor.is_inside_tree():
		return
	var anchor_rect: Rect2 = command_anchor.get_global_rect()
	var panel_size: Vector2 = size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = custom_minimum_size
	var viewport_size: Vector2 = get_viewport_rect().size
	var wanted_position := Vector2(
		anchor_rect.position.x - panel_size.x - command_gap,
		anchor_rect.get_center().y - panel_size.y * 0.5
	)
	wanted_position += command_offset
	wanted_position.x = clampf(
		wanted_position.x,
		12.0,
		viewport_size.x - panel_size.x - 12.0
	)
	wanted_position.y = clampf(
		wanted_position.y,
		68.0,
		viewport_size.y - panel_size.y - 12.0
	)
	position = wanted_position


func _play_roll_open() -> void:
	if open_tween != null and open_tween.is_valid():
		open_tween.kill()
	pivot_offset = Vector2(size.x, size.y * 0.5)
	scale = Vector2(0.08, 1.0)
	modulate.a = 0.25
	open_tween = create_tween()
	open_tween.set_parallel(true)
	open_tween.set_trans(Tween.TRANS_QUAD)
	open_tween.set_ease(Tween.EASE_OUT)
	open_tween.tween_property(self, "scale", Vector2.ONE, 0.14)
	open_tween.tween_property(self, "modulate:a", 1.0, 0.10)
