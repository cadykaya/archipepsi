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
room carries a contracted shell that declares the latch. Nothing else.

**What it is not.** Not a second vocabulary for machines: the plate,
NOT, shutter and bolt are the room's own code, built by the engine and
verified there (`godot-unweighted`, `godot-minor-live`). Not a grant:
the room's `lightened` applicator is the minor's specified local source
and gives the campaign nothing.
"""
from __future__ import annotations

from dataclasses import dataclass

try:
    from .physics import MINOR_PACKAGE_PREFIX
except ImportError:  # pragma: no cover
    from physics import MINOR_PACKAGE_PREFIX


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


CONTRACTS: dict[str, MinorContract] = {
    "minor_unweighted_switch": MinorContract(
        shell_id="minor_unweighted_switch",
        catalogue_id="EX50-033",
        name="Unweighted Switch",
        chamber_type="arena",
        entry_socket="entry",
        sealed_sockets=("exit",),
        latches=("bolt",),
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
}


def contract_for(shell_id: str | None) -> MinorContract | None:
    """The contract for a shell id, or None when it is not a minor."""
    return CONTRACTS.get(shell_id) if shell_id else None


def latch_package(room_id: str) -> str:
    """The `package_id` a hosted minor's latches are recorded under."""
    return f"{MINOR_PACKAGE_PREFIX}{room_id}"
