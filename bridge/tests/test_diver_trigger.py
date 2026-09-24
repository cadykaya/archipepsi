"""The diver's trigger has to be reachable with the base kit (PT-13).

The role's brief is "ignores a grounded player and commits when they
leave the ground". The trigger is a height: how far the player's feet
must be above the floor under them before a diver counts them as in the
air. Set above the apex of an ordinary jump, the brief's "leave the
ground" silently became "be on a grapple arc", and a diver in a room
without one never attacked -- which is what the owner saw.

So these tests hold both ends of the number:

* **an ordinary jump reaches it**, and stays above it long enough for a
  diver that checks every physics frame to see it;
* **a step down is not leaving the ground**: walking off a stair or a
  kerb must not draw a dive.

What they are NOT: proof that a dive lands. That is the engine's
`godot-combat-fairness`, which drives real jumps on the real bindings
and counts the dives, impacts and damage from events.
"""

from __future__ import annotations

import math

from archipepsi_bridge.schemas import constants as C


def _time_above(height: float) -> float:
    """Seconds an ordinary jump spends with its feet above `height`."""
    # h(t) = v t - g t^2 / 2; the two roots of h(t) = height.
    v, g = C.JUMP_VELOCITY, C.GRAVITY
    disc = v * v - 2.0 * g * height
    if disc <= 0.0:
        return 0.0
    return 2.0 * math.sqrt(disc) / g


def test_an_ordinary_jump_leaves_the_ground_for_a_diver():
    assert C.DIVER_TRIGGER_HEIGHT < C.JUMP_APEX_HEIGHT
    # A quarter of a second is fifteen physics frames: seen, not grazed.
    assert _time_above(C.DIVER_TRIGGER_HEIGHT) >= 0.25


def test_a_step_down_is_not_leaving_the_ground():
    # The tallest thing a player walks down without jumping is a stair
    # riser or a kerb, well under half a metre.
    assert C.DIVER_TRIGGER_HEIGHT >= 0.5


def test_the_trigger_follows_the_jump_it_is_measured_against():
    # Derived, so retuning the jump cannot silently move it back above
    # the apex.
    assert C.DIVER_TRIGGER_HEIGHT == round(0.6 * C.JUMP_APEX_HEIGHT, 2)
