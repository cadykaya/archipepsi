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
    raise ValueError(f"unknown Epsilon provider '{name}'")
