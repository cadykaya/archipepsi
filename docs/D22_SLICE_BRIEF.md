# D-22 Slice — the first playable Crossing loop (build brief for Prod)

**Dess → Prod, for Skyiah. 2026-10-14. Build-ready, review only.**

The authority is **D-22** (`docs/D22_CROSSING_LOOP_PLAN.md`, `833f6f74`).
This brief makes D-22 Stage 1 buildable. It **does not redesign the
loop, add features or decide open owner questions.**

**Code baseline:** the campaign line `claude/archipepsi-0-4-blindside`
`a266d5da`. Every **[exists]** below was read there.

**Not merged.** The slice lives on its own review branch, with an
isolated save and offline mock Archipelago.

**The sequence:**

> **station area 1 → Forge (pick a signal, Epsilon's draft, accept or
> redraw) → a generated Crossing → leave and resume → untether → station
> area 2 opens → construct a second Crossing → STOP.**

---

## 0. Owner decisions: where they stand

| # | D-22 decision | Status for this slice |
|---|---|---|
| D1 | The Forge is the Crossing-construction bench | **Treated as confirmed** by your direction: "Epsilon participates in constructing them through the Forge". Please correct me if not. |
| D5 | Station progress counts untethered Crossings | **Treated as confirmed**: "Completing and safely untethering a Crossing advances station progression". |
| D2 | Untethering keeps the Crossing as a place | **Open. The slice doesn't depend on it.** It never deletes a Crossing record (today's behaviour) and offers no re-entry into untethered Crossings. |
| D3 | Static cost for a redraw | **Open.** The slice's redraw costs nothing, **as a placeholder only**. It doesn't decide the release; a cost would be one check added at the redraw intent. |
| D4 | Which Epsilon provider ships | **Open.** The slice uses today's default deterministic provider (`--epsilon=fallback`, `__main__.py:53-56`), offline. It doesn't decide the release. |

---

## 1. Run configuration [exists]

- **Bridge flags:**
  - `--ap=mock`;
  - `--mock-scale prototype`: 30 locations, **3 Checks per Crossing**,
    minimum budget (`schemas/constants.py:272-273`);
  - `--save-dir <slice folder>`, a fresh campaign that never touches the
    player's save.
- **Mock world:** 5 foreign games (`mock_ap.py:29-36`), so there are
  several signals to choose between.
- **Enough Checks without keys:** the Start tier holds about 10 of the 29
  ordinary Checks, so two Crossings need no Signal Keys.
- **No old-save migration.** The only new save field (§4) defaults
  safely.

---

## 2. The sequence: player actions and state

Columns:
- **State** is the bridge's Zone state.
- **Mode** is the Hub mode (`protocol.py:1569-1636`).
- **E** = exists, **B** = Prod builds.

### Step 1: station area 1
- **Player:** starts in today's Hub, reshaped as a graybox room. The
  shop, Echo terminal and abandon console stay as they are **(E)**.
- **The portal becomes the Forge console (B):** same anchor, same
  activation path (`hub.gd:230-235, _on_portal_activated`), new screen.

### Step 2: the Forge, picking a signal
- **Mode `ZONE_AVAILABLE` (E).** The console lists **the signals (tracks)
  that still have eligible Checks**, with the current track cursor
  pre-selected **(B: screen; data from the existing scouts)**.
- **Player** picks one. The console sends
  `request_next_zone{finale:false, track:"<key>"}`.
  - **(B)** One optional field on `RequestNextZone`
    (`protocol.py:2161-2176`).
  - **(B)** `_select_zone_locations` (`campaign.py:491-538`) uses the
    chosen track in place of the cursor's first eligible track.
  - **Everything else in allocation is unchanged:** the deterministic
    shuffle, topping up from other tracks, and the cursor, which still
    advances only on completion.
- **State:** allocation, then `T.start_generation`, then
  PENDING_GENERATION, then the Epsilon pipeline, then **GENERATED**
  (mode `ZONE_READY`) **(E)**.

### Step 3: the Forge, Epsilon's draft card
- **On `ZONE_READY` the console shows the draft card (B).** It is read
  from the offered Zone the client already receives (`zone_ready_received`,
  `bridge_client.gd:11, 179-189`). Card content rules:
  - **Epsilon's lines:** the Zone's **name** and **designer note**, shown
    as his words. If the fallback provider wrote it, say so plainly
    ("drafted offline").
  - **Facts:**
    - signal or game;
    - theme pack;
    - number of rooms;
    - **number of Checks**;
    - notable enemies and activities. These are counts and names from
      the chambers; nothing is hidden, and nothing is invented that the
      Zone doesn't contain.
  - **Actions:** **ACCEPT**, and **REDRAW (n left)**.
- **ACCEPT** = enter the Zone **(E)**: the existing `enter_zone_requested`
  path. **The layout is built and committed on that first entry (E):**
  "a committed layout is replayed, never replaced", `transitions.py:365`.
  From this point the Crossing is fixed.
