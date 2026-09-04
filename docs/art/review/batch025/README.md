# Batch 025 — PROPOSAL: the Forge, and Questionable Goods

**Status: PENDING. Physical and presentation identity only.** Nothing here
designs the mechanic: not the cost, not the family rules, not what
reinterpretation does to an Echo, not whether a reforge can destroy a
capability. Production's own research memo has an open section on the last
one and this batch does not answer it.

## The audit found one of these already has a home

Read-only against `claude/archipepsi-echoes-continuation-b1adno`.

**Questionable Goods has a real Hub anchor.** `hub_anchors.gd` lists `"shop"`
in `REQUIRED`, commented `# QUESTIONABLE GOODS`, at `(-9.4, 0, 2.4)` facing
across the room. The anchor carries a hard-won constraint in its own comment:
at `D * 0.45` the counter spanned z 6.0–8.4 while the Lab doorway spans
4.5–7.5, so the shop stood in two thirds of the only way into the Echo Lab
and **playtest 1 found the Lab unreachable.** This asset is authored to that
contract — 3.0 m of wall run centred on z = 2.4, spanning 0.9–3.9, clearing
the doorway by 0.6 m — and the builder *asserts* it rather than only
documenting it.

**The Forge has no anchor, no scene, no script and no constant.** Its only
mention in Production is `RESEARCH_MEMO.md` §7, an open design question. So
it is authored at proposal scale with no placement claim. **Interface
requirement 26.** The Hub's left wall is already crowded — Epsilon's bay at
the far end, the shop at z = 2.4, the Lab doorway between them — so a Forge
anchor is not a free choice and art is not making it.

**Epsilon Coins are scarce.** `EPSILON_COIN_COUNT = 10` for an entire
campaign. That is why the Forge has **one** coin socket and not a hopper: a
slot that looked like it expected a handful would misprice the currency
before the player spent one.

## The Forge is an instrument, not a workshop

Not blacksmithing, not a crafting table, not a skill tree. The operation is:
*take a foreign object, work out what it means, take it apart, decide what it
could mean instead within a requested family, and rebuild it as that.* Four
verbs, in order — so the bench is four stations in a line and you can see
where your object is.

| station | what it is | why |
|---|---|---|
| ANALYSIS | a scanning head on the spine, pointing **down** at the rail | nothing is changed yet, only read |
| DESTABILISATION | braced clamps and a containment ring, in alien plating | the one violent stage, and it looks like it |
| REINTERPRETATION | **a gap in the bench, with a lined shaft under it** | see below |
| RECONSTRUCTION | a closing die and an output chute | the new thing arrives, and from somewhere |

**A transfer rail runs the whole length**, entering left and leaving right,
and it *bridges* the reinterpretation gap on two thin rails with no bench
under them — so the object crosses that station suspended. The rail is what
makes four fixtures read as one process; without it the bench was a table
with instruments on it, which is exactly what the first render showed.

### The empty third station is the deliberate risk

There is no machine that decides what something could mean. Drawing one would
make the Forge a factory and would lie about where the work happens — Batch
024 already established that Epsilon thinking is *interior*. So the bench top
is absent there and the only thing in the gap is suspended light.

## The selector is one dial

Seven families — ranged, melee, grapple, movement, defense, sustain,
utility — so seven detents, one pointer, one commit lever, one coin socket.
That is the whole control surface, and it is deliberately smaller than any
single station: the machine is mostly process, not interface. A 1998 facility
instrument says "choose a range" with a dial, not a graph.

## Two services, two *kinds* of object

| | Forge | Questionable Goods |
|---|---|---|
| what it is | an apparatus | a counter |
| the process | **made visible** — four stages exposed | **made opaque** — shutter, mesh, one hatch |
| works on | what you already own | what someone else has |
| construction | fabricated for the job | improvised from taken facility parts |
| its green | native — Epsilon's own machine | hijacked — tapped in on scavenged hardware |

Sheet B shoots both from an **identical camera, distance and scale rod**. If
the distinction needed the caption it would not work; from silhouette alone
one is open and skeletal and the other is closed and solid.

## Metrics

| asset | state | tris | size (m) |
|---|---|---|---|
| `forge_bench` | idle | 1036 | 4.25 × 1.17 × 2.19 |
| `forge_bench_working` | working | 1112 | 4.25 × 1.17 × 2.19 |
| `qg_counter` | — | 412 | 3.39 × 1.40 × 2.40 |

## Sheets

| | |
|---|---|
| `A_forge.png` | idle, working, the reinterpretation gap, the selector |
| `B_forge_vs_shop.png` | both services, identical camera and rod |

## What the renders changed

- **The operator plate sat directly in front of the reinterpretation void**,
  hiding the one feature carrying the batch's whole argument behind the least
  important one. Controls moved to the entry end — where you set the dial
  before committing anyway, so the fix was also the better design.
- **Nothing carried direction of travel.** Four instruments on a table are
  four instruments on a table. The transfer rail was added, and it is the
  single change that made the bench read as a process.
- **Absence photographs exactly like darkness.** The missing bench top was
  indistinguishable from bench top in shadow until a lined shaft was put
  under it: a hole needs an *inside* to read as a hole.
- **Analysis and destabilisation shared a silhouette** — two closed rings at
  bench level. They are opposite acts and now look it: one hangs above and
  points down, the other is braced and closed around.
- **Questionable Goods first rendered as clean pale sheet steel**, a *new*
  counter, which is the opposite of the brief; and one bright value flattened
  the shutter, mesh and stock into a single slab. It is now worn metal below
  and taken facility panels above, which separates the half you are served at
  from the half you are kept out of.
