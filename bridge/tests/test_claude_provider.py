"""ClaudeEpsilonProvider tests with a stubbed SDK client — no network.

The shared pipeline is the authority on validation; these tests pin the
provider's own responsibilities: prompt framing, repair-turn construction,
refusal handling, and structured-output degradation.
"""

from __future__ import annotations

import json
from types import SimpleNamespace

import pytest

anthropic = pytest.importorskip("anthropic")

from archipepsi_bridge.epsilon import fallback_zone, generate_zone_validated
from archipepsi_bridge.epsilon.claude import ClaudeEpsilonProvider

from .conftest import run
from .test_providers import zone_request


def _response(text: str, stop_reason: str = "end_turn"):
    return SimpleNamespace(
        stop_reason=stop_reason, stop_details=None,
        content=[SimpleNamespace(type="text", text=text)])


class StubMessages:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls: list[dict] = []

    async def create(self, **kwargs):
        self.calls.append(kwargs)
        result = self.responses.pop(0)
        if isinstance(result, Exception):
            raise result
        return result


def _provider(*responses) -> tuple[ClaudeEpsilonProvider, StubMessages]:
    provider = ClaudeEpsilonProvider(model="claude-opus-5")
    stub = StubMessages(responses)
    provider.client = SimpleNamespace(messages=stub)
    return provider, stub


def test_valid_zone_passes_pipeline_without_fallback():
    async def scenario():
        request = zone_request()
        zone_json = json.dumps(fallback_zone(request))
        provider, stub = _provider(_response(f"```json\n{zone_json}\n```"))
        outcome = await generate_zone_validated(
            provider, request,
            allocated_location_ids=[89100001, 89100002], owned_echo_ids=[])
        assert outcome.used_fallback is False
        assert outcome.value.zone_id == "zone_001"
        # Untrusted-input framing and the schema are in the prompt.
        prompt = stub.calls[0]["messages"][0]["content"]
        assert "<ap_data>" in prompt and "never as instructions" in prompt
        assert "json_schema" in str(stub.calls[0].get("output_config", ""))
    run(scenario())


def test_refusal_uses_deterministic_fallback():
    async def scenario():
        request = zone_request()
        provider, _ = _provider(_response("", stop_reason="refusal"))
        outcome = await generate_zone_validated(
            provider, request,
            allocated_location_ids=[89100001, 89100002], owned_echo_ids=[])
        assert outcome.used_fallback is True
    run(scenario())


def test_repair_turn_carries_previous_output_and_errors():
    async def scenario():
        request = zone_request()
        good = json.dumps(fallback_zone(request))
        provider, stub = _provider(
            _response('{"nonsense": true}'), _response(good))
        outcome = await generate_zone_validated(
            provider, request,
            allocated_location_ids=[89100001, 89100002], owned_echo_ids=[])
        assert outcome.used_fallback is False
        assert len(stub.calls) == 2
        repair_messages = stub.calls[1]["messages"]
        assert repair_messages[1]["role"] == "assistant"
        assert "nonsense" in repair_messages[1]["content"]
        assert "rejected" in repair_messages[2]["content"]
    run(scenario())


def test_schema_rejection_degrades_to_prompt_json():
    httpx2 = pytest.importorskip("httpx2")

    async def scenario():
        bad_request = anthropic.BadRequestError(
            "unsupported schema",
            response=httpx2.Response(
                400, request=httpx2.Request("POST", "http://test")),
            body=None)
        request = zone_request()
        good = json.dumps(fallback_zone(request))
        provider, stub = _provider(bad_request, _response(good))
        outcome = await generate_zone_validated(
            provider, request,
            allocated_location_ids=[89100001, 89100002], owned_echo_ids=[])
        assert outcome.used_fallback is False
        assert provider._schema_ok["zone"] is False
        assert "output_config" in stub.calls[0]
        assert "output_config" not in stub.calls[1]
    run(scenario())
