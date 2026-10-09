# Dining HUD and cinematic pilot — QA handoff

## Delivered scope

The Dining Service Hall stage alone opts into the native bottom HUD and cinematic presentation. The HUD has compact active-party cards, six shared item slots with structured quantity badges, contextual commands, and a Combat Log drawer. Popup clearance and camera-space pointer routing are integrated with the existing controllers. The original pilot supplies sword and Light Arrow effects, warm sprite lighting, shadows, and interpolated movement.

Main changes are under `scenes/battle/ui/reusable/`, `scripts/battle/presentation/`, `data/presentation/dining_hall_presentation.tres`, and `scripts/battle/encounter_coordinator.gd`. Focused tests are `tests/test_dining_presentation.gd` and `tests/test_dining_bottom_dock.gd`, registered in the regression runner. Standalone scene: `scenes/battle/dining_hall_presentation_pilot.tscn`.

No save/schema migration, room activation, registry migration, gameplay-rule change, or artwork replacement is included. Existing non-Dining encounters retain their HUD. The isolated branch excludes unrelated local content-workbench edits. The supplied ZIP had reference media but no UI patch, so the bottom HUD was implemented natively on the integrated original pilot.

## Verification already recorded

- Godot 4.7.2.stable.official.ed1daf0bf, TUXEDO OS 24.04.4, X11, Intel Iris Xe, Vulkan Forward+; production renderer unchanged. Desktop 1920x1080, 100% scaling. No performance claim.
- All 49 registered Godot runtime scripts ran individually with isolated user data: 49 exit 0, no script errors. Four Python tests passed.
- `python3 tools/validate_project.py --allow-generated-cache`: exit 1, 24 errors matching unchanged base `f3a573c`. These comprise Quiet Cell Blanket configuration (1), incomplete room identities (20), registry order/IDs (2), and missing registered backgrounds (1).
- `GODOT_BIN=/home/fluffy56/.local/bin/godot4 python3 tools/run_regression_suite.py`: exit 1 at the same validation prerequisite, before runtime tests.
- The encounter-startup shutdown warning (five ObjectDB instances and three resources still in use) was reproduced on the unchanged base. Clean shutdown is not claimed.
- Actual editor F6 pilot exercised movement, menus, Log, sword victory, Light Arrow cost (one Action and one MP), phase progression, and Grapple/Struggle.
- Actual Main Menu Load -> existing Refuge -> supported Layer 1 restart (seed 2) -> opening combat -> Butler/Mira recruitment -> Wax Preparation Room -> Dining was played using a copied save in an isolated user-data directory. Dining had two active heroines; Seraphine's recruitment is later in the normal route.
- Normal campaign checks included card selection, populated/empty items, Warm Wine consumption, legal/illegal sword targeting, Move/reposition, reactions/Parry, genuine Mira Grapple, Struggle, Wait, and Main Menu exit during sword playback. Continue after that exit has not been checked.
- Native layouts inspected at 1080 fullscreen, 900 window/fullscreen, and 720 window/fullscreen (including F6). Windowed 1080 was clamped by the window manager to 1852x1020; this is not an exact 1920x1080 window pass. Menu combinations were not exhaustively repeated in every mode.

Remaining manual QA was explicitly handed to the user on October 8. This is a test branch, not a claim of complete visual approval. No unresolved design decision blocks testing.

## Remaining manual checklist

Use a disposable save. Run the standalone scene with F6 and the normal campaign entry. For each issue, record resolution/mode, party, seed, exact clicks, expected/actual behavior, and a screenshot or short video.

- [ ] Inspect one-, two-, and three-hero layouts, clicking each card once and checking HP/MP, Resolve/Corruption, Action pips, focus, and tooltips against state. Geometry is automated; all party sizes still need visual sign-off.
- [ ] Inspect populated, empty, unavailable, selected, locked, and three-digit item quantities. Check target/cancel/consume and availability after unlock. Three-digit quantities may require a clearly labeled test fixture; do not change production stack rules.
- [ ] Exercise Begin/End Phase, Move preview/confirm and RMB/Esc cancel, legal/illegal attack/ability targets, and pointer accuracy while the camera moves. Move must cost one Action; Light Arrow one Action plus one MP.
- [ ] Inspect sword and Light Arrow hit, miss, and lethal results, including held target pose before impact and release afterward. Repeated inputs during playback must not resolve an action twice or advance phase early.
- [ ] Inspect every authored move destination, foreground feet/shadows, depth changes, enemy labels, impacts, and attached Grapple clusters during focus/zoom and camera restoration.
- [ ] Test Ability first open, reopen, changed content, close/cancel, AOE controls, and keyboard focus. Repeat with Log open; no popup should overlap the dock or strand an action.
- [ ] Test Log open/close/scroll while idle, targeting, and locked during effects. Its hitbox must not consume battlefield or unrelated command input.
- [ ] Exercise all supported reaction branches: counter, defend, Armor, Shield, Parry, Dodge, Skip, and equipment-break choices. Check placement and completion of the pending action.
- [ ] Exercise genuine Grapple escape and multiple simultaneous tracks, popup sizing, Wait, and Submit both gated and unlocked. Single-track Struggle/Wait were played; the broader matrix remains.
- [ ] Complete a normal campaign Dining victory, reward, and next-room transition. Standalone victory already occurred; campaign completion remains pending.
- [ ] Test defeat and return, then verify surviving/lost inventory follows existing rules.
- [ ] Continue after a mid-effect exit. Confirm pre-node recovery with the same content seed, restored inventory/state, and no camera/material/input leftovers. Exit was exercised; reload was not.
- [ ] Disable cinematic camera/effects through the profile in a disposable checkout and inspect unchanged tactical behavior. Automated coverage exists; native visual sign-off remains.
- [ ] Repeat layout/input/readability and popup combinations at 1920x1080, 1600x900, and 1280x720 windowed/fullscreen. Exact windowed 1080 remains unverified due to the local window manager clamp.
- [ ] Recheck a non-Dining encounter after completing Dining; opening/Butler retained the old HUD on the route in.

## Local evidence

Screenshots, actual-input videos, and logs remain outside source control at:

`/home/fluffy56/.codex/visualizations/2026/10/06/01a11210-8a23-7a52-a0f3-f000d048d95c/dining-qa/`

Useful files: `native/campaign-dining-battle.png`, `native/campaign-grapple-struggle.png`, `native/campaign-mid-effect-menu.png`, `native/popups-720-fullscreen.png`, `native/campaign-dining-input.mp4`, `native/sword-victory-input.mp4`, `runtime/results.json`, and `logs/validator.log`. Fixture captures, where present, are not normal campaign evidence. Save copies and diagnostic data are not uploaded.

Suggested implementation commit message: `Integrate Dining bottom HUD with cinematic pilot`.
