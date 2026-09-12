# The art lane's camera bench — what it is, in case it's useful

Written for whoever is working in `godot/`. **Nothing here is a request.**
It is a tool that exists, that you may not know exists, and that was built
for a problem you also have. Use it, ignore it, or take the parts you want.

It lives on **`claude/archipepsi-art`**. Read any of it without checking the
branch out:

```
git show origin/claude/archipepsi-art:tools/artpreview/camera_rig.gd
git show origin/claude/archipepsi-art:tools/artpreview/shoot.gd
```

## The one-line version

A headless Godot bench that renders `.glb` assets and composed scenes to PNG
from a JSON shot list, with a camera you aim in camera language instead of
magic vectors.

## Why it might matter to you

`godot/` currently captures **no images anywhere** — no `save_png`, no
`SubViewport`, in any driver. Every suite asserts state, geometry or
protocol. That is not a criticism; it is the same reason
`legibility_driver.gd` had to be written after Playtest 1 found every Hub
sign mirrored while nine suites were green. Its own docstring says it: *"a
sign is correct in all three of those while being backwards."*

If you ever want to look at something rather than assert about it, this is a
working starting point rather than a blank file.

## Three pieces, independent of each other

### 1. `tools/shoot.sh` — shots as data

```
tools/shoot.sh tools/shots/batch019_rooms.json [out_dir]
```

A shot list is JSON. Nudging a camera is editing a number, not editing
GDScript and rebuilding. ~20 real lists live in `tools/shots/` as worked
examples. Schema is documented at the top of `tools/artpreview/shoot.gd`.

```json
{ "name": "corridor_entry", "scene": "model:batch015/shells/shell_corridor_narrow.glb",
  "eye": [0, 0, -6.2], "yaw": 0, "game_lens": true,
  "variants": ["grey", "silhouette"] }
```

Scene vocabulary: `void`, `model:<rel path>` (several, with `@x,y,z` and
`#yaw`), and `hub` — though see the limits section, because `hub` is not
your Hub.

### 2. `tools/artpreview/camera_rig.gd` — the vocabulary

The part most worth stealing even if you never run the bench.

```gdscript
rig.lens(35)                    # 35 mm equivalent, not a raw fov
rig.game_lens()                 # or the engine's own 90 deg
rig.frame(box, 0.8, 25, 10)     # fill 80% of frame; the DISTANCE is solved
rig.eye(Vector3(0, 0, 3), 180)  # or stand where the player stands
rig.screen(point)               # ask the camera where something drew
```

`frame()` is the time-saver: "a bit closer" becomes a number between 0 and 1
instead of three more render cycles.

Lenses are in millimetres on purpose. Godot's `Camera3D.fov` is the
**vertical** angle under the default `KEEP_HEIGHT`, so "90°" is a different
picture at 16:9 than at 4:3. Two label-placement bugs came from that
(ART_LESSONS L-34). Focal length does not have the problem.

`rig.screen()` matters for the same reason: two benches computed screen
position from a formula *about* the camera instead of asking the camera, and
put labels a third of a frame from the things they named.

### 3. `docs/art/proposals/photo_mode.gd` — in-game, install-ready

A detachable free camera: F2 to toggle, WASD/QE to fly, mouse to look, hide
the interface, save a PNG. It pauses the tree, remembers the current camera,
and restores it on exit. **It touches no gameplay state.**

It belongs at `godot/scripts/ui/photo_mode.gd`. The art lane does not write
to `godot/`, so it has been sitting in a proposals folder since Batch 16 —
finished, with three-step install instructions in its own header, and
nobody was ever told it was there. That is an art-lane failure, not yours.

Its `frame()` and `frame_orbit()` use the same maths as `camera_rig.gd`, so a
shot composed in one reproduces in the other.

## The variant passes

Every shot can emit derived frames from the **same** camera:

| variant | what it tests |
|---|---|
| `grey` | does it compose without hue |
| `silhouette` | flat black on light — pure shape read |
| `clay` | untextured — form without surface |
| `guides` | thirds, centre and horizon overlaid |

`silhouette` earns its keep. It decided Batch 035-R this week: an interaction
receiver had a throat closed by a lintel, and the silhouette sheet showed
instantly that **a cavity in a front face does not break an outline** — so
the receiver and its decoy twin were the same dark slab from any angle you
could not see into. Lit renders had not shown it.

`grey` is derived *before* captions go on. Desaturating a captioned frame
measures the caption (L-38).

## Four gotchas, each of which cost a real debugging session

1. **`--headless` cannot render.** It selects the dummy driver and an awaited
   `SubViewport` capture hangs forever with no output. Use
   `xvfb-run -a -s "-screen 0 1920x1200x24" godot --rendering-driver opengl3`.
2. **The xvfb screen must be at least as large as the SubViewport.** A larger
   viewport is silently clamped and the parts outside come back black, with
   no error anywhere — `get_viewport().size` still reports what you asked
   for. A 1600×1080 sheet into a default 1280×1024 screen produced a frame
   whose entire figure band was empty.
3. **A `class_name` script is invisible until an import pass writes the class
   cache, and `-s` does not rescan.** Run `--import` first after adding one.
   The nastier version: a *stale* cache can keep resolving a `class_name`
   that no longer exists, so a check passes for the wrong reason until the
   next import. Preload by path when you want certainty (L-80).
4. **The toolchain is fetched per session and gitignored** (`.tools/godot`,
   Godot 4.5.1 stable `f62fdbde1`, stock). Set `GODOT=` to point elsewhere.
   `tools/artpreview/project.godot` pins the build hash on purpose.

## What it cannot do, stated plainly

**It cannot render the actual game.** `tools/artpreview/` is a *separate*
Godot project with none of the runtime — no `ZoneBuilder`, no
`ContentInstantiator`, no generated Zone. Its `hub` scene is `hub_scene.gd`,
an art-lane **reconstruction** built from `hub.gd`'s published numbers, not
your Hub scene.

So no automated process in this repository has ever photographed a generated
Zone. The gap that would close it is a driver in `godot/tests/` that builds a
Zone from a fixed seed and saves PNGs — which only makes sense in your
project, and which is entirely your call whether it is worth the time.

If it ever is, `camera_rig.gd` is standalone (`RefCounted`, one `Camera3D`
and a viewport size) and drops in without the rest of the bench.
