"""Every tone a caller asks for has to exist in the bank.

`Tones.play` looks its argument up in a dictionary and returns silently
when the name is absent, so a misspelled cue is not an error -- it is
simply no sound, forever, and nothing in a green suite says otherwise.

That is not hypothetical. `ZoneController._on_activity_completed` asked
for `"secret_found"` while `tones.gd` keys its chime `"secret"`; the
name is real in `epsilon_voice.gd`, which is how it got there. Solving
an activity made no sound for as long as that line stood, and the first
human playtest reported exactly that as "the game told me nothing".

This is the cheap half of the feedback repair: a textual check that the
code *contains* `tones.play(...)` would have passed the whole time. This
one asks whether the name resolves.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot" / "scripts"
BANK = GODOT / "ui" / "tones.gd"

#: `tones.play("x")`, `Tones.play("x")`, `_tones.play("x")` -- any
#: receiver, because the autoload is reached by several names.
CALL = re.compile(r"""\b[A-Za-z_][A-Za-z0-9_]*\.play\(\s*"([a-z_]+)"\s*[,)]""")
#: `_players["x"] = ...` is how the bank declares what it can voice.
DECLARED = re.compile(r"""_players\[\s*"([a-z_]+)"\s*\]\s*=""")


def _bank() -> set[str]:
    return set(DECLARED.findall(BANK.read_text(encoding="utf-8")))


def test_the_bank_declares_something() -> None:
    """A guard on the guard: an empty bank would pass everything."""
    kinds = _bank()
    assert len(kinds) >= 8, f"only parsed {sorted(kinds)} out of tones.gd"
    assert "secret" in kinds


def test_every_tone_a_caller_asks_for_exists() -> None:
    kinds = _bank()
    missing: list[str] = []
    for path in sorted(GODOT.rglob("*.gd")):
        if path == BANK:
            continue
        text = path.read_text(encoding="utf-8")
        for name in CALL.findall(text):
            # Only names the bank *could* own: several classes have their
            # own `play()` (an AnimationPlayer, a stream). A name the bank
            # does not know is only a defect if no other bank does, and
            # `tones.gd` is the only bank, so membership is the test --
            # restricted to calls on a receiver spelled like the tones
            # autoload so an animation name is not mistaken for a cue.
            if name in kinds:
                continue
            line = next((i + 1 for i, ln in enumerate(text.splitlines())
                         if f'.play("{name}"' in ln), 0)
            if re.search(rf"\b_?[Tt]ones\.play\(\s*\"{name}\"", text):
                missing.append(f"{path.relative_to(ROOT)}:{line} -> {name!r}")
    assert not missing, (
        "a caller asks the tone bank for a sound it does not define, so "
        "the cue is silent and nothing reports it:\n  "
        + "\n  ".join(missing)
        + f"\nthe bank defines: {sorted(kinds)}")
