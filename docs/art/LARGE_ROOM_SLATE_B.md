# LARGE room slate B — ten rooms, three grayboxed

Independent design/art prep for the LARGE authored-shell library. This slate was
designed without reading `docs/art/LARGE_ROOM_SLATE.md` or any of Art's ten
LARGE-room concepts; the only exposure to the other slate was the one-line theses
in the Art branch's commit message for f510fd1, and those were treated as things
to stay away from, not as input.

| consumed | head | how |
|---|---|---|
| Production `claude/archipepsi-echoes-continuation-b1adno` | `b37fe07`, then `301374d` (descent ruling, §7.2) | read-only worktree; contract, validators, movement numbers, hall integration |
| Art `claude/archipepsi-art` | `f510fd1` | read-only worktree; `build_hall.py`, `roomcollision.py`, `roomcontract.py`, `export_content_pack.py`, manifest batch039 |
| this branch | `claude/archipepsi-room-architecture-h3woci` | everything below |

Coordinates are Godot (x right, y up, z depth from the entry wall) unless marked.
Room sizes are quoted interior **W × H × D**; declared `size_godot` is the outer box
the contract sees. Movement numbers are the pinned set in
`tools/graybox/engine_dims.json` (verified byte-for-byte against the Art branch's
`assets/art_budgets.json` by `tools/graybox/verify_dims.py`).

---

## 0. Summary

- **Ten concepts** (§3): `shell_lemniscate`, `shell_hypostyle`, `shell_cleft`,
  `shell_bascule`, `shell_stack`, `shell_beast`, `shell_cascade`, `shell_overpass`,
  `shell_face`, `shell_oculus`. Each carries thesis, dimensions, first read,
  landmark, local spaces, circulation, offers, three-plus package readings, the
  empty-room reason, and its difference from the other nine.
- **Wave 1** (§5–§6): `shell_lemniscate` (the owner's archetype: a 40 m void with
  a 163 m self-crossing rail), `shell_hypostyle` (LARGE by footprint, 18 m low, a
  column forest with a walkway lattice), `shell_cleft` (an L-shaped crack 12 m
  wide and 44 m tall). All three are built as inspectable grayboxes with contract
  metadata and pass the source-side preflight with **0 errors, 0 warnings**.
- **Tooling** (§8): a Blender-free graybox kit (`tools/graybox/`) that emits a
  `.glb` with `-convcolonly` collider twins, a batch039-shaped manifest entry, plan
  and section SVGs, a README and a preflight report. It mirrors the walk flood,
  stance search, rail bake, launch arc and grapple checks. It is ~1.1 k lines and
  is not the product; a room spec is ~100 lines of intent.
- **Contract findings** (§7): wedge ramps are unprovable at import; net descent
  IS declarable (Production 301374d; an earlier draft of this document said the
  opposite and §7.2 carries the correction) but the authored envelope still pins
  the visible mesh to the entry plane and the world kill plane caps a chain's
  descent; the declared size is x-symmetric about the entry axis; the 8000-node
  witness cap makes wide diagonal walks fail closed. Plus two stale Art tools
  that would report PASS on a real walk failure.
- **Wave 2** (§11): `shell_bascule`, `shell_stack` (the descending room),
  `shell_beast`, `shell_cascade`, grayboxed the same way.
- **Lessons** for the wave after each: §10 after Wave 1, §11.5 after Wave 2.

---

## 1. Semantics and numbers used

These are the final semantics named in the brief, as this slate applied them:

- A **stand Surface** promises one findable stance (owner ruling C(ii)), not a
  clear rectangle. Stair surfaces are declared as their whole rect; the kit records
  them as "thin" (fewer than 9 of 81 grid stances) as information, not error.
- **Physical evidence** proves a walk: a flood over a 0.4 m lattice where each
  node has support within [y−2.0, y+1.0] and body room above step height, edges
  ≤ 1.0 m in height; declared rectangles only bound the search (grown 1.5 m,
  clipped to the chord bbox + 8 m); the flood fails closed at 8000 nodes.
- A **walk** is continuous supported traversal. Import-time evidence is the AABB
  of every collision hull (support only); the runtime audit uses rays and a
  capsule. A room must pass the weaker, box-shaped evidence first.
- **Rails** are sparse control points; Production smooths them (Catmull-Rom,
  tension 1.0, baked at 0.2 m) and measures pitch and envelope on the baked
  curve. Segments 0.5–60 m, ≤ 64 points, ≤ 75°.
- **Launch** is a source and a landing (span ≤ 80 m, apex 3.5 m over the higher
  end, 24 arc samples, landing radius ≥ 2.5). **Grapple** is a region (anchor in
  clear air, 4 m of swing room, ground ≤ 30 m below).
- **Offers are declinable.** Every room below is completable with no movement
  package. Offers add readings; they never carry the exit.

| number | value | number | value |
|---|---|---|---|
| player h / r / eye | 1.8 / 0.4 / 1.6 | jump apex / flat reach | 1.333 / 4.667 |
| max vertical step | 1.0 | max safe gap (rise 0 / 0.5 / 1.0) | 2.6 / 2.4 / 2.0 |
| headroom / door | 2.4 / 2.4 × 3.2 | min passable | 1.2 × 2.0 |
| wall allowance / floor allowance | 0.55 / 1.0 | fall kill y | −30 |
| rail catch / below / drive | 1.6 / 2.2 / 9 m/s | brute lane | 2.6 |

---

## 2. Why `shell_hall_transit` works, and what was and was not taken

