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

**What each field means for the menu:**

  activation       `slotted` for an Action, `always_on` for every other
                   kind. Always-on is NOT toggleable: passive does not
                   mean the player can switch it off.
  compatible_slots the slots the authority will accept it in -- an
                   Action's one declared slot, and none otherwise. The
                   menu offers exactly these, so a refusal is something
                   the player never has to be shown.
  equipped_in      the slot holding it now, or none.
  charges_*        a consumable's supply. `charges_left == 0` while
                   equipped is LEGAL (owner decision, 2026-09-22): it
                   stays selected, exhausted, until the refill.
  history          every source event that shaped this item, oldest
                   first -- its creation and each upgrade, modification,
                   link or merge. Upgrades live HERE, attached to the
                   resolved item, never as extra equippable objects.
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

from .schemas import constants as C
from .schemas.echo import SlotName


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class HistoryEntry(_Strict):
    interpretation_seq: int = Field(ge=0)
    operation: Literal["create", "upgrade", "modify", "link", "merge"]
    source_item_name: str
    source_game: str
    source_recipient_name: str
    note: str = ""


class InventoryItem(_Strict):
    component_id: str
    display_name: str
    description: str
    kind: str
    mk: int = Field(ge=1)
    activation: Literal["slotted", "always_on"]
    compatible_slots: tuple[SlotName, ...] = ()
    equipped_in: SlotName | None = None
    charges_max: int | None = None
    charges_left: int | None = None
    source_game: str
    history: tuple[HistoryEntry, ...] = Field(min_length=1)
    siblings: tuple[str, ...] = ()


class SlotView(_Strict):
    slot: SlotName
    holds: str | None = None
    #: Owned items the authority would accept here, in fold order.
    accepts: tuple[str, ...] = ()


class InventoryView(_Strict):
    items: tuple[InventoryItem, ...] = ()
    slots: tuple[SlotView, ...] = ()
    #: Echoed on every consumable intent (D-9); here so the menu that
    #: shows a supply also knows which supply it is showing.
    consumable_generation: int = Field(default=0, ge=0)


def inventory_view(save) -> InventoryView:
    """The inventory, as the authority sees it right now."""
    mechanics = save.derive()
    held = dict(save.slots.assigned())
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
        charges = getattr(comp, "charges", None) if is_action else None
        born = next((p.interpretation_seq for p in owned.provenance
                     if p.operation == "create"), None)
        siblings = tuple(c for c in created_by.get(born, ())
                         if c != owned.component_id)
        items.append(InventoryItem(
            component_id=owned.component_id,
            display_name=comp.display_name,
            description=comp.description,
            kind=owned.kind,
            mk=owned.mk,
            activation="slotted" if is_action else "always_on",
            compatible_slots=(comp.slot,) if is_action else (),
            equipped_in=equipped.get(owned.component_id),
            charges_max=charges,
            charges_left=(save.charges_left(owned.component_id)
                          if charges is not None else None),
            source_game=owned.source_game,
            history=tuple(HistoryEntry(
                interpretation_seq=p.interpretation_seq,
                operation=p.operation,
                source_item_name=p.source_item_name,
                source_game=p.source_game,
                source_recipient_name=p.source_recipient_name,
                note=p.note) for p in owned.provenance),
            siblings=siblings))

    slots = tuple(SlotView(
        slot=slot, holds=held.get(slot),
        accepts=tuple(i.component_id for i in items
                      if slot in i.compatible_slots))
        for slot in C.SLOT_NAMES)
    return InventoryView(items=tuple(items), slots=slots,
                         consumable_generation=save.consumable_generation)