- **REDRAW (B):** a new intent `redraw_zone{zone_id}`, accepted only in
  GENERATED **before the first entry**. A new transition **GENERATED →
  PENDING_GENERATION against the same `allocated_location_ids`**. It is
  modelled on the existing `refuse_layout` recovery, "against the ids it
  already holds … nothing is re-allocated" (`transitions.py:388-425`).
  Its rules:
  - `ZoneRecord.redraw_count` +1; **at most 2** (D-22 §3.1).
  - The redraw count reaches the providers as variation, so the draft
    really changes. For the fallback, that means adding it to both seed
    strings, `archipepsi/fallback/zone/{n}/{budget}` and
    `…/{salt}` (`epsilon/fallback.py:103, 118-120`).
  - Composition, proof and validation all run again **(E)**.
  - At the cap, the card offers only ACCEPT. ABANDON stays at its
    existing console.
- **Walking away:** the Zone stays GENERATED and the **same draft** is
  shown next time **(E state; B: the card shows it again)**. Leaving is
  never a free redraw.

### Step 4: in the Crossing
- **Player:** explores and releases Checks **(E)**.
- **Secure = leave (B: a Godot fix).** Today's exit portal is "Locked
  until every assigned Check confirms" (`exit_portal.gd:3-4`; the gate
  at `zone_controller.gd:2203-2208`). The bridge already allows leaving
  early: "The exit does not require every Check … the Zone goes dormant"
  (`campaign.py:1456-1469`).
  - **Make the portal always usable** and send the existing exit intent.
  - Its label tells the truth: **"LEAVE — n transfers remain"**, or
    **"RETURN"** once untethered.
- **Other ways out (E):** warp station "RETURN TO HUB (this Zone stays
  where it is)", or the pause menu.
- **State:** ACTIVE → **DORMANT**, still holding its Checks (`rest_zone`,
  `transitions.py:268-301`) **(E)**.

### Step 5: resume
- **Mode `ZONE_DORMANT`.** The Forge shows **"RESUME <name> — n
  remaining"**. Using it enters the same Crossing **(E: `resume_zone_id`,
  `ZONE_ENTERABLE_MODES`; B: the Forge's screen)**.
- **Re-entry replays the committed manifest (E).** Return-anchor drift
  ([D-22 §4], measured at 5.89 m) is a **Stage 2** fix. The slice
  **records** the resume position (§5, A7) rather than fixing it.

### Step 6: untether
- **Trigger (E):** the last allocated Check is AP-confirmed.
  `zone_completion_sweep` → `T.complete_zone` → COMPLETE, with
  `completed_zone_count` +1, wherever the player is
  (`transactions.py:194-212`). **Nothing local can cause it.**
- **The moment (B: presentation only):**
  - **In the Crossing:** the destination anchor beside the exit portal
    visibly releases its tether, with one line from Epsilon. The portal
    reads "RETURN".
  - **In the station:** the Forge lists the Crossing as **Untethered**,
    and **area 2's door lamp turns from red to green.**
- If it completes while the player is at the station, the station half
  plays on arrival.

### Step 7: station area 2 opens
- **Door rule (B):** open when **`completed_zone_count ≥ 1`**. It's read
  from the snapshot the Hub already gets (`hub.gd:117`). It is
  **derived, never saved.**
- **Area 2 (B, graybox):** one short route with **one base-kit machinery
  step** built from parts **already on the campaign line**:
  - a lever and `ServiceShutter`; or
  - the `PoweredLink` crate-on-plate door.

  Porting G1's Impact Relay plate is allowed only if trivial; it's not
  required. Then a **second Forge console**.
- **No Checks, no Echo requirement, no enemies.**

### Step 8: the second Crossing, then STOP
- **Player:** uses area 2's Forge. Steps 2–3 again (pick a signal,
  draft, accept or redraw) and enters Crossing 2.
- **STOP** once Crossing 2's first entry has committed its layout.
- **Not in the slice:** a second untether, area 3, the finale,
  past-Crossings revisits, contact level.

---

## 3. What Prod builds (the whole list)

1. **The Forge console screen,** reused at both stations: signal list,
   draft card, accept, redraw, resume, untethered list.
2. `RequestNextZone.track`, optional, plus the chosen-track branch in
   `_select_zone_locations`.
3. `redraw_zone`: the intent, the `T.redraw_zone` transition,
   `ZoneRecord.redraw_count` (default 0), and the variation reaching the
   providers.
4. **The exit fix:** the portal is always usable, with a truthful label.
5. **The untether moment:** in the Crossing (anchor release and a line)
   and at the station (Forge list, door lamp).
6. **Station area 2:** graybox route, one machinery step, a Forge, and
   the count-gated door.
7. **The slice's launch configuration** and its scripted check (§5).

**Not to build:** contact level, the past-Crossings list, Static,
untethered re-entry UI, the finale at the Forge, area 3, a real AP
connection, art, music, story beyond Epsilon's card lines.

