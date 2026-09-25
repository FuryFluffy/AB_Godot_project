class_name ApplicationRoot
extends Node


@export var gameplay_scene: PackedScene
@export var session_host: Node
@export var main_menu: MainMenuScreen
@export var session_menu_layer: CanvasLayer
@export var session_menu_button: Button
@export var return_confirmation: Control
@export var return_confirm_button: Button
@export var return_cancel_button: Button

var active_session: Node
var active_controller: AbyssalBloomMainController


func _ready() -> void:
	UserSettingsStore.apply_settings(UserSettingsStore.load_settings())
	main_menu.continue_requested.connect(_on_continue_requested)
	main_menu.load_requested.connect(_on_load_requested)
	main_menu.new_campaign_requested.connect(_on_new_campaign_requested)
	main_menu.delete_slot_requested.connect(_on_delete_slot_requested)
	main_menu.quit_requested.connect(_on_quit_requested)
	session_menu_button.pressed.connect(_show_return_confirmation)
	return_confirm_button.pressed.connect(_return_to_main_menu)
	return_cancel_button.pressed.connect(_hide_return_confirmation)
	session_menu_layer.visible = false
	return_confirmation.visible = false
	var legacy_warning: String = (
		CampaignSaveSlotStore.get_unsupported_legacy_save_warning()
	)
	_refresh_main_menu(
		legacy_warning,
		not legacy_warning.is_empty()
	)


func _on_new_campaign_requested(slot_id: int, campaign_seed: int) -> void:
	var start_error: String = _create_session()
	if start_error.is_empty():
		start_error = active_controller.start_new_campaign(
			campaign_seed,
			slot_id
		)
	if not start_error.is_empty():
		_destroy_session()
		_refresh_main_menu(start_error, true)
		return
	var delete_error: String = CampaignSaveSlotStore.delete_slot(slot_id)
	if not delete_error.is_empty():
		_destroy_session()
		_refresh_main_menu(delete_error, true)
		return
	_enter_active_session()


func _on_load_requested(slot_id: int) -> void:
	var start_error: String = _create_session()
	if start_error.is_empty():
		start_error = active_controller.load_campaign_slot(slot_id)
	if not start_error.is_empty():
		_destroy_session()
		_refresh_main_menu(start_error, true)
		return
	_enter_active_session()


func _on_continue_requested(slot_id: int) -> void:
	var start_error: String = _create_session()
	if start_error.is_empty():
		start_error = active_controller.continue_active_run_slot(slot_id)
	if not start_error.is_empty():
		_destroy_session()
		_refresh_main_menu(start_error, true)
		return
	_enter_active_session()


func _on_delete_slot_requested(slot_id: int) -> void:
	var delete_error: String = CampaignSaveSlotStore.delete_slot(slot_id)
	_refresh_main_menu(
		"Campaign Slot %d deleted." % slot_id
		if delete_error.is_empty()
		else delete_error,
		not delete_error.is_empty()
	)


func _create_session() -> String:
	_destroy_session()
	if gameplay_scene == null or session_host == null:
		return "The gameplay session scene is unavailable."
	active_session = gameplay_scene.instantiate()
	if active_session == null:
		return "The gameplay session could not be instantiated."
	session_host.add_child(active_session)
	active_controller = active_session.get_node_or_null(
		"Controller"
	) as AbyssalBloomMainController
	if active_controller == null:
		return "The gameplay session has no main controller."
	return ""


func _enter_active_session() -> void:
	main_menu.visible = false
	session_menu_layer.visible = true
	return_confirmation.visible = false
	session_menu_button.grab_focus()


func _show_return_confirmation() -> void:
	return_confirmation.visible = true
	return_confirm_button.grab_focus()


func _hide_return_confirmation() -> void:
	return_confirmation.visible = false
	session_menu_button.grab_focus()


func _return_to_main_menu() -> void:
	return_confirmation.visible = false
	session_menu_layer.visible = false
	_destroy_session()
	main_menu.visible = true
	_refresh_main_menu(
		"Returned to the main menu. Continue will resume the latest active-run safe point."
	)


func _destroy_session() -> void:
	active_controller = null
	if active_session == null:
		return
	if active_session.get_parent() != null:
		active_session.get_parent().remove_child(active_session)
	active_session.queue_free()
	active_session = null


func _refresh_main_menu(
	message: String = "",
	is_error: bool = false
) -> void:
	main_menu.configure_slots(
		CampaignSaveSlotStore.list_slots(),
		message,
		is_error
	)


func _on_quit_requested() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if (
		active_session == null
		or not event.is_action_pressed("ui_cancel")
	):
		return
	get_viewport().set_input_as_handled()
	if return_confirmation.visible:
		_hide_return_confirmation()
	else:
		_show_return_confirmation()