Read from `build_hall.py`, its manifest, the P3 owner review and the b37fe07
validators (full anatomy in the study's audit notes):

1. **The numbers come from the job.** 40 m is gallery + core + gallery; 60 m so
   the core has basin in front and behind; 38 m so three layers and a rail arch
   fit with air left over. Nothing is a round number for its own sake.
2. **Scale is a comparison.** The 10 × 9 × 5.5 vestibule is the small term; the
   basin is the big one. Every room below has a small term.
3. **The landmark is a frame, not a mass**, because the door-to-portal sightline
   is load-bearing and is asserted, not hoped for.
4. **Every layer is reachable with no movement package.** That is the condition
   under which offers may exist at all.
5. **The basin is one continuous floor.** A miss costs height, never the level.
6. **Offers are claims about space**, no velocities authored; overlays are
   derived from the manifest so a picture cannot disagree with the data.

Taken: 1–6 as rules. Not taken: the plan (rectangle, central frame, helical
rail); the ramps (its three wedges are unprovable at import under b37fe07, see
§7.1); the surface-count "climb budget" reasoning (no longer the binding
constraint).

---

## 3. The ten rooms

Field order for each: thesis · dimensions · first read · landmark · local spaces
and elevations · circulation (what is mandatory, what is optional) · rail / launch
/ grapple · three-plus package readings · empty-room reason · unlike the other
nine. Built rooms are marked ★: Wave 1 is described as built in §6, Wave 2 in §11.

### 3.1 ★ `shell_lemniscate` — "the room where the rail crosses itself"

- **Thesis.** A rail-first void: the figure-of-eight through open air is the
  room's signature, and the two island towers exist to be crossed between.
- **Dimensions.** 44 × 40 × 72 interior (126,720 m³); declared 45.2 × 40.6 × 74.0.
- **First read.** A 10 m vestibule 5.5 m high opens onto a basin 44 m wide and
  64 m deep under a 40 m roof; the exit portal is dead ahead, 72 m away and 14 m
  up, framed between two towers of unequal height. Asserted sightline: 70.3 m,
  clear.
- **Landmark.** The pair of islands (A at +7 near-left, B at +14 far-right) and
  the rail that ties them: from the vestibule mouth the rail's first pass is
  visible crossing the void 19 m up.
- **Local spaces.** vestibule 0 · basin 0 (one continuous floor) · island A +7
  (10 × 10) · island B +14 (10 × 10) · west stair 0→7 · west gallery +7 (6 m wide,
  28 m long) · north stair 7→14 · north landing +14 (full width, the exit deck) ·
  bridges to both islands · east catwalk +24 (6 m wide, 38 m long) reached by an
  optional stair from the landing · roof trusses at +37 (trim).
- **Circulation.** Mandatory: vestibule → basin → west stair → west gallery →
  north stair → landing → exit. Seven straight walks, 96 m in plan, never diagonal
  across the basin. Optional: bridge A from the gallery, bridge B from the
  landing, the east stair and catwalk, and a 7 m drop from island A.
- **Rail.** 13 points, 162.9 m, from the catwalk (+26.5 above the +24 deck)
  down and across to the west, back east under its own first pass (6.5 m of air
  between passes at z ≈ 37), and out to 1.5 m over the exit landing. Worst baked
  pitch 22.6°. **Launch.** basin → island A (17.3 m, apex 10.5) and island A →
  island B (29.3 m, apex 17.5). **Grapple.** roof-truss anchor over the centre
  (+29) and one over island A (+20).
- **Packages.** (a) *Siege of the islands*: enemies hold A and B, the player
  takes the galleries and shoots across; the bridges are the assault. (b) *The
  courier*: reward on island B, one launch pair each way, the rail as the fast
  exit; enemies on the basin only. (c) *Catwalk gauntlet*: the catwalk is
  enemy_high territory over the whole basin; the player is exposed everywhere
  except under the islands. (d) *Ride-through*: no enemies; the room is a rail
  playground and the exit is at the end of the line.
- **Empty.** Two towers of different height in a 40 m hall, with a gallery you
  climb along the wall: the eye sorts the room in one look and the walk reveals
  it in three.
- **Unlike the others.** The only room whose offer is the thesis; the only
  self-crossing rail; the tallest interior void.

### 3.2 ★ `shell_hypostyle` — "the forest and the lattice"

- **Thesis.** Two plans of the same floor: a column forest that hides everything
  and a walkway lattice that shows everything; the room is the argument between
  them.
- **Dimensions.** 56 × 18 × 56 (56,448 m³); declared 57.2 × 18.6 × 58.0.
- **First read.** Columns 2 m square and 14 m tall on an 8 m pitch receding in
  every direction; through the gaps, a 3 m-wide walkway grid hangs at +8; no
  destination is visible from the door.
- **Landmark.** The one stair to the lattice, in the middle of the forest,
  lantern-posted so it reads from the floor; from its top the whole field and
  every floor socket are visible at once (asserted 42 m avenue sightline at +9.6).
- **Local spaces.** floor 0 · 36 columns · lattice +8: five x-walkways (z 12, 20,
  28, 36, 44; the z 28 avenue broken twice by 2.4 m gaps) and four z-walkways
  (x ±8, ±16) plus a spine at x 0 cut around the stair well · central stair 0→8
  (16 m run) · exit landing +8 on the far wall · two open avenues at x ±24 with
  no lattice above them.
- **Circulation.** Mandatory: floor → stair → spine → landing → exit (four walks,
  51 m). Optional: the whole lattice, both gaps, a 7 m drop from the west avenue
  walkway.
- **Rail.** Two avenue rails: east 44 m flat at +9.5; west 42.9 m descending
  +9.5 → +1.8 (12.7°). **Launch.** west avenue floor → west end of the z 12
  walkway (10.6 m, apex 11.5). **Grapple.** two canopy anchors at +16 (x ±16).
- **Packages.** (a) *Ambush floor*: enemies among the columns, cover sockets at
  the column feet; the lattice is the player's escape and reveal. (b) *Overwatch
  inverted*: enemy_high on the walkways, the player must cross the floor under
  fire and take the stair. (c) *Pressure plates*: reactive sockets on the floor
  visible only from the lattice; the room is a puzzle you read from above and act
  on below. (d) *Empty*: a hypostyle hall.
- **Empty.** Rhythm and occlusion: the same 56 m room is a maze at 0 and an open
  field at +8.
- **Unlike the others.** The only LARGE room by footprint rather than height;
  the only one whose interest is a grid; the only one with no vertical landmark.

### 3.3 ★ `shell_cleft` — "the crack"

- **Thesis.** A room that is a slot: 12 m wide, 44 m tall, bent once; the climb
  is wedged chock-stones you can see from the floor, and the exit is round the
  bend at the top.
- **Dimensions.** L-plan: leg 1 12 × 52 (x −6..6, z 0..52), leg 2 28 × 12
  (x 6..34, z 40..52); H 44; 91,520 m³ of interior; declared 72.0 × 44.6 × 52.6
  because the envelope is x-symmetric (§7.3).
- **First read.** A tall thin gap with light at the top; three chock-stones
  jammed across it at +6.5, +13.5 and +21; the second chock (the destination) is
  visible from the door 45 m away (asserted, clear).
- **Landmark.** The chocks: masses wedged between the walls, each with a ledge
  on its upper face, each the obvious next stand.
- **Local spaces.** floor 1 (0) · stair 1 on the east face 0→6 · ledge e1 +6 ·
  chock 1 +6.5 · ledge w1 +7 · stair 2 on the west face 7→13 · ledge w2 +13 ·
  chock 2 +13.5 · ledge s1 +14 · stair 3 along x 14→20 · ledge s2 +20 · chock 3
  +21 · ledge n1 +22 · stair 4 22→24 · exit landing +24 (x 30..34) · floor 2 (0)
  under leg 2.
- **Circulation.** Mandatory: an 18-segment chain of walks and rises (19 declared), every span
  ≤ 1.8 m, every rise ≤ 1.0 m, crossing the slot four times. Optional: nothing
  bypasses the chain except the offers.
- **Rail.** 81 m along the west face from +2 near the door to +25.5 over the
  exit landing (21.8° worst), the room's one fast line. **Launch.** floor →
  chock 2 (19.4 m, apex 17). **Grapple.** the slot at +20 and the bend at +28.
- **Packages.** (a) *Overhead*: enemies on the ledges above the chain; the
  player climbs into fire and uses the chocks as roofs. (b) *Chase*: the rail is
  the escape, enemies on the floor. (c) *Reward at the chock*: the objective sits
  on chock 2; the launch is the shortcut, the chain is the honest way. (d)
  *Empty*: a canyon.
- **Empty.** The section is the drama; every stand is visible from every other.
- **Unlike the others.** The only non-rectangular plan; the narrowest; the only
  room whose mandatory route is a climb rather than a walk; the exit yaw is 90.

### 3.4 ★ `shell_bascule` — "the room that hides itself behind its own floor"

- **Thesis.** Two lifted leaves: the floor rises away from the door, and only
  from its crest do you see the second leaf, the gap between, and the exit down
  the far slope.
- **Dimensions.** 36 × 36 × 60; declared 37.2 × 36.6 × 62.0.
- **First read.** A slope climbing away from you to a crest 12 m up at z 26,
  blocking everything beyond; the ceiling above it is 36 m high, so the room
  is obviously much bigger than what you can see.
- **Landmark.** The crest edge against the void, then (from the crest) the
  opposing crest 8 m away across a 12 m-deep pit.
- **Local spaces.** leaf A 0 → +12 (stepped, z 4..26, full width) · pit floor 0
  (z 26..34, full width, the crucible) · leaf B +12 → 0 (z 34..56) · side stairs
  at both wall pockets: crest A → pit (west), pit → crest B (east) · exit at y 0
  on the far wall.
- **Circulation.** Mandatory: up leaf A (stairs, 26.6°) → west pocket stair down
  to the pit → across → east pocket stair up to crest B → down leaf B → exit.
  Four straight walks. Optional: none; the leaves are solid stepped masses.
- **Rail.** From crest A the rail dives into the pit, rises over crest B and
  runs down leaf B to 1.5 m over the exit (~70 m, one big dip). **Launch.**
  crest A → crest B (8 m, apex 15.5; the shortcut). **Grapple.** ceiling anchor
  over the pit at +30 (ground 30 below, at the limit).
- **Packages.** (a) *Pit fight*: the pit is the arena, enemies on both crests.
  (b) *Crest duel*: enemies on crest B only; the launch is the assault. (c)
  *Retreat*: reward at the pit floor, enemies arrive on leaf B behind you and the
  rail is the way out. (d) *Empty*: two slopes and a gap.
- **Empty.** The room withholds its second half until you earn the crest.
- **Unlike the others.** The only room whose floor is the landmark; the only
  one you cannot see across from the door; net rise zero.
- **Descent variant (after 301374d).** With `floor_depth` the pit can lie 12 m
  below the entry plane instead of at it, so the crest looks DOWN into a chasm
  and the leaves are half as tall; kept level for Wave 2 because withholding,
  not depth, is the thesis.

### 3.5 ★ `shell_stack` — "the room you fall through"

- **Thesis.** Three full plates 12 m apart, each with a well cut in a different
  place, so the room shows its own section from anywhere inside it. Rewritten
  after 301374d as the slate's descending room: you enter on the TOP plate and
  the mandatory route is two sheer drops through the offset wells; the exit is
  on the bottom plate; switchback flights are the optional way back up.
- **Dimensions.** 36 × 14 × 44 above the entry plane with `floor_depth` 24
  (plates at 0, −12, −24); declared 37.2 × 14.6 × 46.0 over a 39.6 m box.
- **First read.** A ceiling 14 m up with a 14 × 14 hole in its front half;
  through the hole, the underside of a second ceiling with its hole further back;
  through that, the roof at 42. Enemies (or nothing) at the hole edges.
- **Landmark.** The offset wells: a diagonal shaft of air you look up through
  and, later, down through.
- **Local spaces.** ground 0 (whole) · plate 1 +14 with the front well · plate 2
  +28 with the back well · east wall pocket with two switchback stairs (0→14,
  14→28) · exit at +28 on the far wall.
- **Circulation.** Mandatory: ground → pocket stair → plate 1 (walk round the
  well) → pocket stair → plate 2 → exit. Optional: drops through the wells
  (14 m, survivable: the level is never lost).
- **Rail.** Ground front → up through the front well → across plate 1 → up
  through the back well → 1.5 m over plate 2 at the exit (~90 m, two climbs).
  **Launch.** ground → plate 1 through the front well (14 m rise, apex 17.5).
  **Grapple.** underside of plate 2 over plate 1's well (ground 27 below).
- **Packages.** (a) *Floor by floor*: each plate is held; enemies rain through
  the wells. (b) *Snipers' stack*: enemy_high on the well rims, the player runs
  the ground. (c) *Descent chase*: reward on plate 2, enemies below; the wells
  are your fast way down. (d) *Empty*: a building with the floors cut open.
- **Empty.** A section made walkable.
- **Unlike the others.** The only room with full floor plates above the floor;
  the only one where "up" is visible as a stack rather than a void.

### 3.6 ★ `shell_beast` — "the ribcage"

- **Thesis.** A long nave under an arched section: ribs every 8 m meet at a
  spine 30 m up, and vertebra-decks alternate left and right so the walk zigzags
  while the rail runs the spine.
- **Dimensions.** 40 × 34 × 80; declared 41.2 × 34.6 × 82.0.
- **First read.** A tunnel of arches receding 80 m; the far exit at +9 visible
  through them; decks jutting from alternate sides at +9 and +18 like teeth.
- **Landmark.** The rhythm: ten ribs, and the spine they meet at.
- **Local spaces.** floor 0 · ribs as stepped block arches (wall role) · decks:
  west +9 (z 8..24), east +18 (z 24..40), west +9 (z 40..56), east +18
  (z 56..72) · floor stairs to each west deck, deck-to-deck stairs to each east
  deck · exit at +9 on the far wall from the last west deck.
- **Circulation.** Mandatory: floor → first west deck → floor → third west deck
  → exit; the east decks are optional high ground. All walks along the room's
  axis.
- **Rail.** 76 m under the spine at +27, one dip to +20 at mid-length so it
  passes between the east decks (long, straight, fast). **Launch.** floor → east
  deck 1 (18 m rise). **Grapple.** spine anchors at +27 above each east deck.
- **Packages.** (a) *Gauntlet*: enemies on every deck, the player runs the
  floor. (b) *Swallowed*: the exit is closed until the reward at the far end is
  taken; enemies come from behind. (c) *Spine ride*: the rail is the only quiet
  way through. (d) *Empty*: a nave.
- **Empty.** The tallest point is the centre line, and you walk beneath it.
- **Unlike the others.** The only arched section; the longest; the only rail
  that is straight by design.

### 3.7 ★ `shell_cascade` — "the bowl you climb out of"

- **Thesis.** Concentric terraces rise away from the door like a cavea; the
  player enters on the stage at the bottom and the exit is on the top ring.
- **Dimensions.** 52 × 36 × 52; declared 53.2 × 36.6 × 54.0.
- **First read.** Five rings stepping up and back, 5 m each, the topmost 25 m up
  and 40 m away; the exit portal in it, centred.
- **Landmark.** The bowl itself; from the stage every ring looks down at you.
- **Local spaces.** stage 0 (front half-disc, r 12) · rings +5, +10, +15, +20,
  +25 (8 m deep, octagonal in graybox) · ring-to-ring stairs alternating east and
  west along the ring · exit at +25 on the far wall.
- **Circulation.** Mandatory: stage → east stair → ring 1 → walk the ring → west
  stair → ring 2 … → ring 5 → exit (ten short straight walks). Optional: none.
- **Rail.** A chord across the bowl at +18 from ring 4 east to ring 4 west,
  50 m through open air over the stage. **Launch.** stage → ring 3 (15 m rise).
  **Grapple.** truss anchor over the stage at +28.
- **Packages.** (a) *The mob above*: enemies on rings 2–4, the player climbs
  into them. (b) *Stage fight*: enemies spawn on the stage; the rings are the
  player's high ground. (c) *Reward on the stage*: the objective is under every
  eye; the rail is the exit. (d) *Empty*: an amphitheatre.
- **Empty.** The one room where the whole room looks at one place.
- **Unlike the others.** The only concentric plan; the only room where the exit
  is the highest point of a continuous rise.
- **Descent variant (after 301374d).** Entered from the top ring and descended
  to a stage exit is the way a real cavea is entered; kept rising for Wave 2 so
  the slate spends its descent budget on the stack.

### 3.8 `shell_overpass` — "the crossroads in section"

- **Thesis.** Two routes cross at right angles and different heights: a trench
  floor running left–right toward a side exit, and a deck 10 m up running
  front–back across it.
- **Dimensions.** 60 × 28 × 40; declared 61.2 × 28.6 × 42.0.
- **First read.** A wide low room; a 6 m-wide deck overhead runs away from you
  to the far wall; the floor is a trench running sideways under it; the exit is
  in the east wall, up a stair bank, at +10.
- **Landmark.** The deck: the thing over your head that goes the other way.
- **Local spaces.** trench floor 0 (full width) · deck +10 (x −3..3, z 4..40)
  on piers · far-wall gallery +10 joining deck to both side walls · east stair
  bank 0→10 (x 22..30) to the exit · exit on the east wall at +10, yaw 90.
- **Circulation.** Mandatory: floor → east stair bank → exit (two walks).
  Optional: front stair to the deck, deck → far gallery → east wall → exit
  (the long way, above everything).
- **Rail.** Along the deck's underside line at +7 from the far wall to the
  entry, then up onto the deck (a loop under and over the same slab). **Launch.**
  trench west end → deck (10 m rise). **Grapple.** deck-edge anchors at +10.
- **Packages.** (a) *Under fire*: enemy_high on the deck, the player runs the
  trench beneath it. (b) *Hold the deck*: player above, enemies fill the trench.
  (c) *Two doors*: the reward is at the far gallery, reachable only from the
  deck; the exit is on the floor. (d) *Empty*: an overpass.
- **Empty.** The mass over your head.
- **Unlike the others.** The widest; the shallowest section; the only room
  whose mandatory route ignores the landmark.

### 3.9 `shell_face` — "the wall"

- **Thesis.** A tall shallow room whose east wall is a 48 m climbing face; the
  exit is on the floor, the climb is optional and everything on it is visible
  from the floor.
- **Dimensions.** 30 × 48 × 40; declared 31.2 × 48.6 × 42.0.
- **First read.** A floor you can see the end of, the exit at the far wall
  at 0; to your right a wall of ledges going up out of the light.
- **Landmark.** The face and its high alcove at +40.
- **Local spaces.** floor 0 · ledges on the east face at +6, +13, +21, +30, +40
  (alternating short stairs and 1.8 m gaps) · alcove +40 (the room's high
  reward) · exit at 0 on the far wall.
- **Circulation.** Mandatory: floor → exit (one walk). Optional: the whole face.
- **Rail.** 60 m cable from the alcove diving to the entry floor. **Launch.**
  floor → ledge +13, ledge +21 → alcove. **Grapple.** three anchors up the face.
- **Packages.** (a) *Archers*: enemies on the ledges, the player crosses
  below. (b) *The key*: the objective is in the alcove; the exit gate elsewhere
  needs it. (c) *Descent chase*: reward taken at the top, enemies arrive below,
  the rail is the way down. (d) *Empty*: one wall.
- **Empty.** Height as reward, not route.
- **Unlike the others.** The only room where verticality is entirely optional;
  the only rail that hugs a wall.

### 3.10 `shell_oculus` — "lit from one hole"

- **Thesis.** A square room organised around a point: a 16 m hole in the roof, a
  dais beneath it, pylons round it, and galleries round the walls that the
  mandatory route follows while the centre waits.
- **Dimensions.** 52 × 44 × 52; declared 53.2 × 44.6 × 54.0.
- **First read.** Dark edges, a lit centre: the dais under the shaft of light,
  ringed by eight 20 m pylons; the galleries at +12 and +24 fade into the walls.
- **Landmark.** The hole in the roof (the only room whose landmark is above the
  player).
- **Local spaces.** floor 0 · dais +3 (octagon r 8) · eight pylons (4 × 4 × 20 at
  r 18) · wall galleries +12 and +24 (4 m wide, all round) · west stairs 0→12 and
  12→24 · exit at +24 on the far wall.
- **Circulation.** Mandatory: floor → west stair → gallery +12 → stair → gallery
  +24 → exit (five walks along the walls). Optional: the dais, the pylon tops
  (by grapple only).
- **Rail.** Two straight chords at +30 crossing under the oculus (a plus), each
  48 m through the light. **Launch.** dais → gallery +12. **Grapple.** pylon-top
  anchors at +20 (ground 17 below on the dais).
- **Packages.** (a) *Arena*: the dais is the fight; galleries are enemy rings.
  (b) *Heist*: the reward sits under the light and every gallery sees it. (c)
  *Crossings*: the rails are the only way over the pit of pylons. (d) *Empty*: a
  pantheon.
- **Empty.** Light as landmark.
- **Unlike the others.** The only radial plan; the only ceiling landmark. Also
  the most conventional room of the ten (a hall with a centre), ranked last for
  that reason.

---

## 4. Diversity analysis

### 4.1 Strip test

Each room with every gameplay package removed (no enemies, no reward, no
offers), in one line, and whether a person would still want to walk it:

| room | stripped to | still worth walking? |
|---|---|---|
| lemniscate | two towers of unequal height in a 40 m void with a wall gallery | yes: the sightline and the climb reveal it in three views |
| hypostyle | 36 columns and a walkway grid 8 m up | yes: the maze/field switch at the stair |
| cleft | a bent slot with three chocks wedged in it | yes: the section is visible from the floor |
| bascule | a slope, a pit, a slope | yes: the second half is withheld |
| stack | three floor plates with offset holes | yes: the diagonal shaft of air |
| beast | ten arches and four decks | yes, weaker: rhythm only |
| cascade | five concentric rings | yes: everything looks at the stage |
| overpass | a trench and a deck over it | marginal: a big low room with one slab |
| face | a floor and one tall wall | marginal: the wall is a picture from the floor |
| oculus | a lit dais in a dark square | yes, but familiar |

Two rooms are marginal under the strip test (overpass, face). They stay in the
slate because their readings under packages are distinct, but they are ranked
low and are the first candidates to replace if Wave 2 needs a stronger empty
room.

### 4.2 Axes of difference

| room | plan | section | mandatory route | landmark | where the void is | rail character |
|---|---|---|---|---|---|---|
| lemniscate | rectangle | void with islands | wall galleries, +14 | islands + rail | centre | self-crossing arc |
| hypostyle | square | low, gridded | centre stair, +8 | stair in forest | above the lattice | two straight avenues |
| cleft | L | slot | zigzag climb, +24 | chocks | between the faces | wall-hugging climb |
| bascule | rectangle | two wedges + pit | up, down, up, down, 0 | crest | above the leaves | dive and rise |
| stack | rectangle | three plates | switchbacks, +28 | offset wells | the shaft of wells | threads the wells |
| beast | long rectangle | arch | zigzag decks, +9 | ribs + spine | under the spine | straight spine line |
| cascade | half-disc | stepped bowl | ring by ring, +25 | the bowl | over the stage | chord across |
| overpass | wide rectangle | shallow, one slab | floor to side, +10 | deck overhead | either side of deck | under-and-over loop |
| face | narrow tall | one wall | floor, 0 | the face | in front of the face | wall dive |
| oculus | square | radial | wall galleries, +24 | hole in the roof | the centre | plus of chords |

No two rooms share a (plan, section, route) triple. The one soft overlap is
cleft/face (both are climbs on a wall); it is kept because the cleft's climb is
mandatory and enclosed and the face's is optional and exposed, which are opposite
readings. Nothing in the slate is "a rectangular hall with a central pillar and a
spiral rail".

### 4.3 What the owner asked for

"Huge vertical areas with long smooth spline rails through open air" is carried
by lemniscate, bascule, stack, beast, cascade and oculus (six of ten), strongly
by lemniscate. Hypostyle, overpass and face deliberately are not that room, so
the library has a low room, a wide room and a wall room to put next to the tall
ones.

---

## 5. Dungeon-system awareness

Rooms are composed by Epsilon and sit in a dungeon with distant cause and
effect. Each room names one place a later machinery system can act at a
distance without the shell changing:

| room | distant cause the room can host | distant effect the room can receive |
|---|---|---|
| lemniscate | objective on island B (a switch nobody can reach without the bridge or the launch) | vestibule mouth is 10 m wide and 5.5 m high: a gate can close it; the exit portal at +14 can be sealed |
| hypostyle | reactive sockets on the floor readable only from the lattice | the central stair well (`no_build` volume) is the one place a lift or a blocker changes the mandatory route |
| cleft | chock 2 holds the reward | the exit landing is a 4 × 6 shelf: a door there holds the whole climb hostage |
| bascule | the pit floor is a natural pressure plate | the launch across the crests is the thing a machine can enable or remove |
| stack | each well rim is a place to fire from | plates are full: a hatch in any plate is a new route |
| beast | the far-end exit is the natural "sealed until" door | decks can be raised or dropped by machinery without touching the route |
| cascade | the stage is watched by every ring: a reward there is a public event | ring stairs are short: any one can be gated |
| overpass | the deck holds the reward off the mandatory route | the east stair bank is the single gate point |
| face | the alcove key at +40 | the floor exit is the door that key opens elsewhere |
| oculus | the dais under the light | pylon tops (grapple-only) are where a machine can drop a bridge |

Every room keeps its mandatory route on stairs and floors, so any of these
effects can remove an offer without breaking completion.

---

## 6. Ranking and Wave 1

### 6.1 Ranking

| rank | room | why here |
|---|---|---|
| 1 | lemniscate | the owner's archetype, done as a rail-first room rather than a hall with a rail added; largest void; hardest test of rail smoothing and self-crossing |
| 2 | hypostyle | proves LARGE without height; the reading a height-led brief does not produce; strongest strip test after the cleft |
| 3 | cleft | the extreme of spatial variety (L, 12 m wide, 44 m tall); the sharpest contract stress (x-symmetric size, 19-segment chain, yaw 90 exit) |
| 4 | bascule | withholding as a spatial idea; net-zero rise; strong empty room |
| 5 | stack | the section as the landmark; needs full plates, which the kit does not yet do cheaply |
| 6 | beast | strong rhythm, but arches out of blocks are expensive to read as arches in graybox |
| 7 | cascade | strong empty room, but eight-sided rings are many parts; concentric stairs are the 8000-node risk |
| 8 | overpass | marginal strip test |
| 9 | face | soft overlap with the cleft; marginal strip test |
| 10 | oculus | the most conventional; keep for the library's centre-organised slot |

### 6.2 Why these three prove the three things asked

- **Extreme spatial variety.** A 40 m void, an 18 m grid, a 44 m slot: no
  quantity or shape shared between them (see §4.2).
- **Value of LARGE.** Lemniscate needs 40 m so a rail can cross itself with
  6.5 m of air between passes; hypostyle needs 56 m so a lattice avenue can be a
  42 m sightline the floor never has; cleft needs 44 m so three chocks can be
  seen from the door before any is reached. Halve any of them and the thesis
  goes.
- **Something the other library is unlikely to discover.** Hypostyle, by
  construction: a LARGE room that is low and gridded is the room a "huge vertical
  areas" brief does not generate. (This is a claim about the brief, not about
  the other slate, which was not read.)

