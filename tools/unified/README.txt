ARCHIPEPSI - UNIFIED INTEGRATION 1 (review build, revision @REVISION@)
=====================================================================

The first time the systems run as one game, offline:

  the D-22 loop (Station 1 -> the Forge, with Epsilon -> a Crossing ->
  untether -> station area 2) + the five weapons on keys 1-5, everywhere
  + the Freight Bay, an optional annex off Station 1, with one Shunter
  + Condi's approved music: the calm station music, and the Freight
  Bay's exploration / combat music with its two stingers.

A review candidate, not the campaign. Mock Archipelago (nothing connects
to a real server), prototype scale, Epsilon's offline fallback, a
graybox station. Nothing here is promoted until Skyiah has played it.

PLAY
  Windows: double-click "1 - START HERE - Archipepsi Unified 1 (Windows).bat".
  Linux:   ./play-unified-1.sh
  Needs Python 3 (python.org; on Windows tick "Add python.exe to PATH").
  The launcher installs the two libraries the bridge needs if missing.
  Close any other Archipepsi first (the ordinary game or the D-22
  slice): this build runs its own bridge.

  Saves go in "saves-unified-1" in this folder and nowhere else. Quit any
  time and double-click again to carry on. "2 - ... start over" renames
  the old run aside and begins again.

CONTROLS
  WASD move - SPACE jump - mouse look - E interact - ESC pause
  1 Foundry   2 Sightline   3 Switchback   4 Bulkhead   5 Mass Driver
  LMB fire (hold for the Switchback; hold and release for the Driver)
  RMB aim, where the weapon has it (Sightline, Switchback, Driver)
  The same key again: the variant (3 hip-fire Switchback; 4 Breacher /
  Sweeper). 0 puts the weapon away: the Static Pulse is back on LMB
  and your Echo in slot B returns.

WHERE THINGS ARE
  The loop: the Forge is the portal at the far end of Station 1. Pick a
  signal, DRAFT WITH EPSILON, ACCEPT (or REDRAW twice at most). Leave a
  Crossing any time through its exit; release every Check to untether it,
  and area 2's door (right-hand wall) opens with the second Forge.

  The Freight Bay: turn round at the start. The doorway behind you, signed
  FREIGHT BAY, leads up a short corridor to a glazed booth over the bay.
  Watch the Shunter work from the booth; take the ramp down when you are
  ready. The ramp ends at a narrow PERSONNEL ONLY door in the side of a
  small vestibule: a dogleg the Shunter cannot charge or squeeze through.
  The door shuts behind you on the bay floor. To leave, pull the green
  LEAVE THE BAY lever outside the vestibule: the door opens unless the
  Shunter is near it, and it shuts while the Shunter is that close. It
  opens for good when the Shunter is down. Die in the bay and you wake in Station 1 with the bay reset. The
  RESTART THE BAY lever and the LAST FIGHT board are in the booth. The bay
  has no Checks and saves nothing.

THE SHUNTER (Dess's D-20 revision 2)
  It tends its lane until it notices you, then sounds its horn, closes
  in, BRACES (the lane lights up) and RUSHES straight along it. Step out
  of the lane. After a rush it is open: a long window if it hits steel
  (a pillar, the closed gate), shorter after a crate or a miss. Its front
  is armoured while it closes, braces or rushes; its back and its
  recovery are not. A heavy hit breaks a brace once per cycle. The orange
  crates burst when it rushes into them. The freight gate's levers (one
  on each face) close the gate for 6 s: a wall it walks round, and steel
  if it rushes into it.

PROTOTYPE DECISIONS (for this playtest only, not campaign rules)
  - The Freight Bay is an optional annex off Station 1: no Checks, no
    campaign progression.
  - A "heavy hit" is one hit at or over the plough's rating, 14 (Dess's
    D-20 addendum): the Sightline (12) stays light, the Foundry (15)
    breaks a brace.
  - No damage cap: the Mass Driver does its 14-60 against the Shunter as
    everywhere (the earlier 30 cap was dropped on 2026-10-17). A full
    charge downs it in one shot.
  - The Shunter keeps 40 HP and its heavy-hit brace behaviour; the gate
    is a usable tool.
  - Condi's tuned freight horn is the Shunter's horn.
  - Keys 1-5 everywhere: station, Crossings and Freight Bay. 0 or
    holstering gives the Static Pulse back; an Echo in slot B is set
    aside while a weapon is out.
  - When the Shunter loses interest, the music stays in combat (Condi's
    default; her open point 1).

STILL MISSING OR PLACEHOLDER
  - The Shunter has no art model: a graybox blockout (body, plough, brow
    lamps, vents).
  - Its horn is approved. Its other seven sounds (plough scrape, rush,
    crumple clang, skid, vent gust, plume hiss, power-down) are Condi's
    CANDIDATES from her draft PR #45: not approved yet, and heard in the
    game for the first time in this build. The clang when a hit lands on
    its frontal armour is not one of the seven and is still the game's
    placeholder tone.
  - The Freight Bay itself is graybox (pillars, crates, gate, booth).
  - The station is graybox, as agreed.
  - No music in the Crossings, the Forge screen's own space or menus:
    none is approved there. The station music keeps playing while the
    Forge console is open, because the player is still in the station.
    The ESC menu pauses the world, and the music pauses with it (Condi's
    runtime does that); it carries on when the menu closes.
  - Condi's music has been checked by script (every hook, every state
    change) but never heard inside Archipepsi before this build.
  - The Music bus is at +3 dB (inside Condi's +4 dB headroom). No ducking
    under gunfire: her optional suggestion, left for after listening.
  - Weapon sounds are Condi's five-weapon SigmAudio set from the range
    (her draft PR #34), unchanged; still awaiting your range test there.
  - Real Archipelago is not connected in this build at all.
  - Dess, to confirm: the gate closes in 2.05 s (D-20 assumed 1.6); and
    hearing (18 m) equals the notice radius (18 m), so hearing never
    fires first.
  - The LAST FIGHT board shows time to kill, rushes, and each weapon's
    damage, hits and the rushes it faced. It is also printed to the game's
    console; nothing is written to disk.

The developer report, with every check run, is
docs/reports/2026-10-17-unified-integration-1.md in the repository.
