"""The bulwark's weakness has to be reachable with the base kit.

"Cannot be fought frontally" is only a brief if the other side can be
got to. A bulwark that tracked the player instantly would hold its
shield between them forever and the role would read as *immune* — and
the fix for that is not an Echo requirement, because this enemy is in
the ORDINARY, UNGATED pool and has to offer counterplay to a player
carrying the guaranteed kit.

So the tuning is three numbers — a bounded turn rate, a commitment, a
recovery — and `bulwark_opening()` states what they give the player in
degrees. These tests are what stop someone raising the turn rate until
the opening quietly closes.

**WHAT THESE TESTS ARE NOT.** They are geometry against the role brief.
A stationary DPS comparison is not proof of unbeatability and neither is
a synthetic front/back damage check; **the played acceptance is open**
and is the engine lane's: a continuous fight with real movement and
attacks, reaching `kill_all` completion. Nothing here closes that row.
"""

from __future__ import annotations

import inspect
import math

import pytest

from archipepsi_bridge.schemas import constants as C


def test_the_player_out_circles_it_by_movement_alone():
    """Without waiting for a swing.

    If this is zero or less the shield never leaves the player's face,
    the commitment window is the ONLY opening, and a player who never
    baits an attack has no answer at all. The margin is what makes
    flanking a thing you do rather than a thing that happens to you.
    """
    o = C.bulwark_opening()
    assert o["net_gain_deg_s"] > 0.0, (
        f"the bulwark turns at {C.BULWARK_TURN_RATE_DEG_S} deg/s and a "
        f"player at contact range circles it at {o['player_deg_s']:.0f} "
        "deg/s, so the shield stays in the player's face for as long as "
        "they keep moving — the role is immune, not armoured")
    assert o["net_gain_deg_s"] >= 40.0, (
        "the advantage is real but so thin that flanking depends on "
        "frame-perfect circling")


def test_clearing_the_shield_costs_something_and_is_not_hopeless():
    """Between free and impossible.

    Cheap enough and the armour is decoration; dear enough and the
    player is dead before the flank. One bulwark swing lands every
    `cooldown`, so the cost is measured in swings.
    """
    o = C.bulwark_opening()
    cooldown = C.ENEMY_STATS["bulwark"]["cooldown"]
    swings = o["seconds_to_clear_shield"] / cooldown
    assert 0.25 <= swings <= 1.0, (
        f"getting past the shield takes {swings:.2f} of a swing "
        f"({o['seconds_to_clear_shield']:.2f} s against a {cooldown} s "
        "cooldown), which is either free or a death sentence")


def test_one_commitment_hands_over_the_whole_back():
    """It cannot turn while committed, so the player gains the full
    angle rather than the difference — and 180 degrees of it is the
    difference between a flank and a back."""
    o = C.bulwark_opening()
    assert o["degrees_swept_committed"] >= 180.0, (
        f"a {o['no_turn_seconds']:.1f} s commitment only lets the player "
        f"sweep {o['degrees_swept_committed']:.0f} deg, so the swing "
        "that is supposed to be the opening does not reach the back")
    assert o["degrees_swept_committed_strafing"] >= 180.0, (
        "the opening survives at full walk speed and not under the 0.8 "
        "strafe allowance, so it depends on a player who circles "
        "without shooting")


def test_it_is_not_a_statue():
    """The other failure. A bulwark that never comes around makes
    standing behind it permanently safe, which is not counterplay
    either — it is a turret with a blind spot."""
    around = 180.0 / C.BULWARK_TURN_RATE_DEG_S
    assert around <= 2.5, (
        f"it takes {around:.1f} s to face someone who walked behind it "
        "and stopped, so the back is a safe room rather than an opening")


def test_the_opening_check_would_notice_instant_tracking():
    """Sabotage: the measurement has to DISCRIMINATE.

    An enemy that tracks the player instantly is exactly the thing the
    owner ruled out — "do not add an Echo requirement merely to excuse
    instant tracking that prevents its intended weakness being used" —
    so the check that permits the current tuning must refuse that one.
    """
    o = C.bulwark_opening()
    instant = o["player_deg_s"] + 1.0
    original = C.BULWARK_TURN_RATE_DEG_S
    try:
        C.BULWARK_TURN_RATE_DEG_S = instant
        assert C.bulwark_opening()["net_gain_deg_s"] < 0.0
        assert math.isinf(C.bulwark_opening()["seconds_to_clear_shield"]), (
            "a bulwark that out-turns the player reports a finite time "
            "to clear its shield, so the first test above would pass on "
            "an enemy nobody can flank")
    finally:
        C.BULWARK_TURN_RATE_DEG_S = original
    assert C.bulwark_opening()["net_gain_deg_s"] > 0.0


def test_the_three_numbers_reach_the_engine():
    """They are behaviour the engine runs, not bridge bookkeeping."""
    gd = (C.__file__.rsplit("/", 1)[0] + "/generated/constants.gd")
    text = open(gd, encoding="utf-8").read()
    for name in ("BULWARK_TURN_RATE_DEG_S", "BULWARK_COMMIT_SECONDS",
                 "BULWARK_RECOVERY_SECONDS"):
        assert f"const {name} = " in text, (
            f"{name} never reaches the engine, so the tuning above is a "
            "number the fight does not use")


def test_the_tuning_still_says_it_is_provisional():
    """A guard against this reading as a finished row.

    The numbers were chosen against the brief and the geometry. The
    acceptance that closes the row is a played fight, and the moment
    this file's green is mistaken for that, the row is closed by
    report.
    """
    src = inspect.getsource(C)
    at = src.index("BULWARK_TURN_RATE_DEG_S = ")
    preamble = src[max(0, at - 1200):at]
    assert "PROVISIONAL" in preamble and "played acceptance is OPEN" in (
        preamble), (
        "the bulwark tuning no longer says it is provisional with its "
        "played acceptance open")