---

## 4. Save behaviour

| What | Saved? | Where |
|---|---|---|
| Zone record, its allocation, state, manifest and `ZoneProgress` | Yes **(E)** | `CampaignSave.zones` |
| Chosen track | Yes **(E)**, as the record's existing `target_game` | `ZoneRecord.target_game` |
| `redraw_count` | **Yes (B)**, default 0 | `ZoneRecord` |
| Station area unlocked | **No: derived** from `completed_zone_count` **(E)** | — |
| Mid-Crossing quit, then reload | Resumes DORMANT/ACTIVE as today **(E)** | — |
| Quit with a draft open (GENERATED) | The same draft is offered again **(E)** | — |
| AP truth (checked, received) | **Never saved** **(E)**: "Never persists a second copy of AP truth" | `protocol.py:1154` |

---

## 5. Archipelago safety rules for this slice

1. **Allocation is unchanged** apart from the track preference. The
   console lists **only tracks with eligible Checks**. A request naming
   an empty or unknown track is **refused** by the bridge.
2. **A redraw never changes the Check ids.** It re-proves the same
   allocation. It is allowed only in GENERATED before the first entry,
   at most 2 times.
3. **Station areas hold no Checks.** The station door reads
   `completed_zone_count` only.
4. **One Crossing holds Checks at a time.** The existing invariant
   (`transitions.py:100-107`) is unchanged.
5. **Untethering comes only from AP confirmation** (the existing sweep),
   never from local state. **Abandoning never untethers** and never
   counts.
6. **Required station routes use only the base kit.** Area 2's machinery
   needs no Echo.
7. **No Crossing record is deleted** (D2 stays open).
8. **Offline:** mock AP only, 0 real connections, the player's own saves
   untouched.

---

## 6. Acceptance

### A. Scripted check (truth, not fun), by real input where the game allows
1. **The Forge lists signals.** Only tracks with eligible Checks are
   shown. Picking track X allocates **3 Checks that X has eligible**, or
   tops up exactly as today when X has fewer.
2. **Draft card.** It shows the offered Zone's own name, note, rooms,
   Checks and pack, and **matches the Zone's data**.
3. **Redraw:**
   - the same `allocated_location_ids` before and after;
   - a different draft (name or chamber list differs);
   - the proof re-ran;
   - a third redraw is refused;
   - a redraw after the first entry is refused.
4. **Accept** → the first entry commits the layout. Re-entering replays
   the same manifest.
5. **Leaving early:** the exit portal is usable with Checks remaining.
   The state goes to DORMANT and its Checks stay held. The Forge shows
   RESUME, which re-enters the same Crossing.
6. **Quit with a draft open, then relaunch:** the same draft. Quit
   mid-Crossing, then relaunch: it resumes.
7. **Resume position:** record the distance between the player's exit
   point and the resume spawn. It is reported, not a pass/fail (a
   Stage 2 fix).
8. **Untether:**
   - releasing the last Check → COMPLETE and the count goes to 1;
   - the anchor-release moment plays;
   - the portal reads RETURN;
   - the Forge lists it as Untethered;
   - the area 2 lamp is green.
9. **The door:**
   - shut while the count is 0, including after an **abandon** (abandon
     and rebuild, and the door stays shut);
   - opens at 1;
   - stays open after a relaunch.
10. **Area 2:**
    - the machinery step is solvable with the base kit;
    - its Forge builds Crossing 2 from the shared pool;
    - **no Check was allocated to a station.**
11. **Isolation:** 0 real AP connections; the player's normal save folder
    byte-identical; the campaign's existing suites still pass.

### B. Skyiah's playtest (the real acceptance)
1. Did building the Crossing feel like making something **with Epsilon**?
2. Did picking a signal, or a redraw, feel like a real choice?
3. Was leaving and coming back clear?
4. Did untethering feel like an achievement?
5. Did area 2 feel earned?

---

## 7. Cut order (cut from the top; never cut the last block)
1. Area 2's machinery step (keep a plain route and the door).
2. Epsilon's line at the untether (keep the anchor release and the lamp).
3. Redraw (the card offers ACCEPT only).
4. Signal choice (fall back to today's round-robin, and show the chosen
   signal on the card).

**Never cut:**
- the Forge console with Epsilon's draft card;
- the exit fix;
- untether → door;
- resume;
- save behaviour;
- every rule in §5.

**If redraw *and* signal choice are both cut, the Forge stops being
meaningful.** Report that to Skyiah instead of delivering it as the
slice.

---

## 8. Stopping point and delivery

**STOP** when Crossing 2's first entry commits its layout and §6.A passes.

**Deliver:**
- the review branch and its build;
- the slice launcher;
- a short clip of the full sequence;
- the §6.A results, including the A7 measurement;
- known issues.

**Then stop.** No Stage 2, no merge, no watchers.