---

## 7. Contract and preflight findings

Things learned by building that are true of the contract at b37fe07, not of
these rooms. Each is a blocker or a rule for every LARGE author.

### 7.1 A wedge ramp is unprovable at import

`ShellValidator` passes support-only evidence built from the AABB of every
collision hull. A ramp that is one wedge has a hull whose top equals its high
end over the whole footprint; from the ramp's foot every sample sees support
more than 1.0 m above and no lattice node exists. `RoomAudit` (rays) would climb
it, but import comes first and an import refusal degrades the shell to
procedural. **Consequence:** the hall's three ramps fail import at b37fe07
whatever the surfaces declare; every mandatory climb in this slate is stairs,
0.5 m risers on 1.0 m treads (26.6°), which prove under both evidences. The
kit's `stair()` builds them; the kit checks every mandatory walk under box
evidence *and* ray evidence and reports the difference.

### 7.2 Net descent is declarable (correction)

An earlier version of this section said "no net-descent room is declarable".
That was wrong, and Production 301374d adjudicated it against the real law:

- `drop` exists for sheer descent and is bounded only by having to go down;
  how far is a damage question, and there is no fall damage in the game
  (`player.gd` takes damage only from the kill plane and from DoT).
- A descending stair or ramp is a `walk`, proven by ground continuity, not by
  the fall between its ends (a 12 m descending ramp passes the flood).
