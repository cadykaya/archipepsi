ARCHIPEPSI - D-22 SLICE (review build, revision @REVISION@)
==============================================================

The first playable Crossing loop, offline:

  Station 1 -> the Forge, with Epsilon -> Crossing 1 -> leave, resume
  -> untether -> station area 2 opens -> its Forge -> Crossing 2 -> STOP

Mock Archipelago (nothing connects to a real server), prototype scale,
Epsilon's offline fallback. A graybox: no art, no music.

PLAY
  Windows: double-click "1 - START HERE - D-22 Slice (Windows).bat".
  Linux:   ./play-d22-slice.sh
  Needs Python 3 (python.org; on Windows tick "Add python.exe to PATH").
  The launcher installs the two libraries the bridge needs if missing.
  Close the ordinary game's bridge first: the slice runs its own.

  Saves go in "saves-d22-slice" in this folder and nowhere else. Quit
  any time and double-click again to carry on where you were.
  "2 - D-22 Slice, start over" renames the old run aside and begins again.

THE LOOP
  1. The portal at the far end of station 1 is now THE FORGE. [E] it.
     Pick a signal (a game with Checks still open), DRAFT WITH EPSILON,
     and read his draft card: the rooms, enemies, activities and Checks
     of the Crossing he made. ACCEPT it, or REDRAW (twice at most: same
     Checks, new rooms). Walking away keeps the same draft.
  2. Accepting enters the Crossing; the first entry fixes its layout.
  3. The exit portal is always a way out: "LEAVE - n transfers remain".
     Leaving puts the Crossing down, still holding its Checks; the Forge
     then offers RESUME.
  4. Release every Check. When the (mock) multiworld confirms the last
     one, the Crossing UNTETHERS: Epsilon says so, the anchor beside the
     exit lets go when you get there, and the exit reads RETURN.
  5. Back at the station, area 2's door (right-hand wall) turns green and
     opens. Through it: pull the lever, the shutter rises, and the second
     Forge builds Crossing 2. The slice stops once you are inside it.

CONTROLS
  WASD move · SPACE jump · mouse look · LMB Static Pulse · E interact
  ESC closes the Forge / opens the pause menu

PROTOTYPE RULE, NOT A RELEASE RULE
  Here a Crossing untethers when all of its allocated Checks are confirmed
  by the mock. That is prototype behaviour only. Before this meets a real
  Archipelago, how station progress stays possible when Checks need items
  from other worlds (or other Crossings) is an open design question.
