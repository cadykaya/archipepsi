"""O05-06.1: the occurrence contract of an existing minor.

A MINOR is a whole situation with a room of its own. EX50-033 Unweighted
Switch is one: a 16 by 14 m chamber, a 1.9 m sill, a crate on a guide
track, a HEAVY-class plate under a NOT, a shutter, a `lightened`
applicator, a bolt and a return stair. The engine builds it from a
registry room shell (`godot/content/registry/minor_rooms.json`, pack
`minor_rooms`), the same scene the development launcher plays, and the
registry never offers one to a provider (`shells.is_offerable`).

**What this file is.** What the bridge knows about each minor that the
registry cannot say: which chamber type hosts it, which socket is the
way in and which are closed, the one Check its objective holds, the
latches it may record, and in plain words what completing it and
recovering in it mean. The SPACE and the DOORWAYS are the registry
entry's own -- its `size` is the room and its joinable sockets are its
openings -- so nothing here restates a number the manifest owns.

**Who reads it.** `minor_hosting.compose_minor` selects a host against
it and declines by name when none qualifies; `record_latch` accepts a
`minor_<room>/<latch>` only when the accepted Zone's chamber in that
room carries a contracted shell that declares the latch, and
`record_carrier_rested` a carrier's rest only for a carrier and stop
that shell declares. Nothing else.

**What it is not.** Not a second vocabulary for machines: the plate,
NOT, shutter and bolt are the room's own code, built by the engine and
verified there (`godot-unweighted`, `godot-counterfire`,
`godot-passing-platforms`) and played in a Zone (`godot-candidate-live`). Not a grant:
the room's `lightened` applicator is the minor's specified local source
and gives the campaign nothing.
"""
from __future__ import annotations

from dataclasses import dataclass

try:
    from .physics import MINOR_PACKAGE_PREFIX
    from .signal_graph import (ActuatorBinding, LogicNode, RoomGraph,
                               SensorNode)
except ImportError:  # pragma: no cover
    from physics import MINOR_PACKAGE_PREFIX
    from signal_graph import (ActuatorBinding, LogicNode, RoomGraph,
                              SensorNode)


@dataclass(frozen=True)
class MinorContract:
    """One minor, as a host has to take it."""

    #: The registry room shell the engine builds it from.
    shell_id: str
    #: The catalogue entry it realizes.
    catalogue_id: str
    name: str
    #: The chamber type a host must already be. The registry entry is
    #: tagged with it too, so `ContentInstantiator._misfit` agrees.
    chamber_type: str
    #: The one opening a player comes in by. A minor is hosted as a DEAD
    #: END: its other openings are closed (`SEALED`), so its puzzle is
    #: never on the way to anywhere else and the Zone's reachability is
    #: the host's, unchanged.
    entry_socket: str
    sealed_sockets: tuple[str, ...]
    #: The latches the room records, each `minor_<room>/<latch>`.
    latches: tuple[str, ...]
    #: What completing it means, and where its Check is.
    completion: str
    #: What a player who gets it wrong can always do.
    recovery: str
    #: `(archetype, count)` the chamber itself declares -- the Zone's own
    #: encounter, spawned at the shell's `enemy_spawn` volume and tracked
    #: and persisted like any other. A minor that needs an enemy never
    #: builds its own copy (EX50-021 §9).
    enemies: tuple[tuple[str, int], ...] = ()
    #: `(carrier_id, stops)` for each machine the room runs whose REST
    #: is saved (EX50-011 §9: "Carrier poses, destinations and hold
    #: states are package-local"). The bridge records a carrier at rest
    #: as `minor_<room>/<carrier>` only if it is declared here, and only
    #: at one of these stops or held between them. The stops are names,
    #: not numbers: where each one stands is the room's own geometry.
    carriers: tuple[tuple[str, tuple[str, ...]], ...] = ()
    #: O05-07. The minor's own relationship as a declared signal graph,
    #: run by the shared `SignalGraph` in the room that hosts it -- and in
    #: the development scenario, the same declaration. Validated here by
    #: the schema every Zone graph passes; exported to Godot as
    #: `Constants.MINOR_SIGNAL_GRAPHS`. `room_id` is a placeholder: the
    #: graph is bound to whichever room hosts the minor. Its LATCH nodes
    #: are exactly the contract's latches, which is what makes a fired
    #: latch `minor_<room>/<latch>`.
    graph: RoomGraph | None = None

    def carrier_stops(self, carrier_id: str) -> tuple[str, ...] | None:
        """A declared carrier's stops, or None when it has no such one."""
        return dict(self.carriers).get(carrier_id)


