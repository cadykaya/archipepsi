"""Epsilon providers: mock, deterministic fallback, and Claude."""

from .base import EpsilonProvider, GenerationOutcome, generate_echo_validated, generate_zone_validated
from .fallback import FallbackEpsilonProvider, fallback_echo, fallback_zone
from .mock import MockEpsilonProvider
from .requests import (
    CampaignContext, EchoGenerationRequest, EchoSummary, PlayerContext,
    RequestLocation, ZoneGenerationRequest, ZoneSummary,
)

__all__ = [
    "EpsilonProvider", "GenerationOutcome",
    "generate_zone_validated", "generate_echo_validated",
    "FallbackEpsilonProvider", "fallback_zone", "fallback_echo",
    "MockEpsilonProvider",
    "ZoneGenerationRequest", "EchoGenerationRequest",
    "CampaignContext", "PlayerContext", "RequestLocation",
    "EchoSummary", "ZoneSummary",
]


def make_provider(name: str):
    """Resolve a provider by configuration name."""
    if name == "mock":
        return MockEpsilonProvider()
    if name == "fallback":
        return FallbackEpsilonProvider()
    if name == "claude":
        from .claude import ClaudeEpsilonProvider
        return ClaudeEpsilonProvider()
    # A NAMED SAMPLE, SERVED LIVE. `--epsilon=sample` asks for one
    # proposal out of the declared sample instead of composing one, so a
    # case the offline census names can be put in front of a real client
    # and a real bridge. The path travels in the environment because the
    # provider is constructed by name and nothing else threads a value
    # through; it is a diagnostic axis, never a shipping one.
    if name == "sample":
        import os
        from .sample import SampleEpsilonProvider
        where = os.environ.get("ARCHIPEPSI_SAMPLE_ZONE", "")
        if not where:
            raise ValueError(
                "--epsilon=sample needs ARCHIPEPSI_SAMPLE_ZONE to name "
                "the proposal to serve")
        return SampleEpsilonProvider(where)
    raise ValueError(f"unknown Epsilon provider '{name}'")
