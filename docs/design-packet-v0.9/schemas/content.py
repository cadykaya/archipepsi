"""The authored-content contract (v0.9 S12).

`AUTHORED_CONTENT.md` says humans make the alphabet, Godot enforces the
grammar and Epsilon writes sentences. This module is the *dictionary* —
the list of letters that exist, what each one is, and what it needs to sit
next to. It is the thing Epsilon may name and the thing Godot may
instantiate.

Two readers, one file. The manifests live in the Godot project beside the
scenes they describe (`godot/content/registry/*.json`), which is what
makes adding an asset a matter of dropping in a scene and a manifest entry
rather than editing generator logic. Godot loads them as the physical
authority — it is the one that can check a scene actually exists and that
its collision is real. This module is the other half: it validates the
manifest's SHAPE, and it is what a provider's output is checked against,
because Epsilon's output is validated in Python long before Godot sees it.

**Epsilon references ids and tags. Never paths.** `scene` exists in the
manifest because Godot needs it; there is deliberately no path field
anywhere a provider can write, and `test_authored_boundary.py` enforces
that separately.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:
    from . import constants as C
except ImportError:  # pragma: no cover
    import constants as C


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


#: The five levels of `AUTHORED_CONTENT.md` §3. Stored as an int because
#: the document numbers them and a reader should not have to translate.
ContentLevel = Literal[0, 1, 2, 3, 4]

#: What a piece of content IS. The category decides which fields are
#: required, which is why it is closed rather than a free tag: a room
#: shell with no sockets is a room nothing can connect to, and that has to
#: be a validation error rather than a surprise at instantiation.
ContentCategory = Literal[
    "prop",             # L0
    "module",           # L1  architectural module
    "fixture",          # L2  composed alcove / station / perch
    "room_shell",       # L3
    "landmark",         # L4
    "connector",        # L1, but its own category: sockets on both ends
    "affordance_visual",  # L2, bound to a §13 tag
    "interactable",     # L0-L2, the repeatedly-seen objects of §2
]

#: Which level each category may declare. A mismatch is a manifest that
#: has not decided what it is.
_LEVELS: dict[str, tuple[int, ...]] = {
    "prop": (0,),
    "module": (1,),
    "connector": (1,),
    "fixture": (2,),
    "affordance_visual": (2,),
    "interactable": (0, 1, 2),
    "room_shell": (3,),
    "landmark": (4,),
}

#: Categories that must declare at least one socket, because something
#: has to be able to attach to them.
_NEEDS_SOCKETS = ("room_shell", "connector")

_ID = Annotated[str, Field(min_length=3, max_length=48,
                           pattern=r"^[a-z][a-z0-9_]*$")]
_TAG = Annotated[str, Field(min_length=2, max_length=32,
                            pattern=r"^[a-z][a-z0-9_]*$")]


class Socket(Strict):
    """A named attachment point in the content's own local space.

    Position is metres from the content's origin and `yaw` is degrees
    about +Y, which is the convention `ART_ASSET_SPEC.md` states and the
    importer relies on. Both are here rather than inferred from the scene
    because the validator has to answer "do these two fit together"
    without loading Godot.
    """
    name: _TAG
    kind: Literal["doorway", "corridor_end", "affordance", "spawn",
                  "objective", "secret", "vista", "presentation"]
    position: tuple[float, float, float]
    yaw: float = Field(default=0.0, ge=-360.0, le=360.0)
    #: Clear opening, for the two kinds that join to another socket.
    width: float = Field(default=0.0, ge=0.0, le=32.0)
    height: float = Field(default=0.0, ge=0.0, le=32.0)

    @model_validator(mode="after")
    def _joining_sockets_have_an_opening(self):
        if self.kind in ("doorway", "corridor_end"):
            if self.width <= 0.0 or self.height <= 0.0:
                raise ValueError(
                    f"socket '{self.name}' is a {self.kind} and must "
                    f"declare a width and height; two openings cannot be "
                    f"checked for fit without them")
        return self


class Volume(Strict):
    """An axis-aligned box in the content's local space, for the things
    Godot must place safely: where a player may arrive, where an enemy may
    spawn, where an objective may sit."""
    name: _TAG
    kind: Literal["player_entry", "enemy_spawn", "objective", "no_build"]
    center: tuple[float, float, float]
    size: tuple[float, float, float]

    @model_validator(mode="after")
    def _has_volume(self):
        if any(s <= 0.0 for s in self.size):
            raise ValueError(f"volume '{self.name}' has a zero or negative "
                             f"dimension: {self.size}")
        return self


class ContentEntry(Strict):
    """One authored thing, by stable id.

    The id is the contract. A scene may be replaced, re-exported, split
    into variants or swapped from graybox to final art without the id
    changing, and nothing outside this manifest ever names the file.
    """
    id: _ID
    level: ContentLevel
    category: ContentCategory
    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)

    #: The Godot resource. Present for Godot and for nobody else — a
    #: provider never reads this and can never write one.
    scene: str = Field(default="", max_length=200)
    #: True while the entry describes the legacy procedural builder rather
    #: than an authored scene. Honest bookkeeping: it is what lets the
    #: registry describe the game as it is TODAY without pretending the
    #: placeholders are authored content.
    procedural_fallback: bool = False

    theme_tags: tuple[_TAG, ...] = ()
    semantic_tags: tuple[_TAG, ...] = ()

    #: Overall extent in metres (x, y, z). Godot re-derives this from the
    #: real scene and refuses a manifest that lies about it.
    size: tuple[float, float, float] = (0.0, 0.0, 0.0)
    #: Clearances this content REQUIRES around it, by name.
    clearances: dict[str, float] = Field(default_factory=dict)

    sockets: tuple[Socket, ...] = ()
    volumes: tuple[Volume, ...] = ()

    #: Action primitives or affordance tags a player must own for this
    #: content to be USABLE. Never a reason to place it on a mandatory
    #: path — that is I4, enforced elsewhere and not weakened here.
    requires_capabilities: tuple[_TAG, ...] = ()
    #: For `affordance_visual`, the §13 tag it renders.
    affordance_tag: str = Field(default="", max_length=32)

    #: Rough instantiation cost, for a per-Zone budget Godot enforces.
    cost: int = Field(default=1, ge=0, le=1000)
    variants: tuple[_ID, ...] = ()
    #: The id to use when this one cannot be instantiated. The migration
    #: shape of S13: authored scene if available, validated placeholder
    #: otherwise.
    fallback: str = Field(default="", max_length=48)

    @model_validator(mode="after")
    def _category_and_level_agree(self):
        allowed = _LEVELS[self.category]
        if self.level not in allowed:
            raise ValueError(
                f"'{self.id}' is a {self.category} at level {self.level}; "
                f"that category is level {' or '.join(map(str, allowed))}")
        return self

    @model_validator(mode="after")
    def _has_what_its_category_requires(self):
        if self.category in _NEEDS_SOCKETS:
            joins = [s for s in self.sockets
                     if s.kind in ("doorway", "corridor_end")]
            if not joins:
                raise ValueError(
                    f"'{self.id}' is a {self.category} and declares no "
                    f"doorway or corridor_end socket; nothing could ever "
                    f"connect to it")
        if self.category == "affordance_visual" and not self.affordance_tag:
            raise ValueError(
                f"'{self.id}' is an affordance_visual and names no "
                f"affordance_tag; it renders nothing in particular")
        return self

    @model_validator(mode="after")
    def _is_either_authored_or_honest_about_not_being(self):
        if self.procedural_fallback:
            if self.scene:
                raise ValueError(
                    f"'{self.id}' is marked as a procedural fallback and "
                    f"also names a scene; it is one or the other")
        elif not self.scene:
            raise ValueError(
                f"'{self.id}' names no scene and is not marked "
                f"`procedural_fallback`. An entry describing nothing is "
                f"how the registry starts lying about what exists")
        return self

    @model_validator(mode="after")
    def _socket_names_are_unique(self):
        names = [s.name for s in self.sockets]
        if len(set(names)) != len(names):
            raise ValueError(f"'{self.id}' repeats a socket name: {names}")
        volumes = [v.name for v in self.volumes]
        if len(set(volumes)) != len(volumes):
            raise ValueError(f"'{self.id}' repeats a volume name: {volumes}")
        return self

    @model_validator(mode="after")
    def _the_scene_path_stays_inside_the_content_root(self):
        """A path is the one thing in this file that could reach outside
        the project. It is Godot's field, never a provider's, and it is
        still checked — an entry pointing at `res://../` or an absolute
        path is a manifest that can address anything on the disk."""
        if not self.scene:
            return self
        if not self.scene.startswith("res://content/"):
            raise ValueError(
                f"'{self.id}' points at {self.scene!r}; authored content "
                f"lives under res://content/ and nowhere else")
        if ".." in self.scene:
            raise ValueError(f"'{self.id}' path escapes: {self.scene!r}")
        return self


class ContentManifest(Strict):
    """One manifest file. Several may exist — one per content pack — and
    the registry is their union, so an artist adds a pack rather than
    editing a growing shared file."""
    schema_version: Literal[1] = 1
    pack: _TAG
    description: str = Field(default="", max_length=C.MAX_TEXT_LEN)
    entries: tuple[ContentEntry, ...] = Field(min_length=1)

    @model_validator(mode="after")
    def _ids_are_unique_within_the_pack(self):
        ids = [e.id for e in self.entries]
        if len(set(ids)) != len(ids):
            dupes = sorted({i for i in ids if ids.count(i) > 1})
            raise ValueError(f"pack '{self.pack}' repeats ids: {dupes}")
        return self


class RegistryError(ValueError):
    """A manifest set that does not describe a usable alphabet."""


def build_registry(manifests) -> dict[str, ContentEntry]:
    """Merge manifests into one id -> entry map, refusing anything a
    consumer could not act on.

    Cross-manifest checks live here rather than on the models because
    none of them can be answered by one entry alone: an id colliding
    across packs, a variant or fallback naming something that does not
    exist, a fallback chain that loops.
    """
    registry: dict[str, ContentEntry] = {}
    origin: dict[str, str] = {}
    for manifest in manifests:
        for entry in manifest.entries:
            if entry.id in registry:
                raise RegistryError(
                    f"id '{entry.id}' is defined in both "
                    f"'{origin[entry.id]}' and '{manifest.pack}'; ids are "
                    f"the contract and must be unique across every pack")
            registry[entry.id] = entry
            origin[entry.id] = manifest.pack

    for entry in registry.values():
        for variant in entry.variants:
            if variant not in registry:
                raise RegistryError(
                    f"'{entry.id}' lists variant '{variant}', which no "
                    f"pack defines")
            if registry[variant].category != entry.category:
                raise RegistryError(
                    f"'{entry.id}' lists '{variant}' as a variant, but it "
                    f"is a {registry[variant].category} and this is a "
                    f"{entry.category}; a variant is the same THING made "
                    f"differently")
        if entry.fallback:
            if entry.fallback not in registry:
                raise RegistryError(
                    f"'{entry.id}' falls back to '{entry.fallback}', which "
                    f"no pack defines. A fallback that does not exist is "
                    f"the failure the fallback was there to prevent")
            if registry[entry.fallback].category != entry.category:
                raise RegistryError(
                    f"'{entry.id}' falls back to '{entry.fallback}', a "
                    f"{registry[entry.fallback].category}; it must be a "
                    f"{entry.category}")

    _refuse_fallback_cycles(registry)
    return registry


def _refuse_fallback_cycles(registry: dict[str, ContentEntry]) -> None:
    """A fallback chain must terminate.

    S13's whole shape is "authored scene if available, validated
    placeholder otherwise", and a cycle turns the otherwise into a hang at
    the exact moment something was already going wrong.
    """
    for start in registry:
        seen = [start]
        current = registry[start].fallback
        while current:
            if current in seen:
                raise RegistryError(
                    f"fallback cycle: {' -> '.join(seen + [current])}. A "
                    f"chain has to end at something that always works")
            seen.append(current)
            current = registry[current].fallback


def resolve(registry: dict[str, ContentEntry], content_id: str,
            available) -> ContentEntry:
    """The S13 selection rule, decided here so both languages agree.

    `available` answers "can this entry actually be instantiated" — in
    Godot, whether the scene loads; in a test, whatever the test says. The
    first entry down the fallback chain that answers yes wins, and the
    chain is known to terminate.
    """
    if content_id not in registry:
        raise RegistryError(f"unknown content id '{content_id}'")
    current: str = content_id
    while current:
        entry = registry[current]
        if available(entry):
            return entry
        current = entry.fallback
    raise RegistryError(
        f"'{content_id}' is unavailable and its fallback chain ends "
        f"without anything that is")
