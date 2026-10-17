# D-22 Stage 0 — The Crossing lifecycle contract (Secure / Untether)

**Dess, 2026-10-17. A design contract, text only.**

Its authority is D-22 (`833f6f74`) §3–5 and the D-22 slice (`f91371a5`).
It is read against what the slice built: `integration/unified-1`
`349ef77f`, which carries `review/d22-slice`.

**Owner decisions are marked ★ with my pick. None of them is decided
here.**

---

## 1. States (the bridge's Zone states; D-22 names in brackets)

| State | Meaning | Holds Checks? | Entered by | Built? |
|---|---|---|---|---|
| PENDING_GENERATION | Allocated, being drafted | yes | `request_next_zone{track}`, or a redraw | yes |
| GENERATED **[draft]** | Epsilon's draft is ready; no layout yet | yes | the pipeline accepted it | yes |
| ACTIVE **[committed, in play]** | The layout was committed at first entry; the player is inside | yes | ACCEPT (first entry) or RESUME | yes |
| DORMANT **[committed, left]** | The player left with transfers remaining | yes | exit, warp, Return to Station | yes |
| COMPLETE **[untethered]** | Every allocated Check is AP-confirmed | no | `zone_completion_sweep` only | yes |
| VISITING **[untethered, re-entered]** | Re-entering an untethered Crossing | no | enter on COMPLETE (bridge only) | bridge yes; **no UI** (★ D2) |
| ABANDONED | The player discarded it; its Checks go back to the pool | no | abandon console | yes |

**Rules:**
- **One Crossing holds Checks at a time** (`transitions.py:100-107`).
- **Redraw** is allowed only in GENERATED before the first entry, at
  most 2 times. It keeps the same `allocated_location_ids`.
- **After commit**, the layout is replayed and never replaced.

---

## 2. The two events

| | **Secure** | **Untether** |
|---|---|---|
| **Means** | The route to the destination is established ("destination secured", RIFT §3.4) | Every stranded transfer is released; the Crossing's foreign tie is resolved |
| **Trigger** | The player reaches the Crossing's destination anchor (the exit room), the first time for this Crossing | **Only** the existing completion sweep: all allocated Checks AP-confirmed (`transactions.py:194-212`) |
| **Can local state cause it?** | Yes. It's a local presentation fact and gates nothing in AP. | **Never** (slice rule 5). Abandoning never untethers. |
| **Progression effect** | None | `completed_zone_count` +1, which opens station areas (derived, never saved) |
| **Save** | **Proposed:** one additive `ZoneRecord.secured: bool`, default false, so the moment plays once per Crossing, not on every visit. Old saves read false. | Nothing new. COMPLETE already is the record. |
| **Player sees** | The destination anchor wakes, the exit reads "LEAVE — n transfers remain", and the Forge lists the Crossing as *Secured* | The anchor releases its tether (when seen within range, as built in the slice), Epsilon's line, the exit reads "RETURN", the Forge lists *Untethered*, and the next door's lamp turns green |
| **Order** | Usually first. If every Check is confirmed before the player reaches the exit, both fire on arrival: **Secure, then Untether.** | — |
| **Built?** | **No.** The bridge's exit already makes the Crossing DORMANT; the flag and the moment are new | **Yes** (slice A8) |

**Suggested audio and presentation event names** (Condi's
`events.json` style):
- `crossing.drafted`
- `crossing.committed`
- `crossing.secured`
- `crossing.untethered`: when the bridge confirms
- `crossing.untether_seen`: when the player witnesses the release

The audio placement map's pending Secure/Untether cues should key on
`crossing.secured` and `crossing.untether_seen`.

---

## 3. Invariants for Archipelago safety (unchanged from the slice)

1. Allocation is deterministic and drawn from the eligible pool. The
   chosen signal changes only which track is preferred.
2. A redraw never changes the Check ids.
3. Station areas hold no Checks. Station doors read
   `completed_zone_count` only.
