# Archipepsi — APWorld Specification (v0.7)

Authority for the Archipepsi APWorld: locations, items, regions, logic, slot data, packaging, and the recommended YAML.

Targets **Archipelago 0.6.7**. Re-verify against the pinned tag if it moves.

> **Authority:** see `README.md`. IDs and counts are in `schemas/constants.py` and are binding.

---

# 1. Identity

Game name: `Archipepsi`. Package: `archipepsi`.

No custom generation options are required. Use Archipelago's standard per-game common options.

`epsilon_creativity` is a **runtime Archipepsi setting**, not an AP generation option, and never appears in slot data or YAML.

---

# 2. Locations

Exactly **30** addressed locations:

```
Archipepsi Check 001 -> 89_100_001
Archipepsi Check 002 -> 89_100_002
...
Archipepsi Check 030 -> 89_100_030
```

Python may use underscores; serialized JSON uses plain integers such as `89100001`.

ID range note: Archipelago permits IDs to overlap other games' IDs, so there is no collision concern. Keep IDs ≤ 2^31−1, which these are.

**Check 030 is the goal location** and is reserved by the runtime — never shop stock, never a normal Zone reward. The APWorld itself needs no special handling for this; it is a runtime allocation rule (`DESIGN.md` §10.6). Note this asymmetry deliberately: to Archipelago, Check 030 is an ordinary location.

---

# 3. Regions and logic tiers

Three regions plus the origin.

**Critical:** Archipelago's origin region defaults to `"Menu"`. v0.3 named the first region `Start` without setting `origin_region_name`, which makes generation fail outright. Pick one and be explicit:

```python
class ArchipepsiWorld(World):
    game = "Archipepsi"
    origin_region_name = "Menu"     # or rename the region below to "Menu"
```

| Region | Locations | Entrance rule |
|---|---|---|
| `Menu` | — | origin |
| `Start` | Checks 001–010 | always |
| `Tier 1` | Checks 011–020 | `state.has("Signal Key", player, 1)` |
| `Tier 2` | Checks 021–030 | `state.has("Signal Key", player, 2)` |

`Menu → Start → Tier 1 → Tier 2`, chained.

The bridge mirrors this tier structure when deciding eligibility. **The mirror is `schemas/constants.py`: `TIER_BOUNDS`, `tier_of()`, `locations_in_tier()`, `unlocked_location_ids()`.** Build the regions from those functions and derive the slot-data `tiers` block from them too, so the mapping exists once rather than four times. (v0.4 pointed at a `TIER_BOUNDS` that was never defined, which guaranteed the opposite.)

**`unlocked_location_ids()` is the APWorld's function, not the bridge allocator's.** It answers "is this location reachable in Archipelago logic", so it includes Check 030 — correct here, because to Archipelago the goal is an ordinary Tier 2 location. The runtime's allocator and shop call **`eligible_location_ids()`** instead, which is the same set minus the goal. v0.5 described the first function as "legal to allocate ... goal included" and told both callers to derive from it; that sentence is how the shop ended up able to sell the goal. The two functions are deliberately named differently and the goal-free one is the one every allocation path uses.

---

# 4. Items

Exactly three addressed item names:

```
Signal Key      -> 89_200_001   progression   x2
Epsilon Coin   -> 89_200_002   filler        x10
Epsilon Static -> 89_200_003   filler        x18
```

Total 30, matching the location count exactly.

**Signal Key** — monotonic, never spent. 0 keys: Start eligible. 1: +Tier 1. 2: all 30.

**Epsilon Coin** — delivered through normal `ReceivedItems`, contributes to lifetime coins received, spendable only in Archipepsi's local Hub shop. Spending is local persisted state; coins are never removed from AP's inventory history.

