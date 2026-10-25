class_name RunRecoveryDialog
extends ConfirmationDialog
## Shared small confirmation. No gameplay state or save ownership lives here.
signal failed(message: String)
var preview: Callable
var commit: Callable
var access_guard: Callable
var origin: Control
var request: Dictionary = {}

func _ready() -> void:
	title = "Confirm"
	transient = true
	exclusive = true
	get_ok_button().text = "Confirm"
	add_theme_font_size_override("title_font_size", 22)
	get_label().add_theme_font_size_override("font_size", 24)
	get_ok_button().add_theme_font_size_override("font_size", 22)
	get_cancel_button().add_theme_font_size_override("font_size", 22)
	confirmed.connect(_confirm)
	canceled.connect(_restore_focus)

func open_confirmation(button: Control) -> void:
	if not preview.is_valid() or not commit.is_valid() or not _access_error().is_empty():
		return
	request = preview.call()
	var error: String = String(request.get("error", ""))
	if not error.is_empty():
		failed.emit(error)
		return
	origin = button
	title = String(request.get("title", "Confirm"))
	dialog_text = String(request.get("text", ""))
	popup_centered(Vector2i(520, 170))
	get_cancel_button().grab_focus()

func _confirm() -> void:
	var error: String = _access_error()
	if error.is_empty():
		error = String(commit.call(request))
	request = {}
	if not error.is_empty():
		failed.emit(error)
	_restore_focus()

func _process(_delta: float) -> void:
	if visible and not _access_error().is_empty():
		hide()
		request = {}
		_restore_focus()

func _access_error() -> String:
	return String(access_guard.call()) if access_guard.is_valid() else "Recovery is unavailable."

func _restore_focus() -> void:
	if is_instance_valid(origin) and origin.is_inside_tree() and origin.is_visible_in_tree():
		origin.grab_focus.call_deferred()
