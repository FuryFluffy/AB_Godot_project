"""Godot may omit default-valued exports; explicit invalid values still fail."""
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import validate_project as validator


class ResourceDefaultsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ab-validator-defaults-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        original = validator.ROOT
        for entry in original.iterdir():
            if entry.name.startswith("."):
                continue
            if entry.name != "data":
                (self.root / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
        (self.root / "data").mkdir()
        for entry in (original / "data").iterdir():
            target = self.root / "data" / entry.name
            if entry.name in ("rooms", "items"):
                shutil.copytree(entry, target)
            else:
                target.symlink_to(entry, target_is_directory=entry.is_dir())
        self.patch = patch.object(validator, "ROOT", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.room = self.root / "data/rooms/layer_1/01_opening_servant_corridor.tres"

    def room_errors(self):
        errors = []
        validator.validate_layer_room_registry(errors)
        return errors

    def append_property(self, path, value):
        path.write_text(path.read_text() + "\n" + value + "\n")

    def test_saved_defaults_are_accepted(self):
        self.assertEqual([], self.room_errors())
        errors = []
        validator.validate_item_system(errors)
        self.assertEqual([], errors)

    def test_explicit_wrong_layer_is_rejected_without_false_missing_art(self):
        self.append_property(self.room, "layer_number = 2")
        errors = self.room_errors()
        self.assertTrue(any("authored Layer 2" in e for e in errors))
        self.assertFalse(any("backgrounds absent" in e for e in errors))

    def test_explicit_wrong_order_is_rejected(self):
        self.append_property(self.room, "canonical_order = 99")
        self.assertTrue(any("order/IDs differ" in e for e in self.room_errors()))

    def test_explicit_malformed_or_zero_order_is_rejected(self):
        source = self.room.read_text()
        for value in ('"one"', "0"):
            with self.subTest(value=value):
                self.room.write_text(source + "\ncanonical_order = " + value + "\n")
                self.assertTrue(any("canonical_order" in e for e in self.room_errors()))

    def test_missing_root_id_does_not_use_nested_id(self):
        source = self.room.read_text().replace('room_id = &"opening_servant_corridor"', '')
        self.room.write_text(source.replace('[resource]', '[sub_resource type="Resource" id="bogus"]\nroom_id = &"opening_servant_corridor"\n\n[resource]'))
        self.assertTrue(any("root room_id" in e for e in self.room_errors()))

    def test_missing_background_reference_is_rejected(self):
        source = self.room.read_text()
        source = "\n".join(line for line in source.splitlines() if 'path="res://assets/backgrounds/' not in line)
        self.room.write_text(source)
        self.assertTrue(any("backgrounds absent" in e for e in self.room_errors()))

    def test_explicit_canonical_legacy_blanket_is_rejected(self):
        blanket = next((self.root / "data/items").rglob("quiet_cell_blanket.tres"))
        self.append_property(blanket, "canonical_workbook_item = true")
        errors = []
        validator.validate_item_system(errors)
        self.assertTrue(any("Blanket must not be canonical" in e for e in errors))

    def test_subresource_default_does_not_override_root(self):
        properties = validator.root_resource_properties('[sub_resource type="Resource" id="x"]\nlayer_number = 2\n[resource]\nroom_id = &"example"\n')
        default = validator.exported_scalar_default(self.root / "scripts/data/rooms/layer_room_definition.gd", "layer_number")
        self.assertEqual(1, validator.effective_resource_integer(properties, "layer_number", default))

    def test_item_bar_stays_vertical_by_default(self):
        scene_link = self.root / "scenes"
        original_scenes = scene_link.resolve()
        scene_link.unlink()
        shutil.copytree(original_scenes, scene_link)
        scene = scene_link / "battle/ui/reusable/components/item_bar_view.tscn"
        source = scene.read_text()
        errors = []
        validator.validate_combat_hud(errors)
        self.assertEqual([], errors)
        scene.write_text(source.replace("columns = 1", "columns = 6"))
        errors = []
        validator.validate_combat_hud(errors)
        self.assertTrue(any("default to one vertical column" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
