extends RefCounted
## Test-only media attachments. Never registered in the production lore catalog.

static func catalog() -> LoreCatalogDefinition:
	var result := LoreCatalogDefinition.new()
	for index: int in range(3):
		var entry := LoreEntryDefinition.new()
		entry.lore_id = StringName("stage09_fixture_%d" % index)
		entry.title = ["Image fixture", "Scene fixture", "Image + scene fixture"][index]
		entry.discovery_text = "Test fixture only."
		entry.archive_text = "Test fixture only. No production Gallery entry has been authored."
		if index != 1:
			entry.archive_image = load("res://assets/backgrounds/layer_2/sdxl_curated/07_Bloom_Refuge_Transformed.png")
		if index != 0:
			entry.archive_replay = load("res://data/dialogue/layer1_bell_pull_gallery_observation.tres")
			entry.archive_replay_context = DialogueContext.new().to_snapshot()
		result.entries.append(entry)
	return result
