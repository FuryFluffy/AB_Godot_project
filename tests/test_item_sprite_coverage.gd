extends SceneTree


const CATALOG_PATH: String = "res://data/items/layer_1_2_item_catalog.tres"
const RUSTY_KEY_PATH: String = "res://data/items/keys/rusty_key.tres"
const PROP_PATHS: Array[String] = [
	"res://assets/exploration/shared/props/bone_dice_cup.png",
	"res://assets/exploration/shared/props/butlers_records.png",
	"res://assets/exploration/shared/props/tarnished_service_bell.png",
]
const DOOR_PATHS: Array[String] = [
	"res://assets/exploration/shared/doors/gothic_door_closed.png",
	"res://assets/exploration/shared/doors/gothic_door_open.png",
]


var failures: int = 0


func _init() -> void:
	_test_catalog_icons()
	_test_rusty_key_icon()
	_test_authored_room_art()

	if failures == 0:
		print("Layer 1–2 item sprite coverage tests passed.")
	else:
		push_error("%d item sprite coverage test(s) failed." % failures)
	quit(failures)


func _test_catalog_icons() -> void:
	var catalog: ItemCatalogDefinition = load(CATALOG_PATH) as ItemCatalogDefinition
	_expect(catalog != null, "The Layer 1–2 item catalog should load.")
	if catalog == null:
		return
	_expect(
		catalog.items.size() == 33,
		"The catalog should contain 32 executable workbook items and one legacy item."
	)
	for item: ItemDefinition in catalog.items:
		_expect(item != null, "The item catalog must not contain an empty entry.")
		if item == null:
			continue
		_expect(item.icon != null, "%s must have an assigned icon." % item.item_id)
		if item.icon != null:
			_expect(
				item.icon.get_width() == 512 and item.icon.get_height() == 512,
				"%s must use a 512x512 runtime icon." % item.item_id
			)


func _test_rusty_key_icon() -> void:
	var rusty_key: ItemDefinition = load(RUSTY_KEY_PATH) as ItemDefinition
	_expect(rusty_key != null, "The universal Rusty Key definition should load.")
	if rusty_key == null:
		return
	_expect(rusty_key.icon != null, "The universal Rusty Key must have an assigned icon.")
	if rusty_key.icon != null:
		_expect(
			rusty_key.icon.get_width() == 512 and rusty_key.icon.get_height() == 512,
			"The universal Rusty Key must use a 512x512 runtime icon."
		)


func _test_authored_room_art() -> void:
	for path: String in PROP_PATHS:
		_expect(ResourceLoader.exists(path), "Missing interaction prop: %s" % path)
	for path: String in DOOR_PATHS:
		_expect(ResourceLoader.exists(path), "Missing reusable door state: %s" % path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
