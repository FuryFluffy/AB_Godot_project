#!/usr/bin/env python3
"""Focused tests for the Godot regression-suite launcher."""

from __future__ import annotations

import tempfile
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True

import run_regression_suite


class RegressionSuiteRunnerTests(unittest.TestCase):
    def test_explicit_godot_path_overrides_environment_and_path(self) -> None:
        with mock.patch.dict("os.environ", {"GODOT_BIN": "/env/godot"}):
            self.assertEqual(
                run_regression_suite.find_godot("/explicit/godot4"),
                "/explicit/godot4",
            )

    def test_godot_environment_is_fresh_writable_and_cleaned_up(self) -> None:
        isolated_roots: list[Path] = []

        for _index in range(2):
            with run_regression_suite.isolated_godot_environment() as environment:
                data_home = Path(environment["XDG_DATA_HOME"])
                config_home = Path(environment["XDG_CONFIG_HOME"])
                cache_home = Path(environment["XDG_CACHE_HOME"])
                isolated_root = data_home.parent
                isolated_roots.append(isolated_root)

                self.assertTrue(data_home.is_dir())
                self.assertTrue(config_home.is_dir())
                self.assertTrue(cache_home.is_dir())
                probe = data_home / "write-probe"
                probe.write_text("writable", encoding="utf-8")
                self.assertEqual(probe.read_text(encoding="utf-8"), "writable")

            self.assertFalse(isolated_root.exists())

        self.assertNotEqual(isolated_roots[0], isolated_roots[1])

    def test_pristine_project_requires_import_bootstrap(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            project_root = Path(temporary_directory)
            self.assertTrue(
                run_regression_suite.godot_cache_needs_bootstrap(project_root)
            )

            godot_cache = project_root / ".godot"
            godot_cache.mkdir()
            (godot_cache / "global_script_class_cache.cfg").write_text(
                "list=[]\n",
                encoding="utf-8",
            )
            self.assertTrue(
                run_regression_suite.godot_cache_needs_bootstrap(project_root)
            )

            (godot_cache / "imported").mkdir()
            self.assertFalse(
                run_regression_suite.godot_cache_needs_bootstrap(project_root)
            )

    def test_bootstrap_uses_isolated_environment_and_editor_mode(self) -> None:
        isolated_paths: list[Path] = []

        def capture_run(
            command: list[str],
            *,
            env: dict[str, str] | None = None,
        ) -> int:
            self.assertIsNotNone(env)
            assert env is not None
            self.assertIn("--headless", command)
            self.assertIn("--editor", command)
            self.assertIn("--quit", command)
            for variable in (
                "XDG_DATA_HOME",
                "XDG_CONFIG_HOME",
                "XDG_CACHE_HOME",
            ):
                isolated_path = Path(env[variable])
                isolated_paths.append(isolated_path)
                self.assertTrue(isolated_path.is_dir())
            return 0

        with mock.patch.object(
            run_regression_suite,
            "run",
            side_effect=capture_run,
        ):
            self.assertEqual(
                run_regression_suite.bootstrap_godot_cache("godot4"),
                0,
            )

        for isolated_path in isolated_paths:
            self.assertFalse(isolated_path.exists())


if __name__ == "__main__":
    unittest.main()
