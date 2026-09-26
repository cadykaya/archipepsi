# P14 — the latch-route candidate: replay and launch

**What it is.** Dess's `godot/tests/fixtures/latched_route_zone.json`: the
played `zone_001` (default scale, fallback provider, mock slot `Skyiah`)
with `latched_route.compose_latched_route` applied. That puts a `MEDIUM`
plate that counts the player and a `LATCH` in `c002`, plus a shutter
across the doorway that `TopologyEdge e:c002:c003.opened_by` names. You
step on the plate once and then walk through. It is **opt-in only**: the
ordinary campaign composes no room graph, and nothing below changes that.

**Identity, checked.** The live path (bridge `--ap=mock --epsilon=fallback
--mock-scale=default`, slot `Skyiah`) generates the same `zone_001` as
`playtest.played_zone()`, id `31b0c6aeae37de93`.
`bridge/tools/compose_latched_route.py` applies the composer to it and
refuses unless the result equals the fixture byte for byte: `508868a38b2fd508`.
**No re-keying**: same Zone id, rooms, Checks, plate, latch and shutter.

## Commands

| command | what it does |
|---|---|
| `make godot-latched-route` | Standalone, about 95 s. Runs the fixture from its own arrival with the real body. The arena is cleared with the base kit, the shut doorway is pressed against, the plate is stepped on (one real `latch_fired`) and off, and the player walks through into `c003` and back. The control takes the `LATCH` out, and the same walk stops at the door. |
| `make godot-latched-route-live` | About 85 s. **seed**: the real path generates `zone_001`, and the tool composes it (identity checked). **play**: the real `Main` goes through the portal and gets the bridge's own layout verdict. The latch is accepted and read back off the save file on disk, and forged latches are refused: pre-commit, unknown latch, room with no graph, unplaced room. **restore**: both processes are restarted, and the route is open before anyone reaches the plate. Nothing is announced, and the doorway is walked with the plate untouched. |
| `make latched-route-play` | By hand, in the ordinary windowed client, on a disposable save in `.latched-route-play/`. The first run seeds it; `FRESH=1` discards and reseeds it. |
| `make latched-route-fixture` | Dess's: regenerates the fixture from source. It is never hand-edited. |

## By hand

1. `make latched-route-play`
2. Title screen: **MOCK CAMPAIGN**. Then, in the Hub, take the portal into `zone_001`.
3. Walk on into `c002`, the second room: a battery of five artillery
   guards its reward. Artillery cannot fire at anything within 8 m, so
   get in among the guns and clear them.
4. A shutter closes the far doorway (to `c003`). The plate is on this
   side of it. Step on the plate and the shutter rises. Step off and it
   stays up.
5. Walk through into `c003`, then come back.
6. Quit, then run `make latched-route-play` again without `FRESH`. Take
   the portal back in: the doorway is already open before you go near
   the plate.

## Where things live

- The saves are in `.latched-route-play/` (by hand) and
  `.latched-route-saves/` (the gate). Both are git-ignored and disposable.
  No other save, build or asset is read or written.
- The logs are `/tmp/archipepsi-latched-*.log`.

## Limits

- The by-hand target launches the ordinary windowed client. It was not
  run windowed in the environment that wrote it, because there is no
  display there. The same client path runs headless, end to end, in
  `godot-latched-route-live`.
- This closes one permanent-latch interaction: "step on it once, walk
  through". It is not the cross-room puzzle programme, and reversible or
  held requirements are not modelled as latches.
- The composed room is a `kill_all` arena of five artillery. The
  acceptance clears it with the base kit (0 hp lost), but a hurried
  player standing outside the guns' 8 m minimum range will be shelled.
- The bridge's startup banner prints `zone 1 31b0c6aeae37de93`. That id
  is computed from the default composition (`playtest.played_zone`),
  not read from the save. The `zone_001` in the save is the composed
  `508868a38b2fd508`, which the compose tool checked.
