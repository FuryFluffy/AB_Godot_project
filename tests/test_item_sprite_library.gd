extends SceneTree


const MANIFEST_PATH: String = "res://data/items/item_sprite_manifest.json"
const EXPECTED_ITEM_COUNT: int = 126
const TEXTURE_ROOT: String = "res://assets/items/by_stable_id/"


var failures: int = 0


func _init() -> void:
	_test_stable_id_sprite_library()

	if failures == 0:
		print("Stable-ID item sprite library tests passed.")
	else:
		push_error("%d item sprite library test(s) failed." % failures)
	quit(failures)


func _test_stable_id_sprite_library() -> void:
	_expect(
		FileAccess.file_exists(MANIFEST_PATH),
		"The item sprite manifest should exist."
	)
	if not FileAccess.file_exists(MANIFEST_PATH):
		return

	var manifest_file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	_expect(manifest_file != null, "The item sprite manifest should be readable.")
	if manifest_file == null:
		return

	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	_expect(
		parsed is Dictionary,
		"The item sprite manifest should contain a JSON object."
	)
	if not (parsed is Dictionary):
		return

	var manifest: Dictionary = parsed as Dictionary
	_expect(
		int(manifest.get("canonical_item_count", 0)) == EXPECTED_ITEM_COUNT,
		"The manifest should declare %d canonical items." % EXPECTED_ITEM_COUNT
	)
	var item_value: Variant = manifest.get("items", [])
	_expect(
		item_value is Array,
		"The item sprite manifest should contain an items array."
	)
	if not (item_value is Array):
		return

	var items: Array = item_value as Array
	_expect(
		items.size() == EXPECTED_ITEM_COUNT,
		"The manifest should contain %d sprite records." % EXPECTED_ITEM_COUNT
	)
	var seen_ids: Dictionary = {}
	for item_value_entry: Variant in items:
		_expect(
			item_value_entry is Dictionary,
			"Every sprite record should be an object."
		)
		if not (item_value_entry is Dictionary):
			continue
		var item: Dictionary = item_value_entry as Dictionary
		var stable_id: String = String(item.get("stable_id", ""))
		var texture_path: String = String(item.get("texture_path", ""))
		_expect(not stable_id.is_empty(), "Every sprite record should have a Stable ID.")
		if stable_id.is_empty():
			continue
		_expect(
			not seen_ids.has(stable_id),
			"Duplicate sprite Stable ID: %s" % stable_id
		)
		seen_ids[stable_id] = true
		_expect(
			texture_path == "%s%s.png" % [TEXTURE_ROOT, stable_id],
			"%s should use its canonical Stable-ID texture path." % stable_id
		)
		_expect(
			ResourceLoader.exists(texture_path),
			"Missing item sprite: %s" % texture_path
		)
		if not ResourceLoader.exists(texture_path):
			continue
		var texture: Texture2D = load(texture_path) as Texture2D
		_expect(texture != null, "%s should load as a Texture2D." % stable_id)
		if texture != null:
			_expect(
				texture.get_width() == 512 and texture.get_height() == 512,
				"%s should use a 512x512 runtime texture." % stable_id
			)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