- A downward `gap` is held to the FLAT reach: `max_safe_gap` is fed
  `maxf(rise, 0)`, so falling buys no range.
- `ZoneBuilder` adds the whole `exit_offset` vector to its cursor, y included,
  so a room whose exit sits below its entry moves the next room down with it.
  Nothing in the schema bounds a socket's height or an exit's elevation.

What still constrains an AUTHORED shell, read at 301374d and verified by three
independent readers of the tree:

1. **The envelope pins the visible mesh, not the route.** `_from_authored_scene`
   builds `bounds` from `size` alone with the floor at −1.0 below the entry
   plane, and `ShellValidator._check_envelope` refuses at import any
   `MeshInstance3D` box outside that envelope grown 0.55. Collision hulls
   (`-convcolonly` nodes, which is how every shipped shell carries its floors)
   are never envelope-tested, and `RoomAudit` runs only in the test suite. So a
   shell whose VISIBLE mesh reaches below −1.55 m is refused; a shell that hid
   its lower floors in hulls alone would pass, which is a loophole, not a
   design path. The honest fix is one optional field (`floor_depth`, metres the
   room's lowest floor lies below its entry plane, default 0) added to the
   bounds floor in those two places; the kit declares it in the manifest and
   warns once when a room uses it (§8).
2. **The entry plane is local y 0 by chaining**, not by convention: the shell's
   origin is placed at the previous room's exit floor and nothing subtracts the
   entry socket. A shell cannot be entered at the top of its box by declaring a
   high entry socket.
3. **The kill plane is world-absolute.** `FALL_KILL_Y = −30` is compared with
   the player's world y (feet), the zone root sits at the world origin and the
   builder's cursor starts at zero. A chain's cumulative descent below the zone
   origin, net of ascents, must stay above −30 m or the floor itself kills and
   the player respawns at chamber 1. A 24 m descending room is therefore usable
   only after at least 24 m of prior rise (the hall gives 28, the cleft 24).

**Consequence for this slate:** descent is a real option, priced in prior rise.
`shell_stack` is rebuilt as the descending room (§3.5, §11); `shell_bascule`
and `shell_cascade` keep their rising/level forms and record their descending
variants (§3.4, §3.7).

### 7.3 The declared size is x-symmetric about the entry axis

`size_godot[0]` is a full width centred on x = 0. The cleft's L is 40 m wide but
must declare 72 m, and the composer will reserve 32 m the room does not use.
Asymmetric plans are possible but expensive in the composer's footprint; make
asymmetry the thesis when you spend it.

### 7.4 The witness cap makes wide walks fail closed

The flood is bounded by the declared rects grown 1.5 m and clipped to the chord
bbox grown 8 m, and stops at 8000 nodes (about 1280 m² at 0.4 m). A diagonal
walk across a 44 × 64 basin would bound over 17,000 nodes and fail with no route
proven. Every mandatory walk in the slate is straight and short (the longest is
26 m and bounds under 4,000). The kit mirrors the cap and reports the failure
message Production would give.

### 7.5 Walkways at head height are a headroom bug the boxes catch first

The hypostyle's z 36 walkway originally crossed the central stair well 2.4 m
over the treads. Support evidence passes; body evidence (0.8 m box from
floor + 1.05) fails. Production's `RoomAudit` would refuse it; the kit refused it
before anyone walked it. Rule: cut every deck 3 m clear of a stair well.

### 7.6 Front wall placement and the exit socket

Geometry with any part at z < 0 is 0.05 m outside the envelope once the wall
allowance is applied; the front wall must sit inside z 0..0.6 (the hall's
convention). The exit doorway socket sits 2 m past the far face and *is* the
next room's origin; the declared length therefore includes it.

### 7.7 Rail clearance and Catmull-Rom overshoot are not Production checks

`rail_path.gd` measures pitch and envelope containment on the baked curve, not
distance from geometry. The lemniscate's first control pair originally let the
baked curve sag to 0.6 m over the east catwalk. The kit bakes the same curve
(tension 1.0, 0.2 m) and requires 0.7 m of clearance from every solid; treat
that as an authoring standard, stricter than the contract.

### 7.8 Launch arcs rise through decks in their plan footprint

The arc's apex is 3.5 m over the higher end, so anything below the apex inside
the arc's plan footprint is a candidate obstruction. The hypostyle's first pair
rose through the z-walkway at x −8. Rule: put the source outside the plan of
every deck between it and the landing.

### 7.9 Stale Art verification

`tools/verify_shells.gd` and `tools/content/preflight_shells.py` on the Art
branch still classify walk refusals as "kind-blind / NOTED" (correct at their
writing, wrong since 93ddc60). A real walk failure in a new shell prints PASS at
stage 4. Do not trust a PASS from those tools on a walk; use Production's
validators or the kit's report.

### 7.10 Caps are not the constraint

The busiest room in Wave 1 uses 18 of 32 surfaces, 19 of 32 traversal segments,
7 of 32 offers, 13 points of 64. The binding constraints are §7.1 and §7.4.

---

## 8. Tooling (preserved; not the product)

`tools/graybox/` runs on plain `python3` (no Blender, no Godot) and is
intended to bridge to the Blender pipeline, not replace it.

| file | lines | what |
|---|---|---|
| `gbkit.py` | 1133 | `Room` (block/slab/surface/stair/socket/seg/rail/launch/landing/grapple/volume/sightline/doors/enclose); law mirrors (walk flood under box and ray evidence, stance search, Catmull-Rom bake, launch arc, grapple); `preflight`; `manifest`; `.glb` writer with `-convcolonly` twins; plan and section SVGs |
| `build.py` | 101 | CLI: `python3 tools/graybox/build.py tools/graybox/rooms/<id>.py [--out DIR]`; exit 1 on preflight errors |
| `engine_dims.json` | — | every number the checks use, with provenance |
| `verify_dims.py` | 27 | drift check against a repo's `assets/art_budgets.json` |
| `rooms/shell_*.py` | ~100 each | a room as intent: parts, surfaces, route, offers, sockets, volumes, sightlines |

Outputs go to `assets/graybox/large/<id>/`: `<id>.glb`, `manifest.json`
(batch039 shape, plus `graybox: true` and `measured_box`; `review: pending`),
`plan.svg`, `section_z.svg`, `section_x.svg`, `preflight.json`, `README.md`.

What it deliberately does not do: paint, UV, texel density, triangle budgets,
the export pack, the `.tscn` wrap, or Production's validators themselves. A room
that passes the kit still has to be rebuilt as a `build_<id>.py` under Blender
for batch, and still has to pass `ShellValidator` and `RoomAudit` in Godot. The
kit's value is that those two runs are no longer the first time a room meets
the contract.

Feature freeze: the kit gains a feature only when a room in the slate cannot be
expressed without it (stack's full plates with wells; cascade's octagonal rings
are already expressible as blocks).

---

## 9. Wave 1 as built

### 9.1 `shell_lemniscate`

| | |
|---|---|
| interior / declared / measured | 44 × 40 × 72 · [45.2, 40.6, 74.0] · 45.2 × 41.6 × 72.6 |
| parts / colliders / triangles | 73 / 70 / 876 |
| surfaces / traversal / offers / sockets / volumes | 12 / 12 / 7 / 12 / 4 |
| mandatory route | 7 walks, 96 m in plan, rise 14, all stairs and galleries |
| rail | 13 points, 162.9 m, 22.6° worst, 18.5 m height range, self-crossing with 6.5 m of air |
| launches | basin → A 17.3 m (apex 10.5); A → B 29.3 m (apex 17.5) |
| grapples | (0, 29, 38), (−9, 20, 27) |
| sightlines | entry → portal 70.3 m; island A → island B 28.8 m |
| lowest floor | y 0 (nothing falls forever) |
| preflight | 0 errors, 0 warnings |

**What the player wants to reach.** The exit portal, visible from the door;
island B, because the rail visibly ends near it and the launch from island A is
aimed at it.

**Fun before enemies.** Reading the route from the mouth (gallery, stair,
landing), then discovering the islands are reachable by bridges you could not
see from below; the rail, if you have it.

**What LARGE enables.** A rail that crosses its own path with clearance; two
towers whose heights can be compared from one viewpoint; a 70 m sightline.

**Under rail / grapple / launch / none.** Rail: the room is a 163 m line and
the walk is a warm-up. Grapple: island A from the basin and the truss centre as
a swing over the whole basin. Launch: A-to-B is the room's fast middle. None:
a tall room with two towers and a wall gallery, 96 m of walking, complete.

**Combat territory.** Basin (cover ×3, reactive ×2), islands (enemy_high ×2),
gallery (enemy_high), catwalk (enemy_high), landing (enemy_high). Enemies above
the basin see the whole floor; the underside of the islands is the only shadow.

**Falls.** The worst is catwalk → basin, 24 m, onto y 0: the level is never
lost. No hole, no pit.

**Future machinery.** Vestibule gate; portal seal; a bridge from island B to the
landing (bridge B exists as a slab: a machine can be the thing that removes it).

**Non-interchangeability.** Swap it for the hall and the rail loses its
crossing; swap it for the cleft and the sightline goes.

### 9.2 `shell_hypostyle`

| | |
|---|---|
| interior / declared / measured | 56 × 18 × 56 · [57.2, 18.6, 58.0] · 57.2 × 19.6 × 56.6 |
| parts / colliders / triangles | 83 / 79 / 996 |
| surfaces / traversal / offers / sockets / volumes | 18 / 9 / 6 / 13 / 3 |
| mandatory route | 4 walks, 51 m in plan, rise 8 (one 16 m stair) |
| rails | east avenue 44 m flat at +9.5; west avenue 42.9 m, +9.5 → +1.8, 12.7° |
| launch | (−25, 0, 12) → (−18, 8, 12): 10.6 m, apex 11.5 |
| grapples | (±16, 16, 28) |
| sightline | lattice avenue 42 m at +9.6 |
| preflight | 0 errors, 0 warnings |

**What the player wants to reach.** The stair, once glimpsed between columns;
then the lattice, because it is the only place the room makes sense.

**Fun before enemies.** The switch: the same room as a maze and as a field; the
two 2.4 m gaps on the broken avenue; the west avenue rail that runs the whole
length descending.

**What LARGE enables.** 36 columns is enough that the floor has no sightline
longer than 8 m in any direction while the lattice above has 42 m ones.

**Under rail / grapple / launch / none.** Rail: two avenues bracket the forest,
one flat, one descending; the room becomes a loop. Grapple: canopy anchors put
you on the lattice without the stair. Launch: one shortcut from the west avenue.
None: a forest with one stair, complete in 51 m.

**Combat territory.** Floor (cover ×4 at column feet, reactive ×2), lattice
(enemy_high ×5). Whoever holds the lattice sees every socket on the floor.

**Falls.** 8 m from any walkway to the floor; nothing below 0.

**Future machinery.** The stair well is a `no_build` volume 3 × 16 m: a lift, a
blocker or a second stair goes there and nowhere else.

**Non-interchangeability.** No other room in the slate has short sightlines at
ground; drop it into a tall room's slot and the encounter design built on
occlusion dies.

### 9.3 `shell_cleft`

| | |
|---|---|
| interior / declared / measured | L 40 × 44 × 52 · [72.0, 44.6, 52.6] · 41.2 × 45.6 × 52.6 |
| parts / colliders / triangles | 66 / 65 / 792 |
| surfaces / traversal / offers / sockets / volumes | 16 / 19 / 5 / 10 / 3 |
| mandatory route | 18 of 19 segments mandatory (walks and rises), 78 m in plan, rise 24, spans ≤ 1.8, rises ≤ 1.0 |
| rail | 9 points, 81 m, 21.8° worst, 23.6 m height range |
| launch | (0, 0, 32) → chock 2 (0, 13.5, 46): 19.4 m, apex 17 |
| grapples | (0, 20, 30), (16, 28, 46) |
| sightline | entry → chock 2 top 45.4 m |
| exit | (36, 24, 46), yaw 90 |
| preflight | 0 errors, 0 warnings |

**What the player wants to reach.** Chock 2, visible from the door, wedged
across the slot at +13.5 with light above it.

**Fun before enemies.** The chain: every stand is the next obvious one, four
crossings of the slot, the bend revealing leg 2 only at +21.

**What LARGE enables.** Three chocks stacked in one 44 m view; a rail that gains
23.6 m in 81 m along one face.

**Under rail / grapple / launch / none.** Rail: the climb becomes a line up the
west face. Grapple: the slot anchor lets you skip chock 1 and 2. Launch: floor
to chock 2 in 1.7 s. None: 18 segments of stairs and ledges, complete.

**Combat territory.** Floor (cover ×2, reactive), leg 2 floor (cover), ledges
(enemy_high ×3), chock 2 (enemy_high). Enemies above are always in view; the
undersides of the chocks are the only cover from them.

**Falls.** Any miss lands on floor 1 or floor 2 at 0; the slot is 12 m wide, so
a fall from a ledge lands on the floor, never on a chock.

**Future machinery.** The exit landing at +24 is a 4 × 6 shelf behind the bend:
one door there gates the whole room; chock 2 is the reward stand.

**Non-interchangeability.** Its declared footprint is an L in a 72 m box; a
composer that treats it as a rectangle will place things in air. That is the
point of building it: the contract's x-symmetry is now a measured cost, not a
suspicion.

---

## 10. Lessons from Wave 1

1. **Stairs, not ramps**, for every mandatory climb (§7.1). Use 0.5 m risers on
   1.0 m treads; a 12 m rise is 24 slabs and reads as a stair from any distance.
   Declare the stair as one surface; the stance search finds a tread.
2. **Straight, short mandatory walks** (§7.4). Break a long floor crossing at a
   socket or a surface edge; never chord diagonally across a basin. Keep chords
   under ~30 m.
3. **Design the mandatory route first and prove it before any offer exists.**
   Both Wave 1 fixes after round 1 were offers; the routes passed first time.
4. **Rails: two things the contract does not check.** Start ≥ 2 m over the catch
   deck and keep the second point high enough that the bake does not sag; keep
   0.7 m from every solid along the baked curve.
5. **Launches: the source outside the plan of every deck between it and the
   landing** (§7.8). Apex is 3.5 over the higher end; anything under the arc's
   footprint below that is a risk.
6. **Cut decks 3 m clear of stair wells** (§7.5).
7. **Sightlines aim at edges, not faces.** A target on a block's face is a
   sample inside the block; aim at the visible top edge or 0.5 m above it.
8. **Symmetric plans unless asymmetry is the thesis** (§7.3); the composer pays
   for the mirror image.
9. **Rooms may go down** (§7.2): declare `drop` for sheer descent, stairs for
   walked descent, a negative exit y, and `floor_depth` for the envelope; spend
   descent only where the chain has risen first (world kill plane at −30).
10. **Stack needs plates with wells**; cascade needs many parts; beast needs
    stepped arches. Add one kit helper per need when the room is authored, not
    before.
11. **Keep the numbers derived**: every room's manifest, SVGs and README come
    from the same spec; if a figure and the data disagree, the data is wrong and
    the build says so.

---

## 11. Wave 2 as built

Four more rooms, built the same way and to the same standard: the spec is intent,
the kit derives the geometry, the manifest, the drawings and the preflight from
it, and nothing ships that the preflight refuses. All four carry `graybox: true`
and `review: pending`. Production's capsule `RoomAudit` remains the final
physical authority; the kit mirrors the weaker import-time evidence.

**Why these four.** They are ranked 4, 5, 6 and 7 in §6.1, and together they
extend Wave 1 along every axis it left thin: a room whose landmark is its own
floor, the slate's first descending room, the only arched section, and the only
concentric plan. The two rooms left out of Wave 2 (`shell_overpass`,
`shell_face`) are the two that fail the strip test in §4.1, and `shell_oculus`
is held back as the most conventional. Nothing was chosen to be easy: the beast
is the largest part count in the library and the cascade the largest footprint.

| | bascule | stack | beast | cascade |
|---|---|---|---|---|
| interior W × H × D | 36 × 36 × 68 | 36 × 14 × 44 (+24 below) | 40 × 34 × 80 | 64 × 30 × 64 |
| declared size | 37.2 × 36.6 × 70.0 | 37.2 × 14.6 × 46.0 | 41.2 × 34.6 × 82.0 | 65.2 × 30.6 × 66.0 |
| exit | y 0, yaw 0 | **y −24**, yaw 0 | y 9, yaw 0 | y 20, yaw 0 |
| parts / colliders / tris | 112 / 111 / 1344 | 76 / 76 / 912 | 210 / 209 / 2520 | 76 / 75 / 912 |
| surfaces / traversal / offers / sockets | 11 / 13 / 4 / 9 | 16 / 10 / 5 / 10 | 13 / 21 / 5 / 13 | 22 / 20 / 5 / 10 |
| mandatory route | 11 walks, 131 m | 3 walks + **2 drops**, 39 m | 13 walks, 189 m | 18 walks, 286 m |
| preflight | 0 err, 0 warn | 0 err, **1 expected warn** | 0 err, 0 warn | 0 err, 0 warn |

### 11.1 `shell_bascule` — the room that hides itself behind its own floor

**Spatial thesis.** The floor is the landmark. Two lifted leaves rise away from
the entry to crests 12 m up, and only from the first crest do you see the second
leaf, the pit between them and the exit down the far slope. Net rise zero.

**First read.** An 8 × 4 × 4 m porch opens on a slope climbing away to a crest
12 m up and 22 m off, which blocks everything beyond it; the roof is 36 m up, so
the room is plainly much bigger than what can be seen. The asserted sightline
from the entry is 27 m and stops at the crest, not at the exit: withholding is
the design, so the far half is proven hidden rather than hoped hidden.

**Plan and section logic.** Plan is a plain 36 m rectangle; all the information
is in the section. Leaf A climbs z 4→26 as 24 stepped treads, crest A caps it at
12, the pit floor sits at y 0 for 12 m of z, crest B and leaf B mirror them, and
an apron at y 0 carries the exit. The two pocket stairs that link crest to pit
run across the room in x rather than z, so the descent into the pit is a corner
turned, not a slide continued.

**Mandatory circulation.** Porch → leaf A → crest A → west pocket stair down →
pit → east pocket stair up → crest B → leaf B → apron → exit. Eleven straight
walks, 131 m in plan, no diagonals. Leaf B is a walked descent, legal since
301374d and proven here by ground continuity, not by the drop between its ends.

**Offers.** `rail_dive` is 61.8 m of one big dip: caught over leaf A, into the
pit and out over crest B, ending 2 m over the apron; worst baked pitch 60.7°,
the steepest in the library and deliberately so. `launch_crest` crosses the pit
crest to crest in 14 m. `grapple_pit` hangs from the ceiling truss over the pit.

**Package readings.** Pit fight (the pit is the arena, both crests are held);
crest duel (enemies on crest B only, the launch is the assault); retreat (reward
on the pit floor, enemies arrive over leaf B behind you and the rail is the way
out); empty (two slopes and a gap).

**Strip test.** Passes. Two slopes, a pit, and a second half you cannot see
until you have earned the crest.

**Recovery geography.** Everything falls to y 0, which is the pit floor or a
leaf. The pit has two stairs out, one per side, so a fall costs the climb and
never the level; there is no fall damage.

### 11.2 `shell_stack` — the room you fall through

**Spatial thesis.** Three full plates 12 m apart with wells cut in different
places, entered at the top and left at the bottom: the room shows its own
section from anywhere inside it, and the mandatory route is two sheer drops.
This is the slate's descending room, rewritten after Production 301374d.

**First read.** A plate underfoot and two more below it: through well A in front
of you, the underside of plate 1 with its own well further back, and through
that, plate 2 twenty-four metres down. The asserted sightline runs 42.5 m
through both wells.

**Plan and section logic.** Plan is the same 36 × 44 rectangle three times over
with the well moved: A at the front of plate 0, B at the back of plate 1, so the
two are never in line and nobody falls the whole way by accident. The section is
the room. `floor_depth` 24 is what lets the shell declare it (§7.2).

**Mandatory circulation.** Plate 0 walk → **drop** through well A → plate 1 walk
→ **drop** through well B → plate 2 walk to the exit. Three walks and two drops,
39 m in plan, the shortest mandatory route in the library, because the room's
length is vertical. The east-pocket switchback flights are the optional way back
up, and are proven walks under both evidences.

**Offers.** `rail_wells` threads both wells in 55.2 m, from 2 m over plate 0 to
1.5 m over plate 2. `launch_up` throws you from plate 2 back up through well B
to plate 1: the one offer in the library that undoes the mandatory route rather
than shortening it. Two grapples hang under the plates.

**Package readings.** Floor by floor (each plate is a held room, enemies rain
through the wells); snipers' stack (enemy_high on four well rims, the player runs
the bottom under two rings of fire); descent chase (reward on plate 2, enemies
above, the wells are the fast way down); empty (a building with its floors cut
open).

