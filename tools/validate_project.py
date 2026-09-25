#!/usr/bin/env python3
"""Small dependency-free integrity check for the downloadable Godot project."""

from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import re
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_RE = re.compile(r'(?:path|run/main_scene)="res://([^"]+)"')
CLASS_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
FUNCTION_RE = re.compile(
    r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(",
    re.MULTILINE,
)
GLOBAL_ENUM_COLLISION_RE = re.compile(r"^\s*enum\s+Side\b", re.MULTILINE)
TYPED_COLLECTION_CALL_RE = re.compile(
    r"\b(?:Array|Dictionary)\s*\[[^\]\n]+\]\s*\("
)
EXPORTED_COLLECTION_TYPE_LINEBREAK_RE = re.compile(
    r"^@export[^\n]*:\s*(?:Array|Dictionary)\[\s*$",
    re.MULTILINE,
)
TYPED_INT_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*int\b")
NODE_RE = re.compile(
    r'^\[node name="([^"]+)"(?: type="[^"]+")?'
    r'(?: parent="([^"]+)")?',
    re.MULTILINE,
)
NODE_PATH_RE = re.compile(r'NodePath\("([^"]+)"\)')
MAIN_SCENE_RE = re.compile(r'^run/main_scene="([^"]+)"', re.MULTILINE)
SCENE_UID_RE = re.compile(r'^\[gd_scene\b[^\]]*\buid="([^"]+)"', re.MULTILINE)
CONNECTION_RE = re.compile(
    r'^\[connection signal="([^"]+)" from="([^"]+)" '
    r'to="([^"]+)" method="([^"]+)"\]',
    re.MULTILINE,
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate the Abyssal Bloom Godot project.",
    )
    parser.add_argument(
        "--allow-generated-cache",
        action="store_true",
        help=(
            "Validate a development worktree while skipping ignored .godot/ "
            "cache contents. Omit this option when validating a package."
        ),
    )
    args = parser.parse_args()
    errors: list[str] = []

    if not (ROOT / "project.godot").is_file():
        errors.append("project.godot is missing from the archive root")
    else:
        validate_main_scene(errors)

    class_owners: dict[str, Path] = {}

    for source in sorted(ROOT.rglob("*")):
        if args.allow_generated_cache and ".godot" in source.parts:
            continue
        if not source.is_file():
            continue

        if ".godot" in source.parts:
            errors.append(f"generated .godot content should not be packaged: {source}")
        if "__pycache__" in source.parts:
            errors.append(f"generated Python cache should not be packaged: {source}")

        if source.suffix not in {".gd", ".tscn", ".tres", ".godot"}:
            continue

        text = source.read_text(encoding="utf-8")

        for match in RESOURCE_RE.finditer(text):
            target = ROOT / match.group(1)
            if not target.exists() and not match.group(1).startswith("uid://"):
                errors.append(f"{source}: missing res://{match.group(1)}")

        if source.suffix == ".gd":
            validate_gdscript_delimiters(source, text, errors)
            function_lines: dict[str, int] = {}
            for match in FUNCTION_RE.finditer(text):
                function_name = match.group(1)
                line = text.count("\n", 0, match.start()) + 1
                previous_line = function_lines.get(function_name)
                if previous_line is not None:
                    errors.append(
                        f"{source}: duplicate function {function_name} "
                        f"at lines {previous_line} and {line}"
                    )
                function_lines[function_name] = line
            if GLOBAL_ENUM_COLLISION_RE.search(text):
                errors.append(
                    f"{source}: enum Side collides with Godot's global Side enum"
                )
            if TYPED_COLLECTION_CALL_RE.search(text):
                errors.append(
                    f"{source}: typed collection used as a callable constructor"
                )
            if EXPORTED_COLLECTION_TYPE_LINEBREAK_RE.search(text):
                errors.append(
                    f"{source}: exported collection type is split after '['"
                )
            typed_int_names = {
                match.group(1) for match in TYPED_INT_RE.finditer(text)
            }
            for int_name in sorted(typed_int_names):
                invalid_constructor = re.compile(
                    rf"\bString\s*\(\s*{re.escape(int_name)}\s*\)"
                )
                for match in invalid_constructor.finditer(text):
                    line = text.count("\n", 0, match.start()) + 1
                    errors.append(
                        f"{source}:{line}: String(int) is not a valid Godot "
                        "constructor; use str(...)"
                    )
            for match in CLASS_RE.finditer(text):
                class_name = match.group(1)
                previous = class_owners.get(class_name)
                if previous is not None:
                    errors.append(
                        f"duplicate class_name {class_name}: {previous} and {source}"
                    )
                class_owners[class_name] = source

        if source.suffix == ".tscn":
            validate_scene_node_paths(source, text, errors)

    required_classes = {
        "ActionRequest",
        "ActionResult",
        "AbilityDefinition",
        "AbilityCatalogDefinition",
        "AbilityEffectDefinition",
        "AbilityEffectResolver",
        "AttackAbilityEffect",
        "HealAbilityEffect",
        "ApplyStatusAbilityEffect",
        "RemoveStatusAbilityEffect",
        "BlessAbilityEffect",
        "WardAbilityEffect",
        "AnalyzeAbilityEffect",
        "GroupHealAbilityEffect",
        "BloodRiposteAbilityEffect",
        "AbilityActionController",
        "AbilityPanel",
        "AbilityUseResult",
        "AnchorDefinition",
        "PositionContactDefinition",
        "AoeActionController",
        "AoeResolutionState",
        "CombatEngine",
        "CombatPresenter",
        "DiceRoller",
        "DodgeStepController",
        "ReusableCombatHUD",
        "ReactionExchange",
        "ReactionExchangeController",
        "HeroineCardView",
        "EnemyHudView",
        "CommandBarView",
        "ItemBarView",
        "CombatLogDrawer",
        "AttackReactionChoice",
        "AttackResolutionQueue",
        "AttackTargetingResult",
        "BattleActionController",
        "BattleFlowController",
        "BattleMovementController",
        "BattleRuntimeState",
        "BattleState",
        "BattleLifecycleController",
        "BattleTargetingController",
        "BattlefieldDefinition",
        "BattlefieldInteractionOverlay",
        "BattlefieldOverlay",
        "BattlefieldState",
        "BattlerPlacementDefinition",
        "BattlerPositionState",
        "BattleZoneDefinition",
        "CommittedMoveState",
        "EnemyAIController",
        "EnemyDecision",
        "EnemyGroupRuleDefinition",
        "EnemyGroupRulebookDefinition",
        "EnemyRuleDefinition",
        "EnemyRulebookDefinition",
        "GrappleActionResult",
        "GrappleAttemptResult",
        "GrappleController",
        "GrappleStageDefinition",
        "GrappleTemplateDefinition",
        "GrappleTrackState",
        "InventorySlotState",
        "ItemCatalogDefinition",
        "ItemDefinition",
        "MaterialDefinition",
        "MaterialCatalogDefinition",
        "ItemEffectDefinition",
        "ItemUseController",
        "ItemUseResult",
        "LayerRoomCatalogDefinition",
        "LayerRoomDefinition",
        "LayerRoomVisualDefinition",
        "MovementPreview",
        "StatusApplicationResult",
        "StatusController",
        "StatusDefinition",
        "StatusInstance",
        "StatusPhaseReport",
        "SpecialtyEntry",
        "StrugglePanel",
        "SixSlotInventoryState",
        "TerrainLineDefinition",
        "ArmorDefinition",
        "ArmorState",
        "EquipmentDefinition",
        "EquipmentCatalogDefinition",
        "EquipmentInstance",
        "EquipmentLoadout",
        "PersonalEquipmentLoadoutState",
        "RunEquipmentState",
        "ShieldDefinition",
        "ShieldState",
        "WeaponState",
        "HeroineProgressionState",
        "WeaponDefinition",
        "WeaponFamilyDefinition",
        "WeaponRankDefinition",
        "WeaponEffectDefinition",
        "DefenseIgnoreWeaponEffect",
        "ActionLossOnDamageWeaponEffect",
        "StatusOnDamageWeaponEffect",
        "FlatAttackSuccessWeaponEffect",
        "RangeDiceWeaponEffect",
        "CriticalFreeAttackWeaponEffect",
        "MapNodeState",
        "LayerMapGraph",
        "LayerMapGenerator",
        "EncounterDefinition",
        "EncounterOutcome",
        "RunInventoryState",
        "RewardSourceCatalogDefinition",
        "RewardSourceResolver",
        "RefugeOwnershipState",
        "RefugeRecipeDefinition",
        "RefugeRecipeCatalogDefinition",
        "RunState",
        "LayerMapView",
        "AbyssalBloomMainController",
        "AuthoredBattlefield",
        "AuthoredBattleZone",
        "AuthoredAnchor",
        "AuthoredPosition",
        "AuthoredSpawnSlot",
        "SpawnSlotDefinition",
        "EncounterTemplateDefinition",
        "BattlerCatalogDefinition",
        "BattlerViewDefinition",
        "BattlerViewCatalogDefinition",
        "BattlerVisualStateDefinition",
        "BattlerVisualFallbackDefinition",
        "BattlerGrappleVisualMetadata",
        "BattlerVisualProfile",
        "BattlerVisualProfileCatalog",
        "BattlerVisualIntentResolver",
        "BattleMarkerFactory",
        "DialogueConditionDefinition",
        "DialogueConditionGroup",
        "DialogueAutomaticTransitionDefinition",
        "DialogueOutcomeDefinition",
        "DialogueItemOptionDefinition",
        "DialogueChoiceDefinition",
        "DialogueNodeDefinition",
        "DialogueDefinition",
        "DialogueCatalogDefinition",
        "DialogueContext",
        "DialogueResult",
        "DialogueSessionState",
        "DialogueRunner",
        "DialoguePanel",
        "StoryDialogueOutcome",
        "ExplorationModeController",
        "ExplorationHUD",
        "NarrativeState",
        "CampaignLifecycleState",
        "CampaignSaveStore",
        "CampaignSaveSlotStore",
        "UserSettingsStore",
        "ApplicationRoot",
        "MainMenuScreen",
        "BloomRefugeScreen",
    }
    missing_classes = sorted(required_classes - class_owners.keys())
    if missing_classes:
        errors.append("missing required classes: " + ", ".join(missing_classes))

    validate_modular_combat_architecture(errors)
    validate_battler_visual_profiles(errors)
    validate_position_contact_editor_contract(errors)
    validate_attack_dice_floor(errors)
    validate_item_system(errors)
    validate_reward_sources(errors)
    validate_item_sprite_library(errors)
    validate_layer_room_registry(errors)
    validate_node_map(errors)
    validate_opening_event_room_flow(errors)
    validate_dialogue_foundation(errors)
    validate_production_dialogue_authoring(errors)
    validate_milestone_15_pilot_a(errors)
    validate_mira_recruitment(errors)
    validate_seraphine_recruitment(errors)
    validate_wipe_narrative_state_recovery(errors)
    validate_bloom_refuge_hub(errors)
    validate_refuge_ownership_and_loss_policy(errors)
    validate_production_save_slots_and_menu(errors)
    validate_campaign_lifecycle(errors)
    validate_layer_2_first_slice_and_backgrounds(errors)
    validate_combat_hud(errors)
    validate_ability_resources(errors)
    validate_weapon_resources(errors)
    validate_authored_equipment_materials(errors)

    required_files = {
        ROOT / "README.md",
        ROOT
        / "docs"
        / "CLEAN_MODULAR_MERGE_SUMMARY_2026-07-29.md",
        ROOT / "docs" / "MODULAR_ARCHITECTURE.md",
        ROOT / "docs" / "MODULAR_COMBAT_TEST_CHECKLIST.md",
        ROOT / "scenes" / "main" / "main.tscn",
        ROOT / "scenes" / "battle" / "combat_encounter.tscn",
        ROOT / "data" / "items" / "layer_1_2_item_catalog.tres",
        ROOT / "data" / "items" / "item_sprite_manifest.json",
        ROOT / "data" / "rooms" / "layer_1_2_room_catalog.tres",
        ROOT / "docs" / "ITEM_SPRITE_LIBRARY_INTEGRATION_2026-08-21.md",
        ROOT / "docs" / "LAYER_1_2_ROOM_REGISTRY_2026-08-21.md",
        ROOT / "docs" / "LAYER_1_2_GENERATOR_ACTIVATION_2026-08-27.md",
        ROOT / "tests" / "test_combat_kernel.gd",
        ROOT / "tests" / "test_battle_flow.gd",
        ROOT / "tests" / "test_spatial_battle.gd",
        ROOT / "tests" / "test_spatial_combat.gd",
        ROOT / "tests" / "test_enemy_ai.gd",
        ROOT / "tests" / "test_ordinary_combat.gd",
        ROOT / "tests" / "test_board_interaction.gd",
        ROOT / "tests" / "test_grapple_foundation.gd",
        ROOT / "tests" / "test_grapple_move_reactions.gd",
        ROOT / "tests" / "test_item_system.gd",
        ROOT / "tests" / "test_canonical_item_ids.gd",
        ROOT / "tests" / "test_reward_sources.gd",
        ROOT / "tests" / "test_item_sprite_coverage.gd",
        ROOT / "tests" / "test_item_sprite_library.gd",
        ROOT / "tests" / "test_node_map.gd",
        ROOT / "tests" / "test_layer_room_registry.gd",
        ROOT / "tests" / "test_layer_generator_activation.gd",
        ROOT / "tests" / "test_opening_event_room_flow.gd",
        ROOT / "tests" / "test_dialogue_foundation.gd",
        ROOT / "tests" / "test_production_dialogue_authoring.gd",
        ROOT / "tests" / "test_milestone_15_pilot_a.gd",
        ROOT / "data" / "dialogue" / "production_dialogue_catalog.tres",
        ROOT
        / "docs"
        / "DIALOGUE_AND_CUTSCENE_PRODUCTION_AUTHORING_2026-08-30.md",
        ROOT / "tests" / "test_jailer_refuge_origin.gd",
        ROOT / "tests" / "test_bloom_refuge_hub.gd",
        ROOT / "tests" / "test_production_save_slots.gd",
        ROOT / "tests" / "test_active_run_safe_points.gd",
        ROOT / "tests" / "test_campaign_lifecycle.gd",
        ROOT / "tests" / "test_l1_l2_demo_flow.gd",
        ROOT / "docs" / "L1_JAILER_REVERSE_L2_DEMO_FLOW_2026-08-27.md",
        ROOT / "docs" / "LOOT_SOURCES_AND_REWARD_ROUTING_2026-08-28.md",
        ROOT / "scenes" / "app" / "application_root.tscn",
        ROOT / "scenes" / "menu" / "main_menu_screen.tscn",
        ROOT / "scripts" / "app" / "application_root.gd",
        ROOT / "scripts" / "menu" / "main_menu_screen.gd",
        ROOT / "scripts" / "save" / "campaign_save_slot_store.gd",
        ROOT / "scripts" / "save" / "user_settings_store.gd",
        ROOT / "docs" / "PRODUCTION_SAVE_SLOTS_AND_MAIN_MENU_2026-08-12.md",
        ROOT / "docs" / "BLOOM_REFUGE_HUB_AND_CAMPAIGN_BOUNDARY_2026-08-10.md",
        ROOT / "docs" / "REFUGE_OWNERSHIP_AND_RUN_RESOLUTION_2026-08-26.md",
        ROOT / "scripts" / "refuge" / "refuge_ownership_state.gd",
        ROOT / "docs" / "reference" / "vowbreaker_castle_exterior_concept.png",
        ROOT / "scenes" / "refuge" / "bloom_refuge_screen.tscn",
        ROOT / "scripts" / "refuge" / "campaign_save_store.gd",
        ROOT / "scripts" / "refuge" / "bloom_refuge_screen.gd",
        ROOT / "assets" / "backgrounds" / "layer_2" / "bloom_refuge_transformed.png",
        ROOT / "assets" / "backgrounds" / "layer_2" / "farthest_cell_pre_refuge.png",
        ROOT / "assets" / "backgrounds" / "layer_2" / "jailer_boss_room.png",
        ROOT / "data" / "dialogue" / "dialogue_foundation_test.tres",
        ROOT / "data" / "dialogue" / "layer2_refuge_origin.tres",
        ROOT
        / "data"
        / "dialogue"
        / "layer2_refuge_origin_from_upper_route.tres",
        ROOT / "data" / "battlers" / "enemies" / "jailer.tres",
        ROOT
        / "data"
        / "encounters"
        / "jailer_containment_landing_template.tres",
        ROOT / "data" / "enemy_ai" / "jailer_rulebook.tres",
        ROOT
        / "scenes"
        / "battle"
        / "battlefields"
        / "jailer_containment_landing_battlefield.tscn",
        ROOT
        / "docs"
        / "JAILER_FIRST_DEFEAT_AND_BLOOM_REFUGE_ORIGIN_2026-08-10.md",
        ROOT
        / "data"
        / "dialogue"
        / "layer1_seraphine_recruitment_prelude.tres",
        ROOT
        / "data"
        / "dialogue"
        / "layer1_seraphine_recruitment_aftermath.tres",
        ROOT
        / "scenes"
        / "exploration"
        / "story"
        / "seraphine_ruined_chapel_backdrop.tscn",
        ROOT
        / "scenes"
        / "exploration"
        / "components"
        / "exploration_hud.tscn",
        ROOT
        / "docs"
        / "EXPLORATION_DIALOGUE_FOUNDATION_2026-08-10.md",
        ROOT
        / "docs"
        / "LAYER_1_SOLO_OPENING_EVENT_ROOM_REGRESSION_MILESTONE_2026-08-10.md",
        ROOT
        / "docs"
        / "SERAPHINE_RUINED_CHAPEL_RECRUITMENT_2026-08-10.md",
        ROOT / "tests" / "test_heroine_kits.gd",
        ROOT / "tests" / "test_ability_resources.gd",
        ROOT / "tests" / "test_weapon_resources.gd",
        ROOT / "tests" / "test_refuge_salvage_recipes.gd",
        ROOT / "tests" / "test_weapon_techniques.gd",
        ROOT / "tests" / "test_layer_1_enemy_roster.gd",
        ROOT / "tests" / "test_combat_hud.gd",
        ROOT / "tests" / "test_reusable_merge.gd",
        ROOT / "tests" / "test_encounter_startup.gd",
        ROOT / "tests" / "test_battle_composition.gd",
        ROOT / "tests" / "test_battlefield_authoring.gd",
        ROOT / "tests" / "test_battler_visual_profiles.gd",
        ROOT
        / "data"
        / "presentation"
        / "battler_visual_profile_catalog.tres",
        ROOT
        / "docs"
        / "BATTLER_VISUAL_PROFILE_DATA_2026-08-30.md",
        ROOT / "docs" / "BATTLE_COMPOSITION_MILESTONE_2026-08-03.md",
        ROOT
        / "docs"
        / "VISUAL_BATTLEFIELD_AUTHORING_MILESTONE_2026-08-03.md",
        ROOT
        / "docs"
        / "BATTLEFIELD_PRESENTATION_LANGUAGE_2026-08-03.md",
        ROOT
        / "docs"
        / "REUSABLE_BATTLE_ROOM_AUTHORING_GUIDE_2026-08-03.md",
        ROOT
        / "docs"
        / "CONTEXTUAL_BATTLEFIELD_UI_CHECKPOINT_2026-08-03.md",
        ROOT
        / "docs"
        / "COMPACT_EDGE_COMBAT_HUD_CHECKPOINT_2026-08-04.md",
        ROOT
        / "assets"
        / "backgrounds"
        / "layer_1"
        / "opening_servant_corridor_battle.png",
        ROOT
        / "assets"
        / "backgrounds"
        / "layer_1"
        / "servant_dormitory_battle.png",
        ROOT
        / "assets"
        / "backgrounds"
        / "layer_1"
        / "service_stair_landing_battle.png",
        ROOT
        / "scenes"
        / "battle"
        / "battlefields"
        / "authoring_templates"
        / "servant_dormitory_authoring.tscn",
        ROOT
        / "scenes"
        / "battle"
        / "battlefields"
        / "authoring_templates"
        / "service_stair_landing_authoring.tscn",
        ROOT / "tools" / "run_regression_suite.py",
    }
    for required_file in sorted(required_files):
        if not required_file.is_file():
            errors.append(f"missing milestone file: {required_file}")

    if errors:
        print("Project validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        f"Project validation passed: {len(class_owners)} named GDScript classes."
    )
    return 0


def validate_battler_visual_profiles(errors: list[str]) -> None:
    catalog_path = (
        ROOT / "data" / "presentation" / "battler_visual_profile_catalog.tres"
    )
    runner_path = ROOT / "tools" / "run_regression_suite.py"
    combat_scene_path = ROOT / "scenes" / "battle" / "combat_encounter.tscn"
    marker_factory_path = (
        ROOT / "scripts" / "battle" / "presentation" / "battle_marker_factory.gd"
    )
    marker_path = (
        ROOT / "scripts" / "battle" / "presentation" / "battle_marker.gd"
    )
    coordinator_path = ROOT / "scripts" / "battle" / "encounter_coordinator.gd"
    intent_resolver_path = (
        ROOT
        / "scripts"
        / "data"
        / "presentation"
        / "battler_visual_intent_resolver.gd"
    )
    anchor_paths = (
        ROOT / "scripts" / "data" / "battlefield" / "anchor_definition.gd",
        ROOT / "scripts" / "data" / "battlefield" / "authored_anchor.gd",
    )
    schema_paths = (
        ROOT
        / "scripts"
        / "data"
        / "presentation"
        / "battler_visual_state_definition.gd",
        ROOT
        / "scripts"
        / "data"
        / "presentation"
        / "battler_visual_fallback_definition.gd",
        ROOT
        / "scripts"
        / "data"
        / "presentation"
        / "battler_grapple_visual_metadata.gd",
        ROOT
        / "scripts"
        / "data"
        / "presentation"
        / "battler_visual_profile.gd",
        ROOT
        / "scripts"
        / "data"
        / "presentation"
        / "battler_visual_profile_catalog.gd",
    )
    required_roster = {
        "lysandra",
        "mira",
        "seraphine",
        "hollow_servant",
        "knife_footman",
        "prayer_rag_novice",
        "corrupted_butler",
        "red_wax_acolyte",
        "blood_nun",
        "chain_thrall",
        "iron_masked_guard",
        "cell_slime",
        "chain_warden",
        "jailer",
    }
    profiled_roster = required_roster - {"chain_warden"}

    if catalog_path.is_file():
        catalog_text = catalog_path.read_text(encoding="utf-8")
        profile_ids = set(
            re.findall(r'^profile_id = &"([^"]+)"$', catalog_text, re.MULTILINE)
        )
        battler_ids = set(
            re.findall(r'^battler_id = &"([^"]+)"$', catalog_text, re.MULTILINE)
        )
        expected_profile_ids = {
            f"{battler_id}_visual" for battler_id in profiled_roster
        }
        if profile_ids != expected_profile_ids:
            errors.append(
                f"{catalog_path}: profile IDs do not match the thirteen curated sets"
            )
        if battler_ids != profiled_roster:
            errors.append(
                f"{catalog_path}: profiled battler IDs do not match curated coverage"
            )
        required_line = next(
            (
                line
                for line in catalog_text.splitlines()
                if line.startswith("required_battler_ids = ")
            ),
            "",
        )
        if set(re.findall(r'&"([^"]+)"', required_line)) != required_roster:
            errors.append(f"{catalog_path}: required visual roster is incomplete")
        marker_line = next(
            (
                line
                for line in catalog_text.splitlines()
                if line.startswith("allowed_marker_only_battler_ids = ")
            ),
            "",
        )
        if re.findall(r'&"([^"]+)"', marker_line) != ["chain_warden"]:
            errors.append(
                f"{catalog_path}: only Chain Warden may be marker-only"
            )
        texture_paths = re.findall(
            r'path="res://([^"]+\.png)"',
            catalog_text,
        )
        if len(texture_paths) != 162 or len(set(texture_paths)) != 162:
            errors.append(
                f"{catalog_path}: expected 162 unique curated pose textures"
            )
        for texture_path in texture_paths:
            if not (ROOT / texture_path).is_file():
                errors.append(
                    f"{catalog_path}: missing curated texture res://{texture_path}"
                )

    forbidden_profile_fields = (
        "connected_anchor_ids",
        "position_contacts",
        "capacity",
        "cover",
        "line_of_sight",
        "path_blocks",
        "terrain_lines",
    )
    for schema_path in schema_paths:
        if not schema_path.is_file():
            continue
        schema_text = schema_path.read_text(encoding="utf-8")
        for field_name in forbidden_profile_fields:
            if re.search(rf"@export\s+var\s+{field_name}\b", schema_text):
                errors.append(
                    f"{schema_path}: visual profiles must not define gameplay "
                    f"field {field_name}"
                )

    for anchor_path in anchor_paths:
        if not anchor_path.is_file():
            continue
        anchor_text = anchor_path.read_text(encoding="utf-8")
        for required_fragment in (
            "visual_depth_band",
            "visual_orientation",
            "bounded_y_sort_within_band",
        ):
            if required_fragment not in anchor_text:
                errors.append(
                    f"{anchor_path}: missing presentation intent {required_fragment}"
                )

    runtime_fragments = {
        combat_scene_path: (
            "battler_visual_profile_catalog.tres",
            "CombatStagePresenter",
            "combat_stage_catalog.tres",
        ),
        marker_factory_path: ("visual_profile_catalog",),
        marker_path: (
            "POSE_CROSSFADE_SECONDS",
            "fade_character_art_to",
        ),
        coordinator_path: (
            "MOVE_STEP_FADE_OUT_SECONDS",
            "_resolve_battler_visual_orientation",
            "_refresh_battler_marker_orientations",
        ),
        intent_resolver_path: (
            "EVENT_HOLD_SECONDS",
            "orientation_toward_opponent",
        ),
    }
    for runtime_path, fragments in runtime_fragments.items():
        if not runtime_path.is_file():
            continue
        runtime_text = runtime_path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in runtime_text:
                errors.append(
                    f"{runtime_path}: Milestone 14 renderer is missing {fragment}"
                )
    if (
        runner_path.is_file()
        and '"tests/test_battler_visual_profiles.gd"'
        not in runner_path.read_text(encoding="utf-8")
    ):
        errors.append(
            f"{runner_path}: battler visual profile regression is not registered"
        )

    stage_catalog_path = (
        ROOT / "data" / "presentation" / "combat_stage_catalog.tres"
    )
    milestone_14_files = (
        stage_catalog_path,
        ROOT
        / "scripts"
        / "battle"
        / "presentation"
        / "combat_stage_presenter.gd",
        ROOT
        / "scripts"
        / "data"
        / "presentation"
        / "exploration_stage_trigger_state.gd",
        ROOT / "tests" / "test_static_png_combat_presentation.gd",
        ROOT / "tests" / "test_combat_stage_triggers.gd",
    )
    for required_path in milestone_14_files:
        if not required_path.is_file():
            errors.append(f"missing Milestone 14 presentation file: {required_path}")
    if stage_catalog_path.is_file():
        stage_text = stage_catalog_path.read_text(encoding="utf-8")
        if len(re.findall(r'^stage_id = &"', stage_text, re.MULTILINE)) != 7:
            errors.append(f"{stage_catalog_path}: expected seven active stage variants")
        if len(re.findall(r'^binding_id = &"', stage_text, re.MULTILINE)) != 7:
            errors.append(f"{stage_catalog_path}: expected seven reachable bindings")
        reviewed_assets = (
            "l01_room_opening_servant_corridor.png",
            "l01_room_ruined_chapel.png",
            "l01_room_blood_nun_processing_chapel.png",
            "l02_room_jailers_containment_hall.png",
            "l01_prop_pew_long.png",
            "l02_prop_divider_iron_long.png",
        )
        for asset_name in reviewed_assets:
            if asset_name not in stage_text:
                errors.append(
                    f"{stage_catalog_path}: missing reviewed asset {asset_name}"
                )
        if "experimental_foreground_enabled = true" in stage_text:
            errors.append(
                f"{stage_catalog_path}: experimental foreground must stay disabled"
            )
    if runner_path.is_file():
        runner_text = runner_path.read_text(encoding="utf-8")
        for test_name in (
            '"tests/test_static_png_combat_presentation.gd"',
            '"tests/test_combat_stage_triggers.gd"',
        ):
            if test_name not in runner_text:
                errors.append(f"{runner_path}: missing Milestone 14 test {test_name}")


def validate_milestone_15_pilot_a(errors: list[str]) -> None:
    required_paths = (
        ROOT / "data" / "encounters" / "dining_service_hall_template.tres",
        ROOT
        / "data"
        / "exploration"
        / "rooms"
        / "layer1"
        / "dining_service_hall.tres",
        ROOT
        / "data"
        / "exploration"
        / "rooms"
        / "layer1"
        / "bell_pull_gallery.tres",
        ROOT
        / "data"
        / "dialogue"
        / "layer1_bell_pull_gallery_observation.tres",
        ROOT
        / "scenes"
        / "battle"
        / "battlefields"
        / "dining_service_hall_battlefield.tscn",
        ROOT
        / "scenes"
        / "exploration"
        / "rooms"
        / "layer1"
        / "dining_service_hall.tscn",
        ROOT
        / "scenes"
        / "exploration"
        / "rooms"
        / "layer1"
        / "bell_pull_gallery.tscn",
        ROOT
        / "scripts"
        / "exploration"
        / "interactions"
        / "room_encounter_hotspot.gd",
        ROOT / "tests" / "test_milestone_15_pilot_a.gd",
    )
    for path in required_paths:
        if not path.is_file():
            errors.append(f"missing Milestone 15 Pilot A file: {path}")

    contracts = {
        ROOT / "scripts" / "map" / "layer_map_generator.gd": (
            '&"dining_service_hall"',
            '&"layer_1_dining_service_hall"',
            '&"dining_service_hall_regular"',
            'room_catalog.get_room(\n\t\t&"lower_kitchen"',
            'first_node.encounter_template_id = &"lower_kitchen_regular"',
        ),
        ROOT / "scripts" / "map" / "run_state.gd": (
            "DINING_SERVICE_HALL_TEMPLATE",
            'return [&"hollow_servant", &"knife_footman"]',
            "node.has_encounter_content()",
        ),
        ROOT / "scripts" / "map" / "main_controller.gd": (
            "room_encounter_requested.connect(",
            "_on_event_room_encounter_requested",
            "target.requires_event_room()",
            'requested_trigger_type == &"interaction"',
        ),
        ROOT / "scripts" / "exploration" / "event_room_screen.gd": (
            "signal room_encounter_requested(trigger_id: StringName)",
            "func set_room_encounter_resolved(",
            "ROOM_ENCOUNTER_HOTSPOT_SCRIPT",
        ),
        ROOT / "data" / "presentation" / "combat_stage_catalog.tres": (
            'stage_id = &"dining_service_hall_stage"',
            'binding_id = &"dining_service_hall_battle_binding"',
            'trigger_type = &"interaction"',
            "l01_room_dining_service_hall.png",
        ),
        ROOT / "data" / "exploration" / "rooms" / "event_room_catalog.tres": (
            "dining_service_hall.tres",
            "bell_pull_gallery.tres",
        ),
        ROOT / "data" / "dialogue" / "layer1_bell_pull_gallery_observation.tres": (
            'trigger_id = &"bell_pull_gallery"',
            'completion_kind = &"resolved_interaction"',
            "cords move without visible hands",
        ),
        ROOT / "tools" / "run_regression_suite.py": (
            '"tests/test_milestone_15_pilot_a.gd"',
        ),
    }
    for path, fragments in contracts.items():
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{path}: missing Pilot A contract {fragment}")


def validate_bloom_refuge_hub(errors: list[str]) -> None:
    contracts = {
        ROOT / "scripts" / "map" / "run_state.gd": (
            "func make_refuge_campaign_snapshot(",
            "func restore_refuge_campaign_snapshot(",
            "func begin_next_layer_2_run(",
            "func apply_post_refuge_defeat(",
            "bloom = 0",
        ),
        ROOT / "scripts" / "map" / "layer_map_generator.gd": (
            "func generate_layer_2_run(",
            '&"l2_refuge_farthest_cell"',
            '&"l2_jailer_first_encounter"',
        ),
        ROOT / "scripts" / "map" / "main_controller.gd": (
            "CampaignSaveSlotStore.save_refuge_slot(",
            "CampaignSaveSlotStore.restore_envelope(",
            "_show_refuge_hub(",
            "_return_failed_run_to_refuge()",
            "_on_refuge_start_new_story_requested(",
        ),
        ROOT / "scripts" / "refuge" / "bloom_refuge_screen.gd": (
            "signal begin_layer_2_run_requested(run_seed: int)",
            "signal start_new_story_requested(run_seed: int)",
            "%StartNewStory",
        ),
        ROOT / "save_test" / "persistence" / "knowledge_state.gd": (
            'const SAVE_PATH: String = "user://',
            "func to_snapshot(",
            "func restore_from_snapshot(",
        ),
    }
    for path, fragments in contracts.items():
        if not path.is_file():
            errors.append(f"missing Bloom Refuge lifecycle file: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{path}: missing Bloom Refuge contract {fragment}")


def validate_refuge_ownership_and_loss_policy(errors: list[str]) -> None:
    contracts = {
        ROOT / "scripts" / "refuge" / "refuge_ownership_state.gd": (
            "class_name RefugeOwnershipState",
            "const PREPARATION_SLOT_COUNT: int = 15",
            "var selected_party_ids: Array[StringName]",
            "var preparation_slots_by_heroine: Dictionary",
            "var equipment_loadouts_by_heroine: Dictionary",
            "var memento_slots_by_heroine: Dictionary",
            "var stash_item_stacks: Array[Dictionary]",
            "var stash_equipment_instances: Dictionary",
            "var key_chain: Dictionary",
            "var banked_materials: Dictionary",
            "func restore_from_snapshot(",
            "func make_run_start_transfer(",
            "func make_run_return_transfer(",
            "func withdraw_banked_material_to_run(",
        ),
        ROOT / "scripts" / "map" / "run_state.gd": (
            "var refuge_ownership: RefugeOwnershipState",
            "func ensure_refuge_ownership_initialized(",
            "func make_refuge_ownership_snapshot(",
            "func apply_restored_refuge_ownership(",
            "refuge_ownership.make_run_start_transfer(",
            "refuge_ownership.make_run_return_transfer(",
        ),
        ROOT / "scripts" / "data" / "items" / "item_definition.gd": (
            "enum KeyPersistenceScope {",
            "RUN_ONLY",
            "PERSISTENT_REFUGE",
            "@export var key_persistence_scope: KeyPersistenceScope",
        ),
        ROOT / "tests" / "test_bloom_refuge_hub.gd": (
            "func _test_refuge_ownership_moves_and_stash_safety(",
            "func _test_defeat_loss_policy(",
            "func _test_material_banking_is_one_way(",
        ),
        ROOT / "tests" / "test_production_save_slots.gd": (
            "func _test_empty_refuge_snapshot_compatibility(",
            "source.make_refuge_ownership_snapshot()",
        ),
    }
    for path, fragments in contracts.items():
        if not path.is_file():
            errors.append(f"missing Milestone 5 ownership file: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(
                    f"{path}: missing Milestone 5 ownership contract "
                    f"{fragment.rstrip('(')}"
                )

    for key_path in (
        ROOT / "data" / "items" / "keys" / "rusty_key.tres",
        ROOT / "data" / "items" / "layer_1" / "ledger_seal.tres",
        ROOT / "data" / "items" / "layer_2" / "guiltless_key.tres",
    ):
        if not key_path.is_file():
            errors.append(f"missing authored Key definition: {key_path}")
            continue
        key_text = key_path.read_text(encoding="utf-8")
        if "key_persistence_scope = 0" not in key_text:
            errors.append(
                f"{key_path}: registered Key lacks explicit run-only "
                "persistence metadata"
            )


def validate_production_save_slots_and_menu(errors: list[str]) -> None:
    contracts = {
        ROOT / "scripts" / "save" / "campaign_save_slot_store.gd": (
            "const SLOT_COUNT: int = 3",
            "const INCOMPATIBLE_VERSION_ERROR: String",
            "func save_refuge_slot(",
            "func save_active_run_slot(",
            "func clear_active_run_snapshot(",
            "func make_v3_envelope(",
            "func validate_envelope(",
            "func restore_envelope(",
            "func read_document_for_load(",
            "func delete_slot(",
            "func get_unsupported_legacy_save_warning(",
            '"save_version": CampaignSaveStore.SAVE_VERSION',
            '"campaign_snapshot": campaign_snapshot.duplicate(true)',
            '"refuge_snapshot": refuge_snapshot.duplicate(true)',
            '"active_run_snapshot": (',
            "DirAccess.rename_absolute(",
            "get_backup_path(",
        ),
        ROOT / "scripts" / "refuge" / "campaign_save_store.gd": (
            "const SAVE_VERSION: int = 3",
            "func make_campaign_snapshot(",
            "func restore_campaign_snapshot(",
            "LEGACY_ITEM_ID_MIGRATIONS",
        ),
        ROOT / "scripts" / "app" / "application_root.gd": (
            "func _on_new_campaign_requested(",
            "func _on_load_requested(",
            "func _return_to_main_menu(",
        ),
        ROOT / "scripts" / "menu" / "main_menu_screen.gd": (
            "signal continue_requested(slot_id: int)",
            "signal new_campaign_requested(slot_id: int, campaign_seed: int)",
            "signal delete_slot_requested(slot_id: int)",
        ),
        ROOT / "scripts" / "map" / "main_controller.gd": (
            "func start_new_campaign(",
            "func load_campaign_slot(",
            "func continue_active_run_slot(",
            "func _save_active_refuge(",
            "func _save_active_run_safe_point(",
        ),
    }
    for path, fragments in contracts.items():
        if not path.is_file():
            errors.append(f"missing production persistence file: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(
                    f"{path}: missing production persistence contract "
                    f"{fragment}"
                )


def validate_campaign_lifecycle(errors: list[str]) -> None:
    contracts = {
        ROOT / "scripts" / "map" / "campaign_lifecycle_state.gd": (
            "TUTORIAL_PRE_REFUGE",
            "REFUGELESS_ASCENT",
            "REFUGE_RUN",
            "CAMPAIGN_COMPLETE",
            "tutorial_layer_1_seed",
            "refugeless_world_seed",
            "active_run_seed",
            "combat_sequence_index",
            "defeated_boss_ids",
        ),
        ROOT / "scripts" / "map" / "run_state.gd": (
            "func apply_jailer_victory(",
            "func is_at_refugeless_farthest_cell(",
            "func establish_refuge_at_farthest_cell(",
            "func apply_refugeless_defeat_and_refuge_origin(",
            "func no_refuge_ending_is_eligible(",
            "func has_defeated_boss(",
            'campaign_lifecycle.mark_boss_defeated(BLOOD_NUN_BOSS_ID)',
        ),
        ROOT / "scripts" / "map" / "main_controller.gd": (
            "run_state.is_refugeless_ascent()",
            "run_state.apply_jailer_victory(",
            "generator.generate_refugeless_reverse_layer_2(",
            "UPPER_ROUTE_REFUGE_ORIGIN_DIALOGUE_ID",
        ),
    }
    for path, fragments in contracts.items():
        if not path.is_file():
            errors.append(f"missing campaign lifecycle file: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{path}: missing campaign lifecycle contract {fragment}")


def validate_position_contact_editor_contract(errors: list[str]) -> None:
    path = (
        ROOT
        / "scripts"
        / "data"
        / "battlefield"
        / "position_contact_definition.gd"
    )
    if not path.is_file():
        errors.append(f"missing Position contact Resource script: {path}")
        return
    text = path.read_text(encoding="utf-8")
    if re.search(r"^\s*@tool\b", text) is None:
        errors.append(
            f"{path}: must use @tool because AuthoredBattlefield calls its "
            "methods during editor-time scene validation"
        )


def validate_opening_event_room_flow(errors: list[str]) -> None:
    run_state = ROOT / "scripts" / "map" / "run_state.gd"
    main_controller = ROOT / "scripts" / "map" / "main_controller.gd"
    hud = (
        ROOT
        / "scripts"
        / "battle"
        / "presentation"
        / "reusable"
        / "reusable_combat_hud.gd"
    )
    exploration_hud = (
        ROOT / "scripts" / "exploration" / "ui" / "exploration_hud.gd"
    )
    event_screen = ROOT / "scripts" / "exploration" / "event_room_screen.gd"
    opening_template = (
        ROOT / "data" / "encounters" / "opening_servant_corridor.tres"
    )
    for path in (
        run_state,
        main_controller,
        hud,
        exploration_hud,
        event_screen,
        opening_template,
    ):
        if not path.is_file():
            errors.append(f"missing Layer 1 opening integration file: {path}")
            return

    run_text = run_state.read_text(encoding="utf-8")
    main_text = main_controller.read_text(encoding="utf-8")
    hud_text = hud.read_text(encoding="utf-8")
    exploration_hud_text = exploration_hud.read_text(encoding="utf-8")
    event_screen_text = event_screen.read_text(encoding="utf-8")
    template_text = opening_template.read_text(encoding="utf-8")

    for fragment in (
        'definition.party_ids = [&"lysandra"]',
        'definition.enemy_ids = [&"hollow_servant"]',
        "func apply_opening_encounter_outcome(",
        "or not opening_completed",
    ):
        if fragment not in run_text:
            errors.append(
                f"{run_state}: missing canonical opening contract {fragment}"
            )
    for fragment in (
        "_launch_opening_battle()",
        '"Return to the Beginning"',
        "run_state.apply_opening_encounter_outcome(",
        "_restart_failed_run_from_beginning()",
    ):
        if fragment not in main_text:
            errors.append(
                f"{main_controller}: missing opening lifecycle {fragment}"
            )
    if "func set_active_party_ids(" not in hud_text:
        errors.append(f"{hud}: combat HUD is not solo-party aware")
    for fragment in (
        "func set_active_party_ids(",
        "party_strip.offset_top = party_strip.offset_bottom - content_height",
    ):
        if fragment not in exploration_hud_text:
            errors.append(
                f"{exploration_hud}: exploration Party Strip does not reflow: "
                f"{fragment}"
            )
    if "exploration_hud.set_active_party_ids(current_party_ids)" not in event_screen_text:
        errors.append(
            f"{event_screen}: current party is not handed to the adaptive Party Strip"
        )
    for fragment in (
        'if outcome.result == EncounterOutcome.Result.DEFEAT:',
        'return_to_map_button.text = "Return to the Beginning"',
        'if pending_outcome.result == EncounterOutcome.Result.DEFEAT:',
    ):
        if fragment not in main_text:
            errors.append(
                f"{main_controller}: generic full-wipe restart is missing {fragment}"
            )
    if 'template_id = &"opening_servant_corridor_opening"' not in template_text:
        errors.append(
            f"{opening_template}: missing registered corridor template id"
        )


def validate_dialogue_foundation(errors: list[str]) -> None:
    event_scene = ROOT / "scenes" / "exploration" / "event_room_screen.tscn"
    event_script = ROOT / "scripts" / "exploration" / "event_room_screen.gd"
    hud_scene = (
        ROOT
        / "scenes"
        / "exploration"
        / "components"
        / "exploration_hud.tscn"
    )
    run_state = ROOT / "scripts" / "map" / "run_state.gd"
    test_dialogue = ROOT / "data" / "dialogue" / "dialogue_foundation_test.tres"
    suite = ROOT / "tools" / "run_regression_suite.py"
    for path in (
        event_scene,
        event_script,
        hud_scene,
        run_state,
        test_dialogue,
        suite,
    ):
        if not path.is_file():
            errors.append(f"missing dialogue-foundation file: {path}")
            return

    scene_text = event_scene.read_text(encoding="utf-8")
    event_text = event_script.read_text(encoding="utf-8")
    hud_text = hud_scene.read_text(encoding="utf-8")
    run_text = run_state.read_text(encoding="utf-8")
    dialogue_text = test_dialogue.read_text(encoding="utf-8")
    suite_text = suite.read_text(encoding="utf-8")

    for fragment in (
        "exploration_hud.tscn",
        'node name="ExplorationHUD"',
    ):
        if fragment not in scene_text:
            errors.append(f"{event_scene}: missing shared HUD contract {fragment}")
    for fragment in (
        'node name="PartyStrip"',
        'node name="ItemBar"',
        'node name="ExplorationCommandBar"',
        'node name="DialoguePanel"',
    ):
        if fragment not in hud_text:
            errors.append(f"{hud_scene}: missing exploration HUD node {fragment}")
    for fragment in (
        "func start_dialogue(",
        "func _set_room_interactions_enabled(",
        "suspended_interaction_states",
        "room_lock.get_exit_hotspot() == room_exit",
        "dialogue_result_snapshots",
        "narrative_context_snapshot",
    ):
        if fragment not in event_text:
            errors.append(f"{event_script}: missing dialogue lifecycle {fragment}")
    if "var narrative_state: NarrativeState" not in run_text:
        errors.append(f"{run_state}: missing scoped narrative state")
    dialogue_runner = ROOT / "scripts" / "dialogue" / "dialogue_runner.gd"
    dialogue_node = (
        ROOT
        / "scripts"
        / "data"
        / "dialogue"
        / "dialogue_node_definition.gd"
    )
    for path, fragments in (
        (
            dialogue_runner,
            (
                "consume_pending_transition_result",
                "_enter_current_node_and_resolve_automatic_transitions",
            ),
        ),
        (
            dialogue_node,
            ("entry_outcomes", "automatic_transitions"),
        ),
    ):
        if not path.is_file():
            errors.append(f"missing extended dialogue-flow file: {path}")
            continue
        path_text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in path_text:
                errors.append(
                    f"{path}: missing extended dialogue-flow contract {fragment}"
                )
    for fragment in (
        'dialogue_id = &"dialogue_foundation_test"',
        'subject_id = &"mira"',
        'item_id = &"l01_warm_wine_flask"',
        'next_node_id = &"rejoin"',
    ):
        if fragment not in dialogue_text:
            errors.append(f"{test_dialogue}: missing test graph contract {fragment}")
    if '"tests/test_dialogue_foundation.gd"' not in suite_text:
        errors.append(f"{suite}: dialogue regression is not registered")


def validate_production_dialogue_authoring(errors: list[str]) -> None:
    dialogue_dir = ROOT / "data" / "dialogue"
    catalog = dialogue_dir / "production_dialogue_catalog.tres"
    suite = ROOT / "tools" / "run_regression_suite.py"
    focused_test = ROOT / "tests" / "test_production_dialogue_authoring.gd"
    expected_graphs = {
        "layer1_mira_recruitment_aftermath.tres",
        "layer1_seraphine_recruitment_prelude.tres",
        "layer1_seraphine_recruitment_aftermath.tres",
        "layer1_blood_nun_aftermath.tres",
        "layer2_refuge_origin.tres",
        "layer2_refuge_origin_from_upper_route.tres",
        "layer2_jailer_victory_aftermath.tres",
        "layer2_farthest_cell_refuge_establishment.tres",
        "layer1_wine_cellar_observation.tres",
        "layer1_butlers_office_observation.tres",
        "layer1_bell_pull_gallery_observation.tres",
    }
    for path in (catalog, suite, focused_test):
        if not path.is_file():
            errors.append(f"missing production dialogue authoring file: {path}")
            return

    catalog_text = catalog.read_text(encoding="utf-8")
    curated_character_graphs = {
        "layer1_seraphine_recruitment_prelude.tres",
        "layer1_seraphine_recruitment_aftermath.tres",
        "layer1_blood_nun_aftermath.tres",
        "layer2_refuge_origin.tres",
        "layer2_refuge_origin_from_upper_route.tres",
    }
    for graph_name in sorted(expected_graphs):
        if graph_name not in catalog_text:
            errors.append(f"{catalog}: missing production graph {graph_name}")
            continue
        graph_path = dialogue_dir / graph_name
        if not graph_path.is_file():
            errors.append(f"missing production dialogue graph: {graph_path}")
            continue
        graph_text = graph_path.read_text(encoding="utf-8")
        for field in (
            "dialogue_id = &",
            "start_node_id = &",
            "trigger_kind = &",
            "trigger_id = &",
            "completion_kind = &",
            "completion_id = &",
        ):
            if field not in graph_text:
                errors.append(f"{graph_path}: missing authoring field {field}")
        if graph_name in curated_character_graphs:
            if "assets/characters/heroines/" in graph_text:
                errors.append(
                    f"{graph_path}: active graph still uses temporary heroine art"
                )
            if "assets/characters/curated/" not in graph_text:
                errors.append(
                    f"{graph_path}: active graph lacks curated character art"
                )

    room_bindings = {
        ROOT
        / "data"
        / "exploration"
        / "rooms"
        / "layer1"
        / "wine_cellar_warm_bottles.tres": "layer1_wine_cellar_observation.tres",
        ROOT
        / "data"
        / "exploration"
        / "rooms"
        / "layer1"
        / "butlers_office.tres": "layer1_butlers_office_observation.tres",
        ROOT
        / "data"
        / "exploration"
        / "rooms"
        / "layer1"
        / "bell_pull_gallery.tres": "layer1_bell_pull_gallery_observation.tres",
    }
    for room_path, graph_name in room_bindings.items():
        if not room_path.is_file() or graph_name not in room_path.read_text(
            encoding="utf-8"
        ):
            errors.append(f"{room_path}: missing entry dialogue {graph_name}")
    if '"tests/test_production_dialogue_authoring.gd"' not in suite.read_text(
        encoding="utf-8"
    ):
        errors.append(f"{suite}: production dialogue regression is not registered")


def validate_mira_recruitment(errors: list[str]) -> None:
    run_state = ROOT / "scripts" / "map" / "run_state.gd"
    main_controller = ROOT / "scripts" / "map" / "main_controller.gd"
    event_screen = ROOT / "scripts" / "exploration" / "event_room_screen.gd"
    dialogue = (
        ROOT
        / "data"
        / "dialogue"
        / "layer1_mira_recruitment_aftermath.tres"
    )
    dialogue_definition = (
        ROOT / "scripts" / "data" / "dialogue" / "dialogue_definition.gd"
    )
    battle_script = ROOT / "scripts" / "battle" / "encounter_coordinator.gd"
    for path in (
        run_state,
        main_controller,
        event_screen,
        dialogue,
        dialogue_definition,
        battle_script,
    ):
        if not path.is_file():
            errors.append(f"missing Mira recruitment integration file: {path}")
            return

    contracts = {
        run_state: (
            "MIRA_RECRUITMENT_ENCOUNTER_ID",
            'definition.party_ids.append(&"mira")',
            "func apply_mira_recruitment_aftermath(",
        ),
        main_controller: (
            '"Speak with Mira"',
            "_launch_mira_recruitment_aftermath()",
            "apply_mira_recruitment_aftermath(",
            "_resolve_story_background(",
        ),
        event_screen: (
            "func prepare_story_dialogue(",
            "story_dialogue_outcome_ready.emit(outcome)",
        ),
        dialogue: (
            'dialogue_id = &"layer_1_mira_recruitment_aftermath"',
            'subject_id = &"mira"',
            "You are either very brave or very lost.",
        ),
        dialogue_definition: ("background_override",),
        battle_script: ("func get_scene_background_texture(",),
    }
    for path, fragments in contracts.items():
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{path}: missing Mira recruitment contract {fragment}")


def validate_seraphine_recruitment(errors: list[str]) -> None:
    generator = ROOT / "scripts" / "map" / "layer_map_generator.gd"
    run_state = ROOT / "scripts" / "map" / "run_state.gd"
    main_controller = ROOT / "scripts" / "map" / "main_controller.gd"
    main_scene = ROOT / "scenes" / "main" / "main.tscn"
    prelude = (
        ROOT
        / "data"
        / "dialogue"
        / "layer1_seraphine_recruitment_prelude.tres"
    )
    aftermath = (
        ROOT
        / "data"
        / "dialogue"
        / "layer1_seraphine_recruitment_aftermath.tres"
    )
    for path in (
        generator,
        run_state,
        main_controller,
        main_scene,
        prelude,
        aftermath,
    ):
        if not path.is_file():
            errors.append(
                f"missing Seraphine recruitment integration file: {path}"
            )
            return

    contracts = {
        generator: (
            "SERAPHINE_RECRUITMENT_ENCOUNTER_ID",
            '"Ruined Chapel — False Prayer"',
            '&"l1_c5_n0"',
            '&"ruined_chapel"',
        ),
        run_state: (
            "SERAPHINE_RECRUITMENT_PRELUDE_STORY_ID",
            "SERAPHINE_RECRUITMENT_AFTERMATH_STORY_ID",
            'definition.party_ids.append(&"seraphine")',
            "func apply_seraphine_recruitment_prelude(",
            "func apply_seraphine_recruitment_aftermath(",
            "func make_full_wipe_recovery_narrative_snapshot(",
        ),
        main_controller: (
            "_launch_seraphine_recruitment_prelude()",
            '"Speak with Seraphine"',
            "_launch_seraphine_recruitment_aftermath()",
        ),
        main_scene: (
			"production_dialogue_catalog.tres",
        ),
        prelude: (
            'dialogue_id = &"layer_1_seraphine_recruitment_prelude"',
            'transition_id = &"seraphine_arrival_with_mira"',
            "This place remembers prayer, but not mercy.",
        ),
        aftermath: (
            'dialogue_id = &"layer_1_seraphine_recruitment_aftermath"',
            'subject_id = &"seraphine"',
            'subject_id = &"layer_1_seraphine_recruitment"',
        ),
    }
    for path, fragments in contracts.items():
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(
                    f"{path}: missing Seraphine recruitment contract {fragment}"
                )


def validate_wipe_narrative_state_recovery(errors: list[str]) -> None:
    narrative_state = (
        ROOT / "scripts" / "dialogue" / "narrative_state.gd"
    )
    run_state = ROOT / "scripts" / "map" / "run_state.gd"
    main_controller = ROOT / "scripts" / "map" / "main_controller.gd"
    flow_test = ROOT / "tests" / "test_opening_event_room_flow.gd"
    contracts = {
        narrative_state: (
			"func restore_from_snapshot(",
            "Commit only after the entire snapshot has been validated.",
        ),
        run_state: (
            "if narrative_state == null:",
            "narrative_state.restore_from_snapshot(",
            "func get_narrative_state_snapshot() -> Dictionary:",
        ),
        main_controller: (
            "run_state.get_narrative_state_snapshot()",
            '"The run narrative state is unavailable."',
        ),
        flow_test: (
            "Reusing RunState after a wipe must restore a live three-heroine narrative state.",
            "Butler's Office must load after a wipe",
        ),
    }
    for path, fragments in contracts.items():
        if not path.is_file():
            errors.append(
                f"missing wipe narrative-state recovery file: {path}"
            )
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(
                    f"{path}: missing wipe recovery contract {fragment}"
                )

    if main_controller.is_file() and (
        "run_state.narrative_state.to_snapshot()"
        in main_controller.read_text(encoding="utf-8")
    ):
        errors.append(
            f"{main_controller}: UI launchers must use the guarded narrative snapshot API"
        )


def validate_weapon_resources(errors: list[str]) -> None:
    required = {
        ROOT / "scripts" / "data" / "weapon_definition.gd",
        ROOT
        / "scripts"
        / "data"
        / "weapons"
        / "weapon_family_definition.gd",
        ROOT
        / "scripts"
        / "data"
        / "weapons"
        / "weapon_rank_definition.gd",
        ROOT / "data" / "weapon_families" / "sword.tres",
        ROOT / "data" / "weapon_families" / "dagger.tres",
        ROOT / "data" / "weapon_families" / "staff.tres",
        ROOT / "data" / "abilities" / "weapon_technique_catalog.tres",
        ROOT
        / "scripts"
        / "progression"
        / "heroine_progression_state.gd",
        ROOT
        / "docs"
        / "WEAPON_FAMILY_RANK_RESOURCE_MIGRATION_2026-07-30.md",
        ROOT
        / "docs"
        / "WEAPON_TECHNIQUES_AND_PROGRESSION_2026-08-03.md",
        ROOT
        / "docs"
        / "WEAPON_ARTS_MP_REBALANCE_2026-08-03.md",
        ROOT
        / "docs"
        / "KNIFE_DANCE_SINGLE_TARGET_FIX_2026-08-03.md",
        ROOT
        / "docs"
        / "EQUIPMENT_INSTANCES_AND_PERSONAL_LOADOUTS_2026-08-26.md",
        ROOT / "scripts" / "data" / "equipment_definition.gd",
        ROOT / "scripts" / "data" / "equipment_loadout.gd",
        ROOT / "scripts" / "map" / "equipment_instance.gd",
        ROOT
        / "scripts"
        / "map"
        / "personal_equipment_loadout_state.gd",
        ROOT / "scripts" / "map" / "run_equipment_state.gd",
        ROOT / "scripts" / "data" / "equipment_catalog_definition.gd",
        ROOT / "scripts" / "data" / "items" / "material_definition.gd",
        ROOT / "scripts" / "data" / "items" / "material_catalog_definition.gd",
        ROOT / "scripts" / "data" / "refuge_recipe_definition.gd",
        ROOT / "scripts" / "data" / "refuge_recipe_catalog_definition.gd",
        ROOT / "data" / "equipment" / "layer_1_2_equipment_catalog.tres",
        ROOT / "data" / "materials" / "layer_1_2_material_catalog.tres",
        ROOT / "data" / "refuge" / "refuge_recipe_catalog.tres",
        ROOT / "docs" / "AUTHORED_EQUIPMENT_MATERIALS_SALVAGE_RECIPES_2026-08-28.md",
    }
    for path in sorted(required):
        if not path.is_file():
            errors.append(
                f"missing weapon Resource architecture file: {path}"
            )

    technique_root = ROOT / "data" / "abilities" / "weapon_techniques"
    expected_techniques = {
        "forced_blade.tres": 'required_weapon_family_id = &"sword"',
        "knife_dance.tres": 'required_weapon_family_id = &"dagger"',
        "jaw_break.tres": 'required_weapon_family_id = &"staff"',
    }
    for filename, family_line in expected_techniques.items():
        path = technique_root / filename
        if not path.is_file():
            errors.append(f"missing initial weapon technique: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for required_line in (
            family_line,
            "requires_progression_unlock = true",
            "uses_equipped_weapon_attack_profile = true",
            "action_cost = 1",
            "mp_cost = 2",
            "dice_modifier = 0",
        ):
            if required_line not in text:
                errors.append(
                    f"{path}: missing technique contract {required_line}"
                )

    for family_id, technique_path in (
        ("sword", "forced_blade.tres"),
        ("dagger", "knife_dance.tres"),
        ("staff", "jaw_break.tres"),
    ):
        family_path = ROOT / "data" / "weapon_families" / f"{family_id}.tres"
        if family_path.is_file() and technique_path not in family_path.read_text(
            encoding="utf-8"
        ):
            errors.append(
                f"{family_path}: missing compatible technique {technique_path}"
            )

    focused_contracts = {
        technique_root / "forced_blade.tres": (
            "forced_blade_dodge_1.tres",
            "flat_damage_1.tres",
        ),
        technique_root / "knife_dance.tres": (
            "required_target_count = 2",
            "allows_fewer_targets_when_unavailable = true",
            "flat_damage_1.tres",
        ),
        technique_root / "jaw_break.tres": (
            "jaw_break_stun.tres",
            "flat_damage_1.tres",
        ),
    }
    for path, required_lines in focused_contracts.items():
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for required_line in required_lines:
            if required_line not in text:
                errors.append(
                    f"{path}: missing weapon-art behavior {required_line}"
                )

    retired_techniques = (
        technique_root / "dread_slash.tres",
        technique_root / "guardbreaker.tres",
        technique_root / "rebuke.tres",
    )
    for path in retired_techniques:
        if path.exists():
            errors.append(f"retired provisional technique remains: {path}")

    equipment_roots = (
        ROOT / "scripts" / "data" / "equipment" / "weapons",
        ROOT / "scripts" / "data" / "armor",
        ROOT / "scripts" / "data" / "shields",
    )
    for equipment_root in equipment_roots:
        for path in sorted(equipment_root.rglob("*.tres")):
            text = path.read_text(encoding="utf-8")
            for required_line in (
                "equipment_id = &\"",
                "allowed_slots = Array[int]([",
                "condition_maximum = ",
                "destructible = ",
            ):
                if required_line not in text:
                    errors.append(
                        f"{path}: missing authored equipment metadata "
                        f"{required_line.rstrip()}"
                    )
            if any(
                legacy_line in text
                for legacy_line in (
                    "weapon_id =",
                    "armor_id =",
                    "shield_id =",
                )
            ):
                errors.append(f"{path}: legacy equipment identity remains")
            if (
                "destructible = true" in text
                and "salvage_material_id = &\"" not in text
            ):
                errors.append(
                    f"{path}: destructible equipment lacks salvage_material_id"
                )

    loadout_root = ROOT / "scripts" / "data" / "equipment" / "loadouts"
    for path in sorted(loadout_root.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        if "shield = ExtResource" in text:
            errors.append(
                f"{path}: shields must use the explicit Off Hand assignment"
            )

    equipment_contracts = {
        ROOT / "scripts" / "data" / "equipment_definition.gd": (
            "enum Slot {",
            "MAIN_HAND",
            "OFF_HAND",
            "ARMOR",
            "destructible and salvage_material_id == &\"\"",
            "authored_positive_effect_ids",
            "authored_negative_effect_ids",
        ),
        ROOT / "scripts" / "map" / "equipment_instance.gd": (
            "var instance_id: StringName",
            "var definition_id: StringName",
            "var current_condition: int",
            "func apply_condition_damage(",
            "func repair_condition(",
            "func to_snapshot(",
            "func restore_from_snapshot(",
        ),
        ROOT
        / "scripts"
        / "map"
        / "personal_equipment_loadout_state.gd": (
            "func equip(",
            "func unequip(",
            "assigned more than once",
            "func to_snapshot(",
        ),
        ROOT / "scripts" / "map" / "run_equipment_state.gd": (
            "var loadouts_by_heroine: Dictionary",
            "func assign_memento(",
            "return run_inventory.assign_memento(",
            "func get_snapshot(",
        ),
        ROOT / "scripts" / "battle" / "states" / "battler_state.gd": (
            "var equipment_loadout_state: PersonalEquipmentLoadoutState",
            "func _refresh_equipment_adapters(",
            "main_hand_instance",
            "off_hand_instance",
        ),
        ROOT / "scripts" / "map" / "run_state.gd": (
            "var run_equipment: RunEquipmentState",
            "run_equipment.initialize(",
        ),
    }
    for path, fragments in equipment_contracts.items():
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(
                    f"{path}: missing Milestone 4 equipment contract {fragment}"
                )


def validate_authored_equipment_materials(errors: list[str]) -> None:
    material_ids = {
        "mat_l01_red_wax",
        "mat_l01_servant_cloth",
        "mat_l02_chain_links",
        "mat_l02_prison_iron",
    }
    item_catalog = ROOT / "data" / "items" / "layer_1_2_item_catalog.tres"
    material_catalog = (
        ROOT / "data" / "materials" / "layer_1_2_material_catalog.tres"
    )
    equipment_catalog = (
        ROOT / "data" / "equipment" / "layer_1_2_equipment_catalog.tres"
    )
    recipe_catalog = ROOT / "data" / "refuge" / "refuge_recipe_catalog.tres"
    for path in (item_catalog, material_catalog, equipment_catalog, recipe_catalog):
        if not path.is_file():
            errors.append(f"missing Milestone 10 authored catalog: {path}")
            return

    item_text = item_catalog.read_text(encoding="utf-8")
    material_text = material_catalog.read_text(encoding="utf-8")
    for material_id in sorted(material_ids):
        material_path = next(
            (
                path
                for path in (ROOT / "data" / "materials").rglob("*.tres")
                if path.name != "layer_1_2_material_catalog.tres"
                and f'item_id = &"{material_id}"' in path.read_text(encoding="utf-8")
            ),
            None,
        )
        if material_path is None:
            errors.append(f"missing authored Material definition: {material_id}")
            continue
        material_definition = material_path.read_text(encoding="utf-8")
        for fragment in (
            f'item_id = &"{material_id}"',
            f"res://assets/items/by_stable_id/{material_id}.png",
            "content_category = 4",
            "canonical_workbook_item = true",
            "purpose_ids = Array[StringName]([",
        ):
            if fragment not in material_definition:
                errors.append(
                    f"{material_path}: missing Material contract {fragment}"
                )
        if str(material_path.relative_to(ROOT)).replace("\\", "/") not in item_text:
            errors.append(f"{item_catalog}: Material {material_id} is not registered")
        if str(material_path.relative_to(ROOT)).replace("\\", "/") not in material_text:
            errors.append(f"{material_catalog}: Material {material_id} is not registered")

    mappings = {
        ROOT / "scripts" / "data" / "equipment" / "weapons" / "red_wax_drip.tres": (
            'rarity = 1',
            'salvage_material_id = &"mat_l01_red_wax"',
        ),
        ROOT / "scripts" / "data" / "armor" / "corrupted_butler_cloth.tres": (
            'rarity = 1',
            'salvage_material_id = &"mat_l01_servant_cloth"',
        ),
        ROOT / "scripts" / "data" / "equipment" / "weapons" / "chain_thrall_chain.tres": (
            'rarity = 2',
            'salvage_material_id = &"mat_l02_chain_links"',
        ),
        ROOT / "scripts" / "data" / "equipment" / "weapons" / "iron_guard_gaoler_pole.tres": (
            'rarity = 3',
            'salvage_material_id = &"mat_l02_prison_iron"',
        ),
    }
    for path, fragments in mappings.items():
        if not path.is_file():
            errors.append(f"missing authored salvage equipment: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        if "destructible = true" not in text:
            errors.append(f"{path}: authored salvage mapping is not destructible")
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{path}: missing authored salvage contract {fragment}")

    ownership = ROOT / "scripts" / "refuge" / "refuge_ownership_state.gd"
    if ownership.is_file():
        ownership_text = ownership.read_text(encoding="utf-8")
        for fragment in (
            "func salvage_owned_equipment(",
            "func execute_refuge_recipe(",
            "get_salvage_yield()",
            "Banked Materials cannot be withdrawn into a run.",
        ):
            if fragment not in ownership_text:
                errors.append(f"{ownership}: missing Milestone 10 contract {fragment}")


def validate_gdscript_delimiters(
    source: Path,
    text: str,
    errors: list[str],
) -> None:
    opening = {"(": ")", "[": "]", "{": "}"}
    closing = {value: key for key, value in opening.items()}
    stack: list[tuple[str, int]] = []
    quote: str | None = None
    escaped = False
    in_comment = False
    line = 1

    for character in text:
        if character == "\n":
            line += 1
            in_comment = False
            escaped = False
            continue

        if in_comment:
            continue

        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            continue

        if character == "#":
            in_comment = True
        elif character in {'"', "'"}:
            quote = character
        elif character in opening:
            stack.append((character, line))
        elif character in closing:
            if not stack or stack[-1][0] != closing[character]:
                errors.append(
                    f"{source}:{line}: unmatched closing {character}"
                )
                return
            stack.pop()

    if quote is not None:
        errors.append(f"{source}: unterminated string")
    if stack:
        character, opening_line = stack[-1]
        errors.append(
            f"{source}:{opening_line}: unclosed delimiter {character}"
        )


def validate_ability_resources(errors: list[str]) -> None:
    definition = ROOT / "scripts" / "data" / "ability_definition.gd"
    controller = (
        ROOT
        / "scripts"
        / "battle"
        / "abilities"
        / "ability_action_controller.gd"
    )
    resolver = (
        ROOT
        / "scripts"
        / "battle"
        / "abilities"
        / "ability_effect_resolver.gd"
    )
    for path in (definition, controller, resolver):
        if not path.is_file():
            errors.append(f"missing ability Resource architecture file: {path}")
            return

    combined = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (definition, controller)
    )
    if "EffectType" in combined or "effect_type" in combined:
        errors.append("legacy AbilityDefinition EffectType switch remains")
    if "Array[AbilityEffectDefinition]" not in combined:
        errors.append("AbilityDefinition is missing composed effect Resources")
    if "effect_resolver.resolve" not in controller.read_text(encoding="utf-8"):
        errors.append("AbilityActionController does not use AbilityEffectResolver")

    required_spells = {
        "dispel_magic.tres",
        "slow.tres",
        "regeneration.tres",
        "cure.tres",
    }
    spell_root = ROOT / "data" / "abilities" / "retained_spells"
    present_spells = {
        path.name for path in spell_root.glob("*.tres")
    } if spell_root.is_dir() else set()
    missing_spells = sorted(required_spells - present_spells)
    if missing_spells:
        errors.append(
            "missing retained spell Resources: " + ", ".join(missing_spells)
        )

    for path in (
        ROOT / "data" / "abilities" / "prayer_rag_dark_prayer.tres",
        ROOT / "data" / "ability_effects" / "attack_dark_prayer.tres",
    ):
        if not path.is_file():
            errors.append(f"missing Prayer-Rag attack ability Resource: {path}")

    current_abilities = [
        path
        for path in (ROOT / "data" / "abilities").glob("*.tres")
        if path.name != "retained_spell_catalog.tres"
    ]
    for ability in current_abilities:
        text = ability.read_text(encoding="utf-8")
        if "script_class=\"AbilityDefinition\"" in text and "effects =" not in text:
            errors.append(f"{ability}: ability has no composed effects")


def validate_scene_node_paths(
    source: Path,
    text: str,
    errors: list[str],
) -> None:
    node_matches = list(NODE_RE.finditer(text))
    if not node_matches:
        errors.append(f"{source}: scene contains no nodes")
        return

    known_nodes: set[str] = set()
    blocks: list[tuple[str, int, int]] = []

    for index, match in enumerate(node_matches):
        name, parent = match.groups()
        if index == 0:
            full_path = ""
        elif parent in {None, "."}:
            full_path = name
        else:
            full_path = posixpath.normpath(f"{parent}/{name}")

        if full_path in known_nodes:
            errors.append(f"{source}: duplicate node path {full_path}")
        known_nodes.add(full_path)

        block_end = (
            node_matches[index + 1].start()
            if index + 1 < len(node_matches)
            else len(text)
        )
        blocks.append((full_path, match.end(), block_end))

    for owner_path, block_start, block_end in blocks:
        block = text[block_start:block_end]
        for match in NODE_PATH_RE.finditer(block):
            node_path = match.group(1)
            if not node_path or node_path == ".":
                continue
            resolved = posixpath.normpath(
                f"{owner_path}/{node_path}" if owner_path else node_path
            )
            if resolved not in known_nodes:
                errors.append(
                    f"{source}: {owner_path or '<root>'} references "
                    f"missing NodePath {node_path}"
                )


def validate_main_scene(errors: list[str]) -> None:
    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    main_scene_match = MAIN_SCENE_RE.search(project_text)
    if main_scene_match is None:
        errors.append("project.godot has no run/main_scene")
        return

    main_scene = main_scene_match.group(1)
    if main_scene.startswith("res://"):
        if not (ROOT / main_scene.removeprefix("res://")).is_file():
            errors.append(f"project.godot main scene is missing: {main_scene}")
        return

    if not main_scene.startswith("uid://"):
        errors.append(f"project.godot has unsupported main scene: {main_scene}")
        return

    for scene in ROOT.rglob("*.tscn"):
        scene_text = scene.read_text(encoding="utf-8")
        uid_match = SCENE_UID_RE.search(scene_text)
        if uid_match is not None and uid_match.group(1) == main_scene:
            return

    errors.append(f"project.godot main scene UID is unresolved: {main_scene}")


def validate_modular_combat_architecture(errors: list[str]) -> None:
    encounter_scene = (
        ROOT / "scenes" / "battle" / "combat_encounter.tscn"
    )
    coordinator = (
        ROOT / "scripts" / "battle" / "encounter_coordinator.gd"
    )
    main_controller = ROOT / "scripts" / "map" / "main_controller.gd"
    combat_engine = (
        ROOT / "scenes" / "battle" / "runtime" / "combat_engine.tscn"
    )
    combat_presenter = (
        ROOT
        / "scripts"
        / "battle"
        / "presentation"
        / "reusable"
        / "combat_presenter.gd"
    )
    reusable_hud = (
        ROOT
        / "scenes"
        / "battle"
        / "ui"
        / "reusable"
        / "combat_hud.tscn"
    )
    for path in (
        encounter_scene,
        coordinator,
        main_controller,
        combat_engine,
        combat_presenter,
        reusable_hud,
    ):
        if not path.is_file():
            errors.append(f"missing modular combat artifact: {path}")
            return

    encounter_text = encounter_scene.read_text(encoding="utf-8")
    coordinator_text = coordinator.read_text(encoding="utf-8")
    main_text = main_controller.read_text(encoding="utf-8")

    if '[node name="CombatEncounter" type="Node"' not in encounter_text:
        errors.append(
            f"{encounter_scene}: production root must be CombatEncounter"
        )
    if "class_name CombatEncounter" not in coordinator_text:
        errors.append(
            f"{coordinator}: missing CombatEncounter class"
        )
    for required_fragment in (
        'path="res://scenes/battle/runtime/combat_engine.tscn"',
        'path="res://scenes/battle/ui/reusable/combat_hud.tscn"',
        'path="res://scenes/battle/runtime/combat_presenter.tscn"',
    ):
        if required_fragment not in encounter_text:
            errors.append(
                f"{encounter_scene}: missing production composition "
                f"{required_fragment}"
            )
    for required_fragment in (
        'path="res://data/battlers/battler_catalog.tres"',
        'path="res://data/encounters/opening_servant_corridor.tres"',
        'path="res://scripts/battle/presentation/battle_marker_factory.gd"',
        'name="BattlefieldHost" type="Node"',
        'name="MarkerHost" type="Node2D"',
    ):
        if required_fragment not in encounter_text:
            errors.append(
                f"{encounter_scene}: missing dynamic battle composition "
                f"{required_fragment}"
            )
    for forbidden_fragment in (
        "ruined_chapel_battle.png",
        "ruined_chapel_spatial_test.tres",
        "lysandra.tres",
        "hollow_servant.tres",
        'name="LysandraMarker"',
        'name="HollowServantMarker"',
    ):
        if forbidden_fragment in encounter_text:
            errors.append(
                f"{encounter_scene}: fixed battlefield composition remains: "
                f"{forbidden_fragment}"
            )
    composition_paths = (
        ROOT
        / "scenes"
        / "battle"
        / "battlefields"
        / "ruined_chapel_battlefield.tscn",
        ROOT
        / "scenes"
        / "battle"
        / "battlefields"
        / "processing_chapel_battlefield.tscn",
        ROOT / "data" / "encounters" / "ruined_chapel_template.tres",
        ROOT / "data" / "encounters" / "processing_chapel_template.tres",
    )
    for path in composition_paths:
        if not path.is_file():
            errors.append(f"missing Battle Composition artifact: {path}")
    if "var active_battle: CombatEncounter" not in main_text:
        errors.append(
            f"{main_controller}: active encounter must use CombatEncounter"
        )
    if (
        "func _retire_active_battle()" not in main_text
        or "parent.remove_child(active_battle)" not in main_text
    ):
        errors.append(
            f"{main_controller}: retired encounter CanvasLayers may leak "
            "into the next battle"
        )
    if (
        "func _skip_momentum_locked_phase_if_needed()" not in coordinator_text
        or "func _queue_combat_progression()" not in coordinator_text
        or "func _advance_combat_progression()" not in coordinator_text
        or (
            "state.is_side_momentum_locked(state.get_active_side())"
            not in coordinator_text
        )
    ):
        errors.append(
            f"{coordinator}: centralized Momentum progression gate "
            "is incomplete"
        )
    for required_reaction_fragment in (
        "func _resume_after_grapple_dodge_step()",
        "pending_grapple_dodge_attempt = attempt",
        "heroine.current_actions <= 0 or heroine.is_defeated",
        'call_deferred("_on_grapple_response_chosen", false)',
        "func _on_reusable_equipment_break_selected(",
    ):
        if required_reaction_fragment not in coordinator_text:
            errors.append(
                f"{coordinator}: reaction lifecycle contract is incomplete: "
                f"{required_reaction_fragment}"
            )

    retired_paths = (
        ROOT / "scenes" / "battle" / "ui" / "panels",
        ROOT / "scenes" / "battle" / "ui" / "scripts",
        ROOT / "scenes" / "ui",
        ROOT / "scripts" / "ui",
    )
    for retired_path in retired_paths:
        if retired_path.exists():
            errors.append(
                f"retired production artifact is still active: {retired_path}"
            )

    for forbidden_fragment in (
        "UILayer",
        "InspectPanel",
        "AttackReactionPanel",
        "GrappleReactionPanel",
        "MoveReactionChoicePanel",
    ):
        if forbidden_fragment in encounter_text:
            errors.append(
                f"{encounter_scene}: retired UI remains: "
                f"{forbidden_fragment}"
            )

    engine_directories = (
        "abilities",
        "ai",
        "aoe",
        "core",
        "grapple",
        "items",
        "lifecycle",
        "reactions",
        "rules",
        "runtime",
        "spatial",
        "states",
        "status",
    )
    ui_coupling_re = re.compile(
        r"\b(?:Control|Button|Label|PanelContainer|CanvasLayer|"
        r"BattleMarker|CombatPresenter|ReusableCombatHUD)\b"
    )
    for directory_name in engine_directories:
        directory = ROOT / "scripts" / "battle" / directory_name
        if not directory.is_dir():
            continue
        for source in directory.rglob("*.gd"):
            source_text = source.read_text(encoding="utf-8")
            if ui_coupling_re.search(source_text):
                errors.append(
                    f"{source}: combat engine layer depends on "
                    "presentation types"
                )


def validate_attack_dice_floor(errors: list[str]) -> None:
    resolver = (
        ROOT
        / "scripts"
        / "battle"
        / "rules"
        / "attack_resolver.gd"
    )
    if not resolver.is_file():
        errors.append("AttackResolver is missing")
        return
    resolver_text = resolver.read_text(encoding="utf-8")
    if "dice_count = maxi(dice_count, 1)" not in resolver_text:
        errors.append(
            f"{resolver}: legal committed Attacks must retain the 1d10 floor"
        )


def validate_combat_hud(errors: list[str]) -> None:
    required_paths = (
        "scenes/battle/ui/reusable/combat_hud.tscn",
        "scenes/battle/ui/reusable/components/ability_panel.tscn",
        "scenes/battle/ui/reusable/components/combat_log_drawer.tscn",
        "scenes/battle/ui/reusable/components/command_bar_view.tscn",
        "scenes/battle/ui/reusable/components/enemy_hud_view.tscn",
        "scenes/battle/ui/reusable/components/heroine_card_view.tscn",
        "scenes/battle/ui/reusable/components/item_bar_view.tscn",
        "scenes/battle/ui/reusable/components/reaction_exchange.tscn",
        "scenes/battle/ui/reusable/components/struggle_panel.tscn",
        "scenes/battle/ui/reusable/styles/hud_frame_style.tres",
        "assets/backgrounds/layer_1/ruined_chapel_battle.png",
        "assets/backgrounds/layer_1/blood_nun_processing_chapel.png",
        "assets/characters/enemies/corrupted_butler.png",
        "assets/characters/curated/lysandra/core_idle_front.png",
        "assets/characters/curated/mira/core_move_front.png",
        "assets/characters/curated/seraphine/core_idle_front.png",
        "scenes/battle/battlefields/ruined_chapel_battlefield.tscn",
        "scenes/battle/battlefields/processing_chapel_battlefield.tscn",
        "data/presentation/battler_view_catalog.tres",
    )
    for relative_path in required_paths:
        if not (ROOT / relative_path).is_file():
            errors.append(f"missing Combat HUD artifact: {relative_path}")

    battle_scene = ROOT / "scenes" / "battle" / "combat_encounter.tscn"
    if not battle_scene.is_file():
        return
    scene_text = battle_scene.read_text(encoding="utf-8")
    if (
        'path="res://scenes/battle/ui/reusable/combat_hud.tscn"'
        not in scene_text
    ):
        errors.append("live combat scene does not use ReusableCombatHUD")
    battlefield_scenes = (
        ROOT
        / "scenes"
        / "battle"
        / "battlefields"
        / "ruined_chapel_battlefield.tscn",
        ROOT
        / "scenes"
        / "battle"
        / "battlefields"
        / "processing_chapel_battlefield.tscn",
    )
    for battlefield_scene in battlefield_scenes:
        if not battlefield_scene.is_file():
            continue
        battlefield_text = battlefield_scene.read_text(encoding="utf-8")
        if (
            'name="BackgroundArt" type="TextureRect"' not in battlefield_text
            and 'name="BackgroundArt" type="Sprite2D"' not in battlefield_text
        ):
            errors.append(
                f"{battlefield_scene}: authored battlefield lacks BackgroundArt"
            )
        for required_fragment in (
            'path="res://scripts/data/battlefield/authored_battle_zone.gd"',
            'path="res://scripts/data/battlefield/authored_anchor.gd"',
            'path="res://scripts/data/battlefield/authored_position.gd"',
            'path="res://scripts/data/battlefield/authored_spawn_slot.gd"',
            'name="Zones" type="Node2D"',
            'name="Anchors" type="Node2D"',
            'name="SpawnSlots" type="Node2D"',
            'type="Polygon2D" parent="Zones"',
        ):
            if required_fragment not in battlefield_text:
                errors.append(
                    f"{battlefield_scene}: missing visual authoring "
                    f"fragment {required_fragment}"
                )
        for forbidden_fragment in (
            "ruined_chapel_runtime.tres",
            "processing_chapel_runtime.tres",
            "terrain_line_definition.gd",
        ):
            if forbidden_fragment in battlefield_text:
                errors.append(
                    f"{battlefield_scene}: production scene still depends on "
                    f"separate/deferred data {forbidden_fragment}"
                )
    view_catalog = ROOT / "data" / "presentation" / "battler_view_catalog.tres"
    if view_catalog.is_file():
        view_text = view_catalog.read_text(encoding="utf-8")
        for art_path in (
            "curated/lysandra/core_idle_front.png",
            "curated/mira/core_move_front.png",
            "curated/seraphine/core_idle_front.png",
            "corrupted_butler.png",
        ):
            if art_path not in view_text:
                errors.append(
                    f"{view_catalog}: missing dynamic battler view {art_path}"
                )
    for hud_scene in (
        ROOT / "scenes" / "battle" / "ui" / "reusable" / "combat_hud.tscn",
        ROOT / "scenes" / "exploration" / "components" / "exploration_hud.tscn",
    ):
        if not hud_scene.is_file():
            continue
        hud_text = hud_scene.read_text(encoding="utf-8")
        if "res://assets/ui/portraits/" in hud_text:
            errors.append(f"{hud_scene}: active HUD still uses legacy portraits")
        for art_path in (
            "curated/lysandra/core_idle_front.png",
            "curated/mira/core_move_front.png",
            "curated/seraphine/core_idle_front.png",
        ):
            if art_path not in hud_text:
                errors.append(
                    f"{hud_scene}: missing curated party portrait {art_path}"
                )
    marker_script = (
        ROOT
        / "scripts"
        / "battle"
        / "presentation"
        / "battle_marker.gd"
    )
    if marker_script.is_file():
        marker_text = marker_script.read_text(encoding="utf-8")
        if (
            "select_button.flat = true" not in marker_text
            or "Color(0, 0, 0, 0)" not in marker_text
        ):
            errors.append(
                f"{marker_script}: full-body enemy hit area may cover "
                "CharacterArt"
            )
    hud_script = (
        ROOT
        / "scripts"
        / "battle"
        / "presentation"
        / "reusable"
        / "reusable_combat_hud.gd"
    )
    if hud_script.is_file():
        hud_script_text = hud_script.read_text(encoding="utf-8")
        for log_fragment in (
            "@onready var log_animation: AnimationPlayer = %LogAnimation",
            "func toggle_log() -> void:",
            "if log_is_open:",
            'log_animation.play_backwards(&"log_open")',
            'log_animation.play(&"log_open")',
            "log_is_open = not log_is_open",
            "func close_log() -> void:",
            "log_is_open = false",
        ):
            if log_fragment not in hud_script_text:
                errors.append(
                    f"{hud_script}: authored reusable log animation "
                    "contract is incomplete"
                )
                break
    reusable_hud = (
        ROOT
        / "scenes"
        / "battle"
        / "ui"
        / "reusable"
        / "combat_hud.tscn"
    )
    if reusable_hud.is_file():
        hud_text = reusable_hud.read_text(encoding="utf-8")
        for log_scene_fragment in (
            '&"log_open": SubResource("Animation_log_open")',
            'Vector2(1920',
        ):
            if log_scene_fragment not in hud_text:
                errors.append(
                    f"{reusable_hud}: authored reusable log drawer scene "
                    f"is missing {log_scene_fragment!r}"
                )
        if (
            'path="res://scenes/battle/ui/reusable/styles/'
            'hud_frame_style.tres"'
            not in hud_text
        ):
            errors.append(
                f"{reusable_hud}: original custom frame style is not imported"
            )
        if "SystemControls" in hud_text:
            errors.append(
                f"{reusable_hud}: extra system controls changed the "
                "separately designed UI"
            )
        for layout_fragment in (
            'node name="PartyStrip" type="PanelContainer" parent="Root"',
            'node name="Cards" type="VBoxContainer" parent="Root/PartyStrip"',
            'node name="ItemBar" parent="Root"',
            'node name="CommandBar" parent="Root"',
            "offset_left = -90.0",
            "offset_left = -104.0",
        ):
            if layout_fragment not in hud_text:
                errors.append(
                    f"{reusable_hud}: compact edge HUD is missing "
                    f"{layout_fragment!r}"
                )
        if not re.search(
            r'\[node name="LogAnimation" type="AnimationPlayer" '
            r'parent="Root"[^\]]*\]',
            hud_text,
        ):
            errors.append(
                f"{reusable_hud}: authored Log AnimationPlayer is missing"
            )
    log_drawer_scene = (
        ROOT
        / "scenes"
        / "battle"
        / "ui"
        / "reusable"
        / "components"
        / "combat_log_drawer.tscn"
    )
    if log_drawer_scene.is_file():
        log_drawer_text = log_drawer_scene.read_text(encoding="utf-8")
        for width_fragment in (
            '[node name="LogScroll" type="ScrollContainer"',
            "horizontal_scroll_mode = 0",
            '[node name="Entries" type="VBoxContainer"',
        ):
            if width_fragment not in log_drawer_text:
                errors.append(
                    f"{log_drawer_scene}: Log drawer width contract is "
                    f"missing {width_fragment!r}"
                )
        entries_index = log_drawer_text.find(
            '[node name="Entries" type="VBoxContainer"'
        )
        if (
            entries_index < 0
            or "size_flags_horizontal = 3"
            not in log_drawer_text[entries_index:]
        ):
            errors.append(
                f"{log_drawer_scene}: Log entries must expand to drawer width"
            )
    log_drawer_script = (
        ROOT
        / "scripts"
        / "battle"
        / "presentation"
        / "reusable"
        / "combat_log_drawer.gd"
    )
    if log_drawer_script.is_file():
        log_drawer_script_text = log_drawer_script.read_text(
            encoding="utf-8"
        )
        if (
            "label.size_flags_horizontal = Control.SIZE_EXPAND_FILL"
            not in log_drawer_script_text
            or "label.mouse_filter = Control.MOUSE_FILTER_STOP"
            not in log_drawer_script_text
            or 'label.add_theme_font_size_override("font_size", 12)'
            not in log_drawer_script_text
            or "label.custom_minimum_size.x = 1.0"
            in log_drawer_script_text
        ):
            errors.append(
                f"{log_drawer_script}: generated Log labels must use the "
                "full drawer width"
            )
    expected_component_sizes = {
        "item_bar_view.tscn": "Vector2(74, 384)",
        "command_bar_view.tscn": "Vector2(88, 372)",
    }
    for component_name, expected_size in expected_component_sizes.items():
        component = (
            ROOT
            / "scenes"
            / "battle"
            / "ui"
            / "reusable"
            / "components"
            / component_name
        )
        if not component.is_file():
            continue
        component_text = component.read_text(encoding="utf-8")
        if f"custom_minimum_size = {expected_size}" not in component_text:
            errors.append(
                f"{component}: missing compact authored size {expected_size}"
            )
        if (
            component_name == "item_bar_view.tscn"
            and 'name="Slots" type="VBoxContainer"' not in component_text
        ):
            errors.append(
                f"{component}: Item tray must remain a vertical icon stack"
            )
    reaction_scene = (
        ROOT
        / "scenes"
        / "battle"
        / "ui"
        / "reusable"
        / "components"
        / "reaction_exchange.tscn"
    )
    if reaction_scene.is_file():
        reaction_text = reaction_scene.read_text(encoding="utf-8")
        if "custom_minimum_size = Vector2(430, 170)" not in reaction_text:
            errors.append(
                f"{reaction_scene}: reaction card must use the compact 430x170 size"
            )
        if (
            'node name="ReactionExchange" type="Control"' not in reaction_text
            or 'node name="Frame" type="PanelContainer" parent="."'
            not in reaction_text
            or "anchor_right = 1.0" not in reaction_text
            or "anchor_bottom = 1.0" not in reaction_text
        ):
            errors.append(
                f"{reaction_scene}: reaction must use a compact floating root "
                "with a full-rect inner Frame"
            )
        if "icon =" in reaction_text or "assets/ui/icons" in reaction_text:
            errors.append(
                f"{reaction_scene}: reaction buttons must remain text-only"
            )
        reaction_script = (
            ROOT
            / "scripts"
            / "battle"
            / "presentation"
            / "reusable"
            / "reaction_exchange.gd"
        )
        if reaction_script.is_file():
            reaction_script_text = reaction_script.read_text(encoding="utf-8")
            if "→" in reaction_script_text:
                errors.append(
                    f"{reaction_script}: unsupported arrow glyph remains in UI copy"
                )
    struggle_scene = (
        ROOT
        / "scenes"
        / "battle"
        / "ui"
        / "reusable"
        / "components"
        / "struggle_panel.tscn"
    )
    if struggle_scene.is_file():
        struggle_text = struggle_scene.read_text(encoding="utf-8")
        for struggle_fragment in (
            'name="Might" type="Button"',
            'name="Agility" type="Button"',
            'name="Endurance" type="Button"',
        ):
            if struggle_fragment not in struggle_text:
                errors.append(
                    f"{struggle_scene}: direct Attribute choices are incomplete"
                )
                break
        if "ConfirmButton" in struggle_text or "CancelButton" in struggle_text:
            errors.append(
                f"{struggle_scene}: obsolete Struggle confirm/cancel buttons remain"
            )
        if "custom_minimum_size = Vector2(420, 0)" not in struggle_text:
            errors.append(
                f"{struggle_scene}: Struggle tray must shrink to its content height"
            )
        if (
            'node name="StrugglePanel" type="Control"' not in struggle_text
            or 'node name="Frame" type="PanelContainer" parent="."'
            not in struggle_text
            or 'parent="Frame/Margin/Content"' not in struggle_text
        ):
            errors.append(
                f"{struggle_scene}: Struggle must use a floating root and an "
                "inner content-sized Frame"
            )
        if "offset_bottom = 165.0" in struggle_text:
            errors.append(
                f"{struggle_scene}: fixed Struggle height still leaves blank space"
            )
        struggle_script = (
            ROOT
            / "scripts"
            / "battle"
            / "presentation"
            / "struggle_panel.gd"
        )
        if struggle_script.is_file():
            struggle_script_text = struggle_script.read_text(encoding="utf-8")
            for layout_fragment in (
                "modulate.a = 0.0",
                "await get_tree().process_frame",
                "expected_generation != open_generation",
                "_fit_to_content()",
                "_play_roll_open()",
            ):
                if layout_fragment not in struggle_script_text:
                    errors.append(
                        f"{struggle_script}: first-open layout synchronization "
                        f"is missing {layout_fragment!r}"
                    )
                    break
    frame_style = (
        ROOT
        / "scenes"
        / "battle"
        / "ui"
        / "reusable"
        / "styles"
        / "hud_frame_style.tres"
    )
    if frame_style.is_file():
        frame_text = frame_style.read_text(encoding="utf-8")
        for imported_fragment in (
            'uid="uid://b6m37hpkc3vee"',
            "bg_color = Color(0.0627451, 0.0627451, 0.078431375, 0.8666667)",
            "border_color = Color(0.57254905, 0.45490196, 0.2627451, 1)",
        ):
            if imported_fragment not in frame_text:
                errors.append(
                    f"{frame_style}: imported custom style changed or "
                    f"is incomplete"
                )
    stale_heroine_uids = (
        "uid://cjuy5y10xhvp0",
        "uid://vwcspe1xxbs3",
        "uid://dh5553mhratun",
    )
    for stale_uid in stale_heroine_uids:
        if stale_uid in scene_text:
            errors.append(f"stale heroine resource UID remains: {stale_uid}")


def validate_item_system(errors: list[str]) -> None:
    expected_workbook_items = {
        "l01_bandage_roll": 1,
        "l01_smelling_salts": 1,
        "l01_warm_wine_flask": 1,
        "l01_servants_tonic": 1,
        "l01_wax_sealed_needle": 1,
        "l01_red_wax_ampoule": 1,
        "l01_kitchen_knife": 1,
        "l01_repair_thread_wax": 1,
        "l01_polished_serving_tray": 1,
        "l01_chapel_rosary": 1,
        "l01_hollow_livery_pin": 1,
        "l01_courtesy_collar": 1,
        "l01_ledger_seal": 1,
        "l01_torn_cuff": 1,
        "l02_prisoners_poultice": 2,
        "l02_bitter_wakefulness_tonic": 2,
        "l02_chain_oil": 2,
        "l02_filed_iron_shard": 2,
        "l02_shackle_key": 2,
        "l02_rusted_nail_bundle": 2,
        "l02_lime_dust_pouch": 2,
        "l02_iron_wedge": 2,
        "l02_jailers_maintenance_kit": 2,
        "l02_mercy_chain": 2,
        "l02_jailers_tag": 2,
        "l02_guiltless_key": 2,
        "l02_quiet_shackle": 2,
    }
    legacy_items = {"quiet_cell_blanket": 2}
    expected_items = expected_workbook_items | legacy_items
    item_id_re = re.compile(r'^item_id = &"([^"]+)"$', re.MULTILINE)
    layer_re = re.compile(r"^layer = ([0-9]+)$", re.MULTILINE)
    discovered: dict[str, Path] = {}

    for layer in (1, 2):
        item_directory = ROOT / "data" / "items" / f"layer_{layer}"
        if not item_directory.is_dir():
            errors.append(f"missing item directory: {item_directory}")
            continue
        for resource in sorted(item_directory.glob("*.tres")):
            resource_text = resource.read_text(encoding="utf-8")
            item_id_match = item_id_re.search(resource_text)
            if item_id_match is None:
                errors.append(f"{resource}: missing item_id")
                continue
            item_id = item_id_match.group(1)
            if item_id in discovered:
                errors.append(
                    f"duplicate item_id {item_id}: "
                    f"{discovered[item_id]} and {resource}"
                )
            discovered[item_id] = resource

            layer_match = layer_re.search(resource_text)
            authored_layer = int(layer_match.group(1)) if layer_match else 1
            if authored_layer != layer:
                errors.append(
                    f"{resource}: authored Layer {authored_layer}, "
                    f"but stored in layer_{layer}"
                )

            if item_id in expected_workbook_items:
                if "canonical_workbook_item = true" not in resource_text:
                    errors.append(
                        f"{resource}: workbook item is not marked canonical"
                    )
            elif item_id == "quiet_cell_blanket":
                for fragment in (
                    "content_category = 7",
                    "canonical_workbook_item = false",
                ):
                    if fragment not in resource_text:
                        errors.append(
                            f"{resource}: legacy Quiet Cell Blanket must contain "
                            f"{fragment}"
                        )

    missing_items = sorted(expected_items.keys() - discovered.keys())
    unexpected_items = sorted(discovered.keys() - expected_items.keys())
    if missing_items:
        errors.append("missing approved items: " + ", ".join(missing_items))
    if unexpected_items:
        errors.append(
            "unexpected Layer 1–2 items: " + ", ".join(unexpected_items)
        )
    for item_id, expected_layer in expected_items.items():
        resource = discovered.get(item_id)
        if resource is None:
            continue
        actual_directory = resource.parent.name
        if actual_directory != f"layer_{expected_layer}":
            errors.append(
                f"{item_id} is in {actual_directory}; expected "
                f"layer_{expected_layer}"
            )

    rusty_key = ROOT / "data" / "items" / "keys" / "rusty_key.tres"
    if not rusty_key.is_file():
        errors.append(f"missing shared Rusty Key definition: {rusty_key}")
    else:
        rusty_text = rusty_key.read_text(encoding="utf-8")
        for fragment in (
            'item_id = &"shared_rusty_key"',
            "content_category = 3",
            "rarity = 4",
            "canonical_workbook_item = true",
            'path="res://assets/items/by_stable_id/shared_rusty_key.png"',
        ):
            if fragment not in rusty_text:
                errors.append(f"{rusty_key}: missing {fragment}")

    manifest_path = ROOT / "data" / "items" / "item_sprite_manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"{manifest_path}: could not validate item metadata: {error}")
        manifest = {}
    manifest_items = manifest.get("items", [])
    manifest_by_id = {
        item.get("stable_id"): item
        for item in manifest_items
        if isinstance(item, dict) and isinstance(item.get("stable_id"), str)
    }
    if "quiet_cell_blanket" in manifest_by_id:
        errors.append(
            "legacy Quiet Cell Blanket must remain absent from the workbook manifest"
        )
    category_values = {
        "Active": 1,
        "Memento": 2,
        "Key": 3,
        "Material": 4,
        "Story": 5,
        "Knowledge": 6,
    }
    rarity_values = {
        "Common": 1,
        "Uncommon": 2,
        "Rare": 3,
        "Unique": 4,
    }
    canonical_resources = {
        item_id: resource
        for item_id, resource in discovered.items()
        if item_id in expected_workbook_items
    }
    if rusty_key.is_file():
        canonical_resources["shared_rusty_key"] = rusty_key
    expected_manifest_ids = {
        stable_id
        for stable_id, item in manifest_by_id.items()
        if item.get("source_kind") == "existing_project_item"
    }
    if set(canonical_resources) != expected_manifest_ids:
        errors.append(
            "implemented canonical item IDs do not match manifest-backed "
            "project items"
        )
    for item_id, resource in canonical_resources.items():
        record = manifest_by_id.get(item_id)
        if record is None:
            errors.append(f"{resource}: {item_id} is absent from the manifest")
            continue
        resource_text = resource.read_text(encoding="utf-8")
        expected_fragments = (
            f"content_category = {category_values.get(record.get('class'), -1)}",
            f"rarity = {rarity_values.get(record.get('rarity'), -1)}",
            "canonical_workbook_item = true",
            f'path="{record.get("texture_path", "")}"',
        )
        for fragment in expected_fragments:
            if fragment not in resource_text:
                errors.append(f"{resource}: missing canonical metadata {fragment}")

    catalog = ROOT / "data" / "items" / "layer_1_2_item_catalog.tres"
    if catalog.is_file():
        catalog_text = catalog.read_text(encoding="utf-8")
        catalog_paths = set(
            re.findall(
                r'path="res://(data/items/(?:layer_[12]|keys)/[^"]+\.tres)"',
                catalog_text,
            )
        )
        expected_paths = {
            resource.relative_to(ROOT).as_posix()
            for resource in canonical_resources.values()
        }
        legacy_blanket_resource = discovered.get("quiet_cell_blanket")
        if legacy_blanket_resource is not None:
            expected_paths.add(
                legacy_blanket_resource.relative_to(ROOT).as_posix()
            )
        if catalog_paths != expected_paths:
            missing_paths = sorted(expected_paths - catalog_paths)
            extra_paths = sorted(catalog_paths - expected_paths)
            if missing_paths:
                errors.append(
                    f"{catalog}: missing item resources: "
                    + ", ".join(missing_paths)
                )
            if extra_paths:
                errors.append(
                    f"{catalog}: unexpected item resources: "
                    + ", ".join(extra_paths)
                )

    active_presentation_resources = (
        (
            ROOT
            / "data"
            / "exploration"
            / "item_pools"
            / "layer1"
            / "warm_wine_flask_room_entry.tres",
            "res://assets/items/by_stable_id/l01_warm_wine_flask.png",
            "res://data/items/layer_1/warm_wine_flask.tres",
        ),
        (
            ROOT
            / "data"
            / "exploration"
            / "item_pools"
            / "layer1"
            / "rusty_key_room_entry.tres",
            "res://assets/items/by_stable_id/shared_rusty_key.png",
            "res://data/items/keys/rusty_key.tres",
        ),
        (
            ROOT
            / "data"
            / "exploration"
            / "events"
            / "entries"
            / "red_wax_vial_entry.tres",
            "res://assets/items/by_stable_id/l01_red_wax_ampoule.png",
            None,
        ),
    )
    for resource, expected_texture, expected_item in active_presentation_resources:
        if not resource.is_file():
            errors.append(f"missing active item presentation resource: {resource}")
            continue
        resource_text = resource.read_text(encoding="utf-8")
        if f'path="{expected_texture}"' not in resource_text:
            errors.append(
                f"{resource}: active presentation must use {expected_texture}"
            )
        if expected_item is not None and f'path="{expected_item}"' not in resource_text:
            errors.append(
                f"{resource}: active pickup must resolve {expected_item}"
            )

    legacy_ids = {
        Path(str(item.get("source_path", ""))).stem
        for item in manifest_by_id.values()
        if item.get("source_kind") == "existing_project_item"
    }
    migration_file = ROOT / "scripts" / "refuge" / "campaign_save_store.gd"
    migration_text = migration_file.read_text(encoding="utf-8")
    if '"quiet_cell_blanket": true' not in migration_text:
        errors.append(
            f"{migration_file}: legacy Quiet Cell Blanket is not retained"
        )
    for source_root in (ROOT / "scripts", ROOT / "data", ROOT / "tests"):
        for source in source_root.rglob("*"):
            if (
                not source.is_file()
                or source.suffix not in {".gd", ".tres", ".tscn"}
                or source == migration_file
            ):
                continue
            source_text = source.read_text(encoding="utf-8")
            for legacy_id in legacy_ids:
                if legacy_id == "quiet_shackle" and (
                    source.is_relative_to(ROOT / "data" / "rooms")
                    or source.name == "test_layer_room_registry.gd"
                ):
                    continue
                if (
                    f'&"{legacy_id}"' in source_text
                    or re.search(
                        rf'"item_id"\s*:\s*"{re.escape(legacy_id)}"',
                        source_text,
                    )
                ):
                    errors.append(
                        f"{source}: active legacy item ID remains: {legacy_id}"
                    )

    item_scene = (
        ROOT
        / "scenes"
        / "battle"
        / "ui"
        / "reusable"
        / "components"
        / "item_bar_view.tscn"
    )
    battle_scene = ROOT / "scenes" / "battle" / "combat_encounter.tscn"
    inventory_script = (
        ROOT
        / "scripts"
        / "battle"
        / "items"
        / "six_slot_inventory_state.gd"
    )
    if inventory_script.is_file():
        inventory_text = inventory_script.read_text(encoding="utf-8")
        if not re.search(
            r"^const SLOT_COUNT: int = 6$",
            inventory_text,
            re.MULTILINE,
        ):
            errors.append(
                f"{inventory_script}: SLOT_COUNT must remain exactly six"
            )
    run_inventory_script = ROOT / "scripts" / "map" / "run_inventory_state.gd"
    if not run_inventory_script.is_file():
        errors.append(f"missing run inventory state: {run_inventory_script}")
    else:
        run_inventory_text = run_inventory_script.read_text(encoding="utf-8")
        for fragment in (
            "const ITEM_BAR_SLOT_COUNT: int = 6",
            "const BACKPACK_SLOT_COUNT: int = 15",
            "func move_backpack_to_item_bar(",
            "func move_item_bar_to_backpack(",
            "func add_to_key_chain(",
            "func add_to_material_pouch(",
            "func assign_memento(",
            "func route_reward(",
            "canonical_workbook_item",
        ):
            if fragment not in run_inventory_text:
                errors.append(
                    f"{run_inventory_script}: missing Milestone 3 contract "
                    f"{fragment.rstrip('(')}"
                )
    run_state_path = ROOT / "scripts" / "map" / "run_state.gd"
    if run_state_path.is_file():
        run_state_text = run_state_path.read_text(encoding="utf-8")
        for fragment in (
            "var run_inventory: RunInventoryState",
            "run_inventory.initialize(",
            "func get_run_inventory_snapshot(",
            "run_inventory.route_reward(",
        ):
            if fragment not in run_state_text:
                errors.append(
                    f"{run_state_path}: missing RunInventoryState ownership "
                    f"{fragment.rstrip('(')}"
                )
    event_room_path = ROOT / "scripts" / "exploration" / "event_room_screen.gd"
    if event_room_path.is_file():
        event_room_text = event_room_path.read_text(encoding="utf-8")
        for fragment in (
            "run_inventory.route_reward(",
            "run_inventory.consume_key(",
            "outcome.run_inventory_snapshot = run_inventory.get_snapshot()",
        ):
            if fragment not in event_room_text:
                errors.append(
                    f"{event_room_path}: missing carried-domain integration "
                    f"{fragment.rstrip('(')}"
                )
    if item_scene.is_file():
        item_scene_text = item_scene.read_text(encoding="utf-8")
        for slot_number in range(1, 7):
            if not re.search(
                rf'^\[node name="Slot{slot_number}" type="Button" ',
                item_scene_text,
                re.MULTILINE,
            ):
                errors.append(
                    f"{item_scene}: missing persistent Item Bar Slot"
                    f"{slot_number}"
                )
    if battle_scene.is_file():
        battle_scene_text = battle_scene.read_text(encoding="utf-8")
        reusable_hud_path = (
            ROOT
            / "scenes"
            / "battle"
            / "ui"
            / "reusable"
            / "combat_hud.tscn"
        )
        reusable_hud_text = (
            reusable_hud_path.read_text(encoding="utf-8")
            if reusable_hud_path.is_file()
            else ""
        )
        if (
            'path="res://scenes/battle/ui/reusable/combat_hud.tscn"'
            not in battle_scene_text
            or '[node name="ItemBar"' not in reusable_hud_text
        ):
            errors.append(
                f"{battle_scene}: reusable ItemBar scene is not instantiated"
            )


def validate_reward_sources(errors: list[str]) -> None:
    source_directory = ROOT / "data" / "rewards" / "sources"
    expected_sources = {
        "demo_map_item_cache": (0, (1, 2)),
        "l01_linen_sorting_servant_cloth": (4, (1,)),
        "l01_wax_prep_red_wax_material": (4, (1,)),
        "l02_kept_watch_chain_oil": (1, (2,)),
        "l02_polished_gallery_chain_links": (4, (2,)),
        "l02_punishment_room_prison_iron": (4, (2,)),
        "layer_1_rusty_key_01": (2, (1,)),
        "m8_compat_bandage_cache": (0, (1, 2)),
    }
    discovered: dict[str, Path] = {}
    source_id_re = re.compile(r'^source_id = &"([^"]+)"$', re.MULTILINE)
    for resource in sorted(source_directory.glob("*.tres")):
        text = resource.read_text(encoding="utf-8")
        match = source_id_re.search(text)
        if match is None:
            errors.append(f"{resource}: reward source has no explicit source_id")
            continue
        source_id = match.group(1)
        if source_id in discovered:
            errors.append(
                f"duplicate reward source_id {source_id}: "
                f"{discovered[source_id]} and {resource}"
            )
        discovered[source_id] = resource
        for fragment in (
            "source_channel = ",
            "eligible_layers = Array[int]",
            "once_only = true",
            "pool = ExtResource",
        ):
            if fragment not in text:
                errors.append(f"{resource}: missing reward metadata {fragment}")
        if "quiet_cell_blanket" in text:
            errors.append(f"{resource}: legacy Quiet Cell Blanket is reward-eligible")

    if set(discovered) != set(expected_sources):
        errors.append(
            "production reward source resources do not match the authored "
            "source set"
        )
    for source_id, (channel, layers) in expected_sources.items():
        resource = discovered.get(source_id)
        if resource is None:
            continue
        text = resource.read_text(encoding="utf-8")
        expected_layers = ", ".join(str(layer) for layer in layers)
        for fragment in (
            f"source_channel = {channel}",
            f"eligible_layers = Array[int]([{expected_layers}])",
        ):
            if fragment not in text:
                errors.append(f"{resource}: missing locked metadata {fragment}")

    catalog = ROOT / "data" / "rewards" / "reward_source_catalog.tres"
    catalog_text = catalog.read_text(encoding="utf-8") if catalog.is_file() else ""
    required_catalog_paths = (
        "data/rewards/sources/demo_map_item_cache.tres",
        "data/rewards/sources/l02_kept_watch_chain_oil.tres",
        "data/rewards/sources/layer1_rusty_key.tres",
        "data/rewards/sources/m8_compat_bandage_cache.tres",
        "data/rewards/sources/l01_wax_prep_red_wax_material.tres",
        "data/rewards/sources/l01_linen_sorting_servant_cloth.tres",
        "data/rewards/sources/l02_polished_gallery_chain_links.tres",
        "data/rewards/sources/l02_punishment_room_prison_iron.tres",
        "data/exploration/loot_sources/wine_cellar_specific_sources.tres",
        "data/exploration/loot_sources/butlers_office_specific_sources.tres",
        "data/exploration/loot_sources/layer_1_common_sources.tres",
    )
    for resource_path in required_catalog_paths:
        if f'path="res://{resource_path}"' not in catalog_text:
            errors.append(f"{catalog}: missing source res://{resource_path}")

    implementation_contracts = {
        ROOT / "scripts" / "exploration" / "items" / "reward_source_resolver.gd": (
            'const SEED_NAMESPACE: StringName = &"reward_source_selection"',
            "const CURRENT_LAYER_WEIGHT_MULTIPLIER: int = 3",
            "entry.item.layer == current_layer",
            "func validate_resolution_record(",
        ),
        ROOT / "scripts" / "map" / "run_state.gd": (
            "var reward_resolutions: Dictionary = {}",
            '"reward_resolutions": reward_resolutions.duplicate(true)',
            "func retry_deferred_reward(",
            "run_inventory.route_reward(",
        ),
        ROOT / "scripts" / "exploration" / "event_room_screen.gd": (
            "RewardSourceResolver.resolve(",
            'assignment["deferred"] = true',
            'assignment["claimed"] = true',
        ),
        ROOT / "scripts" / "exploration" / "generated_items" / "generated_room_item_placement_rule.gd": (
            "@export var reward_source: RoomLootSourceDefinition",
        ),
    }
    for path, fragments in implementation_contracts.items():
        if not path.is_file():
            errors.append(f"missing reward implementation: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{path}: missing reward contract {fragment}")


def validate_item_sprite_library(errors: list[str]) -> None:
    manifest_path = ROOT / "data" / "items" / "item_sprite_manifest.json"
    texture_root = ROOT / "assets" / "items" / "by_stable_id"
    expected_count = 126

    if not manifest_path.is_file():
        errors.append(f"missing Stable-ID item sprite manifest: {manifest_path}")
        return
    if not texture_root.is_dir():
        errors.append(f"missing Stable-ID item sprite directory: {texture_root}")
        return

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"{manifest_path}: invalid JSON: {error}")
        return

    if manifest.get("canonical_item_count") != expected_count:
        errors.append(
            f"{manifest_path}: canonical_item_count must be {expected_count}"
        )
    items = manifest.get("items")
    if not isinstance(items, list):
        errors.append(f"{manifest_path}: items must be an array")
        return
    if len(items) != expected_count:
        errors.append(
            f"{manifest_path}: expected {expected_count} item records, "
            f"found {len(items)}"
        )

    stable_id_re = re.compile(r"^[a-z0-9_]+$")
    seen_ids: set[str] = set()
    expected_files: set[Path] = set()
    forbidden_metadata_chunks = {b"tEXt", b"zTXt", b"iTXt", b"eXIf"}

    for index, item in enumerate(items):
        if not isinstance(item, dict):
            errors.append(f"{manifest_path}: item record {index} is not an object")
            continue
        stable_id = item.get("stable_id")
        if not isinstance(stable_id, str) or not stable_id_re.fullmatch(stable_id):
            errors.append(
                f"{manifest_path}: item record {index} has an invalid Stable ID"
            )
            continue
        if stable_id in seen_ids:
            errors.append(f"{manifest_path}: duplicate Stable ID {stable_id}")
        seen_ids.add(stable_id)

        expected_texture_path = (
            f"res://assets/items/by_stable_id/{stable_id}.png"
        )
        if item.get("texture_path") != expected_texture_path:
            errors.append(
                f"{manifest_path}: {stable_id} must use "
                f"{expected_texture_path}"
            )
        layer = item.get("layer")
        if not isinstance(layer, int) or layer not in range(1, 11):
            errors.append(f"{manifest_path}: {stable_id} has invalid Layer {layer}")

        image_path = texture_root / f"{stable_id}.png"
        expected_files.add(image_path)
        if not image_path.is_file():
            errors.append(f"missing Stable-ID item sprite: {image_path}")
            continue
        try:
            image_bytes = image_path.read_bytes()
        except OSError as error:
            errors.append(f"{image_path}: could not be read: {error}")
            continue

        expected_hash = item.get("runtime_sha256")
        actual_hash = hashlib.sha256(image_bytes).hexdigest()
        if expected_hash != actual_hash:
            errors.append(
                f"{image_path}: SHA-256 differs from the approved manifest"
            )
        if image_bytes[:8] != b"\x89PNG\r\n\x1a\n":
            errors.append(f"{image_path}: invalid PNG signature")
            continue
        if image_bytes[12:16] != b"IHDR" or len(image_bytes) < 33:
            errors.append(f"{image_path}: missing PNG IHDR")
            continue

        width, height, bit_depth, color_type, _, _, _ = struct.unpack(
            ">IIBBBBB", image_bytes[16:29]
        )
        if (width, height, bit_depth, color_type) != (512, 512, 8, 6):
            errors.append(
                f"{image_path}: expected 512x512 8-bit RGBA PNG, found "
                f"{width}x{height}, bit depth {bit_depth}, color type "
                f"{color_type}"
            )

        offset = 8
        while offset + 12 <= len(image_bytes):
            chunk_length = struct.unpack(">I", image_bytes[offset : offset + 4])[0]
            chunk_type = image_bytes[offset + 4 : offset + 8]
            chunk_end = offset + 12 + chunk_length
            if chunk_end > len(image_bytes):
                errors.append(f"{image_path}: truncated PNG chunk")
                break
            if chunk_type in forbidden_metadata_chunks:
                errors.append(
                    f"{image_path}: metadata chunk {chunk_type.decode()} "
                    "should be stripped"
                )
            offset = chunk_end
            if chunk_type == b"IEND":
                break

    actual_files = set(texture_root.glob("*.png"))
    unexpected_files = sorted(actual_files - expected_files)
    if unexpected_files:
        errors.append(
            "unregistered Stable-ID item sprites: "
            + ", ".join(path.name for path in unexpected_files)
        )
    non_png_files = sorted(
        path
        for path in texture_root.iterdir()
        if path.suffix != ".png"
        and not (
            path.name.endswith(".png.import")
            and path.with_suffix("").is_file()
        )
    )
    if non_png_files:
        errors.append(
            "non-PNG files in the Stable-ID item sprite directory: "
            + ", ".join(path.name for path in non_png_files)
        )


def validate_layer_room_registry(errors: list[str]) -> None:
    room_root = ROOT / "data" / "rooms"
    catalog = room_root / "layer_1_2_room_catalog.tres"
    expected_ids = {
        1: (
            "opening_servant_corridor",
            "servant_ledger_alcove",
            "wine_cellar_warm_bottles",
            "servant_dormitory",
            "ruined_confessional",
            "coat_beside_service_door",
            "ruined_chapel",
            "blood_nun_processing_chapel",
            "lower_kitchen",
            "cold_pantry",
            "linen_sorting_room",
            "bell_pull_gallery",
            "butlers_office",
            "dishwashing_hall",
            "service_stair_landing",
            "wax_prep_room",
            "abandoned_guest_bedroom",
            "laundry_boiler_room",
            "dining_service_hall",
            "sorting_vestibule",
        ),
        2: (
            "offering_list_room",
            "rusted_key_cell",
            "false_safe_cell",
            "quiet_shackle",
            "empty_mens_cell",
            "farthest_cell",
            "jailers_gate_hall",
            "jailers_containment_hall",
            "intake_corridor",
            "chain_maintenance_room",
            "guard_station_without_guards",
            "cell_block_crossroads",
            "polished_shackle_gallery",
            "prison_infirmary",
            "isolation_cell",
            "communal_prison_hall",
            "drainage_passage",
            "punishment_mechanism_room",
            "wardens_records_office",
            "sealed_exercise_yard",
        ),
    }
    room_id_re = re.compile(r'^room_id = &"([^"]+)"$', re.MULTILINE)
    layer_re = re.compile(r"^layer_number = ([0-9]+)$", re.MULTILINE)
    order_re = re.compile(r"^canonical_order = ([0-9]+)$", re.MULTILINE)
    texture_re = re.compile(
        r'path="res://(assets/backgrounds/layer_[12]/sdxl_curated/[^"]+\.png)"'
    )
    registered_paths: set[Path] = set()
    discovered: dict[int, list[tuple[int, str]]] = {1: [], 2: []}
    seen_ids: set[str] = set()
    room_texts: dict[Path, str] = {}

    for layer in (1, 2):
        layer_directory = room_root / f"layer_{layer}"
        if not layer_directory.is_dir():
            errors.append(f"missing Layer room directory: {layer_directory}")
            continue
        resources = sorted(layer_directory.glob("*.tres"))
        if len(resources) != 20:
            errors.append(
                f"{layer_directory}: expected 20 room resources, "
                f"found {len(resources)}"
            )
        for resource in resources:
            text = resource.read_text(encoding="utf-8")
            room_texts[resource] = text
            id_match = room_id_re.search(text)
            layer_match = layer_re.search(text)
            order_match = order_re.search(text)
            if id_match is None or layer_match is None or order_match is None:
                errors.append(f"{resource}: incomplete Layer room identity")
                continue
            room_id = id_match.group(1)
            authored_layer = int(layer_match.group(1))
            canonical_order = int(order_match.group(1))
            if room_id in seen_ids:
                errors.append(f"duplicate registered Layer room_id: {room_id}")
            seen_ids.add(room_id)
            if authored_layer != layer:
                errors.append(
                    f"{resource}: authored Layer {authored_layer}, "
                    f"but stored in layer_{layer}"
                )
            discovered[layer].append((canonical_order, room_id))
            for texture_match in texture_re.finditer(text):
                registered_paths.add(ROOT / texture_match.group(1))

    for layer, ids in expected_ids.items():
        actual_ids = tuple(
            room_id for _, room_id in sorted(discovered[layer])
        )
        if actual_ids != ids:
            errors.append(
                f"Layer {layer} room registry order/IDs differ from "
                "the canonical twenty-room list"
            )

    if not catalog.is_file():
        errors.append(f"missing Layer room catalog: {catalog}")
    else:
        catalog_text = catalog.read_text(encoding="utf-8")
        catalog_paths = {
            ROOT / path
            for path in re.findall(
                r'path="res://(data/rooms/layer_[12]/[^"]+\.tres)"',
                catalog_text,
            )
        }
        expected_room_paths = set(room_texts)
        if catalog_paths != expected_room_paths:
            errors.append(
                f"{catalog}: entries do not exactly cover the forty "
                "Layer 1–2 room resources"
            )

    delivered_paths = set()
    for layer in (1, 2):
        delivered_paths.update(
            (ROOT / "assets" / "backgrounds" / f"layer_{layer}" / "sdxl_curated")
            .glob("*.png")
        )
    if registered_paths != delivered_paths:
        missing = sorted(delivered_paths - registered_paths)
        extra = sorted(registered_paths - delivered_paths)
        if missing:
            errors.append(
                "delivered L1–2 backgrounds absent from the room registry: "
                + ", ".join(path.name for path in missing)
            )
        if extra:
            errors.append(
                "room registry references non-delivered backgrounds: "
                + ", ".join(path.name for path in extra)
            )

    for image in sorted(delivered_paths):
        try:
            header = image.read_bytes()[:24]
            if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) < 24:
                errors.append(f"{image}: invalid registered PNG")
                continue
            width, height = struct.unpack(">II", header[16:24])
            if width < 1280 or height < 720:
                errors.append(
                    f"{image}: registered room background is only "
                    f"{width}x{height}"
                )
        except OSError as error:
            errors.append(f"{image}: could not inspect registered PNG: {error}")

    visual_count = sum(
        len(re.findall(r'^variant_id = &"', text, re.MULTILINE))
        for text in room_texts.values()
    )
    pending_resources = [
        resource
        for resource, text in room_texts.items()
        if "art_pending = true" in text
    ]
    if visual_count != 43:
        errors.append(
            f"Layer room registry requires 43 visual variants, found {visual_count}"
        )
    expected_pending = room_root / "layer_2" / "09_intake_corridor.tres"
    if pending_resources != [expected_pending]:
        errors.append(
            "only Layer 2 Intake Corridor may remain art-pending in the registry"
        )

    exploration_link_count = sum(
        "exploration_definition = " in text for text in room_texts.values()
    )
    production_link_count = sum(
        "production_battlefields = Array[PackedScene]" in text
        for text in room_texts.values()
    )
    template_link_count = sum(
        "battlefield_authoring_templates = Array[PackedScene]" in text
        for text in room_texts.values()
    )
    if exploration_link_count != 39:
        errors.append(
            "Layer room registry must author exploration presentations for "
            "all 39 rooms with available art"
        )
    if production_link_count != 7:
        errors.append("Layer room registry must preserve seven battlefield links")
    if template_link_count != 2:
        errors.append("Layer room registry must preserve two authoring templates")

    generator = ROOT / "scripts" / "map" / "layer_map_generator.gd"
    node_state = ROOT / "scripts" / "map" / "map_node_state.gd"
    regression_suite = ROOT / "tools" / "run_regression_suite.py"
    activation_checks = (
        (
            generator,
            (
                "layer_1_2_room_catalog.tres",
                "func generate_layer_1(",
                "func generate_layer_2_run(",
                "func validate_generated_layer(",
                "MIN_PLAYABLE_NODES: int = 10",
                "MAX_PLAYABLE_NODES: int = 13",
                "StableSeedMixer.make_seed(",
                "func _configure_registered_room_content(",
            ),
        ),
        (
            node_state,
            (
                "var authored_room_id: StringName",
                "var content_seed: int",
                '"authored_room_id": String(authored_room_id)',
                '"content_seed": content_seed',
            ),
        ),
        (
            regression_suite,
            ('"tests/test_layer_generator_activation.gd"',),
        ),
    )
    for path, fragments in activation_checks:
        if not path.is_file():
            errors.append(f"missing generator-activation file: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(
                    f"{path}: missing Layer 1–2 generator contract {fragment}"
                )


