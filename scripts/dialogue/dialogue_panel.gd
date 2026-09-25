class_name DialoguePanel
extends Control


signal advance_requested
signal choice_requested(choice_id: StringName)


@onready var portrait: TextureRect = %Portrait
@onready var left_actor: TextureRect = %LeftActor
@onready var right_actor: TextureRect = %RightActor
@onready var speaker_label: Label = %Speaker
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var choice_scroll: ScrollContainer = %ChoiceScroll
@onready var choice_list: VBoxContainer = %ChoiceList
@onready var item_prompt: Label = %ItemPrompt
@onready var continue_button: Button = %Continue


func _ready() -> void:
	continue_button.pressed.connect(
		advance_requested.emit
	)


func present(runner: DialogueRunner) -> void:
	_clear_choices()
	var node: DialogueNodeDefinition = runner.get_current_node()
	if node == null:
		visible = false
		return

	visible = true
	portrait.texture = node.portrait
	portrait.visible = node.portrait != null
	left_actor.texture = node.left_actor_sprite
	left_actor.flip_h = node.left_actor_flip_h
	left_actor.visible = node.left_actor_sprite != null
	right_actor.texture = node.right_actor_sprite
	right_actor.flip_h = node.right_actor_flip_h
	right_actor.visible = node.right_actor_sprite != null
	speaker_label.text = (
		node.speaker_name
		if not node.speaker_name.is_empty()
		else String(node.speaker_id).capitalize()
	)
	dialogue_text.text = node.text

	var presented_choices: Array[Dictionary] = (
		runner.get_presented_choices()
	)
	for entry: Dictionary in presented_choices:
		var choice := entry.get("choice") as DialogueChoiceDefinition
		if choice == null:
			continue
		var button := Button.new()
		button.text = _choice_label(choice)
		button.disabled = not bool(entry.get("available", false))
		button.tooltip_text = String(entry.get("reason", ""))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(
			choice_requested.emit.bind(choice.choice_id)
		)
		choice_list.add_child(button)
	choice_scroll.visible = not presented_choices.is_empty()

	item_prompt.text = _get_item_prompt(node)
	item_prompt.visible = not item_prompt.text.is_empty()
	continue_button.visible = (
		presented_choices.is_empty()
		and node.item_policy
		!= DialogueNodeDefinition.ItemPolicy.REQUIRED_ITEM
	)
	continue_button.text = (
		"Finish"
		if node.default_next_node_id == &""
		else "Continue"
	)


func _clear_choices() -> void:
	for child: Node in choice_list.get_children():
		choice_list.remove_child(child)
		child.queue_free()


func _choice_label(choice: DialogueChoiceDefinition) -> String:
	if choice.responder_id == &"":
		return choice.text
	return "%s: %s" % [
		String(choice.responder_id).capitalize(),
		choice.text,
	]


func _get_item_prompt(node: DialogueNodeDefinition) -> String:
	match node.item_policy:
		DialogueNodeDefinition.ItemPolicy.DISABLED:
			return ""
		DialogueNodeDefinition.ItemPolicy.NORMAL_USE:
			return "Ordinary Item Bar use is available."
		DialogueNodeDefinition.ItemPolicy.DIALOGUE_ITEMS:
			return "An eligible Item Bar item may be used as an answer."
		DialogueNodeDefinition.ItemPolicy.REQUIRED_ITEM:
			return "Select an eligible Item Bar item to continue."
	return ""
