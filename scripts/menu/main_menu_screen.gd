class_name MainMenuScreen
extends Control


signal continue_requested(slot_id: int)
signal load_requested(slot_id: int)
signal new_campaign_requested(slot_id: int, campaign_seed: int)
signal delete_slot_requested(slot_id: int)
signal quit_requested


enum ConfirmationKind {
	NONE,
	OVERWRITE_SLOT,
	DELETE_SLOT,
}


@onready var continue_button: Button = %Continue
@onready var new_campaign_button: Button = %NewCampaign
@onready var load_campaign_button: Button = %LoadCampaign
@onready var settings_button: Button = %Settings
@onready var quit_button: Button = %Quit
@onready var home_panel: Control = %HomePanel
@onready var new_panel: Control = %NewPanel
@onready var load_panel: Control = %LoadPanel
@onready var settings_panel: Control = %SettingsPanel
@onready var continue_summary: Label = %ContinueSummary
@onready var new_seed_edit: LineEdit = %NewCampaignSeed
@onready var new_slot_option: OptionButton = %NewCampaignSlot
@onready var start_new_button: Button = %StartNewCampaign
@onready var load_slot_list: VBoxContainer = %LoadSlotList
@onready var master_volume_slider: HSlider = %MasterVolume
@onready var fullscreen_check: CheckBox = %Fullscreen
@onready var apply_settings_button: Button = %ApplySettings
@onready var status_label: Label = %MenuStatus
@onready var confirmation_overlay: Control = %ConfirmationOverlay
@onready var confirmation_title: Label = %ConfirmationTitle
@onready var confirmation_message: Label = %ConfirmationMessage
@onready var confirmation_accept: Button = %ConfirmationAccept
@onready var confirmation_cancel: Button = %ConfirmationCancel

var slot_summaries: Array[Dictionary] = []
var pending_confirmation: ConfirmationKind = ConfirmationKind.NONE
var pending_slot_id: int = 0
var pending_campaign_seed: int = 0


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_campaign_button.pressed.connect(_show_new_panel)
	load_campaign_button.pressed.connect(_show_load_panel)
	settings_button.pressed.connect(_show_settings_panel)
	quit_button.pressed.connect(quit_requested.emit)
	start_new_button.pressed.connect(_on_start_new_pressed)
	apply_settings_button.pressed.connect(_on_apply_settings_pressed)
	confirmation_accept.pressed.connect(_on_confirmation_accepted)
	confirmation_cancel.pressed.connect(_hide_confirmation)
	confirmation_overlay.visible = false
	quit_button.visible = not OS.has_feature("web")
	_apply_settings_to_controls(UserSettingsStore.load_settings())
	_show_home_panel()


func configure_slots(
	summaries: Array[Dictionary],
	message: String = "",
	is_error: bool = false
) -> void:
	slot_summaries.clear()
	for summary: Dictionary in summaries:
		slot_summaries.append(summary.duplicate(true))
	_refresh_continue_state()
	_refresh_new_slot_options()
	_refresh_load_slot_rows()
	if not message.is_empty():
		show_status(message, is_error)


func show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.modulate = (
		Color(1.0, 0.55, 0.55)
		if is_error
		else Color(0.86, 0.8, 0.68)
	)


func _refresh_continue_state() -> void:
	var latest: Dictionary = _latest_resumable_summary()
	continue_button.disabled = latest.is_empty()
	load_campaign_button.disabled = not _has_any_stored_slot()
	if latest.is_empty():
		continue_summary.text = (
			"No active-run safe point is available. Begin or load a campaign to play."
		)
		return
	continue_summary.text = (
		"Continue Slot %d\n%s\nSeed %d • %d Bloom • %s"
		% [
			int(latest.get("slot_id", 0)),
			String(latest.get("location_label", "Bloom Refuge")),
			int(latest.get("campaign_seed", 0)),
			int(latest.get("bloom", 0)),
			_format_saved_time(int(latest.get("saved_at_unix", 0))),
		]
	)


