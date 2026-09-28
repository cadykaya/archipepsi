# One ordinary room: `shell_concourse_pier`

*Arty — 2026-09-28*

This is one integration-ready ordinary room for the next playable test. It was built through the existing shell pipeline and walked by Production's own `Player` at `17b76098`. Its review status is **`pending`**. Prod adds the lightly populated comparison and packages the playtest.

## The room

The interior is 16 × 22 m, with 7.0 m to the roof. That is an ordinary arena, inside the fallback arenas' own ranges (12–24 × 10–22 m, walls 4.5–7 m). Left and right below are as you see them when you enter.

* **You come in low.** The entrance opens under a 4 m deep gallery whose underside is the door head (3.2 m). Past it, the room rises to its full height.
* **The pier hides the way on.** A solid pier, 5.6 × 5 m and 3.5 m tall, blocks the straight line to the exit. The exit is 4.8 m off-centre, on your left. Floor lanes run both ways round the pier: 4.4 m wide on the exit side, 3.6–6 m on the stair side.
* **An upper loop that comes back.** Stair A climbs the right wall to the gallery. A bridge crosses from the gallery to the pier top. Stair B comes down behind the pier to a 2.1 m landing beside the exit.
  * The pier's open edges let you drop straight back to the floor.
  * The room's `reward` volume is on the pier. So a chamber's reward sits on the upper loop, and the floor is the quick way through.
* **Stairs, rails and decks:**
  * stairs are solid underneath, with 0.35 m risers;
  * parapets are 1.1 m, higher than the player's 1.0 m step;
  * decks are at 3.5 m, with 3.5 m clear above them.

Everything reused is the house shell kit:

* `brushkit`, `roomcollision`, `roomkit` flight treads and `roomcontract`;
* the concrete_facility textures every shell uses;
* the standard 2.4 × 3.2 m doors at grade;
* the existing export pipeline.

There is no schema, generator or runtime change, and no props.

## Revision and files

* Branch `claude/archipepsi-art-room-2026-09-28`.
* Room commit `697fd8af`, based on `a1584c8`.
* Runtime reference: Production `17b76098`, read only.

**What the runtime needs.** Prod copies these and nothing else:

* `godot/content/shells/shell_concourse_pier.tscn`;
* `godot/content/shells/shell_concourse_pier.glb` and its `.glb.import`;
* `godot/content/shells/shell_concourse_pier_room_concrete_facility_{floor,wall,ceiling,trim}.png`, each with its `.png.import`;
* the single `shell_concourse_pier` entry in `godot/content/registry/authored_art.json`. The rest of that file is identical to the version at `17b76098`.

**What that entry declares:**

* **Basics:** `room_shell`, tagged `arena`; `size_class` is `medium`; size 16.8 × 7.9 × 22.8 m; fallback `shell_arena_proc`.
* **Doorways:** both are 2.4 × 3.2 m, on the `floor` surface:
  * `entry` at (0, 0, 0), yaw 180;
  * `exit` at (4.8, 0, 22), yaw 0.
* **Surfaces:** `floor` at 0 m; `gallery`, `bridge` and `pier` at 3.5 m.
* **Volumes:**
  * `arrival`;
  * `reward` (objective), on the pier;
  * `no_build` over the pier and both stairs.
* **Traversal:**
  * `entry_to_exit` (mandatory, on the floor);
  * `floor_to_gallery`;
  * `gallery_to_pier`;
  * `pier_to_exit`.
* **Collision:** 38 convex hulls and no concave ones, carried in the `.glb`.

**Art-side source and tooling.** None of this is needed at runtime:

* `tools/blender/build_ordinary_room.py`;
* the room's rows in `tools/export_content_pack.py`;
* `assets/models/batch062/shells/`;
* `tools/content/room_walk.gd` and `tools/content/run_room_walk.sh`;
* the builder's name added to the list in `tools/check_art_current.sh`;
* the ledger row in `docs/art/ART_REVIEW.md`;
* `godot/content/SCENE_PLAN.json`. This is art-side only; Production does not read it.