def validate_layer_2_first_slice_and_backgrounds(errors: list[str]) -> None:
    required_files = (
        ROOT / "tests" / "test_layer_2_first_slice.gd",
        ROOT / "data" / "battlers" / "enemies" / "chain_thrall.tres",
        ROOT / "data" / "battlers" / "enemies" / "iron_masked_guard.tres",
        ROOT / "data" / "enemy_ai" / "chain_thrall_rulebook.tres",
        ROOT / "data" / "enemy_ai" / "iron_masked_guard_rulebook.tres",
        ROOT / "data" / "enemy_ai" / "layer2_kept_watch_group_rulebook.tres",
        ROOT / "data" / "grapples" / "chain_thrall_restraint.tres",
        ROOT / "data" / "encounters" / "layer2_chain_maintenance_template.tres",
        ROOT / "scenes" / "battle" / "battlefields" / "layer2_chain_maintenance_battlefield.tscn",
        ROOT / "docs" / "LAYER_2_FIRST_SLICE_AND_SDXL_BACKGROUND_INTEGRATION_2026-08-12.md",
    )
    for required in required_files:
        if not required.is_file():
            errors.append(f"missing Layer 2 first-slice file: {required}")

    generator = ROOT / "scripts" / "map" / "layer_map_generator.gd"
    run_state = ROOT / "scripts" / "map" / "run_state.gd"
    main_controller = ROOT / "scripts" / "map" / "main_controller.gd"
    battler_catalog = ROOT / "data" / "battlers" / "battler_catalog.tres"
    regression_suite = ROOT / "tools" / "run_regression_suite.py"
    checks = (
        (
            generator,
            (
                "layer_2_farthest_cell_kept_watch",
                "Farthest Cell Passage — Kept Watch",
                'first_node.reward_source_id = &"l02_kept_watch_chain_oil"',
                "func generate_layer_2_run(",
            ),
        ),
        (
            run_state,
            (
                "LAYER_2_CHAIN_MAINTENANCE_TEMPLATE",
                'return [&"iron_masked_guard", &"chain_thrall"]',
                "resolved_node.reward_source_id",
                "run_inventory.route_reward(",
            ),
        ),
        (
            main_controller,
            ('return_to_map_button.text = "Return to the Bloom Refuge"',),
        ),
        (
            battler_catalog,
            (
                "res://data/battlers/enemies/chain_thrall.tres",
                "res://data/battlers/enemies/iron_masked_guard.tres",
            ),
        ),
        (
            regression_suite,
            ('"tests/test_layer_2_first_slice.gd"',),
        ),
    )
    for path, fragments in checks:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in text:
                errors.append(f"{path}: missing first-slice contract {fragment}")

    expected_background_counts = {
        ROOT / "assets" / "backgrounds" / "layer_1" / "sdxl_curated": 21,
        ROOT / "assets" / "backgrounds" / "layer_2" / "sdxl_curated": 21,
    }
    for directory, expected_count in expected_background_counts.items():
        images = sorted(directory.glob("*.png")) if directory.is_dir() else []
        if len(images) != expected_count:
            errors.append(
                f"{directory}: expected {expected_count} curated PNGs; "
                f"found {len(images)}"
            )
        for image in images:
            try:
                with image.open("rb") as handle:
                    header = handle.read(24)
                if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) < 24:
                    errors.append(f"{image}: invalid PNG header")
                    continue
                width, height = struct.unpack(">II", header[16:24])
                if (width, height) != (1344, 768):
                    errors.append(
                        f"{image}: expected native 1344x768; "
                        f"found {width}x{height}"
                    )
            except OSError as error:
                errors.append(f"{image}: could not inspect PNG: {error}")


