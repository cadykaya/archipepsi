# Archipepsi

An [Archipelago](https://archipelago.gg) game whose campaign is constructed
*during* the multiworld by an AI dungeon master called **Epsilon**, using the
actual randomized items sitting in the player's Archipelago locations as the
inspiration for levels, rewards, shops, and permanent local abilities called
**Echoes**.

> Archipelago decides the randomized truth. Archipepsi's deterministic code
> decides which truth is currently presented. Epsilon decides what that
> presentation feels like.

Clear a Check holding `Conference Call → BL2Player` and two things happen:
BL2Player receives the real Conference Call, and Epsilon hands you its local
reinterpretation — a ridiculous recoil shotgun that doubles as a movement
tool. Future Zones are designed around what you own.

The look is deliberate **late-1990s PC FPS**: GoldSrc-era brushwork, 64×64
procedural textures generated in code, harsh lights, chunky prisms and
catwalks. Zero shipped assets.

## Layout

```
apworld/            the Archipelago world (30 Checks, 3 tiers, Victory event)
bridge/             Python 3.11: AP client, campaign brain, Epsilon providers
godot/              Godot 4.5.1 (stock, GDScript): the actual videogame
docs/design-packet-v0.8/   the implementation contract
docs/IMPLEMENTATION_DECISIONS.md   deviations and constraints
NEXT_STEPS.md       operational build state
```

## Setup

Requirements: Python 3.11 (3.11.9+), git, and — for the game itself — the
official Godot 4.5.1 stable binary.

```bash
make setup          # clones + pins Archipelago 0.6.7 into .archipelago/
make test           # 487 tests: schemas, bridge, campaign, APWorld
```

If `pip` cannot replace a distro-managed package during setup, install AP's
core requirements with
`pip install -r .archipelago/requirements.txt --ignore-installed`.

Godot: place the official 4.5.1 binary at `godot-bin/godot`
(https://godotengine.org/download — build `f62fdbde1`), then:

```bash
make godot-test           # headless chamber-geometry tests
make godot-integration    # plays the ENTIRE campaign headlessly vs mock AP
```

## Running the game

Two processes: the bridge (owns the campaign, talks to Archipelago) and
Godot (renders the videogame).

```bash
# 1. A server to play on (or use any real Archipelago room):
make seed-multi && make host          # demo 2-slot seed on localhost:38281

# 2. The bridge:
make bridge                           # real AP, fallback Epsilon (default)
#   --epsilon=claude needs ANTHROPIC_API_KEY (runtime credits are separate
#   from development!); without a key it downgrades to fallback and says so.
#   EPSILON_MODEL overrides the model id.

# 3. The game:
godot-bin/godot --path godot
```

In the menu: server `localhost:38281`, slot `Skyiah`, CONNECT — or press
MOCK CAMPAIGN for a complete offline fixture campaign, which needs no
server and no seed.

The bridge prints what it is doing on startup — the port Godot connects
to, whether it is on a real server or the offline fixture, which Epsilon
is running, and **the absolute path it will write saves to**. That last
line matters: the save directory is relative to where the bridge was
STARTED unless `ARCHIPEPSI_SAVE_DIR` is set, so `make bridge` (which runs
from `bridge/`) and the same command from the repo root are two different
campaigns.

Controls: WASD + mouse, Space jump, E interact, Tab inventory, Esc pause,
F3 debug overlay.

**LMB is always the Static Pulse** and never changes. The four Echo slots
each have their own key:

| Slot | Key |
| --- | --- |
| `echo_a` | RMB |
| `echo_b` | MMB, or F |
| `mobility` | Shift |
| `utility` | C |

The mouse wheel cycles favourites within the slot you are looking at.

### Two Archipepsi players in one multiworld

The demo seed generates two Archipepsi worlds (`Skyiah` and `Partner`),
and both can play at once. On one machine that means two bridges, which
need two ports and two save directories:

```bash
cd bridge
ARCHIPEPSI_SAVE_DIR=$PWD/saves-a python3 -m archipepsi_bridge &
ARCHIPEPSI_SAVE_DIR=$PWD/saves-b python3 -m archipepsi_bridge --port 38291 &
```

Then point one Godot at 38290 and the other at 38291, connecting as
`Skyiah` and `Partner`. `make dual-real` proves this path automatically
against a real server.

## Test configurations

The two axes are independent (`--ap=real|mock` × `--epsilon=claude|mock|fallback`).
**Real AP + fallback Epsilon** is the most valuable configuration: the whole
loop, no API cost, no nondeterminism.

```bash
make smoke                                     # headless bridge loop (mock AP)
python3 -m archipepsi_bridge.smoke_real        # same against a live server
make dual-real                                 # TWO Archipepsi slots, one server
make dual-real-soak                            # the same across fresh seeds
make godot-integration                         # the full game, headlessly
```

`bridge/tests/test_startup.py` is the one shaped like an ordinary launch
rather than a subsystem: the bridge binds, Godot's handshake succeeds, the
mock campaign plays a Zone, the save lands where the banner said, and the
three configuration mistakes most likely on a first run each produce a
message that names the fix.

## CI

Three tiers, documented in `docs/CI.md`: a fast PR gate that needs neither
Archipelago nor Godot, a full integration gate that adds both and runs the
whole campaign headlessly, and a nightly tier that generates real
multiworlds and — importantly — proves a **fresh clone reaches green with
no caches at all**.

```bash
make version        # what this build is: version, commit, tree state
```

## Known limitations (by design — see DESIGN.md §18)

- **Deleting the save restores spent coins.** AP remembers every delivered
  Coin; spending is intentionally local. Purchased locations stay checked.
- **Duplicate source items produce independent Echoes.** Two Hookshots are
  two different interpretations. Intended.
- **The shop may not appear in a short session** — it needs 2 completed
  Zones and Coins other players must find first.
- **A solo seed produces no Echoes and no shop at all** (every recipient is
  yourself). Use Mock Campaign or a multiworld to see the real loop.
- Race-mode rooms are refused before scouting.

## Status

The v0.7 POC is complete, and the v0.8 **Echoes 2.0** arc on top of it is
complete through S10: an Echo is an interpretation carrying up to four
operations, live mechanics are a pure fold over an append-only
interpretation log, and a foreign item can now upgrade, modify, link or
merge what you already own rather than only adding a twenty-seventh
unrelated thing.

The loop is proven headlessly (mock AP), against a real Archipelago 0.6.7
server, and — since the dual-slot proof — with two Archipepsi players in
the same multiworld at once. See `NEXT_STEPS.md` for the live frontier and
`docs/design-packet-v0.8/AUTHORED_CONTENT.md` before doing any art work.
