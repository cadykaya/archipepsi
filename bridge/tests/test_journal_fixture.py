"""The journal's fixture must still be what its generator produces.

`godot/tests/fixtures/journal_snapshot.json` is the model's own
`CampaignSnapshot` over the candidate Zone after real transitions, so the
journal (H-JOURNAL) is tested against what the bridge actually sends. This
guards the JSON against drifting from the generator, and the variants
against quietly losing what they are named for.
"""

from __future__ import annotations

import json

from archipepsi_bridge.fixtures import make_journal_snapshot as gen


def test_the_committed_fixture_matches_its_generator():
    on_disk = gen.OUT.read_text(encoding="utf-8")
    assert on_disk == gen.render(), (
        "run `make journal-fixture`; the JSON is generated, not edited")


def test_each_variant_is_the_state_it_is_named_for():
    """The journal's cases are only tested if the variants hold them."""
    v = json.loads(gen.render())
    assert v["hub"]["active_zone"] is None
    assert v["hub"]["zone_map"] is None
    shut = [c for c in v["walked"]["zone_map"]["connectors"]
            if c["state"] != "open"]
    assert len(shut) >= 3 and all(c["reason"] for c in shut)
    arrived = v["arrived"]["active_zone"]["progress"]
    assert not arrived["collected_keys"] and not arrived["macro_state"]
    progressed = v["progressed"]["active_zone"]["progress"]
    assert sorted(progressed["collected_keys"]) == ["blue", "red"]
    assert progressed["opened_locks"] == ["c005/side_right"]
    assert ["power_cell", "cell_socket"] in progressed["consumed_objects"]
    assert ["span_alignment", "lowered"] in progressed["macro_state"]
    assert v["latched"]["active_zone"]["progress"]["latched"] \
        == ["graph_c009/held"]
    assert ["span_alignment", "stowed"] \
        in v["stowed"]["active_zone"]["progress"]["macro_state"]
    # Two of this Zone's Checks are confirmed, and a location is never
    # both checked and missing.
    snap = v["progressed"]
    here = set(snap["active_zone"]["allocated_location_ids"])
    assert len(here & set(snap["checked_location_ids"])) == 2
    assert not set(snap["checked_location_ids"]) \
        & set(snap["missing_location_ids"])
    assert len(snap["interpretations"]) >= 3
