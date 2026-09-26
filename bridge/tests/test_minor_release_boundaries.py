"""H-RELEASE-C — what the authority must NOT require of a hosted minor.

All three source specs accept access the recorded latch never sees:

  EX50-033 §6  "A sufficiently strong jump or mobility tool can reach the
               open upper doorway before the crate is inserted. That is
               a valid shortcut."
  EX50-021 §6  "A sufficiently capable route to the upper flank may
               bypass the receiver entirely if the physical landing is
               legal. The goal should accept that access."
  EX50-011 §6  a qualified grapple or blink may reach the carrier the
               reference route boards.

And the owner: "A legitimately opened path cannot remain software-locked
solely because the player skipped one particular input order." The
minors' latches (bolt, release, stair) are the RETURN and the
permanence, not the reward. So the bridge must accept a minor's Check
with its latch unrecorded, and must not tie it to its gunner's fate.
World and authority agree because the goal is physically reachable only
on the gallery -- which is Prod's to build and test, not this file's.

These pin existing behaviour on the committed candidate Zone (Unweighted
at c024, Counterfire at c025), so a later "fix" that gated the claim on
a latch would fail here by name. No shared source is touched.
"""
from __future__ import annotations

import json
from pathlib import Path

from archipepsi_bridge.schemas import minors as M
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.zone import Zone

FIXTURE = (Path(__file__).resolve().parents[2]
           / "godot/tests/fixtures/candidate_zone.json")


def _zone() -> Zone:
    raw = json.loads(FIXTURE.read_text(encoding="utf-8"))
    return Zone.model_validate(raw.get("zone", raw))


def _save(zone: Zone) -> P.CampaignSave:
    top = max(zone.reward_location_ids) - 89100000
    save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=P.CampaignScale(location_count=max(top + 1, 30),
                              zone_target_checks=15, zone_budget=1000))
    save = T.start_generation(
        save, zone_id=zone.zone_id,
        allocated_location_ids=tuple(zone.reward_location_ids),
        target_game=zone.target_game)
    save = T.enter_zone(T.accept_zone(save, zone), zone.zone_id)
    return T.commit_layout(save, zone.zone_id, {
        "zone_id": zone.zone_id, "manifest_digest": "e" * 16,
        "rooms": {c.id: {} for c in zone.chambers}, "packages": []})


def _minor(zone: Zone, shell: str):
    return next(c for c in zone.chambers if c.shell_id == shell)


def test_a_minors_check_is_claimable_without_its_latch():
    """No input order: the bolt, the release and the stair are the way
    back, and a legal alternate reaches the goal without them."""
    zone = _zone()
    save = _save(zone)
    for shell in ("minor_unweighted_switch", "minor_counterfire_arcade"):
        room = _minor(zone, shell)
        rec = save.zone_by_id(zone.zone_id)
        assert not any(ref.startswith(M.latch_package(room.id))
                       for ref in rec.progress.latched)
        claimed = T.claim_zone_check(
            save, zone_id=zone.zone_id,
            location_id=room.reward_location_id,
            transaction_id=f"tx_{shell}")
        assert any(p.location_id == room.reward_location_id
                   for p in claimed.pending_checks), shell


def test_a_dead_gunner_strands_nothing():
    """EX50-021 §1: "Killing the gunner must not permanently remove the
    only way to finish the room." With the gunner recorded defeated,
    the Check is still claimable and the release is still recordable."""
    zone = _zone()
    room = _minor(zone, "minor_counterfire_arcade")
    save = T.record_defeat(_save(zone), zone.zone_id, f"{room.id}/ranged#0")
    assert save.zone_by_id(zone.zone_id).progress.defeated == (
        f"{room.id}/ranged#0",)
    claimed = T.claim_zone_check(
        save, zone_id=zone.zone_id, location_id=room.reward_location_id,
        transaction_id="tx_gunner_dead")
    assert any(p.location_id == room.reward_location_id
               for p in claimed.pending_checks)
    released = T.record_latch(claimed, zone.zone_id,
                              M.latch_package(room.id), "release")
    assert f"{M.latch_package(room.id)}/release" in released.zone_by_id(
        zone.zone_id).progress.latched


def test_every_minor_declares_the_latch_its_return_needs():
    """A DECLARATION check, not proof of a way back.

    Each contract must name a latch and say how the player returns. The
    physical return after EVERY accepted arrival -- reference or
    alternate -- is Prod's played acceptance (PT-07), and nothing here
    stands in for it."""
    for shell, contract in M.CONTRACTS.items():
        assert contract.latches, f"{shell} declares no return latch"
        assert "return" in contract.recovery.lower() or \
            "back" in contract.recovery.lower() or \
            "stair" in contract.recovery.lower(), (
            f"{shell}'s recovery never says how the player gets back")