def validate_node_map(errors: list[str]) -> None:
    project_file = ROOT / "project.godot"
    main_scene = ROOT / "scenes" / "main" / "main.tscn"
    battle_script = (
        ROOT / "scripts" / "battle" / "encounter_coordinator.gd"
    )
    generator = ROOT / "scripts" / "map" / "layer_map_generator.gd"
    run_state = ROOT / "scripts" / "map" / "run_state.gd"
    main_controller = ROOT / "scripts" / "map" / "main_controller.gd"

    if project_file.is_file():
        project_text = project_file.read_text(encoding="utf-8")
        expected_entry = (
            'run/main_scene="res://scenes/app/application_root.tscn"'
        )
        if expected_entry not in project_text:
            errors.append(
                f"{project_file}: the application root must remain the "
                "explicit main scene for Web Editor imports"
            )

    if main_scene.is_file():
        main_text = main_scene.read_text(encoding="utf-8")
        required_nodes = {
            "MapScreen",
            "MapView",
            "Travel",
            "Resolve",
            "CombatHost",
            "ReturnOverlay",
        }
        authored_nodes = {
            name for name, _parent in NODE_RE.findall(main_text)
        }
        for node_name in sorted(required_nodes - authored_nodes):
            errors.append(
                f"{main_scene}: missing Node Map UI node {node_name}"
            )
        if (
            'path="res://scenes/battle/combat_encounter.tscn"'
            not in main_text
        ):
            errors.append(
                f"{main_scene}: production combat encounter scene is missing"
            )
        if (
            '[node name="Controller" type="Node" parent="."'
            not in main_text
        ):
            errors.append(
                f"{main_scene}: Node Map controller must remain isolated "
                "from the scene root"
            )
        if '[node name="BootFallback"' not in main_text:
            errors.append(
                f"{main_scene}: visible startup diagnostic is missing"
            )
        for label_name in ("Description", "Summary", "Status"):
            label_match = re.search(
                rf'^\[node name="{label_name}" type="Label"[^\n]*\]\n'
                rf'(?P<body>.*?)(?=^\[node |\Z)',
                main_text,
                re.MULTILINE | re.DOTALL,
            )
            if label_match is None:
                errors.append(
                    f"{main_scene}: missing wrapped Label {label_name}"
                )
                continue
            label_body = label_match.group("body")
            if "autowrap_mode = 2" not in label_body:
                errors.append(
                    f"{main_scene}: {label_name} must remain autowrapped"
                )
            if not re.search(
                r"custom_minimum_size = Vector2\([1-9][0-9]*(?:\.[0-9]+)?,",
                label_body,
            ):
                errors.append(
                    f"{main_scene}: autowrapped {label_name} requires a "
                    "positive custom minimum width"
                )

    if battle_script.is_file():
        battle_text = battle_script.read_text(encoding="utf-8")
        for required_fragment in (
            "signal encounter_outcome_ready",
            "func prepare_run_encounter(",
            "func _emit_encounter_outcome_if_ready(",
            "func _capture_party_run_snapshot(",
        ):
            if required_fragment not in battle_text:
                errors.append(
                    f"{battle_script}: missing map bridge "
                    f"{required_fragment.rstrip('(')}"
                )

    if main_controller.is_file():
        controller_text = main_controller.read_text(encoding="utf-8")
        if (
            "active_battle.base_seed = encounter.encounter_seed"
            not in controller_text
        ):
            errors.append(
                f"{main_controller}: Node Map does not pass the encounter "
                "seed to CombatEncounter.base_seed"
            )
        if "active_battle.test_seed" in controller_text:
            errors.append(
                f"{main_controller}: removed sandbox test_seed still blocks "
                "the battle transition"
            )
        for required_fragment in (
            "func _launch_blood_nun_aftermath(",
            "func _on_blood_nun_aftermath_ready(",
            "func _launch_refuge_origin(",
            "func _on_refuge_origin_ready(",
            "map_view.bind_map(run_state.graph, run_state)",
        ):
            if required_fragment not in controller_text:
                errors.append(
                    f"{main_controller}: missing Layer 1 closure bridge "
                    f"{required_fragment.rstrip('(')}"
                )

    if generator.is_file():
        generator_text = generator.read_text(encoding="utf-8")
        if "const COLUMN_COUNT: int = 7" not in generator_text:
            errors.append(
                f"{generator}: provisional Layer 1 map must use seven columns"
            )
        if '&"blood_nun_processing_chapel"' not in generator_text:
            errors.append(
                f"{generator}: fixed Layer 1 Blood Nun boss is missing"
            )
        for required_fragment in (
            "func validate_generated_layer(",
            "func generate_layer_2_entry(",
            "func generate_layer_2_run(",
            "func generate_layer_3_entry(",
            "func generate_bloom_refuge_holding_state(",
            "authored_room_id",
            "content_seed",
            "l2_jailer_first_encounter",
        ):
            if required_fragment not in generator_text:
                errors.append(
                    f"{generator}: corrected layer topology is missing "
                    f"{required_fragment.rstrip('(')}"
                )

    if run_state.is_file():
        run_text = run_state.read_text(encoding="utf-8")
        for required_fragment in (
            "func can_travel_to(",
            "func apply_encounter_outcome(",
            "reward_claimed",
            "inventory_snapshot",
            "party_snapshot",
        ):
            if required_fragment not in run_text:
                errors.append(
                    f"{run_state}: missing run-state contract "
                    f"{required_fragment.rstrip('(')}"
                )
        for required_fragment in (
            "func apply_blood_nun_aftermath(",
            "func begin_immediate_jailer_encounter(",
            "func apply_first_jailer_defeat_and_refuge_origin(",
            "completed_layer_ids",
            "LAYER_1_COMPLETED_FLAG_ID",
            "REFUGE_EVER_ESTABLISHED_FLAG_ID",
        ):
            if required_fragment not in run_text:
                errors.append(
                    f"{run_state}: missing atomic layer-transition contract "
                    f"{required_fragment.rstrip('(')}"
                )


if __name__ == "__main__":
    sys.exit(main())