**Epsilon Static** — `filler`. Runtime effect is a permanent unit of cosmetic Hub corruption plus a counter Epsilon may reference in flavor text. **Purely cosmetic — never affects logic, difficulty, or reachability.** (v0.4: in v0.3 it did nothing, which made 60% of the player's item feed empty.)

---

# 5. Completion

Create one **unaddressed** event location `Archipepsi Victory Event` in `Tier 2`, and place a locked event item `Victory` (code `None`) on it:

```python
victory_loc = ArchipepsiLocation(player, "Archipepsi Victory Event", None, tier2)
victory_loc.place_locked_item(ArchipepsiItem("Victory", ItemClassification.progression, None, player))
tier2.locations.append(victory_loc)
multiworld.completion_condition[player] = lambda state: state.has("Victory", player)
```

So the generator's completion condition is effectively "2 Signal Keys".

**Runtime completion is deliberately stricter, and does not end play.** Confirming Check 030 reports goal and shows the victory presentation; the campaign then continues in postgame with the Hub portal still working, because up to 5 real locations may still be unchecked and their items belong to other players. See `DESIGN.md` §13.5.

 The client reports goal (`ClientStatus.CLIENT_GOAL`, value 30) only when **Check 030 is confirmed**, and Check 030 is only reachable through the finale Zone, which requires 2 Keys **and** 24 of the other 29 Checks (`DESIGN.md` §10.6).

A runtime stricter than AP logic is safe: the seed remains beatable, the solver's reachability assumption still holds, and the player simply takes longer than the solver assumed. The dangerous direction — a runtime *looser* than logic — does not occur here.

---

# 6. Slot data

Small client-required seed information only. Location→item placements are obtained by scouting, never by slot data.

```json
{
  "schema_version": 7,
  "location_ids": [89100001, "...", 89100030],
  "tiers": {
    "0": [89100001, "...", 89100010],
    "1": [89100011, "...", 89100020],
    "2": [89100021, "...", 89100030]
  },
  "goal_location_id": 89100030,
  "item_names": {
    "signal_key": "Signal Key",
    "epsilon_coin": "Epsilon Coin",
    "epsilon_static": "Epsilon Static"
  }
}
```

---

# 7. Recommended player YAML

```yaml
name: Skyiah
game: Archipepsi

Archipepsi:
  accessibility: full
  progression_balancing: 50

  # The POC exists to demonstrate other players finding our currency.
  non_local_items:
    - Epsilon Coin
```

This forces Epsilon Coins outside the Archipepsi world wherever legal placement exists. Signal Keys are **not** forced non-local; normal fill decides.

## 7.1 Solo testing variant

> **A solo seed cannot demonstrate the POC.** With one world, all 30 items land on the 30 Archipepsi locations, so every recipient is the Archipepsi slot. No foreign recipients means **zero Echoes for the whole campaign**, **zero shop-eligible stock ever**, and 10 permanently unspendable Coins — removing steps 8–12 of `DESIGN.md` §4. Use it to smoke-test generation and connection only. For anything involving Echoes or the shop, use Mock Campaign or generate against at least one other world.

For testing generation and connection alone:

```yaml
name: SkyiahTest
game: Archipepsi

Archipepsi:
  accessibility: full
  progression_balancing: 0
  # no non_local_items - everything stays local and reachable solo
```

The default YAML makes the goal depend on other players finding two Signal Keys, which is correct Archipelago citizenship and bad demo determinism. Keep both files. Mock Campaign covers the same need without a server at all.

---

# 8. Packaging

Develop as a normal world folder. `apworld/archipepsi/archipelago.json`:

```json
{
  "game": "Archipepsi",
  "world_version": "0.7.0",
  "minimum_ap_version": "0.6.7",
  "authors": ["Skyiah"]
}
```

`game` is required. `world_version` must be exactly `major.minor.build`; a world without one is treated as older than any world with one. Archipelago is moving to require the manifest for all worlds before 0.7.0.

**Build with Archipelago's own "Build APWorlds" launcher component**, which outputs to `build/apworlds` and adds `version` and `compatible_version` automatically.

Do **not** hand-write those two fields, and do **not** hand-roll a zip script — v0.3's `build_apworld.py` would have produced a manifest the loader mis-versions. If a wrapper script is wanted, have it invoke the official component rather than reimplement it.

The `.apworld` zip must contain a folder named identically to the zip, case-sensitive. An `.apignore` file (gitignore syntax) can exclude files from the archive.

---

# 9. Generation self-checks

Assert in `apworld/tests`:

- exactly 30 addressed locations, IDs 89100001–89100030
- item codes 89200001 / 89200002 / 89200003
- pool contains exactly 2 / 10 / 18 of each
- item count equals location count
- an origin region exists and `origin_region_name` matches it
- Tier 0 reachable from start; Tier 1 needs 1 key; Tier 2 needs 2
- the Victory event exists, is unaddressed, and sits in Tier 2
- `completion_condition` uses the Victory item
- Check 030 is in Tier 2
- slot data is schema version 7 and contains no placements
- the world generates end-to-end, solo
- the world generates in a multiworld alongside another world with `non_local_items: Epsilon Coin`
- `.apworld` packaging succeeds and the manifest validates
