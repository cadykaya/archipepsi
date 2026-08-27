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
docs/design-packet-v0.7/   the frozen implementation contract
docs/IMPLEMENTATION_DECISIONS.md   deviations and constraints
NEXT_STEPS.md       operational build state
```

## Setup

Requirements: Python 3.11 (3.11.9+), git, and — for the game itself — the
official Godot 4.5.1 stable binary.

```bash
make setup          # clones + pins Archipelago 0.6.7 into .archipelago/
make test           # 180+ tests: schemas, bridge, campaign, APWorld
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
MOCK CAMPAIGN for a complete offline fixture campaign.

Controls: WASD + mouse, Space jump, **LMB Static Pulse (always)**, **RMB
equipped Echo**, E interact, Q cycle Echo, Tab inventory, Esc pause, F3
debug overlay.

## Test configurations

The two axes are independent (`--ap=real|mock` × `--epsilon=claude|mock|fallback`).
**Real AP + fallback Epsilon** is the most valuable configuration: the whole
loop, no API cost, no nondeterminism.

```bash
make smoke                                     # headless bridge loop (mock AP)
python3 -m archipepsi_bridge.smoke_real        # same against a live server
make godot-integration                         # the full game, headlessly
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

All seven implementation phases of the v0.7 packet are built and the full
campaign loop is proven end-to-end headlessly (mock AP) and against a real
Archipelago 0.6.7 server. See `NEXT_STEPS.md` for the live frontier.
