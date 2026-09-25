class_name ExplorationModeController
extends RefCounted


signal mode_changed(mode: Mode)


enum Mode {
	FREE_EXPLORATION,
	DIALOGUE,
	CHOICE_SELECTION,
	DIALOGUE_ITEM_SELECTION,
}


var mode: Mode = Mode.FREE_EXPLORATION


func set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


func is_dialogue_active() -> bool:
	return mode != Mode.FREE_EXPLORATION