**Strip test.** Passes, and most cheaply of the four: a section made walkable.

**Recovery geography.** A miss lands on the plate below, which is closer to the
exit, so falling is never a loss — that is what makes the drops legible as a
route rather than a hazard. The switchback returns you to any plate. The
room's 24 m of descent must sit after at least 24 m of rise in the chain, since
the kill plane is world-absolute (§7.2).

### 11.3 `shell_beast` — the ribcage

**Spatial thesis.** A long nave under an arched section: nine ribs spring from
wall pilasters and meet at a spine 30 m up, and decks alternate left at +9 and
right at +18, so the route zigzags across the nave while the rail runs the spine.

**First read.** A tunnel of arches receding 80 m with the exit visible through
them at +9 (asserted, 78.1 m clear), decks jutting from alternate sides like
teeth. The porch is the small term again: 8 × 4 × 4 before 40 × 34 × 80.

**Plan and section logic.** Plan is a long rectangle whose only events are five
decks; the arch is the room. The four cross-flights that carry the route between
decks are built from thin slabs rather than solid stairs, so the nave keeps its
long sightline underneath them — a solid stair flank would have walled the room
in half.

**Mandatory circulation.** Porch → nave → the one solid floor stair to west 1 →
cross-flight → east 1 → cross-flight → west 2 → cross-flight → east 2 →
cross-flight → apse → exit. Thirteen straight walks, 189 m, the longest route in
the library. The nave floor itself is optional: the fast lane nobody is made to
take.

