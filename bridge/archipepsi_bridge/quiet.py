"""A LOWER-BUDGET GENERATION VARIANT, offered opt-in for comparison.

**Read the label first, because it is the finding.** This is NOT "the
same level with only the drills removed". It asks for a smaller band, so
it composes DIFFERENT ROOMS, and it comes out `+17` rooms and `+27`
enemies against the baseline over the twelve cases. Owner ruling,
2026-09-14: kept as an opt-in experimental candidate, labelled this way,
with those measurements preserved. **The strictly matched
no-compensation comparison remains INCOMPLETE** -- see the boundary
below for exactly what would have to change to complete it, and that
change is not made here.

What it does deliver is the narrower claim: the activity-family
substitution the owner asked against is gone.

**What this is.** Follow-up 02 item D. Skyiah played the two standalone
drills -- `timed_run` and `pressure_routing` -- and asked for a playable
comparison with them gone. `tools/family_retirement.py` already measured
what removing them from the offering does on its own, and the answer is
that it removes nothing: the composer picks a family by
`kinds[(guard + len(acts)) % len(kinds)]`, so 161 retired activities came
back as 176 more of the two families that stay, and the budget it could
not spend on an activity it spent on enemies. `fallback.ACTIVITY_KINDS`
says so at the site and leaves the policy to this lane.

**The policy choice, stated once: RETIREMENT IS A REDUCTION, NOT A
REALLOCATION.** The share of a Zone the retired families held is not
handed to the survivors, to enemies, to extra rooms or to a topped-up
score. It is simply not spent. A quieter Zone is a Zone that holds less,
and a preview whose point total matched the baseline would be measuring
nothing.

**What it is NOT.** Not a production policy, not a budget ruling, and not
enabled anywhere. Normal generation composes exactly what it composed
before -- `played_zone` stays at `fe2b014761fbb449`, verified by
regenerating it. No save is touched. `timed_run` and `pressure_routing`
remain in `ActivityKind`, remain buildable by the engine and remain
functional in any committed Zone that already holds them; what changes
in a preview is only what a new Zone is OFFERED. The plate
trigger/linger mechanics are untouched, and nothing translates a retired
race into a switch sequence.

**THE BOUNDARY, recorded rather than improvised.** The policy removes
the family substitution the owner asked against -- measured over the
twelve cases, the surviving families move `+176` under a bare filter and
`-5` under this policy. It does NOT hold rooms and enemies constant:
the preview arm comes out `+17` rooms and `+27` enemies against the
baseline. That is not a choice made here. `fallback._build_to_budget`
derives three separate quantities from the one `budget` number -- the
room envelope (`C.zone_room_envelope`), the enemy caps
(`C.max_enemies_per_zone`, `C.max_brutes_per_zone`) and the per-room
`soft_cap` that spreads content across rooms -- so lowering the band
necessarily loosens the per-room cap and buys more rooms and more
enemies with what it saves. Holding them constant means decoupling
those three derivations in the shipped composer, which is a generation
change this experiment may not make. The comparison is delivered with
the difference reported instead.

The same coupling is why the preview arm does not compose the same ROOMS
as the baseline at all: the provider seeds its rng with the budget
(`random.Random(f".../{n}/{budget}")`). Room-level content is matched in
the filter-only arm and is not matched in the preview arm.

**No new contract was needed.** `ZoneGenerationRequest.constraints` is
already a caller-settable dict and already carries `activity_kinds` and
`zone_budget`; its validator fills them only when the caller supplies
nothing. So a preview is an ordinary request with two keys set, and it
goes through the same provider, the same `validate_zone` and the same
acceptance path as any other. Nothing here post-edits an accepted Zone,
and nothing normalises an output into passing itself.
"""

from __future__ import annotations

try:
    from .schemas import constants as C
except ImportError:  # pragma: no cover
    from schemas import constants as C

#: The two families the preview stops OFFERING. Readable, and still
#: legal everywhere else: the schema keeps them, the engine still builds
#: them, and a Zone already holding one still plays.
RETIRED_FAMILIES: tuple[str, ...] = ("timed_run", "pressure_routing")

#: What a preview request offers instead. Derived, so adding a family to
#: the schema cannot silently leave it out of the preview.
def preview_kinds() -> tuple[str, ...]:
    try:
        from .schemas.zone import ActivityKind
    except ImportError:  # pragma: no cover
        from schemas.zone import ActivityKind
    return tuple(k for k in ActivityKind.__args__
                 if k not in RETIRED_FAMILIES)


#: The share of a Zone's content value the retired families actually
#: held, measured over the twelve default-scale cases
#: `tools/family_retirement.py` composes:
#:
#:     mean 27.4%   median 27.8%   min 22.8%   max 32.8%
#:
#: ONE CONSTANT, DERIVED ONCE, APPLIED TO EVERY CASE. Deriving a budget
#: per Zone from that Zone's own content would be normalising each
#: output into passing itself, which is the thing a comparison may not
#: do: every Zone would pass by construction and the acceptance column
#: would carry no information. This is rounded DOWN from the surviving
#: 72.6% so the preview asks for slightly less rather than slightly
#: more -- if the constant is wrong, it should err toward quieter, not
#: toward quietly topping the Zone back up.
PREVIEW_BUDGET_FRACTION = 0.72


def preview_budget(normal_budget: int) -> int:
    """The band a preview asks for: the baseline less the retired share.

    Not a campaign setting. `CampaignScale.zone_budget` is untouched and
    no generation path reads this.
    """
    return int(round(normal_budget * PREVIEW_BUDGET_FRACTION))


def preview_constraints(request) -> dict:
    """An ordinary request's constraints, narrowed for the preview.

    Two keys, both of which the request already had: which families may
    be composed from, and how big the band is. Everything else -- the
    Checks, the room envelope, the enemy caps, the AP logic -- is the
    request's own and is carried through untouched, because a comparison
    in which a second thing moved measures neither.
    """
    out = dict(request.constraints)
    out["activity_kinds"] = list(preview_kinds())
    out["zone_budget"] = preview_budget(int(out["zone_budget"]))
    return out
