#!/usr/bin/env python3
"""Does the meter agree with the standard it claims to implement?

    python3 tools/vera/test_audio_measure.py

Every signal is synthesised here, written to a temporary WAV and read
back through the same path a real file takes. The anchors are the
standard's, not this file's:

  * BS.1770's published 48 kHz K-weighting coefficients, against the
    ones `k_weighting` derives from its analogue prototypes;
  * a 997 Hz sine at 0 dBFS in one channel reads -3.01 LUFS -- the
    calibration point the -0.691 constant in the formula exists for.
"""
from __future__ import annotations

import math
import os
import pathlib
import struct
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import audio_measure as am  # noqa: E402

failures = 0


def check(ok: bool, what: str) -> None:
    global failures
    print("%s  %s" % ("ok  " if ok else "FAIL", what))
    if not ok:
        failures += 1


def write(path: str, channels: list[list[float]], rate: int,
          kind: str = "float32") -> str:
    n = len(channels[0])
    nch = len(channels)
    inter = [channels[c][i] for i in range(n) for c in range(nch)]
    if kind == "float32":
        tag, bits, body = 3, 32, struct.pack("<%df" % len(inter), *inter)
    elif kind == "pcm16":
        tag, bits = 1, 16
        body = struct.pack("<%dh" % len(inter), *[
            max(-32768, min(32767, int(round(v * 32767)))) for v in inter])
    elif kind == "pcm24":
        tag, bits = 1, 24
        out = bytearray()
        for v in inter:
            q = max(-8388608, min(8388607, int(round(v * 8388607))))
            out += (q & 0xFFFFFF).to_bytes(3, "little")
        body = bytes(out)
    else:
        raise ValueError(kind)
    extensible = kind.endswith("x")
    block = nch * bits // 8
    fmt = struct.pack("<HHIIHH", tag, nch, rate, rate * block, block, bits)
    chunk = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    data = b"data" + struct.pack("<I", len(body)) + body
    with open(path, "wb") as h:
        h.write(b"RIFF" + struct.pack("<I", 4 + len(chunk) + len(data))
                + b"WAVE" + chunk + data)
    return path


def write_extensible(path: str, ch: list[float], rate: int) -> str:
    """16-bit PCM wrapped in WAVE_FORMAT_EXTENSIBLE (as many tools save)."""
    body = struct.pack("<%dh" % len(ch),
                       *[int(round(v * 32767)) for v in ch])
    guid_pcm = struct.pack("<H", 1) + b"\x00\x00\x00\x00\x10\x00\x80\x00" \
        b"\x00\xaa\x00\x38\x9b\x71"
    fmt = struct.pack("<HHIIHHHHI", 0xFFFE, 1, rate, rate * 2, 2, 16,
                      22, 16, 4) + guid_pcm
    chunk = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    data = b"data" + struct.pack("<I", len(body)) + body
    with open(path, "wb") as h:
        h.write(b"RIFF" + struct.pack("<I", 4 + len(chunk) + len(data))
                + b"WAVE" + chunk + data)
    return path


def sine(freq: float, amp: float, seconds: float, rate: int,
         phase: float = 0.0) -> list[float]:
    return [amp * math.sin(2 * math.pi * freq * i / rate + phase)
            for i in range(int(seconds * rate))]


