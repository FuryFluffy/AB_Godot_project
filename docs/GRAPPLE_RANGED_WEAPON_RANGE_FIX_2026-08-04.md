# Grapple Ranged-Weapon Range Fix — 2026-08-04

## Problem

Corrupted Butler's `Silver Tray` is an ordinary ranged weapon. Grapple
initiation reused the equipped main-hand weapon for both the Grapple dice pool
and its targeting check. As a result, `Courteous Embrace` inherited ranged
weapon legality and could target a heroine in an unlinked Position.

## Correction

`GrappleController` now resolves a dedicated legal Grapple weapon:

- a usable melee main-hand weapon remains valid;
- a usable Reach main-hand weapon remains valid and keeps authored Reach range;
- a ranged, broken, or absent main-hand weapon falls through to a generic
  Unarmed/Might melee Grapple check.

Therefore Corrupted Butler may still use `Silver Tray` for ordinary ranged
Attacks, but Grapple requires actual Adjacency: the same Anchor or an authored
Position contact. The ranged tray no longer extends Grapple range.

## Regression coverage

`test_position_contacts.gd` now verifies that Corrupted Butler cannot initiate
Grapple from a connected Anchor whose exact Position has no contact, then can
initiate after moving into the heroine's Anchor.