func _refresh_new_slot_options() -> void:
	var previous_slot_id: int = 1
	if new_slot_option.item_count > 0:
		previous_slot_id = new_slot_option.get_item_id(
			new_slot_option.selected
		)
	new_slot_option.clear()
	var first_empty_index: int = -1
	for summary: Dictionary in slot_summaries:
		var slot_id: int = int(summary.get("slot_id", 0))
		var status: String = String(summary.get("status", "empty"))
		var label: String = "Slot %d — %s" % [
			slot_id,
			"Empty" if status == "empty" else "Overwrite existing campaign",
		]
		new_slot_option.add_item(label, slot_id)
		if status == "empty" and first_empty_index < 0:
			first_empty_index = new_slot_option.item_count - 1
		if slot_id == previous_slot_id:
			new_slot_option.select(new_slot_option.item_count - 1)
	if first_empty_index >= 0:
		new_slot_option.select(first_empty_index)


func _refresh_load_slot_rows() -> void:
	for child: Node in load_slot_list.get_children():
		load_slot_list.remove_child(child)
		child.queue_free()
	for summary: Dictionary in slot_summaries:
		load_slot_list.add_child(_make_slot_row(summary))


func _make_slot_row(summary: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 108.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var description := Label.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = _make_slot_description(summary)
	row.add_child(description)

	var slot_id: int = int(summary.get("slot_id", 0))
	var load_button := Button.new()
	load_button.custom_minimum_size = Vector2(104.0, 44.0)
	load_button.text = (
		"Recover"
		if bool(summary.get("used_backup", false))
		else "Load"
	)
	load_button.disabled = not bool(summary.get("campaign_loadable", false))
	load_button.pressed.connect(_on_load_slot_pressed.bind(slot_id))
	row.add_child(load_button)

	var delete_button := Button.new()
	delete_button.custom_minimum_size = Vector2(104.0, 44.0)
	delete_button.text = "Delete"
	delete_button.disabled = String(summary.get("status", "empty")) == "empty"
	delete_button.pressed.connect(_request_delete_slot.bind(slot_id))
	row.add_child(delete_button)
	return panel


func _make_slot_description(summary: Dictionary) -> String:
	var slot_id: int = int(summary.get("slot_id", 0))
	var status: String = String(summary.get("status", "empty"))
	if status == "empty":
		return "SLOT %d\nEmpty" % slot_id
	if status == "corrupted":
		return "SLOT %d\nUnreadable save — no valid backup" % slot_id
	if status == "incompatible":
		return "SLOT %d\nIncompatible pre-v3 save — file preserved" % slot_id
	var backup_note: String = " • backup recovery" if bool(
		summary.get("used_backup", false)
	) else ""
	return (
		"SLOT %d  •  %s%s\nSeed %d  •  %d Bloom  •  %s"
		% [
			slot_id,
			String(summary.get("location_label", "Bloom Refuge")),
			backup_note,
			int(summary.get("campaign_seed", 0)),
			int(summary.get("bloom", 0)),
			_format_saved_time(int(summary.get("saved_at_unix", 0))),
		]
	)


func _format_saved_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "legacy save"
	var value: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [
		int(value.get("year", 0)),
		int(value.get("month", 0)),
		int(value.get("day", 0)),
		int(value.get("hour", 0)),
		int(value.get("minute", 0)),
	]


func _latest_resumable_summary() -> Dictionary:
	var latest: Dictionary = {}
	for summary: Dictionary in slot_summaries:
		if not bool(summary.get("resumable", false)):
			continue
		if (
			latest.is_empty()
			or int(summary.get("saved_at_unix", 0))
			> int(latest.get("saved_at_unix", 0))
		):
			latest = summary
	return latest


func _has_any_stored_slot() -> bool:
	for summary: Dictionary in slot_summaries:
		if String(summary.get("status", "empty")) != "empty":
			return true
	return false


func _summary_for_slot(slot_id: int) -> Dictionary:
	for summary: Dictionary in slot_summaries:
		if int(summary.get("slot_id", 0)) == slot_id:
			return summary
	return {}


func _on_continue_pressed() -> void:
	var latest: Dictionary = _latest_resumable_summary()
	if latest.is_empty():
		show_status("No valid active-run safe point is available.", true)
		return
	continue_requested.emit(int(latest.get("slot_id", 0)))


func _on_load_slot_pressed(slot_id: int) -> void:
	load_requested.emit(slot_id)


func _on_start_new_pressed() -> void:
	var seed_text: String = new_seed_edit.text.strip_edges()
	if not seed_text.is_valid_int() or seed_text.to_int() <= 0:
		show_status("Enter a positive whole-number campaign seed.", true)
		return
	if new_slot_option.item_count <= 0:
		show_status("No campaign slot is available.", true)
		return
	var slot_id: int = new_slot_option.get_item_id(new_slot_option.selected)
	var campaign_seed: int = seed_text.to_int()
	var summary: Dictionary = _summary_for_slot(slot_id)
	if String(summary.get("status", "empty")) != "empty":
		pending_confirmation = ConfirmationKind.OVERWRITE_SLOT
		pending_slot_id = slot_id
		pending_campaign_seed = campaign_seed
		_show_confirmation(
			"Overwrite Slot %d?" % slot_id,
			"The existing campaign and its recovery backup will be permanently replaced when the new campaign begins.",
			"Overwrite and Begin"
		)
		return
	new_campaign_requested.emit(slot_id, campaign_seed)


func _request_delete_slot(slot_id: int) -> void:
	pending_confirmation = ConfirmationKind.DELETE_SLOT
	pending_slot_id = slot_id
	pending_campaign_seed = 0
	_show_confirmation(
		"Delete Slot %d?" % slot_id,
		"The campaign save and its recovery backup will be permanently removed.",
		"Delete"
	)


func _show_confirmation(
	title: String,
	message: String,
	accept_text: String
) -> void:
	confirmation_title.text = title
	confirmation_message.text = message
	confirmation_accept.text = accept_text
	confirmation_overlay.visible = true
	confirmation_accept.grab_focus()


func _hide_confirmation() -> void:
	confirmation_overlay.visible = false
	pending_confirmation = ConfirmationKind.NONE
	pending_slot_id = 0
	pending_campaign_seed = 0


func _on_confirmation_accepted() -> void:
	var confirmation: ConfirmationKind = pending_confirmation
	var slot_id: int = pending_slot_id
	var campaign_seed: int = pending_campaign_seed
	_hide_confirmation()
	match confirmation:
		ConfirmationKind.OVERWRITE_SLOT:
			new_campaign_requested.emit(slot_id, campaign_seed)
		ConfirmationKind.DELETE_SLOT:
			delete_slot_requested.emit(slot_id)


func _on_apply_settings_pressed() -> void:
	var settings: Dictionary = {
		"master_volume": master_volume_slider.value,
		"fullscreen": fullscreen_check.button_pressed,
	}
	var save_error: String = UserSettingsStore.save_settings(settings)
	show_status(
		"Settings saved."
		if save_error.is_empty()
		else save_error,
		not save_error.is_empty()
	)


func _apply_settings_to_controls(settings: Dictionary) -> void:
	master_volume_slider.value = float(settings.get("master_volume", 0.8))
	fullscreen_check.button_pressed = bool(settings.get("fullscreen", false))
	fullscreen_check.visible = not OS.has_feature("web")


func _show_home_panel() -> void:
	_set_content_panel(home_panel)


func _show_new_panel() -> void:
	_set_content_panel(new_panel)
	if new_seed_edit.text.strip_edges().is_empty():
		new_seed_edit.text = str(maxi(int(Time.get_unix_time_from_system()), 1))


func _show_load_panel() -> void:
	_set_content_panel(load_panel)


func _show_settings_panel() -> void:
	_set_content_panel(settings_panel)


func _set_content_panel(active_panel: Control) -> void:
	for panel: Control in [
		home_panel,
		new_panel,
		load_panel,
		settings_panel,
	]:
		panel.visible = panel == active_panel


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if confirmation_overlay.visible:
		_hide_confirmation()
		return
	_show_home_panel()
