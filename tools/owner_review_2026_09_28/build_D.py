#!/usr/bin/env python3
"""Owner review 2026-09-28 -- Group D, status / enemy-job / combat feedback.

    python3 tools/owner_review_2026_09_28/build_D.py

Only behaviour that exists at the pin is reviewed as live; future-only
pieces are listed apart. Every image here is a posed art-lane render: no
Production driver spawns enemies, telegraphs or statuses, so there is no
runtime frame of any of it.
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from sheets import Panel, Sheet, font  # noqa: E402

REV = "docs/art/review"
OUT = f"{REV}/owner_review_2026-09-28/sheets"
EV = f"{REV}/owner_review_2026-09-28/evidence/D"
FX = f"{REV}/projectiles_2026-09-22"
JB = f"{REV}/jobs_2026-09-22"
ST = f"{REV}/status_2026-09-11"
FOOT = ("Art source 32df699. Production read at c12a72fbc625 (pinned): "
        "enemy.gd, constants.gd, status_effects.gd, hud.gd. Every image is a "
        "posed art-lane render; none is a capture of the game.")


def scale_plan(out: str) -> str:
    """The three ground marks at their art size against the runtime reach,
    drawn to one scale from the pinned constants."""
    ppm = 20                      # pixels per metre
    W, H = 1400, 700
    im = Image.new("RGB", (W, H), (22, 24, 28))
    d = ImageDraw.Draw(im)
    f, fb, fs = font(22), font(24, True), font(18)
    art, run = (120, 200, 255), (255, 170, 60)
    y0 = 90
    d.text((24, 18), "To one scale (1 m = 20 px). BLUE = the art as authored. "
           "ORANGE DASH = the runtime reach at c12a72f.", fill=(230, 230, 230),
           font=f)

    def dashed_rect(x0, y0_, x1, y1_):
        for x in range(x0, x1, 12):
            d.line([x, y0_, min(x + 6, x1), y0_], fill=run, width=3)
            d.line([x, y1_, min(x + 6, x1), y1_], fill=run, width=3)
        for y in range(y0_, y1_, 12):
            d.line([x0, y, x0, min(y + 6, y1_)], fill=run, width=3)
            d.line([x1, y, x1, min(y + 6, y1_)], fill=run, width=3)

    def dashed_circle(cx, cy, r):
        import math
        n = max(24, int(2 * math.pi * r / 10))
        for i in range(0, n, 2):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            d.line([cx + r * math.cos(a0), cy + r * math.sin(a0),
                    cx + r * math.cos(a1), cy + r * math.sin(a1)], fill=run, width=3)

    # 1. the charger: a 0.9 x 6 m lane against a 13 m/s x 1.1 s = 14.3 m rush
    x, top = 70, y0 + 40
    d.text((24, y0), "CHARGER", fill=(255, 255, 255), font=fb)
    lane_w, lane_l, rush = 0.9, 6.0, 14.3
    d.rectangle([x, top, x + lane_w * ppm, top + lane_l * ppm], fill=art)
    dashed_rect(x - 2, top - 2, int(x + lane_w * ppm + 2), int(top + rush * ppm))
    d.text((x + 30, top + 40), "art lane 0.9 x 6 m", fill=art, font=fs)
    d.text((x + 30, top + 250), "rush 14.3 m", fill=run, font=fs)
    d.text((x + 30, top + 272), "(13 m/s x 1.1 s)", fill=run, font=fs)

    # 2. artillery: a 1.3 m ring against a 3.2 m blast
    cx, cy = 400, y0 + 190
    d.text((300, y0), "ARTILLERY", fill=(255, 255, 255), font=fb)
    d.ellipse([cx - 1.3 * ppm, cy - 1.3 * ppm, cx + 1.3 * ppm, cy + 1.3 * ppm],
              outline=art, width=5)
    dashed_circle(cx, cy, 3.2 * ppm)
    d.text((cx - 90, cy + 3.2 * ppm + 12), "ring r 1.3 m | blast r 3.2 m",
           fill=(230, 230, 230), font=fs)

    # 3. beacon: a 1.7 m ring against a 12 m radius
    cx, cy = 900, y0 + 300
    d.text((620, y0), "BEACON", fill=(255, 255, 255), font=fb)
    d.ellipse([cx - 1.7 * ppm, cy - 1.7 * ppm, cx + 1.7 * ppm, cy + 1.7 * ppm],
              outline=art, width=5)
    dashed_circle(cx, cy, 12.0 * ppm)
    d.text((cx - 110, cy + 44), "ring r 1.7 m", fill=art, font=fs)
    d.text((cx + 12.0 * ppm - 190, cy - 12.0 * ppm + 20), "radius 12 m",
           fill=run, font=fs)

    # a person for scale
    px, py = 1270, y0 + 500
    d.rectangle([px, py - 1.8 * ppm, px + 0.5 * ppm, py], fill=(200, 200, 200))
    d.text((px - 40, py + 8), "1.8 m person", fill=(200, 200, 200), font=fs)
    im.save(out)
    return out


def d1() -> None:
    s = Sheet("D1 · The telegraph ring",
              "Six enemy roles wind up before they attack, and Production "
              "already emits telegraph_started, telegraph_progress() and "
              "telegraph_finished(kind, completed). The ring is one flat open "
              "ring, 12 ticks, with a CLOSED ending and a BROKEN one.")
    s.statuses(
        visual=("pending", "051 PENDING (ART_REVIEW.md:4459)."),
        compat=("partial", "Its states map onto signals that exist (enemy.gd "
                "28-33, 233-241, 1622-1651)."),
        binding=("none", "None. No script outside enemy.gd listens."),
        play=("partial", "The BEHAVIOUR is in normal play (all ten roles can "
              "spawn). Today the telegraph is the body's swell, the eye's flare "
              "and a sound."))
    s.row([Panel(f"{FX}/fx_telegraph_ring.png",
                 "The ring, with every state lit at once: a reference, not a "
                 "runtime state.", tag="POSED", crop="auto"),
           Panel(f"{FX}/backdrop_busy.png",
                 "From 1.7 m eye height the flat ring reads edge-on, as a line "
                 "(right of frame).", tag="POSED",
                 note="the 22 Sept legibility scene; textures predate the 24 Sept "
                      "re-bake")])
    s.text("What CLOSED and BROKEN mean at the pin",
           "CLOSED = the windup ran out and the attack was released, NOT that it "
           "hit (enemy.gd:496-506). BROKEN fires only on death or despawn "
           "(:1660-1672). Nothing interrupts a windup today. (Production's own "
           "comment says completed means 'actually landed'; its code does not.)")
    s.decision(
        ask="Approve the open-ring grammar (ticks follow telegraph_progress; "
            "CLOSED = released; BROKEN = died or despawned) for the six roles that "
            "telegraph? Is a FLAT ring acceptable?",
        recommend="Approve the grammar. Hold the flat orientation until someone "
                  "shoots it in the engine from 1.6 m eye height: this frame shows "
                  "it edge-on.",
        risk="A ring on the floor may be invisible exactly where the player "
             "looks. It must coexist with the swell and with the eye, which "
             "Production keeps (ruling 26 Sept).",
        engineering="A listener that places the ring at TelegraphOrigin, scales "
                    "it by the attack, and follows telegraph_progress().")
    s.footer(FOOT)
    print(s.save(f"{OUT}/D1_telegraph_ring.jpg"))


def d2() -> None:
    os.makedirs(EV, exist_ok=True)
    plan = scale_plan(f"{EV}/D2_marks_to_scale_plan.png")
    s = Sheet("D2 · Ground marks and role reads, at the runtime's size",
              "Charger lane, warned ground, beacon range, bulwark face and diver "
              "trail. The behaviours exist; the art was drawn smaller than the "
              "runtime reach, and two pieces point the wrong way.")
    s.statuses(
        visual=("pending", "051 PENDING; the owner's decision on projectile "
                "legibility is still waiting (ART_FRONTIER.md:552)."),
        compat=("no", "Sizes do not match the pinned constants (plan below). "
                "fx_bulwark_face sits on the bulwark's BACK."),
        binding=("none", "None; the rush direction and the aim point are "
                 "private fields."),
        play=("partial", "The behaviours are in normal play. Today artillery "
              "shows a filled 3.2 m disc during the shell's flight only; the "
              "others draw nothing."))
    s.row([Panel(plan, "", tag="SCALE")])
    s.row([Panel(f"{FX}/fx_charger_lane.png", "Charger lane, 0.9 x 6 m.",
                 tag="POSED", crop="auto"),
           Panel(f"{FX}/fx_warned_ground.png", "Warned ground, r 1.3 m.",
                 tag="POSED", crop="auto"),
           Panel(f"{FX}/fx_beacon_range.png", "Beacon range, r 1.7 m, 'sized by "
                 "the runtime'.", tag="POSED", crop="auto")])
    s.row([Panel(f"{FX}/fx_bulwark_face.png", "Bulwark face: the plate is at +Z; "
                 "the bulwark's front is -Z (enemy.gd:1262).", tag="POSED",
                 crop="auto"),
           Panel(f"{FX}/fx_diver_trail.png", "Diver trail: points at the ground; "
                 "the dive aims at an airborne player.", tag="POSED",
                 crop="auto")])
    s.decision(
        ask="Must a danger mark cover the full runtime reach (a 14.3 m rush, a "
            "3.2 m blast)? Should the 12 m beacon radius show all the time? Is "
            "fx_bulwark_face still wanted now that the accepted Tier-2 mantlet "
            "carries the head-on read?",
        recommend="Full reach, built at runtime size (uniform 2.5x scaling "
                  "drops the texel density to about 13/m). Beacon range only with "
                  "a visibility rule: a 24 m disc is bigger than many rooms. Keep "
                  "bulwark_face only for Production's code-built bodies, after "
                  "the facing fix. Hold the diver trail.",
        risk="An undersized mark teaches a false safe zone.",
        engineering="Make the rush direction and the artillery aim point public, "
                    "expose the dive state and vector, and decide whether the art "
                    "replaces the shell's filled disc.")
    s.footer(FOOT + " Smallest repairs: re-export fx_bulwark_face flipped (the "
             "enemy-role builder was fixed in fa16cfea; this builder was not); "
             "rebuild lane, ring and beacon at runtime size.")
    print(s.save(f"{OUT}/D2_ground_marks_to_scale.jpg"))


def d3() -> None:
    s = Sheet("D3 · Impacts: body, shield, wall (and two future pieces)",
              "Three impacts describe something that happens today; two do not.")
    s.statuses(
        visual=("pending", "051 PENDING."),
        compat=("partial", "The events exist inside take_damage, but carry no "
                "impact point and expose no signal."),
        binding=("none", "None."),
        play=("partial", "Today a hit is a 0.88 scale punch for 0.1 s, a damage "
              "tint and a HUD direction arrow; an enemy shot that hits a wall "
              "just vanishes."))
    s.row([Panel(f"{FX}/fx_hit_body.png", "Body: damage goes in.", tag="POSED",
                 crop="auto"),
           Panel(f"{FX}/fx_hit_shield.png", "Shield: 'refused', although 15% "
                 "still lands.", tag="POSED", crop="auto"),
           Panel(f"{FX}/fx_hit_wall.png", "Wall: stopped by a surface.",
                 tag="POSED", crop="auto")])
    s.row([Panel(f"{FX}/fx_hit_miss.png", "FUTURE ONLY: a miss. Nothing reports "
                 "one; an unspent shot just expires.", tag="POSED", crop="auto"),
           Panel(f"{FX}/fx_hit_interrupt.png", "FUTURE ONLY: an interrupt. "
                 "Nothing interrupts a windup today.", tag="POSED", crop="auto")])
    s.decision(
        ask="Approve a three-way impact set: damaging, mostly refused, stopped? "
            "And is 'REFUSED' honest for a shield hit that still does 15%?",
        recommend="Approve body and wall. Approve the shield piece only as 'mostly "
                  "refused'. Keep miss and interrupt parked (or delete miss; its "
                  "own handoff says that costs nothing).",
        risk="An impact that lies about the damage teaches the wrong lesson.",
        engineering="A hit event carrying the impact point and the absorbed "
                    "share, and a hook when a projectile stops; layered over the "
                    "flinch, the tint and the HUD confirmation.")
    s.footer(FOOT + " Note: these frames predate the 24 Sept texture re-bake.")
    print(s.save(f"{OUT}/D3_impacts.jpg"))


def d4() -> None:
    s = Sheet("D4 · Status markers on targets",
              "The 052 grammar and the 043 frames, reviewed only for the statuses "
              "an enemy or an object can carry at the pin. Production has NO "
              "status display anywhere.")
    s.statuses(
        visual=("pending", "052 PENDING (ART_REVIEW.md:4369). Four 043 rulings "
                "stand: neutral families, neutral tick, the double ring, 32/16 px "
                "'subject to gameplay readability'."),
        compat=("partial", "The markers map onto StatusEffects' enemy side. "
                "Expiry has no signal, and the total duration is not stored."),
        binding=("none", "None: no display path."),
        play=("partial", "In normal play enemies can be marked, empowered, "
              "slowed, shocked, poisoned, burning, vulnerable and stunned. "
              "Nothing shows it except a few text labels."))
    s.row([Panel(f"{ST}/SHEET_markers.png", "The marker set, on light, dark and "
                 "mid-grey grounds.", tag="RENDER", crop=(0, 0, 1370, 900)),
           Panel(f"{ST}/room/STATUS_runtime_busy.png", "Markers over capsule "
                 "stand-ins on a busy background: posed, NOT the game.",
                 tag="POSED", note="its caption '13 implemented' is stale: the pin "
                 "has 15")])
    s.row([Panel(f"{ST}/SHEET_native_size.png", "At native size: 32 px markers "
                 "and 16 px glyphs.", tag="RENDER")])
    s.text("Live set vs future set",
           "LIVE on enemies: slowed, frozen, shocked, poisoned, marked, stunned, "
           "vulnerable, empowered, burning, rooted, anchored; on objects: "
           "lightened. FUTURE-ONLY: haste, low_profile and regenerating "
           "(player-only, and no HUD tier), the player tick, the nine staged "
           "statuses, and the compounds.")
    s.decision(
        ask="Rule now on Decision 7 (empowered's family) and on frozen's family. "
            "Decision 8: who owns the HUD tier (recommend Production)? Defer "
            "Decisions 5 and 6.",
        recommend="Review the live set as the candidate grammar, subject to a "
                  "readability test in play (ruling 4). Keep the future set apart.",
        risk="On an enemy, 'empowered' helps the wearer but threatens the player, "
             "so a 'good for the wearer' channel (Decision 5) would read backwards.",
        engineering="A way to pin a marker to a target, polling because expiry "
                    "has no signal, and a stored total duration for the depletion "
                    "track.")
    s.footer(FOOT + " Decisions quoted from status_2026-09-11/DECISIONS_FOR_OWNER.md.")
    print(s.save(f"{OUT}/D4_status_markers.jpg"))


def d5() -> None:
    s = Sheet("D5 · Enemy-job posts (050)",
              "Five props mark where a real job happens; three wait for a job "
              "that does not exist. The idle and alert frames are POSED: ground "
              "roles have no visible alert state at the pin.")
    s.statuses(
        visual=("pending", "050 PENDING (ART_REVIEW.md:4511)."),
        compat=("partial", "Matches the jobs' published numbers (post tolerance "
                "1.5 m; sweep rates)."),
        binding=("none", "None; nothing places a prop at a post."),
        play=("partial", "The JOBS are in normal play (watch, tend, drift, "
              "patrol). Nothing marks them."))
    s.row([Panel(f"{JB}/job_watch_post.png", "Watch post: a column and lamp "
                 "outside the turning circle.", tag="POSED", crop="auto"),
           Panel(f"{JB}/job_post_plate.png", "Post plate: 3 m, the post "
                 "tolerance.", tag="POSED", crop="auto"),
           Panel(f"{JB}/job_drift_perch.png", "Drift perch: where a flyer "
                 "orbits.", tag="POSED", crop="auto")])
    s.row([Panel(f"{JB}/ranged_idle.png", "Ranged at its post, idle.",
                 tag="POSED", crop="auto"),
           Panel(f"{JB}/ranged_alert.png", "'Alert': an orange block staged at "
                 "the warn anchor, which the eye ruling reserves.", tag="POSED",
                 crop="auto")])
    s.decision(
        ask="Approve the five role-fitted props (watch post, tend pedestal, drift "
            "perch, post plate, beat cue) as optional dressing that makes no "
            "claim about alertness?",
        recommend="Approve them as candidates. Judge no alert presentation from "
                  "these frames. Park the three service props (charge socket, "
                  "inspect panel, tool rack): no job visits them.",
        risk="The drifter's idle and alert frames are pixel-identical; the beat "
             "cue describes a 4.5 m circle the pin no longer uses.",
        engineering="A rule for placing props at posts, clear of doorways and of "
                    "the floored patrol beats.")
    s.footer(FOOT)
    print(s.save(f"{OUT}/D5_job_posts.jpg"))


if __name__ == "__main__":
    d1()
    d2()
    d3()
    d4()
    d5()
