"""H-QUALIFY — the featured Echo's mechanical contract (owner ruling D-02).

"The game owns the mechanical requirement for a featured Echo. For
Blindside, that means an Echo must provide the actual traversal
capability the room requires. Epsilon may name, style and author the Echo
within that mechanical contract, and there must be a deterministic
guaranteed fallback if generated content fails the requirement."

Three things, each read by the generation pipeline and never restated:

  requirement   `requirement_for(zone, location_id)`: the proven function
                a featured Check's Echo must supply -- a primitive and
                the resolved-parameter floors that primitive has actually
                been shown to cross the room with. Not a capability
                label: `grapple` also names `grapple_swing`, which nothing
                has measured on the gantry.
  check         `check(log, candidate, requirement, next_seq)`: does THIS
                Echo provide it? Folded onto the log exactly as it would
                be appended, so an upgrade that makes an owned grapple
                qualify counts, and a consumable (it runs out) does not.
  fallback      `fallback_interpretation(...)`: a deterministic Echo
                that always passes the check, named from the item, for
                when generated content fails it after its one repair.

**It does not look at the recipient.** A featured Check's original goes
to whoever it was addressed to; the local Echo exists either way (D-01,
D14), and it is held to the same requirement either way.

**Integration is the pipeline's** (note to Prod in the Dess ledger): the
request states `requirement.describe()`, the semantic step runs `check`,
and after the one repair a failing candidate is replaced by the
fallback. Nothing here calls a provider.
"""
from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:
    from . import constants as C
    from . import mechanics as M
    from .echo import EchoInterpretation
except ImportError:  # pragma: no cover
    import constants as C
    import mechanics as M
    from echo import EchoInterpretation


class FeaturedRequirement(BaseModel):
    """The function a featured Check's Echo must supply, as proven."""
    model_config = ConfigDict(extra="forbid", frozen=True)

    #: The gate's capability, as the Zone declares it.
    capability: str
    #: The one primitive the room has been shown to be crossed with.
    primitive: str
    #: Floors on its resolved parameters, all of which must be met.
    minimums: dict[str, float] = Field(min_length=1)
    #: Where the numbers were shown to work.
    evidence: str = Field(min_length=1)

    @model_validator(mode="after")
    def _a_requirement_is_a_crossing(self):
        family = M.ACTIVITY_CAPABILITIES.get(self.capability)
        if family is None or self.capability not in M.TRAVERSAL_CAPABILITIES:
            raise ValueError(
                f"'{self.capability}' is not a traversal capability; a "
                "featured requirement is a crossing the room demands")
        if self.primitive not in family.get("primitives", ()) or \
                self.primitive not in M.PLAYER_TRAVERSAL_PRIMITIVES:
            raise ValueError(
                f"'{self.primitive}' does not move the player as "
                f"'{self.capability}' requires (D-02: moving an enemy, or "
                "a family name, is not a crossing)")
        return self

    def describe(self) -> str:
        """The contract, stated for a provider that authors within it."""
        floors = ", ".join(f"{k} >= {v:g}" for k, v in
                           sorted(self.minimums.items()))
        return (f"This Echo must create or upgrade a non-consumable Action "
                f"whose primitive is {self.primitive} with {floors}. Name, "
                "style and author it freely around that function.")


#: The proven requirements, by the capability a featured room declares.
#: Blindside's gantry: the development scenario reaches its deck -- 3.1 m
#: up, 7.5 m out, where a standing jump tops out at 1.33 m -- with exactly
#: this grapple, and a 14 m/s pull tops out at 4.45 m.
FEATURED_REQUIREMENTS: dict[str, FeaturedRequirement] = {
    "grapple": FeaturedRequirement(
        capability="grapple", primitive="grapple_to_surface",
        minimums={"range": 20.0, "pull_force": 14.0},
        evidence="godot/scripts/content/railway_scenario.gd:43-57, "
                 "361-364, 747-756 (the pedestal's grapple reaches the "
                 "gantry deck)"),
}


def requirement_for(zone, location_id: int) -> FeaturedRequirement | None:
    """The requirement a Check's Echo is held to, or None if the Check is
    not a featured acquisition. Read off the Zone, never the recipient."""
    featured = getattr(zone, "featured_acquisition", None)
    if featured is None or featured.location_id != location_id:
        return None
    return FEATURED_REQUIREMENTS[featured.capability]


def _unmet(component, requirement: FeaturedRequirement) -> list[str]:
    primitive = component.primitive
    if primitive.type != requirement.primitive:
        return [f"is {primitive.type}, not {requirement.primitive}"]
    if getattr(component, "charges", None) is not None \
            or component.slot == "consumable":
        return ["is a consumable, and a crossing it runs out of is not "
                "supplied"]
    return [f"{field} {getattr(primitive, field):g} < {floor:g}"
            for field, floor in sorted(requirement.minimums.items())
            if getattr(primitive, field, 0.0) < floor]


def check(log, candidate: EchoInterpretation,
          requirement: FeaturedRequirement, next_seq: int) -> list[str]:
    """[] if this Echo provides the requirement, else why not.

    Folded onto `log` as `append_interpretation` would stamp it, so what
    is judged is what the player would own. Only components THIS Echo
    created or changed count: the ruling is that the Echo provides it.
    """
    stamped = EchoInterpretation.model_validate(
        {**candidate.model_dump(), "interpretation_seq": next_seq})
    mechanics = M.derive_mechanics(tuple(log) + (stamped,))
    reasons = []
    for owned in mechanics.owned:
        if owned.kind != "action" or not any(
                p.interpretation_seq == next_seq for p in owned.provenance):
            continue
        unmet = _unmet(owned.component, requirement)
        if not unmet:
            return []
        reasons.append(f"'{owned.component_id}' " + "; ".join(unmet))
    return [f"the featured Echo must supply {requirement.primitive} "
            f"({requirement.capability}): "
            + ("; ".join(reasons) if reasons
               else "it creates or changes no Action")]


def fallback_interpretation(requirement: FeaturedRequirement, *,
                            location_id: int, item_name: str,
                            source_game: str, recipient_name: str
                            ) -> EchoInterpretation:
    """The deterministic Echo that always passes `check`.

    The same inputs give the same Echo. Its function is the requirement's
    own floors -- the numbers shown to work -- and its name and text come
    from the item, so a Signal Key yields a working grapple too.
    """
    item = item_name[:C.MAX_AP_STRING_LEN]
    params = dict(requirement.minimums)
    name = f"{item} Tether"[:C.MAX_TEXT_LEN]
    text = (f"Epsilon's study of {item}: it bites a fixed surface and "
            "pulls you across.")[:C.MAX_TEXT_LEN]
    return EchoInterpretation.model_validate({
        "echo_id": f"echo_{location_id}", "interpretation_seq": 0,
        "source_location_id": location_id, "source_item_name": item,
        "source_game": source_game, "source_recipient_name": recipient_name,
        "display_name": name, "description": text,
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": f"act_featured_{location_id}",
            "display_name": name, "description": text, "slot": "mobility",
            "cooldown": 1.5,
            "primitive": {"type": requirement.primitive, **params},
            "modifiers": []}}]})
