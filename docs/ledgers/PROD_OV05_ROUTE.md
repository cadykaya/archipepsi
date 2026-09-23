# Overnight 05 — a short route to try the candidate (spoiler-light)

The answers, with room names and the evidence behind each claim, are in
`PROD_OV05_ANSWERS.md`. Read this one first if you would rather find
things yourself.

## Start it

1. **Update** the checkout the usual way ("Update Archipepsi"). The
   branch is `claude/archipepsi-0-4-blindside`.
2. **Double-click `Diagnostic Campaign - Candidate (Windows).bat`.** On
   macOS or Linux, run
   `cd bridge && python3 -m archipepsi_bridge.diagnostic --candidate`.
   Leave the window open. Its banner should read **DIAGNOSTIC CAMPAIGN
   (CANDIDATE PROFILE)** and show your revision. It should also say
   `staged nothing`: no item, Echo or key is given to you.
3. **Open the game as usual.** Start a mock campaign if the Hub asks
   for one, ask for a Zone, and take the portal.

The candidate slot is separate from your other campaigns. It will not
continue an ordinary one, and an ordinary launch will not continue it.

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
- **This is an implementation candidate.** It is not approved content
  and not the ordinary game. Everything here comes from the
  deterministic Epsilon and the mock multiworld.
