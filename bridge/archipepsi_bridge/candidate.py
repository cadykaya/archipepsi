"""O05-13: the opt-in CANDIDATE generation profile.

**What it is.** A named profile a caller turns on (`--candidate`), applied
inside the real generation path: after a Zone's graph has been composed
and proved, and before `accept_zone` stores it. It runs the supported
relationship composers in a fixed order. Each one works on the Zone the
previous one handed on, and each emits or declines by name. That is the
same shape as `quiet_generation`, and it is off by default for the same
reason: with the profile off, `CampaignEngine` does not call in here at
all, and every Zone, digest and comparison build is what it was.

**What it is NOT.** Not a fixture. Nothing is loaded from a file, nothing
replaces the composed Zone, and nothing edits a save after acceptance.
Every step derives its relationship from the Zone the campaign really
composed. It declines when that Zone cannot carry the relationship, and
says why. A declined step leaves the Zone exactly as it was.

**The order, and why it is this one.**

1. `zone_state`: D-8's reversible control (`cross_room.compose_zone_state`),
   with a lamp reader in the first room past the gate
   (`reader_order="nearest"`, O05-04.2). It comes first because it
   composes the Zone's FIRST relationship and declines onto a Zone that
   already declares state.
2. `latched_route`: P14's plate, latch and shutter
   (`latched_route.compose_latched_route`). It refuses an edge that
   already carries `requires_state` (one gate per doorway, P5-1).
3. `transport`: P16's carry-and-install journey
   (`transport_route.compose_transport`), which adds its own variable
   beside any the Zone has.

A caller may name a subset (`--candidate=transport`), and the order is
kept either way.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from .schemas.zone import Zone

#: Every step the profile knows, in the order it runs them.
STEPS: tuple[str, ...] = ("zone_state", "latched_route", "transport")


@dataclass(frozen=True)
class Applied:
    """What the profile did to one Zone."""
    zone: Zone
    #: `(step, emitted, note)` for every step asked for, in order.
    steps: tuple[tuple[str, bool, str], ...] = field(default=())

    @property
    def emitted(self) -> tuple[str, ...]:
        return tuple(s for s, done, _ in self.steps if done)


def parse(spec: str | None) -> tuple[str, ...]:
    """`"all"`, `""`/None (off), or a comma list of step names."""
    if spec is None:
        return ()
    spec = spec.strip()
    if spec in ("", "off", "none"):
        return ()
    if spec == "all":
        return STEPS
    asked = [s.strip() for s in spec.split(",") if s.strip()]
    unknown = sorted(set(asked) - set(STEPS))
    if unknown:
        raise ValueError(f"unknown candidate step(s) {unknown}; the profile "
                         f"knows {list(STEPS)}")
    return tuple(s for s in STEPS if s in asked)


def apply(zone: Zone, steps: tuple[str, ...]) -> Applied:
    """Run the named steps, in the profile's order, on `zone`."""
    done: list[tuple[str, bool, str]] = []
    for step in STEPS:
        if step not in steps:
            continue
        if step == "zone_state":
            from .cross_room import compose_zone_state
            out = compose_zone_state(zone, mechanism="lamp",
                                     reader_order="nearest")
            emitted, note, zone = out.emitted, out.note, out.zone
        elif step == "latched_route":
            from .latched_route import compose_latched_route
            out = compose_latched_route(zone)
            emitted, note, zone = out.emitted, out.note, out.zone
        else:
            from .transport_route import compose_transport
            out = compose_transport(zone)
            emitted, note, zone = out.emitted, out.note, out.zone
        done.append((step, emitted, note))
    return Applied(zone, tuple(done))


def strip(zone: Zone) -> Zone:
    """The Zone without anything this profile adds.

    Re-hosting recomposes a Zone's graph, and every relationship above is
    bound to that graph's rooms and edges. So the profile is re-applied
    to the new graph from a clean Zone rather than trusted to survive a
    graph it was not composed on.
    """
    return zone.model_copy(update={
        "zone_state": (), "transported_objects": (), "object_consumers": (),
        "room_graphs": (),
    })
