#!/usr/bin/env python3
"""Objective numbers for weapon and impact sound files.

    python3 tools/vera/audio_measure.py FILE.wav [FILE.wav ...]

Standard library only, so it runs on any machine with Python 3.8+ and no
installs. Reads RIFF/WAVE: integer PCM (8/16/24/32-bit), IEEE float
(32/64-bit), and WAVE_FORMAT_EXTENSIBLE wrapping either.

WHAT IT CANNOT DO. It does not listen. Nothing here says whether a shot
is satisfying; it says whether it clips, how loud it is by the broadcast
standard, how long before it starts and how long it rings -- the parts
of "check clipping, peak levels, perceived loudness, short-tail overlap"
in the brief that a number can answer.

Per file:
  peak            sample peak, dBFS
  true peak (est) 4x windowed-sinc oversampled peak, dBFS -- an ESTIMATE,
                  not a certified BS.1770 Annex 2 meter
  clipped         samples at or beyond full scale (|x| >= 0.9999)
  loudness        ITU-R BS.1770-4: integrated (gated) LUFS where the
                  file is at least 0.4 s; max momentary (400 ms) LUFS;
                  and ungated K-weighted loudness over the whole file
  onset           time to the first sample within 40 dB of the peak --
                  leading silence on a gunshot is felt as input lag
  ring            time from the peak until the level stays 60 dB below
                  it: how long the tail can stack under automatic fire
  crest           peak-to-RMS, dB
  dc              mean offset per channel
  brightness      spectral centroid (Hz) and the share of energy below
                  250 Hz -- "weighty low body" against "crisp dry snap"

Comparing several files prints the spread of max-momentary loudness, the
closest thing here to "roughly matched perceived loudness" for single
shots.
"""
from __future__ import annotations

import cmath
import math
import struct
import sys

# --- reading -----------------------------------------------------------------

PCM, FLOAT = 1, 3
EXTENSIBLE = 0xFFFE


class Audio:
    def __init__(self, rate: int, channels: list[list[float]], kind: str):
        self.rate = rate
        self.channels = channels
        self.kind = kind

    @property
    def frames(self) -> int:
        return len(self.channels[0]) if self.channels else 0


def read_wav(path: str) -> Audio:
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("not a RIFF/WAVE file")
    fmt = None
    body = None
    at = 12
    while at + 8 <= len(data):
        cid, size = data[at:at + 4], struct.unpack_from("<I", data, at + 4)[0]
        chunk = data[at + 8:at + 8 + size]
        if cid == b"fmt ":
            fmt = chunk
        elif cid == b"data":
            body = chunk
        at += 8 + size + (size & 1)
    if fmt is None or body is None:
        raise ValueError("missing fmt or data chunk")
    tag, nch, rate = struct.unpack_from("<HHI", fmt, 0)
    bits = struct.unpack_from("<H", fmt, 14)[0]
    if tag == EXTENSIBLE and len(fmt) >= 26:
        tag = struct.unpack_from("<H", fmt, 24)[0]   # GUID's first 2 bytes
    width = bits // 8
    count = len(body) // (width * nch)
    samples: list[float] = []
    if tag == PCM:
        if width == 1:
            samples = [(b - 128) / 128.0 for b in body[:count * nch]]
        elif width == 2:
            samples = [v / 32768.0 for v in
                       struct.unpack_from("<%dh" % (count * nch), body)]
        elif width == 3:
            raw = body[:count * nch * 3]
            for i in range(0, len(raw), 3):
                v = raw[i] | (raw[i + 1] << 8) | (raw[i + 2] << 16)
                if v & 0x800000:
                    v -= 1 << 24
                samples.append(v / 8388608.0)
        elif width == 4:
            samples = [v / 2147483648.0 for v in
                       struct.unpack_from("<%di" % (count * nch), body)]
        else:
            raise ValueError("unsupported PCM width %d" % bits)
        kind = "PCM %d-bit" % bits
    elif tag == FLOAT:
        code = {4: "f", 8: "d"}.get(width)
        if code is None:
            raise ValueError("unsupported float width %d" % bits)
        samples = list(struct.unpack_from("<%d%s" % (count * nch, code),
                                          body))
        kind = "float %d-bit" % bits
    else:
        raise ValueError("unsupported WAVE format tag 0x%04x" % tag)
    channels = [samples[c::nch] for c in range(nch)]
    return Audio(rate, channels, kind)


# --- ITU-R BS.1770-4 ---------------------------------------------------------

