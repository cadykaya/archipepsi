# Unified integration 1: the systems as one game

Prod, 2026-10-17, for Skyiah, with notes for Dess, Condi and Arty.

- **Branch:** `integration/unified-1`. It was made from `review/five-weapons-v3` with `review/d22-slice` merged in (`3bf3549d`). **Not merged anywhere.** Neither review branch was touched.
- **Build:** `Archipepsi-Unified-1-e1b50717`, as a Windows zip (102 MB) and a Linux zip (95 MB). Each holds the exported game, the bridge's Python source, a launcher and a short `README.txt`.
- **The switch:** everything new sits behind `--unified` on Godot's command line, which only this build's launcher passes. Without it, the campaign, the D-22 slice and the five-weapon range run exactly as before.
- **Promotion:** none. Nothing goes to the main campaign until you have played this and approved it.

## Play it

1. Unzip the Windows build.
2. Double-click **"1 - START HERE - Archipepsi Unified 1 (Windows)"**.
3. Close any other Archipepsi first. This build runs its own bridge.
4. You need Python 3, as you do for the ordinary game.

Saves go in `saves-unified-1` in the build's folder and nowhere else. The README beside the game has the controls, where things are, and the list of what is missing.

## What is in it

| You asked for | What is in the build |
|---|---|
| **1. The D-22 loop** | Station 1 → the Forge with Epsilon → Crossing → untether → area 2. It is the slice's own bridge with the same arguments, on the mock Archipelago. Its saves and progression are unchanged: the slice's own 76-check §6.A run passes with `--unified` on. Real Archipelago is not in this build. |
| **2. Five weapons** | The v3 runtime with Foundry's corrected readiness and recoil, unchanged. It is bound to the game's own player on keys 1–5 in the station, the Crossings and the Freight Bay. 0 brings the Static Pulse back. Arty's five models and lean materials are in, with her Glyph adapter and its layered effects, material impacts and persistent marks. |
| **3. Condi's weapon audio** | Her SigmAudio five-weapon set and `events.json`, as the range plays them. The import check confirms all 19 WAVs match her handoff `63c78a9d`. Her level relationships are untouched: everything still plays on Master. |
| **4. The Shunter** | One Shunter, built to D-20 rev 2 (Dess, `8614654e`), in one freight arena: the Freight Bay, an optional annex off Station 1. It is the game's own `Enemy` (charger stats) with D-20's per-instance behaviour; `enemy.gd` is untouched. It has the telegraphs (horn, brace, lit lane), the environmental pieces (gate, crates, pillars, tote) and the four recovery windows. No new enemy types, no new framework. |
| **5. Condi's music** | Her approved station music (Explore only) and the Freight Bay's four parts with both stingers, from PR #44. They are installed byte for byte and played on her exact hooks through her own SigmAudio runtime. The Shunter's horn stays on SFX, never ducked. |

## Your prototype decisions, as built

These apply to this playtest only. None of them is a campaign rule.

- **The Freight Bay is an optional annex off Station 1.** It has no Checks and changes no progression. It sends nothing to the bridge (check A11: 0 intents).
- **A heavy hit is 13 or more.** That keeps the Sightline (12) a light hit for brace-breaking. D-20 said 12; **flagged for Dess** below.
- **The Mass Driver is capped at 30 against the Shunter, in the Freight Bay only.** Measured: 30.0. Its range damage is unchanged.
- **The Shunter keeps 40 HP** and its heavy-hit brace behaviour. The gate is a usable tool.
- **Condi's tuned horn is the Shunter's horn.** Its other seven sounds are labelled placeholders (see "Still missing").
- **Keys 1–5 everywhere.** 0 brings the Pulse back. An Echo in slot B is set aside while a weapon is out, and comes back on 0.
- **When the Shunter loses interest, the music stays in Combat.** That is Condi's default, from her open point 1.

## Where the systems met, and what was done

Each item below is the smallest change that resolved a real conflict. None of them changes Dess's mechanics or Condi's music.

