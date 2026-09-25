# Counterattack Engagement-Range Fix — 2026-08-03

## Runtime report

- Prayer-Rag Novice's corrected Dark Prayer profile works.
- Repeated attack rolls now vary as intended.
- Blood Nun could still Counterattack Seraphine from Far after both an ordinary Staff Attack and Light Arrow.

## Cause

Blood Nun's Flagellant's Lash is a Reach weapon. The shared spatial targeting rule correctly permits ordinary Reach Attacks across directly connected Anchors, including a cross-zone connection labelled Far. Counterattack availability reused that full Active-Attack range rule without applying an engagement restriction.

## Correction

- A non-ranged, non-magical Counterattack now requires the original attacker to be Adjacent in the same Anchor.
- Reach continues to work across directly connected Anchors for ordinary Active Attacks.
- Ranged and magical Counterattack weapons continue to use their normal authored range and line-of-sight rules.
- Counterattack legality is checked both when the reaction choice is offered and again before the generated Attack is queued.

## Regression coverage

The spatial suite now verifies that Blood Nun cannot use her Reach Lash to Counterattack a Far Staff Attack or Far Light Arrow, while the same Counterattack remains available when the attacker is Adjacent.