**Offers.** `rail_spine` runs 80.1 m under the spine, crossing the nave only in
the bays where no cross-flight hangs, worst baked pitch 38.5°. `launch_w2`
throws from the nave floor to west 2. Two grapples hang from the spine.

**Package readings.** Gauntlet (enemies on every deck, the player runs the floor);
swallowed (the apse is gated until the reward at east 2 is taken, enemies arrive
from behind); spine ride (the rail is the one quiet way through); empty (a nave).

**Strip test.** Passes, though it leans on rhythm more than the others: nine
arches, five decks and the fact that the tallest point in the room is the centre
line you walk beneath.

**Recovery geography.** Any fall lands on the nave floor at y 0 and walks back to
the single floor stair; the launch is the shortcut back for a player who has it.

### 11.4 `shell_cascade` — the bowl you climb out of

**Spatial thesis.** Four concentric terraces rising around a stage: the one room
in the library where every part of the room looks at the same place.

**First read.** A 4 × 4 m tunnel driven 21 m under the front of every terrace
opens at the foot of the bowl; the terraces step up and back 5 m at a time and
the exit portal sits in the topmost one, 20 m up and in line with the tunnel
(asserted, 48.4 m clear). The tunnel is the small term, and it is the most
compressed in the library.

**Plan and section logic.** Plan is concentric and the section is a staircase of
5 m risers; every terrace is a solid mass, so the bowl has no underside and
nothing in the room is hollow. The four ring stairs alternate east and west, so
the climb walks most of every terrace and the stage is behind you at a different
angle each time.

