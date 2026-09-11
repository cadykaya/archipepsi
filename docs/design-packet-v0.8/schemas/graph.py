"""The Zone topology graph and its per-instance assignments.

`09_ROOM_CONTRACT.md` Layer 2. The bridge writes everything here; the
engine reads it and never amends it.

**Additive and optional, so `schema_version` stays 7.** A Zone carrying
no `edges`, no `doors` and no `plugs` is exactly the chain Zone that
shipped before multi-door existed — the list order is its topology and
nothing is lost. Bumping the version would fail every Zone already
inside a save for a change that requires nothing and removes nothing,
which is the same reasoning `features` was added under.

**A plug is not a door.** `PlugAssignment` is a separate record because
a `DoorAssignment` *is* a socket assignment: its first field is
`socket_id`, and the engine carves an aperture at every socket a door
names. Carrying a return plug on a `DoorAssignment` would cut a fourth
opening in a three-door junction, and would make a two-door shell fail
the injective socket assignment outright — which is the opposite of the
promise that every existing shell still composes.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


#: Whether an edge binds geometry. A `JOINED` edge is two sockets meeting
#: at their collars. A `TRAVERSAL_ONLY` edge — a return plug, a
#: non-euclidean door, a rematerialisation pad — carries the player with
#: nothing joining the rooms spatially.
#:
#: **Both are equally real to reachability.** The distinction exists so a
#: placement solver is never asked to close a cycle through a teleport.
Realization = Literal["JOINED", "TRAVERSAL_ONLY"]

#: Three usages, three different geometric outcomes. `SEALED` is not
#: "skip the audit" — it is the same measurement with the expectation
#: inverted, and the expectation comes from this declaration.
DoorUsage = Literal["USED", "LOCKED", "SEALED"]

Direction = Literal["BIDIRECTIONAL", "A_TO_B", "B_TO_A"]

#: The authored plug catalogue. Each is a way back that is not a door.
PlugKind = Literal["pad", "threshold", "tube"]

#: The key tints the engine knows (`zone_key.gd` `COLOURS`). Closed
#: rather than free text: an unknown name silently became gold, so two
#: differently-named keys could read identically to a player.
KeyColour = Literal["red", "blue", "gold", "green"]

_ROOM = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")
_EDGE = Field(min_length=1, max_length=48, pattern=r"^[a-z0-9_:]+$")
_KEY = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")
_SOCKET = Field(min_length=1, max_length=32, pattern=r"^[a-z0-9_]+$")
#: An anchor is a NAME, never a coordinate. The composer says which
#: anchor; the engine says where it is.
_ANCHOR = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9_:]+$")


class TopologyEdge(Strict):
    """One edge of the Zone graph.

    The list order of `Zone.chambers` used to *be* the topology. This is
    what replaces it, and a Zone carrying no edges still means the chain
    it always meant.
    """

    edge_id: str = _EDGE
    room_a: str = _ROOM
    room_b: str = _ROOM
    direction: Direction = "BIDIRECTIONAL"
    realization: Realization = "JOINED"

    @model_validator(mode="after")
    def _an_edge_joins_two_rooms(self):
        if self.room_a == self.room_b:
            raise ValueError(
                f"edge '{self.edge_id}' has both ends in '{self.room_a}'; "
                "a self-loop is not a route between rooms")
        return self

    @property
    def rooms(self) -> tuple[str, str]:
        return (self.room_a, self.room_b)

    def traversable(self, frm: str) -> bool:
        """Can this edge be walked starting from `frm`?"""
        if frm == self.room_a:
            return self.direction in ("BIDIRECTIONAL", "A_TO_B")
        if frm == self.room_b:
            return self.direction in ("BIDIRECTIONAL", "B_TO_A")
        return False

    def other(self, frm: str) -> str:
        return self.room_b if frm == self.room_a else self.room_a


class DoorAssignment(Strict):
    """One joining socket of one room instance, and what it does.

    `edge_id` is required unless the door is `SEALED`, and the edge it
    names must be `JOINED` — a `TRAVERSAL_ONLY` edge is carried by a
    `PlugAssignment` and never by a door.
    """

    socket_id: str = _SOCKET
    usage: DoorUsage
    edge_id: str | None = Field(default=None, max_length=48)
    key_id: str | None = Field(default=None, max_length=24)
    #: Presentation only; the engine tints the slab. Never read by logic.
    colour: KeyColour | None = None

    @model_validator(mode="after")
    def _usage_determines_the_rest(self):
        if self.usage == "SEALED":
            if self.edge_id is not None:
                raise ValueError(
                    f"door '{self.socket_id}' is SEALED and names edge "
                    f"'{self.edge_id}'; a sealed door carries no route")
        elif not self.edge_id:
            raise ValueError(
                f"door '{self.socket_id}' is {self.usage} and names no "
                "edge; only a SEALED door may carry none")
        if self.usage == "LOCKED" and not self.key_id:
            raise ValueError(
                f"door '{self.socket_id}' is LOCKED with no key_id; a lock "
                "nothing opens is a wall that lies about being a door")
        if self.usage != "LOCKED" and self.key_id:
            raise ValueError(
                f"door '{self.socket_id}' is {self.usage} and names key "
                f"'{self.key_id}'; only a LOCKED door takes a key")
        return self

    @property
    def passable_geometry(self) -> bool:
        """Is an aperture cut here?

        `LOCKED` carves: the lock is a placement over a real hole, not an
        uncut wall. Passability is the geometry's question and the key's
        answer is the runtime's.
        """
        return self.usage != "SEALED"


class PlugAssignment(Strict):
    """A return plug: the way back out of a dead end.

    Both ends are anchors rather than coordinates, so the composer still
    names no world position and the authored-alphabet boundary holds
    without special pleading.
    """

    edge_id: str = _EDGE
    room_id: str = _ROOM
    source_anchor: str = _ANCHOR
    destination: str = _ANCHOR
    device: PlugKind = "pad"

    @model_validator(mode="after")
    def _a_plug_goes_somewhere_else(self):
        if self.source_anchor == self.destination:
            raise ValueError(
                f"plug '{self.edge_id}' returns to the anchor it stands "
                "on; a way back that arrives where it departed is not one")
        return self


class ZoneKeySpec(Strict):
    """A Zone-local key. Not an Archipelago item, and never one.

    No location id, never scouted, never sent, does not survive the Zone.
    It is a lock state on generated geometry, which is what buys
    metroidvania structure with zero multiworld risk.
    """

    key_id: str = _KEY
    colour: KeyColour | None = None