1. **Arty's issue 1: the Mass Driver's impact sparks and sound never played.**
   - Reproduced first: 3 checks failed.
   - Fixed with her one line (`CONNECT_DEFERRED` on the slug's `tree_exiting`) in my runtime. None of her files changed.
   - Details: `docs/art-requests/2026-10-16-unified-weapon-integration-reply.md`.
2. **Arty's issue 2: renamed effect nodes.** No change was needed. 19 marks carried Godot's `@…` names, and every one was still counted, because counting goes by list.
3. **The Shunter rocked against the closed gate instead of walking round it.**
   - D-20 §6 says it walks round the gate, using the base sidestep.
   - The base sidestep alternates sides, which only clears something narrower than one step. The gate frame is 6 m.
   - Now, when a sidestep is still blocked, the next one keeps the same side, edges slightly off, and is longer. It is used only when the way stays blocked.
   - Without a clear line it keeps closing instead of holding its stand-off. That is D-20 §6, "never a permanent hiding place".
   - Measured: it goes round and braces once it sees you again. The longest grind was 0.02 s, against D-20's 2 s limit.
4. **The brace aimed at its own facing, not at you.** A brace started 6° off would miss a player standing in the lane. It now locks toward your position, as D-20 §3 describes.
5. **RESTART could lock the bay.** A death on the bay floor restarted the bay with your body still on the floor, so the booth door shut again and stayed shut. RESTART now opens the door, and it shuts only when you next step down onto the floor.
6. **The weapon's name sat on the HUD's Echo rows.** This was found in the first real-renderer stills. The label now sits above the HP line.
7. **The licence gate caught three things:** Condi's music, Arty's art and the horn.
   - The music and art are registered first-party with their sources named, as the five-weapon audio was.
   - The horn (kyles, Freesound 454025, CC0) has a full third-party record.
   - `THIRD_PARTY_NOTICES.md` is regenerated.
8. **The music runs as nodes instead of autoloads.**
   - Condi's README suggests two autoloads. Here the two cues are children of a node that exists only in the unified build, so every other build stays silent.
   - Her scripts are unchanged. They find their files the same way either way.

## The music, exactly as wired

These are the rows of Condi's README and `events.json`. The `music` check drives each one through the real Hub, Freight Bay and a Crossing.

| When | Call |
|---|---|
| Station 1 (both areas) | `StationMusic.play()`: Explore. `set_parameter` and `set_state` are never called. |
| A Crossing, the title | Silence. None is approved there. |
| Into the Freight Bay | Station stop, then Freight Bay `play()`: Exploration |
| The Shunter's HORN | `trigger_event("engage")` → Entry and the entry stinger → Combat |
| The Shunter DOWN | `trigger_event("victory")` → Victory and the victory stinger → Exploration |
| RESTART, or a death in the bay | `stop(); play()` |
| Out of the Freight Bay | Freight Bay stop, then station `play()` |

**Levels:**
- **The Music bus is at +3 dB**, inside her +4 dB headroom. It is the only level set. The files are hers, byte for byte, and their sidecars keep her import settings; Godot only added its uid and path lines.
- **The horn is on the SFX bus at 0 dB**, with no effects, and nothing ducks it.
- **The horn is louder than the combat music.** The horn file measures −13.9 LUFS. Combat on the Music bus comes to about −17.6 LUFS (her −20.6 plus 3 dB). That meets her "at least as loud as the combat music".

**Two behaviours to know:**
- The station music keeps playing at the Forge console, because you are still in the station.
- The ESC menu pauses the world, and her runtime pauses the music with it.

## Checks run

All of these are green on the final code.

| What | Where it ran | Result |
|---|---|---|
| **Unified seams** (`tools/unified_check.sh`): `weapons` 20, `art` 29, `shunter` 44, `music` 24 | source; the exported Linux build; the Windows `.exe` under Wine | 117 / 117 in each |
| **The D-22 loop's own §6.A check** (`tools/d22_slice_check.sh`), 76 checks plus A11 isolation | source without `--unified`; source with it; the exported Linux build; the Windows `.exe` under Wine | 76 / 76 in each, with the player's saves byte-identical and 0 remote connections |
| Python: schemas, bridge and apworld (`make test`) | source | 2321 passed |
| Five-weapon range: Condi's audio import check, then the probe | source | 19 WAVs match; probe PASS |
| Weapon-feel range probe | source | PASS |
| Godot: chamber, boot, room contract, encounter (51), combat fairness (50), HUD | source | all OK |

The Linux and Wine runs used fresh unzips of the delivered build, checked against its `SHA256SUMS.txt`. Under Wine, a test-only wrapper turns the notes file's Unix path into its `Z:` path.

### The Shunter's numbers, measured

| Item | Measured |
|---|---|
| Recovery windows | hit 0.70 s; miss 1.12 s; crate 1.12 s; steel 1.83 s |
| Horn | 0.6 s, or 0.9 s after a heavy hit while it works |
| Mass Driver against it | 30.0 |
| Gate close | 2.05 s |
| Longest grind | 0.02 s |
| On foot from Station 1 to the bay floor | the corridor, booth and ramp work; the booth door shuts behind you |

## Still missing or placeholder

- **The Shunter has no art model.** It is a graybox blockout, Arty's variant B proportions in plain blocks.
- **Seven of its eight sounds are the game's existing enemy tones, marked `PLACEHOLDER` in the code:** the brace's plough scrape, the rush, the crate crumple, the skid on a miss, the clang on its armour, the vent gust in recovery and the power-down. The horn is real.
- **The Freight Bay is graybox**, and so is the station, as agreed.
- **Music has been checked by script but never heard inside the game.** No music plays in the Crossings or menus, because none is approved there.
- **There is no ducking under gunfire.** That was Condi's optional suggestion, left until someone has listened.
- **The weapon sounds are still awaiting your range test** (her PR #34).
- **The renders in this report use the OpenGL compatibility renderer** on a virtual display. On Windows, the build uses its normal renderer.
- **Real Archipelago is not part of this build.**

## For Dess, Condi and Arty

**For Dess to confirm:**
- The heavy-hit threshold, 13 here and 12 in D-20.
- The gate closes in **2.05 s**, against assumption A2's 1.6 s.
- Hearing (18 m) equals the notice radius (18 m). Inside 18 m it has already noticed you by distance, so hearing only ever adds the hit-free trigger.

**For Condi:**
- Her open point 1 is left at her default.
- The Music bus is at +3 dB, pending a listen.
- The music plays at the Forge console.

**For Arty:** nothing. Issue 1 is fixed in my code and issue 2 needed no change. None of her files changed.

## Reproduce

```
tools/unified_check.sh OUT weapons art shunter music
UNIFIED=1 tools/d22_slice_check.sh OUT
tools/unified/package.sh OUT
BUILD=<unzipped build> tools/unified_check.sh OUT weapons art shunter music
```

Stills: run the `shunter` phase under a real renderer with `--unified-shots=DIR`. It writes 11 images: the corridor, the booth, the bay, the gate, a weapon in hand, the Shunter braced, and the Driver in the bay.
