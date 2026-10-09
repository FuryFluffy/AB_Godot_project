class_name CombatItemSlotView
extends Button

@onready var quantity_badge: Label = $Quantity

func display_item(texture: Texture2D, quantity: int, available: bool,
	selected: bool, hint: String) -> void:
	icon = texture
	text = "—" if quantity <= 0 else ""
	quantity_badge.text = str(quantity) if quantity > 0 else ""
	disabled = not available
	set_pressed_no_signal(selected)
	tooltip_text = hint
