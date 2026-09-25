"""H-UI-DATA — one inventory view over the existing fold.

C-INVENTORY: "The menu never reconstructs its own upgrade arithmetic or
fabricates a second copy of an item for its history. Mixed active/passive
components remain representable. Read-only source provenance does not
become a usable duplicate."

**A projection, not a backend.** Everything here is read from the save
the bridge already authorizes: the fold (`derive()`), the slot
assignment, the consumable counts. Nothing is stored, nothing is folded
a second time, and no rule is restated -- compatibility is the save
validator's own (`_reject_unslottable`: only an Action occupies a slot,
and only its declared one), read off the component rather than retyped.

**It adds only what the fold lacks, keyed by `component_id`.** An item's
name, description, kind, mk and whole history -- its creation and every
upgrade, modification, link or merge, oldest first -- are already on the
snapshot, once, in `mechanics.owned`. The menu joins on the id. Upgrades
therefore live on the resolved item and never as extra equippables, and
nothing here repeats them: a second copy of the fold would nearly double
every snapshot, and could disagree with the first.

**What each field adds for the menu:**

  activation       `slotted` for an Action, `always_on` for every other
                   kind. Always-on is NOT toggleable: passive does not
                   mean the player can switch it off.
  compatible_slots the slots the authority will accept it in -- an
                   Action's one declared slot, and none otherwise. The
                   menu offers exactly these, so a refusal is something
                   the player never has to be shown.
  equipped_in      the slot holding it now, or none.
  gear             for a piece of Gear (D16 G1): its territory, the
                   runtime stat it multiplies and by how much, its tier,
                   and whether it is worn. All derived from its atoms at
                   read time, never stored, so the menu shows what the
                   StatStack will apply and a rebalance needs no
                   migration. A worn piece is `worn`, not `slotted`: it
                   fills a territory, not a key.
  charges_*        a consumable's supply. `charges_left == 0` while
                   equipped is LEGAL (owner decision, 2026-09-22): it
                   stays selected, exhausted, until the refill.
  siblings         other items the same Echo created. A mixed Echo that
                   made an Action and a Trait shows both, each with the
                   other named, so neither half is silently dropped.

**Pending and refused are not here, on purpose.** A consumable press in
flight is the client's own record, and a refusal is the `BridgeError`
whose `about` names that use (D-9). The bridge deliberately does not
mirror outstanding authorizations to a client (D-9 §3), so this view
carries the count that is already reduced and nothing a relaunched
client could misread as its own.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

try:
    from . import constants as C
    from . import gear as G
    from .echo import SlotName
except ImportError:  # pragma: no cover
    import constants as C
    import gear as G
    from echo import SlotName


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class GearFacts(_Strict):
    """What a piece of Gear does, derived from its atoms (D16 G1)."""
    territory: G.Territory
    #: runtime stat -> the factor the StatStack multiplies in.
    effects: dict[str, float]
    tier: Literal["USEFUL", "HIGH"]
    worn: bool = False


class InventoryItem(_Strict):
    #: The fold's own id: the menu reads name, kind, mk and history from
    #: `mechanics.owned` under it.
    component_id: str
    activation: Literal["slotted", "always_on", "worn"]
    compatible_slots: tuple[SlotName, ...] = ()
    equipped_in: SlotName | None = None
    charges_max: int | None = None
    charges_left: int | None = None
    siblings: tuple[str, ...] = ()
    gear: GearFacts | None = None


class SlotView(_Strict):
    slot: SlotName
    holds: str | None = None
    #: Owned items the authority would accept here, in fold order.
    accepts: tuple[str, ...] = ()


class TerritoryView(_Strict):
    """One of Design 1 §16.1's four Gear territories (D16 G1)."""
    territory: G.Territory
    holds: str | None = None
    #: Owned Gear the authority would accept here, in fold order.
    accepts: tuple[str, ...] = ()


class InventoryView(_Strict):
    items: tuple[InventoryItem, ...] = ()
    slots: tuple[SlotView, ...] = ()
    territories: tuple[TerritoryView, ...] = ()
    #: Echoed on every consumable intent (D-9); here so the menu that
    #: shows a supply also knows which supply it is showing.
    consumable_generation: int = Field(default=0, ge=0)


def charges_left(mechanics, consumable_uses, component_id: str) -> int:
    """Uses remaining on a consumable; zero for anything that is not one.

    The ONE rule: `CampaignSave.charges_left` asks it too, so the menu
    and the authorization path cannot disagree about a supply.
    """
    owned = mechanics.by_id(component_id)
    if owned is None or owned.kind != "action":
        return 0
    charges = getattr(owned.component, "charges", None)
    if charges is None:
        return 0
    spent = next((u.spent for u in consumable_uses
                  if u.component_id == component_id), 0)
    return max(charges - spent, 0)


def inventory_view(save) -> InventoryView:
    """The inventory, as the authority sees it right now."""
    return inventory_of(save.derive(), save.slots, save.consumable_uses,
                        save.consumable_generation, gear=save.gear)


def inventory_of(mechanics, slots, consumable_uses,
                 consumable_generation: int, gear=None) -> InventoryView:
    """The same view from what a snapshot already carries."""
    worn = dict(gear.worn()) if gear is not None else {}
    wearing = set(worn.values())
    held = dict(slots.assigned())
    equipped = {cid: slot for slot, cid in held.items()}
    created_by: dict[int, list[str]] = {}
    for owned in mechanics.owned:
        for p in owned.provenance:
            if p.operation == "create":
                created_by.setdefault(p.interpretation_seq, []).append(
                    owned.component_id)

    items = []
    for owned in mechanics.owned:
        comp = owned.component
        is_action = owned.kind == "action"
        is_gear = owned.kind == "gear"
        charges = getattr(comp, "charges", None) if is_action else None
        born = next((p.interpretation_seq for p in owned.provenance
                     if p.operation == "create"), None)
        siblings = tuple(c for c in created_by.get(born, ())
                         if c != owned.component_id)
        items.append(InventoryItem(
            component_id=owned.component_id,
            activation=("slotted" if is_action
                        else "worn" if is_gear else "always_on"),
            compatible_slots=(comp.slot,) if is_action else (),
            equipped_in=equipped.get(owned.component_id),
            charges_max=charges,
            charges_left=(charges_left(mechanics, consumable_uses,
                                       owned.component_id)
                          if charges is not None else None),
            siblings=siblings,
            gear=GearFacts(
                territory=G.territory_of(comp.domains[0]),
                effects=G.effects_of(comp.domains, comp.magnitudes),
                tier=G.one_piece_shape(comp.domains, comp.magnitudes),
                worn=owned.component_id in wearing) if is_gear else None))

    slot_views = tuple(SlotView(
        slot=slot, holds=held.get(slot),
        accepts=tuple(i.component_id for i in items
                      if slot in i.compatible_slots))
        for slot in C.SLOT_NAMES)
    territory_views = tuple(TerritoryView(
        territory=territory, holds=worn.get(territory),
        accepts=tuple(i.component_id for i in items
                      if i.gear is not None
                      and i.gear.territory == territory))
        for territory in G.TERRITORIES)
    return InventoryView(items=tuple(items), slots=slot_views,
                         territories=territory_views,
                         consumable_generation=consumable_generation)
