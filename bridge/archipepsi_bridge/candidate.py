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
2. `transport`: P16's carry-and-install journey
   (`transport_route.compose_transport`), which adds its own variable
   beside any the Zone has.
3. `latched_route`: P14's latch and shutter
   (`latched_route.compose_latched_route`). **It declines today:** D-07
   retired the step-once plate, and the lever that replaces it lands
   with `RoomGraphs`' lever placement (D13 1c). It runs LAST, because it is the one
   with the widest choice of rooms. It refuses an edge that already
   carries `requires_state` (one gate per doorway, P5-1) and a room that
   already holds another relationship's control (one control per room,
   P5-11): the first played combination put its plate beside the lever
   in c002, the engine refused the plate for want of floor, and with
   P14 ahead of the transport step the cell's only walkable run was
   taken instead.
4. `minors`: an existing minor added whole behind a dead end
   (`minor_hosting.compose_minor`, O05-06). LAST, because it builds on
   a room and a doorway of its own: it declines a room any earlier step
   put a control in, and a doorway any earlier step gated, so running
   it after them is what lets it see both. It never fits its minor into
   a smaller room; it declines by name.

A caller may name a subset (`--candidate=transport`), and the order is
kept either way.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from .schemas.zone import Zone

#: Every step the profile knows, in the order it runs them.
STEPS: tuple[str, ...] = ("zone_state", "transport", "latched_route",
                          "minors")

#: Profile OPTIONS: switched on by the same `--candidate` spec, and NOT
#: Zone steps. They change what the campaign's other paths may do, not
#: what a Zone contains, so `apply` never sees them and the engine keeps
#: them apart from the steps (`CampaignEngine.candidate_options`).
#:
#: `consumables` (O05-11.4): the Echo requests advertise the consumable
#: slot, and the acceptance gate admits exactly what was advertised. For
#: this profile only; production keeps the slot staged
#: (`capabilities.IMPLEMENTED_ACTION_SLOTS`).
OPTIONS: tuple[str, ...] = ("consumables",)


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
    """`"all"`, `""`/None (off), or a comma list of step and option names.

    The profile's own order, steps before options, whatever order the
    operator typed.
    """
    if spec is None:
        return ()
    spec = spec.strip()
    if spec in ("", "off", "none"):
        return ()
    known = STEPS + OPTIONS
    if spec == "all":
        return known
    asked = [s.strip() for s in spec.split(",") if s.strip()]
    unknown = sorted(set(asked) - set(known))
    if unknown:
        raise ValueError(f"unknown candidate step(s) {unknown}; the profile "
                         f"knows {list(known)}")
    return tuple(s for s in known if s in asked)


def steps_of(profile: tuple[str, ...]) -> tuple[str, ...]:
    """The Zone steps of a parsed profile."""
    return tuple(s for s in profile if s in STEPS)


def options_of(profile: tuple[str, ...]) -> tuple[str, ...]:
    """The options of a parsed profile."""
    return tuple(s for s in profile if s in OPTIONS)


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
        elif step == "minors":
            from .minor_hosting import compose_minor
            out = compose_minor(zone)
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

    A minor comes out too (`minor_hosting.unhost`): the room it added is
    dropped and its Check handed back to the dead end it was built
    behind, which is exactly where the provider put it.
    """
    from .minor_hosting import unhost
    zone = unhost(zone)
    return zone.model_copy(update={
        "zone_state": (), "transported_objects": (), "object_consumers": (),
        "room_graphs": (),
    })
