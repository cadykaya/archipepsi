# Overnight 05 — a short route to try the candidate (spoiler-light)

The answers, with room names and the evidence behind each claim, are in
`PROD_OV05_ANSWERS.md`. Read this one first if you would rather find
things yourself.

## The build

- **Tested revision:** `46bf023` on `claude/archipepsi-0-4-blindside`.
  The frozen full run there was green: 64 of 64 steps passed. The raw per-step results are in
  `docs/ledgers/ov05_evidence/FROZEN_RUN.md`.
- **Pushed revision:** the handoff commit directly on top of it. It
  holds documents and the zone audit's own provenance stamp only; no
  code.
- These are local Linux results. Nothing was run on Windows. The `.bat`
  files were read, and the Python they call is tested.

## Start it (Windows)

1. **Update:** double-click `Update Archipepsi (Windows).bat`. You
   should end up on branch `claude/archipepsi-0-4-blindside`, at the
   pushed revision or later.
2. **Start the candidate bridge:** double-click
   `Diagnostic Campaign - Candidate (Windows).bat`.
   - It needs Python on PATH and says so if it is missing.
   - Its banner reads **DIAGNOSTIC CAMPAIGN (CANDIDATE PROFILE)** with
     your revision, and says `staged nothing`.
   - **Leave this window open** while you play.
   - **Do not also run `Start Archipepsi (Windows).bat`:** that starts
     the ordinary bridge instead.
3. **Start the game:** launch Godot 4.5.1, open `godot/project.godot`
   from the checkout, and press Play (F5).
   - The game connects to the bridge window from step 2. If it says
     BRIDGE OFFLINE, that window is not running.
   - At the Hub, press **MOCK CAMPAIGN** if it asks, ask for a Zone,
     and take the portal.

**Fresh or resumed.**

- The first launch makes the candidate slot.
- Every later double-click resumes that same slot, under the same
  profile. A different profile is refused, with nothing touched.
- For a fresh candidate slot, run it from a command prompt in the
  checkout: `cd bridge`, then
  `py -m archipepsi_bridge.diagnostic --candidate --new`.
- `--list` shows the slots and their folders.

**Where it saves:** `<your checkout>\.diagnostic-candidate\`. That is
a hidden folder beside the repository, separate from your ordinary
campaigns.

- The candidate launcher never continues an ordinary campaign.
- An ordinary launch never continues the candidate slot.

## What to look for

- **An early fight room has a new control in it.** Use it. Watch what it
  says right after you use it, then again a moment later. Then find
  what it changed; it is not in the room you are standing in.
- **Try undoing it, and try undoing it while standing in the way.**
- **A little further on, something is lying around that you can pick
  up** (`E`). It is heavy. Notice what you cannot do while holding it.
  Take it somewhere it fits. What does that do?
- **Drop it somewhere awkward, or walk off with it where it should not
  go**, and see what happens to it.
- Past the power cell's doorway is the last batch's plate-and-shutter
  branch (P14), composed here by the same profile.
- **Off the branch past the first fight room, there is a long firing
  lane with a gunner on a gallery.** You will not out-shoot your way to
  the service shutter. Watch where its shots go.
- **Behind two locked doors off a side room, there is a service room
  with a crate on a track and a doorway you cannot reach.** The room's
  Check is up there. Make the crate a step, then find out why that did
  not help. Everything you need is in the room.
- **Quit the game and close the bridge window.** Then start both again
  (steps 2 and 3) and go back into the same Zone. Check what is still
  as you left it.
- **For the third minor, go on to the next Zone.** A Zone offers the
  minors in turn, and this one has room for two. In the Zone, open the
  pause menu, choose ABANDON ZONE, then CONFIRM ABANDON. At the Hub,
  use the portal to ask for a new Zone, then take it. Somewhere off a
  side room there is a tall room with a lift and a shuttle, and a
  gallery neither of them reaches alone. Try it once without hurrying;
  there is more than one way. Stop partway and quit, then come back
  and see where you left things.

## What is not in this build yet

- **The Blindside loop is not here.** That is earning the featured Echo
  and using it at the junction. It is blocked on three policy
  decisions, listed in the answers.
- **The three minors are not all in one Zone.** The first Zone has
  Unweighted Switch and Counterfire Arcade; the second has Counterfire
  Arcade and Passing Platforms. Abandoning the first returns its
  unclaimed Checks to the pool, which is fine in this separate slot.
- **The consumable slot (`Q`).**
  - The owner's direction of 2026-09-23 applies: the campaign's own Bomb
    Bag now arrives as bombs you can slot, spend and have reloaded.
    Bombs followed by a Bomb Bag is one Bombs at Mk II.
  - That is proven in the bridge and on the real engine path. A live
    run of this naturally acquired bomb was not played. If you never
    see it, report that.
  - The refill rule (a new deployment target refills) is this lane's
    proposal, not your decision.
  - The ordinary game still does not offer the slot.
- **In the engine but not reachable by play.** The twelve manipulation
  verbs, the mass fields, and `rooted` and `anchored` on enemies all
  work and are tested. No Echo the deterministic Epsilon makes delivers
  them (see the answers).
- **This is an implementation candidate.** It is not approved content
  and not the ordinary game. Everything here comes from the
  deterministic Epsilon and the mock multiworld.
