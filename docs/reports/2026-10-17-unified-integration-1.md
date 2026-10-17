# Unified integration 1: the systems as one game

Prod, 2026-10-17, for Skyiah, with notes for Dess, Condi and Arty.

- **Branch:** `integration/unified-1`. It was made from `review/five-weapons-v3` with `review/d22-slice` merged in (`3bf3549d`). **Not merged anywhere.** Neither review branch was touched.
- **Build:** `Archipepsi-Unified-1-349ef77f`, as a Windows zip (109 MB) and a Linux zip (101 MB). Each holds the exported game, the bridge's Python source, a launcher and a short `README.txt`.
- **The switch:** everything new sits behind `--unified` on Godot's command line, which only this build's launcher passes. Without it, the campaign, the D-22 slice and the five-weapon range run exactly as before.
- **Promotion:** none. Nothing goes to the main campaign until you have played this and approved it.

## Since `349ef77f`: the next build, `Archipepsi-Unified-1-32bcf77f`

`349ef77f` is the build you have, unchanged. The next build adds one gameplay fix and nothing else you'd see:
- **The booth is now a personnel dogleg** (Dess's pre-playtest check, `f320b47b`). On `349ef77f` a Shunter rush could beat the door's 5 m interlock and reach a player standing inside the booth channel. A new check reproduced it: 100 → 58 HP.
  - The door is now a 1.2 m personnel door in the side of a small vestibule entered from the north.
  - The Shunter is 0.9 × 1.9 m: it can't fit side-on and can't turn in the vestibule. Its turns are now refused where they'd overlap a wall.
  - The LEAVE THE BAY lever is outside the vestibule.
  - The check now holds: neither rush gets through, and the player keeps 100 HP.
- Everything else in that build is CI and tests (see `docs/reports/2026-10-17-night-shift-prod.md`).

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
- **A heavy hit is one event at or over the plough's rating, 14.** That is your "a threshold above 12" at the rating Dess gave the plough in her D-20 addendum (§13.3, `a4b58a41`): one rating for every Shunter heavy reaction, with no weapon names in the rule. The Sightline (12) is refused and the Foundry (15) accepted, and a check asserts both.
- **No Mass Driver cap.** You dropped the provisional 30 cap on 2026-10-17, as D-20 §13.5 recommends. The slug does its 14–60 against the Shunter as everywhere else; measured: a full release lands 60 and downs it in one shot.
- **The Shunter keeps 40 HP** and its heavy-hit brace behaviour. The gate is a usable tool.
- **Condi's tuned horn is the Shunter's horn** (approved). Its other seven sounds are her **candidates** from draft PR #45, not yet approved (your decision of 2026-10-17, replacing the placeholders).
- **The annex always has a way out** (D-20 §13.1, your decision of 2026-10-17); see item 9 below.
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
5. **RESTART could lock the bay.** A death on the bay floor restarted the bay with your body still on the floor, so the booth door shut again and stayed shut. The door now follows the interlock in item 9: off the floor it is open, on the floor it is shut behind you, and the LEAVE lever opens it.
6. **The weapon's name sat on the HUD's Echo rows.** This was found in the first real-renderer stills. The label now sits above the HP line.
7. **The licence gate caught three things:** Condi's music, Arty's art and the horn.
   - The music, the art and (later) Condi's Shunter sounds are registered first-party with their sources named, as the five-weapon audio was.
   - The horn (kyles, Freesound 454025, CC0) has a full third-party record.
   - `THIRD_PARTY_NOTICES.md` is regenerated.
8. **The music runs as nodes instead of autoloads.**
   - Condi's README suggests two autoloads. Here the two cues are children of a node that exists only in the unified build, so every other build stays silent.
   - Her scripts are unchanged. They find their files the same way either way.
9. **The way out (D-20 §13.1).**
   - The Shunter's collider is the charger's, 0.9 m wide, so it would fit the 2 m booth doorway. An open door is not enough.
   - The booth door is now **interlocked like the gate**: it is shut whenever the Shunter is within 5 m of it, wherever you are, and never closes on you.
   - From the floor, a green **LEAVE THE BAY** lever beside the door opens it while the Shunter is farther off. It refuses while the Shunter is at the door.
   - The glazed ramp channel behind the door is the dogleg: no line of fire from safety, and the glass already stops shots.
   - Death in the bay already returned you to Station 1 with the bay reset; that is unchanged and checked.
10. **Condi's Shunter sounds (PR #45, `b1235032`).**
    - Installed byte for byte in `godot/audio/sigmaudio/shunter/` against her checksums; the sidecars keep her import settings.
    - Wired by her `events.json`: the scrape on BRACE (cut with a 25 ms fade if the brace breaks), the rush on RUSH (faded as it ends), the crumple on steel, the skid on a miss or a crate, the plume hiss in RECOVER (faded over the window's last 0.2 s), the vent gust on a heavy hit in recovery, the power-down (with the skid if it was rushing) on DOWN.
    - Every one is a 3D sound on the SFX bus at one level, as her level contract asks.
    - The clang when a hit lands on its frontal armour is not among D-20's seven, so it stays a labelled placeholder tone. **Condi to confirm.**
11. **Fight telemetry (Dess, D-20 §13).** At each DOWN: the time from the first horn (or first hit) to DOWN, the rushes, and for each weapon its damage, hits and the rushes it faced. It is shown on the LAST FIGHT board in the booth and printed to the console. Nothing is written to disk.

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
| **Unified seams** (`tools/unified_check.sh`): `weapons` 20, `art` 29, `shunter` 54, `music` 24 | source; the exported Linux build; the Windows `.exe` under Wine | 127 / 127 in each |
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
| Mass Driver against it | a full release lands 60.0 and downs it |
| Heavy hit | the plough's rating, 14: Sightline 12 refused, Foundry 15 accepted |
| Gate close | 2.05 s |
| Longest grind | 0.02 s |
| On foot from Station 1 to the bay floor | the corridor, booth and ramp work; the booth door shuts behind you |

## Still missing or placeholder

- **The Shunter has no art model.** It is a graybox blockout, Arty's variant B proportions in plain blocks.
- **Seven of its sounds are Condi's unapproved candidates** (PR #45), heard in the game for the first time in this build. The horn is approved. The armour clang is still the game's placeholder tone.
- **The Freight Bay is graybox**, and so is the station, as agreed.
- **Music has been checked by script but never heard inside the game.** No music plays in the Crossings or menus, because none is approved there.
- **There is no ducking under gunfire.** That was Condi's optional suggestion, left until someone has listened.
- **The weapon sounds are still awaiting your range test** (her PR #34).
- **The renders in this report use the OpenGL compatibility renderer** on a virtual display. On Windows, the build uses its normal renderer.
- **Nothing here has been run on a native Windows machine.** The Windows `.exe` was checked under Wine on Linux, headless, and its `.bat` launcher was not run (that Wine prefix has no Windows Python). Your first launch is the native Windows check.
- **Real Archipelago is not part of this build.**

## For Dess, Condi and Arty

**For Dess to confirm:**
- Her §13 rulings are in: the plough's rating 14, no Driver cap, the way out, the telemetry.
- The gate closes in **2.05 s**, against assumption A2's 1.6 s.
- Hearing (18 m) equals the notice radius (18 m). Inside 18 m it has already noticed you by distance, so hearing only ever adds the hit-free trigger.

**For Condi:**
- The armour clang stays a placeholder (not one of D-20's seven).
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