def k_weighting(rate: int) -> tuple[tuple, tuple]:
    """The two K-weighting biquads for any sample rate.

    Derived from the analogue prototypes (the libebur128 construction),
    which reproduce BS.1770's published 48 kHz coefficients -- the
    accompanying test checks that to 1e-6 rather than trusting it.
    Returns ((b0, b1, b2), (a1, a2)) for each stage.
    """
    f0, gain, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = math.tan(math.pi * f0 / rate)
    vh = 10.0 ** (gain / 20.0)
    vb = vh ** 0.4996667741545416
    a0 = 1.0 + k / q + k * k
    shelf = ((vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0,
             (vh - vb * k / q + k * k) / a0,
             2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0)
    f0, q = 38.13547087602444, 0.5003270373238773
    k = math.tan(math.pi * f0 / rate)
    a0 = 1.0 + k / q + k * k
    high = (1.0, -2.0, 1.0,
            2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0)
    return shelf, high


def biquad(x: list[float], c: tuple) -> list[float]:
    b0, b1, b2, a1, a2 = c
    y: list[float] = []
    x1 = x2 = y1 = y2 = 0.0
    for v in x:
        out = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, out
        y.append(out)
    return y


#: Channel weights: L, R, C at 1.0; surrounds 1.41. Files here are mono
#: or stereo, which BS.1770 weights at 1.0 per channel.
def _weights(n: int) -> list[float]:
    return [1.0, 1.0, 1.0, 0.0, 1.41, 1.41][:n] if n > 2 else [1.0] * n


def loudness(audio: Audio) -> dict[str, float | None]:
    shelf, high = k_weighting(audio.rate)
    weighted = [biquad(biquad(ch, shelf), high) for ch in audio.channels]
    w = _weights(len(weighted))
    n = audio.frames

    def lufs(ms: float) -> float:
        return -0.691 + 10.0 * math.log10(ms) if ms > 0 else -math.inf

    def block_ms(start: int, size: int) -> float:
        return sum(w[c] * sum(v * v for v in weighted[c][start:start + size])
                   / size for c in range(len(weighted)))

    whole = block_ms(0, n) if n else 0.0
    block = int(round(0.4 * audio.rate))
    step = int(round(0.1 * audio.rate))
    if n < block:
        return {"integrated": None, "momentary_max": lufs(whole),
                "ungated": lufs(whole)}
    # running sums so the 400 ms blocks are O(n)
    sq = [[0.0] for _ in weighted]
    for c, ch in enumerate(weighted):
        acc = 0.0
        for v in ch:
            acc += v * v
            sq[c].append(acc)
    blocks = []
    for start in range(0, n - block + 1, step):
        ms = sum(w[c] * (sq[c][start + block] - sq[c][start]) / block
                 for c in range(len(weighted)))
        blocks.append(ms)
    momentary = max(lufs(b) for b in blocks)
    gated = [b for b in blocks if lufs(b) > -70.0]
    if not gated:
        return {"integrated": -math.inf, "momentary_max": momentary,
                "ungated": lufs(whole)}
    relative = lufs(sum(gated) / len(gated)) - 10.0
    final = [b for b in gated if lufs(b) > relative]
    return {"integrated": lufs(sum(final) / len(final)) if final
            else -math.inf, "momentary_max": momentary,
            "ungated": lufs(whole)}


# --- peak, timing, spectrum -------------------------------------------------

def db(x: float) -> float:
    return 20.0 * math.log10(x) if x > 0 else -math.inf


def true_peak_estimate(ch: list[float], factor: int = 4,
                       taps: int = 16) -> float:
    """Peak of a 4x windowed-sinc interpolation. An estimate only."""
    best = max((abs(v) for v in ch), default=0.0)
    half = taps // 2
    kernel = {}
    for phase in range(1, factor):
        frac = phase / factor
        row = []
        for k in range(-half + 1, half + 1):
            t = k - frac
            sinc = math.sin(math.pi * t) / (math.pi * t)
            window = 0.5 + 0.5 * math.cos(math.pi * t / half)  # Hann
            row.append(sinc * window)
        kernel[phase] = row
    n = len(ch)
    for i in range(n - 1):
        for phase, row in kernel.items():
            acc = 0.0
            for j, coef in enumerate(row):
                idx = i + (j - half + 1)
                if 0 <= idx < n:
                    acc += coef * ch[idx]
            if abs(acc) > best:
                best = abs(acc)
    return best


def fft(x: list[complex]) -> list[complex]:
    n = len(x)
    if n <= 1:
        return x
    even, odd = fft(x[0::2]), fft(x[1::2])
    tw = [cmath.exp(-2j * math.pi * k / n) * odd[k] for k in range(n // 2)]
    return [even[k] + tw[k] for k in range(n // 2)] + \
           [even[k] - tw[k] for k in range(n // 2)]


def spectrum_summary(audio: Audio, cap: int = 1 << 15) -> tuple[float, float]:
    mono = [sum(ch[i] for ch in audio.channels) / len(audio.channels)
            for i in range(min(audio.frames, cap))]
    size = 1
    while size < len(mono):
        size <<= 1
    if size < 64:
        return math.nan, math.nan
    window = [0.5 - 0.5 * math.cos(2 * math.pi * i / (len(mono) - 1))
              for i in range(len(mono))] if len(mono) > 1 else [1.0]
    spec = fft([complex(v * window[i]) for i, v in enumerate(mono)]
               + [0j] * (size - len(mono)))
    power = [abs(spec[k]) ** 2 for k in range(size // 2)]
    freqs = [k * audio.rate / size for k in range(size // 2)]
    total = sum(power)
    if total <= 0:
        return math.nan, math.nan
    centroid = sum(f * p for f, p in zip(freqs, power)) / total
    low = sum(p for f, p in zip(freqs, power) if f < 250.0) / total
    return centroid, low


def measure(path: str) -> dict:
    audio = read_wav(path)
    frames = audio.frames
    peak_by_ch = [max((abs(v) for v in ch), default=0.0)
                  for ch in audio.channels]
    peak = max(peak_by_ch, default=0.0)
    clipped = sum(1 for ch in audio.channels for v in ch if abs(v) >= 0.9999)
    mono_abs = [max(abs(ch[i]) for ch in audio.channels)
                for i in range(frames)]
    onset = ring = math.nan
    if peak > 0:
        start_level = peak * 10 ** (-40 / 20)
        first = next((i for i, v in enumerate(mono_abs) if v >= start_level),
                     None)
        onset = first / audio.rate if first is not None else math.nan
        at_peak = mono_abs.index(peak)
        floor = peak * 10 ** (-60 / 20)
        last = max((i for i, v in enumerate(mono_abs) if v >= floor),
                   default=at_peak)
        ring = (last - at_peak) / audio.rate
    rms = math.sqrt(sum(v * v for ch in audio.channels for v in ch)
                    / max(1, frames * len(audio.channels)))
    loud = loudness(audio)
    tp = max(true_peak_estimate(ch) for ch in audio.channels) \
        if frames <= 4 * 48000 else peak
    centroid, low = spectrum_summary(audio)
    return {
        "path": path, "kind": audio.kind, "rate": audio.rate,
        "channels": len(audio.channels), "seconds": frames / audio.rate,
        "peak_db": db(peak), "true_peak_db": db(tp), "clipped": clipped,
        "rms_db": db(rms), "crest_db": db(peak) - db(rms) if rms else
        math.nan, "onset_s": onset, "ring_s": ring,
        "dc": [sum(ch) / len(ch) if ch else 0.0 for ch in audio.channels],
        "centroid_hz": centroid, "low_share": low, **loud,
    }


def fmt(v, spec=".1f", none="n/a") -> str:
    if v is None or (isinstance(v, float) and math.isnan(v)):
        return none
    if isinstance(v, float) and math.isinf(v):
        return "-inf"
    return format(v, spec)


def report(rows: list[dict]) -> None:
    for r in rows:
        print("%s" % r["path"])
        print("  format      %s, %d Hz, %d ch, %.3f s"
              % (r["kind"], r["rate"], r["channels"], r["seconds"]))
        flag = "  <-- CLIPS" if r["clipped"] else ""
        print("  peak        %s dBFS   true peak (est) %s dBFS   clipped %d%s"
              % (fmt(r["peak_db"], ".2f"), fmt(r["true_peak_db"], ".2f"),
                 r["clipped"], flag))
        print("  loudness    integrated %s LUFS   max momentary %s LUFS   "
              "ungated %s LUFS" % (fmt(r["integrated"]),
                                   fmt(r["momentary_max"]),
                                   fmt(r["ungated"])))
        print("  timing      onset %s ms   ring %s ms (to -60 dB)"
              % (fmt(r["onset_s"] * 1000 if not math.isnan(r["onset_s"])
                     else math.nan, ".0f"),
                 fmt(r["ring_s"] * 1000 if not math.isnan(r["ring_s"])
                     else math.nan, ".0f")))
        print("  shape       crest %s dB   rms %s dBFS   dc %s"
              % (fmt(r["crest_db"]), fmt(r["rms_db"]),
                 ", ".join("%+.4f" % d for d in r["dc"])))
        print("  brightness  centroid %s Hz   energy below 250 Hz %s%%"
              % (fmt(r["centroid_hz"], ".0f"),
                 fmt(r["low_share"] * 100 if not math.isnan(r["low_share"])
                     else math.nan, ".0f")))
        if math.isinf(r["peak_db"]):
            print("  note        DIGITALLY SILENT: every sample is zero, so "
                  "there is nothing to measure")
        if r["integrated"] is None:
            print("  note        under 0.4 s: no gated integrated loudness "
                  "exists by the standard")
        print()
    if len(rows) > 1:
        vals = [r["momentary_max"] for r in rows
                if not math.isinf(r["momentary_max"])]
        if vals:
            spread = max(vals) - min(vals)
            print("max-momentary spread across %d files: %.1f LU%s"
                  % (len(vals), spread,
                     "  (more than 3 LU apart: not 'roughly matched')"
                     if spread > 3.0 else ""))


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    rows, bad = [], 0
    for path in argv:
        try:
            rows.append(measure(path))
        except Exception as err:
            print("%s: cannot measure: %s\n" % (path, err))
            bad += 1
    report(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