**Mandatory circulation.** Tunnel → stage → stair 1 → ring 1 → stair 2 → ring 2
→ stair 3 → ring 3 → stair 4 → ring 4 → exit. Eighteen straight walks, 286 m in
plan: the longest walked distance in the library, and every segment axis-aligned
and under 30 m, because a bowl is exactly the shape that tempts a diagonal.

**Offers.** Two straight chord rails cross at right angles 5 m apart over the
stage rather than spiralling the bowl, which is the move the shape invites and
the one the library already has elsewhere. `launch_stage` throws from the stage
to ring 3 west in 29.2 m. `grapple_stage` hangs from the truss 27 m over the stage.

**Package readings.** The mob above (enemies on rings 2 to 4, the player climbs
into fire); stage fight (enemies on the stage, the rings are the player's high
ground); the public reward (the objective on the stage under every eye, the rail
the way out over their heads); empty (an amphitheatre).

**Strip test.** Passes. Four terraces, a stage and a tunnel: the climb is a slow
reveal of how far down you started.

**Recovery geography.** No terrace overhangs and nothing is below y 0, so a miss
lands on the ring below or on the stage; each ring's own stair rejoins the route.
Two optional drops are declared so the composer knows the shortcut down exists.

### 11.5 What Wave 2 changes for the final three

