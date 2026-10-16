class_name BackpackView
extends VBoxContainer
## Passive shared component for Refuge and run inventory. No Stash/service access.

@onready var heroine_selector: HeroineSelector = %InventoryHeroine
@onready var grid: RefugeSlotGrid = %PreparationGrid
@onready var key_ring: ItemList = %KeyList


func _ready() -> void:
	$Keys/Header.text = "Shared Key-ring"
	key_ring.custom_minimum_size.y = 56
	$Keys/Rules.hide()


func present_slots(entries: Array[Dictionary]) -> void:
	grid.present(entries, 3)