CONTRACTS: dict[str, MinorContract] = {
    "minor_unweighted_switch": MinorContract(
        shell_id="minor_unweighted_switch",
        catalogue_id="EX50-033",
        name="Unweighted Switch",
        chamber_type="arena",
        entry_socket="entry",
        sealed_sockets=("exit",),
        latches=("bolt",),
        # EX50-033 §3: the HEAVY plate under a NOT holds the crossing shut
        # while loaded; the bolt, once engaged, holds it open for good.
        graph=RoomGraph(
            room_id="minor",
            sensors=(SensorNode(node_id="plate", kind="PRESSURE_PLATE",
                                requires_class="HEAVY"),
                     SensorNode(node_id="bolt_lever", kind="PULSE_BUTTON")),
            nodes=(LogicNode(node_id="unloaded", kind="NOT",
                             inputs=("plate",)),
                   LogicNode(node_id="bolt", kind="LATCH",
                             inputs=("bolt_lever",)),
                   LogicNode(node_id="open", kind="OR",
                             inputs=("unloaded", "bolt"))),
            actuators=(ActuatorBinding(actuator_id="shutter",
                                       driven_by="open"),)),
        completion=(
            "the crate stands on the HEAVY plate as the step to the sill "
            "and `lightened` releases the plate without moving it; the "
            "bolt on the gallery holds the crossing, and the room's Check "
            "stands at its objective on that gallery"),
        recovery=(
            "the drive returns the crate to parking, `lightened` expires "
            "on its own clock and the applicator is reusable; the gallery "
            "drops back to the floor through the return gap, and the bolt "
            "adds the return stair"),
    ),
    "minor_counterfire_arcade": MinorContract(
        shell_id="minor_counterfire_arcade",
        catalogue_id="EX50-021",
        name="Counterfire Arcade",
        chamber_type="arena",
        entry_socket="entry",
        sealed_sockets=("exit",),
        latches=("release",),
        # EX50-021 §3: "The receiver emits one pulse per valid hit"; "the
        # eight-second TIMER refreshes on another valid receiver hit. Its
        # output opens the service shutter"; the manual release "accepts
        # a permanent return/shortcut condition". §9: "The receiver timer
        # is ephemeral."
        graph=RoomGraph(
            room_id="minor",
            sensors=(SensorNode(node_id="receiver", kind="SHOOTABLE_TARGET",
                                mode="PULSE"),
                     SensorNode(node_id="release_lever",
                                kind="PULSE_BUTTON")),
            nodes=(LogicNode(node_id="window", kind="TIMER",
                             inputs=("receiver",), duration=8.0),
                   LogicNode(node_id="release", kind="LATCH",
                             inputs=("release_lever",)),
                   LogicNode(node_id="open", kind="OR",
                             inputs=("window", "release"))),
            actuators=(ActuatorBinding(actuator_id="shutter",
                                       driven_by="open"),)),
        completion=(
            "the gunner's committed shot, dodged, trips the hooded "
            "receiver and opens the service shutter for eight seconds; "
            "beyond it the flank's manual release makes the service route "
            "permanent, and the room's Check stands at its objective on "
            "the flank"),
        recovery=(
            "a missed bait leaves the player in the arcade to try again; "
            "with the gunner dead, the west stair and an ordinary Static "
            "Pulse at the receiver's face still open the shutter; the "
            "release adds a fixed stair back down"),
        enemies=(("ranged", 1),),
    ),
    "minor_passing_platforms": MinorContract(
        shell_id="minor_passing_platforms",
        catalogue_id="EX50-011",
        name="Passing Platforms",
        chamber_type="arena",
        entry_socket="entry",
        sealed_sockets=("exit",),
        latches=("stair",),
        completion=(
            "the lift and the shuttle are started so that one is beside "
            "the other at the transfer plane; the player steps across "
            "and is carried on to the goal gallery, and walking onto it "
            "releases the permanent service stair down to the arrival "
            "floor; the room's Check stands at its objective on the "
            "gallery"),
        recovery=(
            "a missed transfer is a short fall to the recovery floor, "
            "whose stair climbs back to arrival; STOP holds the shuttle "
            "where it is for the patient crossing; RESET at arrival or on "
            "the shelf calls both carriers home by ordinary motion; the "
            "service stair makes the carriers unnecessary afterwards"),
        carriers=(("lift", ("A", "TRANSFER", "SHELF")),
                  ("shuttle", ("WEST", "EAST"))),
    ),
}


def contract_for(shell_id: str | None) -> MinorContract | None:
    """The contract for a shell id, or None when it is not a minor."""
    return CONTRACTS.get(shell_id) if shell_id else None


def latch_package(room_id: str) -> str:
    """The `package_id` a hosted minor's latches are recorded under."""
    return f"{MINOR_PACKAGE_PREFIX}{room_id}"
