#!/usr/bin/env python3
"""Run the cumulative Abyssal Bloom Godot combat regression suite."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import os
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Iterator, Mapping
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "tools" / "validate_project.py"
TESTS = (
    "tests/test_combat_kernel.gd",
    "tests/test_battle_flow.gd",
    "tests/test_spatial_battle.gd",
    "tests/test_spatial_combat.gd",
    "tests/test_position_contacts.gd",
    "tests/test_enemy_ai.gd",
    "tests/test_ordinary_combat.gd",
    "tests/test_board_interaction.gd",
    "tests/test_cancel_input_routing.gd",
    "tests/test_grapple_foundation.gd",
    "tests/test_grapple_move_reactions.gd",
    "tests/test_item_system.gd",
    "tests/test_canonical_item_ids.gd",
    "tests/test_reward_sources.gd",
    "tests/test_item_sprite_library.gd",
    "tests/test_node_map.gd",
    "tests/test_layer_room_registry.gd",
    "tests/test_registered_room_presentations.gd",
    "tests/test_layer_generator_activation.gd",
    "tests/test_opening_event_room_flow.gd",
    "tests/test_dialogue_foundation.gd",
    "tests/test_production_dialogue_authoring.gd",
    "tests/test_layer1_novel_integration.gd",
    "tests/test_layer_transition.gd",
    "tests/test_jailer_refuge_origin.gd",
    "tests/test_bloom_refuge_hub.gd",
    "tests/test_production_save_slots.gd",
    "tests/test_active_run_safe_points.gd",
    "tests/test_campaign_lifecycle.gd",
    "tests/test_l1_l2_demo_flow.gd",
    "tests/test_layer_2_first_slice.gd",
    "tests/test_heroine_kits.gd",
    "tests/test_ability_resources.gd",
    "tests/test_weapon_resources.gd",
    "tests/test_refuge_salvage_recipes.gd",
    "tests/test_refuge_management_ui.gd",
    "tests/test_weapon_techniques.gd",
    "tests/test_layer_1_enemy_roster.gd",
    "tests/test_combat_hud.gd",
    "tests/test_reusable_merge.gd",
    "tests/test_encounter_startup.gd",
    "tests/test_battle_composition.gd",
    "tests/test_battlefield_authoring.gd",
    "tests/test_battler_visual_profiles.gd",
    "tests/test_static_png_combat_presentation.gd",
    "tests/test_combat_stage_triggers.gd",
    "tests/test_milestone_15_pilot_a.gd",
)


def find_godot(explicit_path: str | None = None) -> str | None:
    if explicit_path:
        return explicit_path
    configured = os.environ.get("GODOT_BIN")
    if configured:
        return configured
    for candidate in ("godot4", "godot"):
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    return None


def run(
    command: list[str],
    *,
    env: Mapping[str, str] | None = None,
) -> int:
    print("+", " ".join(command), flush=True)
    return subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        env=env,
    ).returncode


@contextmanager
def isolated_godot_environment() -> Iterator[dict[str, str]]:
    """Provide fresh Godot user/config/cache roots for one process."""
    with tempfile.TemporaryDirectory(
        prefix="abyssal-bloom-godot-test-"
    ) as temporary_directory:
        temporary_root = Path(temporary_directory)
        environment = os.environ.copy()
        for variable, directory_name in (
            ("XDG_DATA_HOME", "data"),
            ("XDG_CONFIG_HOME", "config"),
            ("XDG_CACHE_HOME", "cache"),
        ):
            isolated_path = temporary_root / directory_name
            isolated_path.mkdir()
            environment[variable] = str(isolated_path)
        yield environment


def godot_cache_needs_bootstrap(project_root: Path = ROOT) -> bool:
    godot_cache = project_root / ".godot"
    return not (
        (godot_cache / "global_script_class_cache.cfg").is_file()
        and (godot_cache / "imported").is_dir()
    )


def bootstrap_godot_cache(godot: str) -> int:
    print(
        "Godot import/class cache is absent; bootstrapping the project editor.",
        flush=True,
    )
    with isolated_godot_environment() as environment:
        return run(
            [
                godot,
                "--headless",
                "--editor",
                "--quit",
                "--path",
                str(ROOT),
            ],
            env=environment,
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--list",
        action="store_true",
        help="List the tests without running them.",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Run structural validation without requiring Godot.",
    )
    parser.add_argument(
        "--godot",
        help="Use this Godot 4.7 executable instead of GODOT_BIN/PATH discovery.",
    )
    args = parser.parse_args()

    if args.list:
        print("\n".join(TESTS))
        return 0

    validation_result = run(
        [sys.executable, str(VALIDATOR), "--allow-generated-cache"]
    )
    if validation_result != 0 or args.validate_only:
        return validation_result

    godot = find_godot(args.godot)
    if godot is None:
        print(
            "Godot was not found. Set GODOT_BIN to the Godot 4.7 executable "
            "or place godot4/godot on PATH.",
            file=sys.stderr,
        )
        return 2

    if godot_cache_needs_bootstrap():
        bootstrap_result = bootstrap_godot_cache(godot)
        if bootstrap_result != 0:
            print(
                "Godot project import/class-cache bootstrap failed.",
                file=sys.stderr,
            )
            return bootstrap_result

    failures: list[str] = []
    for test in TESTS:
        with isolated_godot_environment() as environment:
            result = run(
                [
                    godot,
                    "--headless",
                    "--path",
                    str(ROOT),
                    "--script",
                    f"res://{test}",
                ],
                env=environment,
            )
        if result != 0:
            failures.append(test)

    if failures:
        print(
            "Regression failures:\n- " + "\n- ".join(failures),
            file=sys.stderr,
        )
        return 1

    print(f"All {len(TESTS)} regression scripts passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