## Launch and test

    sh tools/content/run_room_walk.sh [out-dir]    # PROD_REF defaults to 17b76098

It needs:

* `.tools/godot` (4.5.1);
* `xvfb-run`, for the pictures only;
* `17b76098` in the clone. It is on `origin/wip/0.4-art-catchup`.

The script makes a throwaway `git archive` copy of Production's `godot/` and adds the room. It runs the checks below, then deletes the copy. Nothing in either checkout is written. It takes about 3.5 minutes.

**In the game**, the room enters a Zone the way every authored shell does: a chamber names it by `shell_id`. While its review is `pending`, `VisualOwnership.is_shippable` makes the game build the procedural fallback instead. So a playtest build that uses this room needs the owner's `pass` on the entry.

## What I checked, at Production `17b76098`

* **The real player walked it, with no jumps.** A stall counts as a failure; the body is never made to hop.
  * **Control:** sent into the pier, the player stops at its face and names `cp_pier` as the blocker.
  * **Floor route:** in through the entrance, down the exit-side lane and out through the exit. 28.4 m in 4.2 s.
  * **Upper loop:** stair A, the gallery, the bridge, the pier, stair B, then out through the exit. 64.9 m in 9.0 s, standing at 3.50 m on every deck.
  * **Drop:** stepping off the pier's stair-side edge, the player lands on stair A's second step (0.70 m) and walks on down.
  * Eye height 1.60 m and FOV 90 are Production's own values, untouched.
  * Two fixture floors outside the doors stand in for connectors.
* **Production's own census** (`--room-contract`) builds the room through `ContentInstantiator`.
  * The room's line reads `PASS … structural=0 measured=0`.
  * A real body crossed both doorways onto a stub laid where `ZoneBuilder` lays one: 3.10 m and 3.11 m past, with a 0.08 m dip. Every other shell gives the same figures.
  * For this run the review gate is lifted **in the throwaway registry only**. The committed entry stays `pending`.
* **Production's content-pack validation.** `verify_content_pack.sh` with `PROD_REF=17b76098` passes:
  * Production's ContentManifest accepts it;
  * the collision, markers, flight-step and offer checks pass.
* **Preflight.** `preflight_shells.py 17b76098` reports the room ok, with 0 structural refusals.
* **Art checks:**
  * `check_theme_roles.py` and `check_docs_metrics.py` pass;
  * `check_art_current.sh` exits 0, with its rebuild of every builder deliberately skipped;
  * this room's builder rebuilds byte-identical.

**What the checks changed in the room:**

* **Stair B is shorter.** On a 1.1 m landing, the player came off onto the last step's edge, facing the wall.
* **The reward volume is declared.** Without it, the census found the default reward position inside the pier.
* **The roof went from 6.4 to 7.0 m.** At 6.4 m, the first pictures made the upper level read as a tunnel.
* **Materials are named by role.** The theme-roles check requires it.

## Limitations

* **Review is `pending`.** The room is not in Production's pack and not owner-passed. The game will not build it until it is.
* **The room has no lights of its own.** At `17b76098` the game adds lights to procedural rooms but not to authored shells, and a shell may not carry lights. The pictures show what the game gives it: the Zone's ambient light at 0.35, plus fog. How to light it is Prod's call.
* **No enemy has walked it.** The 0.35 m risers fit the enemies' 0.6 m footing on paper only.
* **The walk proves only the routes it drove,** not every possible route. The census audit measured the whole room clean.
* **It is a chain room.** It has one entrance and one exit, both in end walls at grade, and no side doors.
* **The pier's 3.5 m edges are safe only because this Production revision has no fall damage.** The only fall limit is `FALL_KILL_Y`.

## Pictures

Both are in `docs/art/review/ordinary_room_2026-09-28/`, taken through the real player's camera:

* `room_entry_eye.png`: just inside the entrance;
* `room_pier_eye.png`: on the pier, looking back along the bridge to the gallery and stair A.

`run_room_walk.log` in the same folder is the run that made them.
