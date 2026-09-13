"""The quieter-generation preview: opt-in, and normal generation intact.

Follow-up 02 item D. The policy is `archipepsi_bridge.quiet`: retirement
is a REDUCTION, not a reallocation. What these guard is that the preview
is genuinely opt-in, that it does not substitute, and that the two
retired families stay legal everywhere they already exist.
"""

from __future__ import annotations

import collections

from archipepsi_bridge import quiet
from archipepsi_bridge.epsilon import fallback
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.zone import ActivityKind, Zone, validate_zone

from .test_fallback_scale import _request  # the same request shape


def _zone(index, *, kinds=None, budget=None) -> dict:
    cfg = C.DEFAULT_CONFIG
    req = _request(cfg.zone_target_checks, cfg.zone_budget, index=index)
    if budget is not None:
        req = req.model_copy(update={
            "campaign": req.campaign.model_copy(
                update={"zone_budget": budget})})
    if kinds is not None:
        req = req.model_copy(update={
            "constraints": {**req.constraints, "activity_kinds": list(kinds)}})
    return fallback.fallback_zone(req)


def _families(zone) -> collections.Counter:
    return collections.Counter(
        a["kind"] for c in zone["chambers"] for a in (c.get("activities") or ()))


def test_an_unnarrowed_request_composes_exactly_what_it_did_before():
    """THE OPT-IN HALF, and the one that must not be taken on trust.

    The provider now reads `constraints["activity_kinds"]`, which it
    always ignored. The request's list and this module's list are the
    same SET in a different ORDER, and the picker is
    `kinds[(guard + len(acts)) % len(kinds)]` — order decides which
    family each slot gets. Reading the request's order directly moved
    the played Zone's digest on a request that had narrowed nothing.
    So an un-narrowed request must be bit-identical, not merely similar.
    """
    for i in range(4):
        assert _zone(i) == _zone(i, kinds=list(fallback.ACTIVITY_KINDS)), (
            f"zone {i} changed when the full vocabulary was passed "
            "explicitly; the offer is being read in the wrong order")


def test_the_preview_offers_only_the_families_that_stay():
    for i in range(4):
        fams = set(_families(_zone(i, kinds=quiet.preview_kinds(),
                                   budget=quiet.preview_budget(
                                       C.DEFAULT_CONFIG.zone_budget))))
        assert not (fams & set(quiet.RETIRED_FAMILIES)), fams


def test_the_preview_does_not_substitute_what_it_retired():
    """THE WHOLE POINT. A bare filter gives the removed content straight
    back as more of the families that stay; the policy must not.

    Measured over twelve cases: `+176` under a bare filter, `-5` under
    the policy. It is NOT exactly zero and is not claimed to be — over
    the four cases here the policy comes out `+1` — so what is asserted
    is the relationship that actually holds: whatever the policy
    substitutes is a rounding error beside what the bare filter does.
    Asserting `<= baseline` passed at twelve cases and failed at four,
    which would have made this control a transcription of one run.
    """
    budget = quiet.preview_budget(C.DEFAULT_CONFIG.zone_budget)
    kept = [k for k in ActivityKind.__args__
            if k not in quiet.RETIRED_FAMILIES]
    base = collections.Counter()
    filtered = collections.Counter()
    preview = collections.Counter()
    for i in range(4):
        base.update(_families(_zone(i)))
        filtered.update(_families(_zone(i, kinds=quiet.preview_kinds())))
        preview.update(_families(
            _zone(i, kinds=quiet.preview_kinds(), budget=budget)))

    def survivors(counts):
        return sum(counts.get(k, 0) for k in kept)

    assert survivors(filtered) > survivors(base), (
        "the bare filter stopped substituting, so this control no longer "
        "has a subject")
    bare = survivors(filtered) - survivors(base)
    policy = survivors(preview) - survivors(base)
    assert bare > 0, "the bare filter stopped substituting"
    assert abs(policy) <= 0.10 * bare, (
        f"the preview substituted {policy:+d} of the families that stay "
        f"against the bare filter's {bare:+d}; the policy is supposed to "
        "leave the removed content unspent, not hand it back")


def test_the_preview_is_accepted_by_ordinary_validation():
    """Playable, not post-edited JSON that acceptance rejects."""
    budget = quiet.preview_budget(C.DEFAULT_CONFIG.zone_budget)
    for i in range(4):
        z = Zone.model_validate(
            _zone(i, kinds=quiet.preview_kinds(), budget=budget))
        errs = [e for e in validate_zone(
            z, expected_zone_id=z.zone_id,
            allocated_location_ids=list(z.reward_location_ids),
            owned_echo_ids=[], zone_budget=budget) if "shell" not in e]
        assert not errs, errs


def test_the_retired_families_stay_legal_everywhere_they_already_are():
    """Retired from the OFFER, not from the game.

    A committed Zone holding one still loads and still validates, the
    schema still names both, and nothing translates a retired race into
    a switch sequence.
    """
    assert set(quiet.RETIRED_FAMILIES) <= set(ActivityKind.__args__)
    z = Zone.model_validate(_zone(0))
    assert set(_families(_zone(0))) & set(quiet.RETIRED_FAMILIES), (
        "this control needs a baseline Zone that still holds one")
    errs = [e for e in validate_zone(
        z, expected_zone_id=z.zone_id,
        allocated_location_ids=list(z.reward_location_ids),
        owned_echo_ids=[],
        zone_budget=C.DEFAULT_CONFIG.zone_budget) if "shell" not in e]
    assert not errs, errs
