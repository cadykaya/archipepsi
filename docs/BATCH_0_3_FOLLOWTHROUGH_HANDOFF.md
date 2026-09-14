# Bounded 0.3 follow-through — demonstrated, defective, unresolved

Prod (engine lane), branch `claude/archipepsi-echoes-continuation-b1adno`.
Follow-through on the existing brief from `03af8a2`. The delivered ascent
and activity-feedback changes are kept unchanged.

**No shared contract moved, so nothing needed coordinating with Dess.**

---

## DEMONSTRATED SUCCESS

### The exit is handled by the consumer that actually handles it

`integration_driver` takes the real portal and proves the player survives
teardown — that half is retained. What it could not do is run
`main.gd::_on_exit_zone`: a driver is added as a child of `Main` and
`Main` returns **before** `boot()`, so `menu`, `hud` and `world` are null
and `_to_hub()` would dereference all three. The old test therefore
duplicated the teardown by hand.

`boot_driver` is the suite that boots for real, so the consumer half
lives there now. A `ZoneController` is placed in the world and wired
exactly as `main.gd` wires it — `zone.exit_requested.connect(
_on_exit_zone)` — and the signal is fired the way the portal fires it,
not by calling the handler.

Asserted, after the real consumer runs: the **HUB view**, a **Hub that
exists** to have arrived in, the **HUD on**, the **exited Zone gone from
the world**, and **continued usability** — that asking that Hub for
another Zone still reaches `main.gd`, because a transition arriving
somewhere inert is not an arrival.

**Verified against the defect:** removing the `_to_hub()` call from the
consumer fails four of the five checks.

### The Dictionary cast is closed and the exemption is gone

The brief preferred repair over containment and said to read producer and
consumer first. Doing so showed **the earlier attribution was wrong**,
and that is corrected in the findings log.

It had been recorded as `BridgeClient.active_zone().is_empty()` on the
refusal path. `active_zone()` **cannot** throw — it returns `{}` for a
non-Dictionary by construction. That was a guess from a backtrace line
number without reading the producer.

The demonstrated cast was in the **test harness**, at
`integration_driver.gd:932`: `.get("zone", {}) as Dictionary`. A `get`
default applies only when the key is ABSENT; a record in
`PENDING_GENERATION` carries a **null** there, and `null as Dictionary`
throws. The wait now checks the type before casting.

**The exemption is deleted, not scoped.** The Makefile guard is a plain
`grep -q "SCRIPT ERROR"` with no exception of any kind, and the
integration run log now contains **zero**. The crash-reintroduction
control is retained and still works: clean tree exits 0, `camera_ray`
guard removed exits 2.

---

## DEMONSTRATED DEFECT — repaired earlier in this brief, unchanged here

The step-up (ascent), and activity feedback in four places. See
`docs/BATCH_0_3_REPAIR_HANDOFF.md`. Nothing in this follow-through
touched them.

---

## UNRESOLVED MEASUREMENT

### Descending a stair is still open — ascent success is NOT stair comfort

**Explicitly not generalised.** A walking player now climbs a 0.8 m tread
and cover, barrels, low ceilings and shoveable bodies are all still
refused — that is the ascent, and it is tested.

**Descending is not repaired and not tested as repaired.**
`floor_snap_length` is set to the step, and with snap at 1.0,
`velocity.y` at 0 and `up_direction` at +Y — every precondition Godot
documents — a body walking off a 0.4 m tread at 7 m/s still leaves the
floor and free-falls it. The control **reports** the airborne count
rather than asserting one. Stairs are comfortable going up and are not
yet comfortable coming down.

### The exact traversal case is NOT recovered

The brief asked for the owner's diagnostic campaign at
`C:\Users\KayaCady\Documents\GitHub\archipepsi\.diagnostic-582e954`.
**It is not present in this environment** — that is a path on the owner's
Windows machine and this container holds a fresh clone. A copy has been
requested; the original is untouched.

Until it arrives:

* **The reproduction is labelled APPROXIMATE.** `played_zone.json`
  matches the owner's Zone on room ids, counts and 8 of 8 shell
  assignments, and **that does not establish identical placement** — the
  brief is right about this. It also has no CHECK 120, because AP
  location ids are allocated by campaign progression rather than by
  layout, so the reported Check cannot be located by id.
* **The required crossing is untested**, with the guaranteed kit or with
  the Whistle. Those are two separate tests and neither has been run.
  **Skyiah finishing with acquired mobility does not prove baseline
  reachability**, and nothing here claims otherwise.
* **The exit approach / seam is untested**, and is kept separate from the
  transition above, which IS covered.

What the save gives that a rebuild cannot: each zone record carries both
the `zone` proposal and the committed `manifest` (`rooms`, `anchors`,
`joins`, `plugs`, `stations`) — the actual placement.

### The discarded lattice

It establishes **a failed instrument** and nothing more. It is not
evidence that the Zone is safe, and not a general verdict against
geometric searches. No universal solver was built or is proposed.

---

## Evidence

One combined revision `58c9f74`, tree clean. Targets exercised:

- **Python** `make test` 1528 passed / 627 subtests; `make test-schemas`
  131; the v0.8 packet check across 11 documents.
- **Godot offline, all 19**: zone-audit, test, room, room-contract,
  content, activity, graphs, physics, movement, boot, hud, rules, lab,
  legible, stats, verbs, affordance, blink, playtest3a.
- **Godot live bridge, all 3**: integration, return-journey (0 assertion
  failures), reload (2 + 18 checks).
- **Decisiveness checked both ways** on the two new controls: the exit
  consumer (break `_to_hub()` → 4 failures) and the crash guard (remove
  the `camera_ray` guard → exit 2).

Old saves and retained failing fixtures preserved; no schema or fixture
edited by hand.

---

## What is still blocking

1. The owner's diagnostic campaign, for item 1. **Requested.**
2. Descending a tread.
3. The exit approach / seam, pending that save.
4. Everything on the findings log this brief did not touch.

## For a short owner replay

Worth trying: walk up a Check pedestal rather than jumping it; shoot a
target and listen; let a timed activity expire; read the objective line
while playing; and take the exit portal, which no longer crashes and now
leaves you in a Hub that can start the next Zone.