4. Untether comes only from AP confirmation.
5. Abandoning returns Checks and never counts.
6. Required station routes use only the base kit.
7. The finale never needs a station area (D-22 §5.3).
8. **No Crossing record is ever deleted** (whatever ★ D2 decides about
   re-entry).

---

## 4. Owner decisions (★ = my pick)

**D2: What does untethering do to the place?**
- ★ **It keeps the Crossing as a revisitable place.** Re-entering it as
  VISITING holds no Checks, and a "past Crossings" list sits on the
  Forge (Stage 2). This is the canon (RIFT R-04: "completing transfers
  does not delete a Crossing"), and the bridge already supports it.
- Alternative: the Crossing closes and can't be re-entered. The record is
  still kept for AP bookkeeping, and the release saves one Forge list.
  It reverses an accepted direction.

**D3: Does a redraw cost Static?**
- ★ **No cost in the release.** At most 2 redraws per Crossing, as built.
  Static stays counted, not spent, until the Forge economy (B4) is
  decided.
- Alternative: a redraw costs N Static (your 2026-09 wish: "have epsilon
  use the static to re create a zone"). That is the first Static sink, a
  new economy rule. N would need choosing against about 288 Static per
  default campaign.

**D4: Which Epsilon ships?**
- ★ **The deterministic built-in Epsilon by default (offline, free),
  with the live provider optional** for players who supply their own key.
  The card says "drafted offline" truthfully either way.
- Alternative: live by default. That brings API cost, network dependence
  and key handling into the release.

---

## 5. Small calls (Condi's; my pick first)
1. **`ZoneRecord.secured`, saved:** yes (§2). It's one additive bool, and
   nothing reads it for progression.
2. **When the Crossing untethers while the player is far from the exit:**
   keep the slice's behaviour. The release moment waits until the player
   reaches the exit room; Epsilon's line plays on confirmation.
3. **Both Forges can draft:** keep. D-22 §5 rule 2 says every unlocked
   Forge draws from the shared pool.

---

## 6. Not in this contract
- Resume-position persistence: Stage 2, the return-anchor fix.
- Several Crossings held at once.
- A Static economy.
- Station Checks.
- The finale's placement at the Forge: Stage 2, under the existing rule.

---

## 7. Owner decisions recorded, 2026-10-17

These are Skyiah's answers in the project chat (2026-10-17 12:37:16Z),
**relayed by Condi** (session `01EYbg5s…`). They were not given directly
in Dess's session.

| # | Question | Answer (verbatim) | Recorded as |
|---|---|---|---|
| D2 | Can an untethered Crossing be revisited? | "Yes" | **Decided.** Untethering keeps the place, and it stays revisitable (VISITING, holding no Checks). The "past Crossings" list on the Forge stays Stage 2. |
| D3 | Do redraws cost Static? | "No" | **Decided.** No Static cost; at most 2 redraws per Crossing, as built. |
| D4 | Which Epsilon ships? | "Built in" | **Decided:** the built-in deterministic Epsilon ships. **A live AI option is not decided.** She did not confirm it, so it is neither adopted nor ruled out. |
| — | Block consumables in the Freight Bay? | "Yes, i was kinda rhinking consumables would only work in a crossing, ill actually leave that up to you…" | **Delegated to Dess. Decided:** consumables work **only inside Crossings**. The station, including the Freight Bay annex, blocks them. |

**Why consumables work only in Crossings:**
- It follows her own instinct. The station is the safe, hand-built
  place; Crossings are where the run's resources matter.
- The Freight Bay's per-weapon fight numbers stay comparable, with no
  heals or buffs mixed in (D-20 §13 telemetry).
- It avoids a station-side consumable economy, which nothing has
  designed.
- **When a consumable is blocked, say so plainly** (for example "WORKS
  IN CROSSINGS"), never fail silently.

**Holds unchanged:** the Amalgam's gated parts stay closed for now:
- H-AP-GATE, capability events in the AP logic (DESS-28);
- the Gear G1 gate;
- the Forge/Static economy (B4).
