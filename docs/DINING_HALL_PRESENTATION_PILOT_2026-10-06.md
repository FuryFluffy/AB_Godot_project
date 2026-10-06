# Dining Service Hall presentation pilot

The Dining Service Hall now presents sword attacks and Seraphine's Light Arrow with a brief camera focus, an impact cue, and a return to the tactical view. Committed movement interpolates screen position and the existing authored depth scale. Soft contact shadows help ground the static character art.

## Try it in Godot 4.7

1. Open `scenes/battle/presentation/dining_hall_pilot.tscn` and run the current scene (F6).
2. Choose Order and begin the encounter using the existing controls.
3. Move Lysandra into a legal Position in the West Service Lane that contacts the Hollow Servant, then Attack. The camera focuses briefly, the slash lands, and the camera returns before resolution continues.
4. Restart the scene to try Light Arrow. Move Seraphine into a legal Position in the East Service Lane within the ability's existing range, then select Ability → Light Arrow → Hollow Servant.

The preview uses the current three heroines, one Hollow Servant, the existing template, equipment, poses and room art. A lethal sword attack may finish the encounter; restart to try the spell separately. The same presentation profile is also attached to the existing Dining Hall stage catalog entry, so normal Dining Hall encounters receive the pilot treatment.

## Presentation and compatibility

| Change | Implementation |
| --- | --- |
| Sword cue | Existing attack pose, additive slash/sparks, 12% camera zoom and a small impact shake |
| Light Arrow | Existing cast pose, animated floor ring, glowing arrow/trail, impact ring and temporary warm sprite contribution |
| Movement depth | Existing authored endpoints and scales interpolated over 0.42 seconds, using the existing move pose |
| Grounding | Soft procedural contact-shadow ellipses beneath profiled character art |
| HUD | Existing CanvasLayer stays fixed while the battlefield camera moves |

`data/presentation/dining_hall_presentation.tres` controls camera, smooth movement, contact shadows and effects independently. Removing the stage's `presentation_profile` restores its previous presentation. Other stages retain a null profile. There is no save-format migration or gameplay-data migration.

Combat rules resolve first; the presentation consumes their result. Damage, dice/RNG, target legality, authored Positions, action/MP costs, equipment break choices, Grapple and follow-up rules remain in their existing controllers. Only the target's damage/defeat pose is held until impact. HP/action HUD values still update immediately from authoritative state. Input and automatic continuation wait for the cue; repeated reaction callbacks are ignored while it plays. Resuming a Dodge step does not replay the same result's cue.

## Files

- `CombatPresentationProfile`, its Dining Hall resource, and optional `CombatStageDefinition` field define stage opt-in.
- `CombatPresentationDirector`, `CombatActionEffect`, and `spell_light.gdshader` own the camera, interpolation, shadows and temporary VFX.
- `encounter_coordinator.gd` composes and sequences presentation; `battle_marker.gd` supports delaying the result pose.
- `dining_hall_pilot.gd` / `.tscn` provide the playable scene.
- `tests/test_dining_presentation.gd` adds integration coverage and is registered in the regression runner.
- `tools/capture_dining_presentation.gd` provides reproducible rendered QA.

## Recorded QA

The capture fixture runs three fresh encounters: movement, sword, then Light Arrow. It places Lysandra at the existing `west_lane` Position index 1 for sword range and Seraphine at `east_lane` Position index 2 for spell range. These are capture setup placements, not changes to production spawn assignments. It then uses the normal command/target handlers and the existing enemy AI defenses. Movie playback is at the engine's recorded 60 FPS. No generated mockup frames appear in the recording.

Example (a desktop display is required):

```bash
godot --path . --rendering-method gl_compatibility --write-movie /absolute/path/dining.avi --fixed-fps 60 --script res://tools/capture_dining_presentation.gd
```

Set `AB_PILOT_CAPTURE_DIR` to an existing directory to also save tactical, movement, sword-impact, spell-flight and spell-impact PNGs.

## Validation and remaining review

- Godot 4.7.2 editor import: completed without script or shader parse errors.
- Focused integration test: passed, including exact movement endpoint/cost, real sword and spell resolution/costs, delayed target poses, duplicate callbacks, phase locking, camera/material restoration, stage scope, camera disable and encounter exit during a cue.
- All 48 registered regression scripts were run separately with the runner's isolated user/config/cache environment; each exited 0.
- The required `validate_project.py --allow-generated-cache` and `run_regression_suite.py` commands were run. Structural validation exits 1 before the suite starts because of existing Quiet Cell Blanket / canonical room-registry / background registration mismatches. Running the validator on the original `61a9167` checkout reports the same mismatches. Tests and validator expectations were not weakened.
- Existing shutdown messages report 5 ObjectDB instances and 3 resources still in use for encounter-based tests/captures; the same messages occur on the original checkout. The rendered capture has no runtime script or shader errors.
- The actual scene was rendered in Godot's Compatibility renderer and its movement, sword and spell frames were inspected, including fixed HUD framing. A human mouse/keyboard playtest on the target desktop is still required before merging.
- `git diff --check` and full scope review completed.

This is the first presentation pass. Art remains static PNG poses; the room remains a single background. Shadows and warm spell contribution are stylized 2D effects. New animation poses, room occlusion/parallax layers, physical lighting, sound, and additional attack/spell families require further authored work. No design blocker prevents reviewing this pilot.

Suggested commit message: `Add Dining Hall combat presentation pilot`.
