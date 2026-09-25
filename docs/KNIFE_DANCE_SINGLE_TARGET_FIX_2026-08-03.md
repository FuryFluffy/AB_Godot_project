# Knife Dance Single-Target Fix — 2026-08-03

Knife Dance now attacks up to two distinct legal targets instead of requiring
two legal targets before selection may begin.

- When two or more legal targets exist, the player selects two different
  targets and each attack resolves separately as before.
- When only one legal target exists, selecting it immediately commits one
  attack.
- The same target can never be selected twice.
- Both versions cost 1 Action and 2 MP once.
- The one-target version retains Dagger family/rank properties, unique weapon
  effects, its independent attack roll and reaction, and +1 flat damage on a
  penetrating hit.

The generic ability Resource exposes
`allows_fewer_targets_when_unavailable`. It is enabled only for Knife Dance in
this checkpoint, so other future multi-target abilities may still require their
full authored target count.
