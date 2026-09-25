# Layer 2 First Slice and SDXL Background Integration

**Date:** 2026-08-12  
**Godot target:** 4.7  
**Base:** runtime-confirmed Milestone 18 campaign lifecycle checkpoint

## Playable Layer 2 slice

- Ordinary Refuge runs begin at the farthest Layer 2 cell.
- `Farthest Cell Passage — Kept Watch` is the first unlocked route node.
- Its encounter contains one Chain Thrall and one Iron-Masked Guard.
- Chain Thrall is a restraint/control Standard with a three-stage Grapple.
- Iron-Masked Guard is a durable plate frontline Standard.
- First victory grants 4 Bloom and one Chain Oil.
- The reward can use an existing Chain Oil stack or an empty Item Bar slot.
- The node and reward are non-farmable within the run.
- Deeper Layer 2 nodes remain visible but locked.
- The unresolved Jailer remains at the Dungeon exit; a permanently defeated Jailer remains cleared.
- Ordinary defeat in a Refuge campaign returns the party to the Bloom Refuge.

All numerical enemy values are provisional content tuning. The Jailer and campaign lifecycle were not rebalanced or rewritten.

## Background integration

- Added 21 curated Layer 1 SDXL winners.
- Added 21 curated Layer 2 SDXL winners.
- Backups and contact sheets are intentionally excluded from the runtime project.
- `Chain Maintenance Room` is the first ordinary Layer 2 battlefield.
- All currently player-facing Layer 1 and Layer 2 backgrounds now reference the curated winner set.
- The supplied images remain at native `1344×768` resolution.
- Battle and dialogue backdrops use aspect-preserving cover presentation against the authored `1920×1080` coordinate space.
- Interactive Layer 1 room backgrounds use the same cover ratio; their existing hotspot layouts remain in the authored coordinate space.

Layer 2 Intake Corridor remains absent because the curated source archive did not contain that room.