1. **Descent is a budget, not a permission.** A descending room is legal and
   `shell_stack` proves it, but its 24 m has to be paid for by prior rise in the
   chain. The library should hold at most one or two descending rooms, and they
   should say in their notes what they cost. `shell_overpass`, `shell_face` and
   `shell_oculus` all rise.
2. **A solid stair is a wall.** The beast's cross-flights had to be thin slabs
   because `Room.stair`'s solid flank would have divided the nave. The rule for
   the final three: use a solid stair when you want the mass, thin treads when
   you want to see through it, and declare either as one surface.
3. **Rails cross a room where nothing hangs.** The beast's first rail failed on
   31 baked samples because it crossed the nave exactly where the flights are;
   re-routing it to the empty bays fixed it without changing a single point's
   purpose. Plan a rail against the room's occupied volumes, not its plan.
4. **Concentric and radial plans are surface-hungry.** The cascade spends 22 of
   32 surfaces on four terraces alone. `shell_oculus` is radial and will spend
   more; budget its galleries as four strips per level, not eight.
5. **The strip test is the ranking.** The two rooms Wave 2 skipped are exactly
   the two that were marginal in §4.1, and skipping them cost the slate nothing.
   Either strengthen `shell_overpass` and `shell_face` before they are built or
   replace them; the last wave should not be the weak wave.
6. **Withholding is a design, and it must be asserted.** The bascule's entry
   sightline is deliberately short, so it is declared and proven short. A room
   that hides something should say so in its sightlines rather than leave the
   reader to assume the drawing failed.

---

## 12. Paths

| what | where |
|---|---|
| this slate | `docs/art/LARGE_ROOM_SLATE_B.md` |
| kit | `tools/graybox/gbkit.py`, `tools/graybox/build.py`, `tools/graybox/verify_dims.py`, `tools/graybox/engine_dims.json` |
| room specs | `tools/graybox/rooms/`: `shell_lemniscate.py`, `shell_hypostyle.py`, `shell_cleft.py` (Wave 1); `shell_bascule.py`, `shell_stack.py`, `shell_beast.py`, `shell_cascade.py` (Wave 2) |
| grayboxes | `assets/graybox/large/<id>/{<id>.glb, manifest.json, plan.svg, section_z.svg, section_x.svg, preflight.json, README.md}` |
| rebuild all seven | `python3 tools/graybox/build.py tools/graybox/rooms/*.py` |
| dims drift | `python3 tools/graybox/verify_dims.py <art-worktree>` |

Nothing under `assets/graybox/` is in a batch, the export pack, or the catalog,
and nothing here touches Production. The manifests carry `review: pending` and
`graybox: true`; promotion to a batch is a Blender rebuild and the owner's call.