def main() -> int:
    tmp = tempfile.mkdtemp(prefix="vera-audio-")
    p = lambda name: os.path.join(tmp, name)

    # 1. the coefficients, against the standard's own table
    shelf, high = am.k_weighting(48000)
    published_shelf = (1.53512485958697, -2.69169618940638,
                       1.19839281085285, -1.69065929318241,
                       0.73248077421585)
    published_high = (1.0, -2.0, 1.0, -1.99004745483398, 0.99007225036621)
    err = max(abs(a - b) for a, b in zip(shelf + high,
                                         published_shelf + published_high))
    check(err < 1e-6, "K-weighting at 48 kHz matches BS.1770's published "
          "coefficients (max error %.1e)" % err)

    # 2-3. the calibration point, at 48 kHz and at a derived rate
    for rate in (48000, 44100):
        r = am.measure(write(p("cal%d.wav" % rate),
                             [sine(997, 1.0, 3.0, rate)], rate))
        check(abs(r["integrated"] - (-3.01)) < 0.03,
              "997 Hz at 0 dBFS, %d Hz: %.3f LUFS (standard: -3.01)"
              % (rate, r["integrated"]))

    # 4. channel summation: one channel -3.01, both channels 0.00
    rate = 48000
    tone = sine(997, 1.0, 3.0, rate)
    one = am.measure(write(p("one.wav"), [tone, [0.0] * len(tone)], rate))
    both = am.measure(write(p("both.wav"), [tone, tone], rate))
    check(abs(one["integrated"] + 3.01) < 0.03,
          "stereo, tone in one channel: %.3f LUFS (-3.01)"
          % one["integrated"])
    check(abs(both["integrated"] - 0.0) < 0.03,
          "stereo, tone in both: %.3f LUFS (0.00, +3.01 dB of power)"
          % both["integrated"])

    # 5. a level change is a loudness change, dB for dB
    quiet = am.measure(write(p("q.wav"), [sine(997, 0.1, 3.0, rate)], rate))
    check(abs(quiet["integrated"] + 23.01) < 0.03,
          "997 Hz at -20 dBFS: %.3f LUFS (-23.01)" % quiet["integrated"])

    # 6. gating: one second of tone in three of silence is still the tone
    gated = am.measure(write(p("g.wav"), [sine(997, 0.1, 1.0, rate)
                                          + [0.0] * (3 * rate)], rate))
    # By the standard's own block arithmetic, not by intuition: 400 ms
    # blocks every 100 ms over 1 s of tone give 7 whole-tone blocks and
    # 3 straddling the edge (75 %, 50 %, 25 % tone). All three clear
    # both gates, so the gated mean is 8.5/10 of the tone's power. (This
    # case first asserted "about -23.0" and failed; the meter was right.)
    expected = -23.01 + 10 * math.log10(8.5 / 10)
    check(abs(gated["integrated"] - expected) < 0.02,
          "1 s tone + 3 s silence, gated: %.3f LUFS (block arithmetic "
          "gives %.3f; the silence-only blocks are gated out)"
          % (gated["integrated"], expected))
    check(gated["ungated"] < gated["integrated"] - 5.0,
          "...and the ungated figure is lower (%.2f LUFS), as it should be"
          % gated["ungated"])

    # 7. formats read alike
    shot = sine(220, 0.5, 0.5, rate)
    f = am.measure(write(p("f.wav"), [shot], rate, "float32"))
    i16 = am.measure(write(p("i16.wav"), [shot], rate, "pcm16"))
    i24 = am.measure(write(p("i24.wav"), [shot], rate, "pcm24"))
    ext = am.measure(write_extensible(p("ext.wav"), shot, rate))
    check(abs(f["peak_db"] - i16["peak_db"]) < 0.01
          and abs(f["peak_db"] - i24["peak_db"]) < 0.01
          and abs(f["peak_db"] - ext["peak_db"]) < 0.01,
          "float32, PCM16, PCM24 and EXTENSIBLE agree on peak "
          "(%.3f / %.3f / %.3f / %.3f dBFS)"
          % (f["peak_db"], i16["peak_db"], i24["peak_db"], ext["peak_db"]))

    # 8. clipping is counted, and a clean signal reads zero
    square = [1.0 if (i // 60) % 2 else -1.0 for i in range(rate // 2)]
    clip = am.measure(write(p("sq.wav"), [square], rate))
    clean = am.measure(write(p("cl.wav"), [sine(440, 0.89, 0.5, rate)],
                             rate))
    check(clip["clipped"] > 0, "a full-scale square counts as clipped "
          "(%d samples)" % clip["clipped"])
    check(clean["clipped"] == 0, "a sine at -1 dBFS clips nothing")

    # 9. inter-sample peak: 12 kHz at 48 kHz, 45 degrees off the samples
    isp = am.measure(write(p("isp.wav"),
                           [sine(12000, 0.5, 0.25, rate, math.pi / 4)],
                           rate))
    check(abs(isp["peak_db"] - (-9.03)) < 0.05,
          "inter-sample case: sample peak %.2f dBFS (expected -9.03)"
          % isp["peak_db"])
    check(abs(isp["true_peak_db"] - (-6.02)) < 0.5,
          "...true-peak estimate recovers %.2f dBFS (true -6.02)"
          % isp["true_peak_db"])

    # 10. onset: leading silence is measured, because it is felt as lag
    late = [0.0] * int(0.100 * rate) + sine(180, 0.7, 0.4, rate)
    lag = am.measure(write(p("lag.wav"), [late], rate))
    check(abs(lag["onset_s"] - 0.100) < 0.003,
          "100 ms of leading silence reads as %.1f ms onset"
          % (lag["onset_s"] * 1000))

    # 11. ring: an exponential tail decays 60 dB at a known time
    tau = 0.05                         # 60 dB = ln(1000)*tau = 0.345 s
    tail = [0.8 * math.exp(-i / (tau * rate)) *
            math.sin(2 * math.pi * 300 * i / rate + math.pi / 2)
            for i in range(rate)]
    ring = am.measure(write(p("ring.wav"), [tail], rate))
    check(abs(ring["ring_s"] - math.log(1000) * tau) < 0.02,
          "exponential tail rings %.0f ms to -60 dB (theory %.0f ms)"
          % (ring["ring_s"] * 1000, math.log(1000) * tau * 1000))

    # 12. short files: no gated integrated loudness exists
    short = am.measure(write(p("short.wav"), [sine(997, 0.5, 0.2, rate)],
                             rate))
    check(short["integrated"] is None and not math.isinf(
          short["momentary_max"]),
          "a 0.2 s shot has no integrated loudness and still a momentary "
          "figure (%.2f LUFS)" % short["momentary_max"])

    # 13. dc offset and brightness move the right way
    offset = am.measure(write(p("dc.wav"),
                              [[v + 0.1 for v in sine(440, 0.3, 0.5, rate)]],
                              rate))
    check(abs(offset["dc"][0] - 0.1) < 0.005,
          "a +0.1 offset reads dc %+.4f" % offset["dc"][0])
    low = am.measure(write(p("lo.wav"), [sine(80, 0.5, 0.5, rate)], rate))
    hi = am.measure(write(p("hi.wav"), [sine(4000, 0.5, 0.5, rate)], rate))
    check(low["centroid_hz"] < 200 < 3500 < hi["centroid_hz"]
          and low["low_share"] > 0.9 > 0.01 > hi["low_share"],
          "brightness: 80 Hz centroid %.0f Hz (%.0f%% low), 4 kHz centroid "
          "%.0f Hz (%.1f%% low)" % (low["centroid_hz"],
                                    low["low_share"] * 100,
                                    hi["centroid_hz"],
                                    hi["low_share"] * 100))

    print("\n%s" % ("%d case(s) failed" % failures if failures
                    else "the meter agrees with the standard"))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
