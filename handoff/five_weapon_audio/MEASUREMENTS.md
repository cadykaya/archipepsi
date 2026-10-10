# Measurements

Measured by `source/measure.py` on the delivered 48 kHz PCM16 WAVs. Loudness is the loudest 400 ms window (EBU R128 momentary max, LUFS) because these are short events; integrated loudness means little for a 0.3 s shot. True peak by ffmpeg `ebur128=peak=true`. Band figures are each band's share of the energy in the first 0.5 s (dB, flat window from 5 ms before onset). "Tail @ end" is the peak of the last 20 ms, to catch a cut-off decay.

| File | Length s | Sample peak dBFS | True peak dBTP | Loudness (M max) LUFS | Clipped samples | Crest dB | Centroid Hz | Sub <80 | Low 80–300 | Mid 0.3–2k | High 2–8k | Air >8k | Decay to −40 dB, s | Tail @ end dBFS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bulkhead_fire.wav | 1.648 | -3.76 | -3.7 | -21.0 | 0 | 12.5 | 612 | -2.3 | -6.1 | -11.5 | -11.6 | -17.8 | 0.497 | -76.3 |
| bulkhead_pump.wav | 0.535 | -10.18 | -10.1 | -28.0 | 0 | 21.5 | 4619 | -15.0 | -6.4 | -9.4 | -3.5 | -7.6 | 0.241 | -59.4 |
| foundry_fire.wav | 1.264 | -4.14 | -3.9 | -21.0 | 0 | 13.6 | 1044 | -4.7 | -3.9 | -11.9 | -8.6 | -15.3 | 0.365 | -65.2 |
| impact_metal.wav | 0.872 | -8.19 | -8.2 | -25.0 | 0 | 18.8 | 2600 | -21.6 | -5.2 | -3.9 | -7.1 | -10.6 | 0.443 | -62.4 |
| impact_organic.wav | 0.692 | -3.38 | -3.4 | -25.0 | 0 | 15.5 | 152 | -4.0 | -2.9 | -12.0 | -25.6 | -43.7 | 0.113 | -90.3 |
| impact_stone.wav | 1.019 | -9.94 | -9.9 | -25.0 | 0 | 12.1 | 784 | -23.5 | -3.1 | -4.0 | -9.8 | -30.9 | 0.381 | -66.2 |
| massdriver_charge.wav | 1.365 | -13.29 | -13.0 | -24.0 | 0 | 25.2 | 576 | -2.0 | -5.5 | -17.8 | -14.7 | -15.3 | 0.34 | -240.0 |
| massdriver_charge_hold_loop.wav | 1.6 | -14.91 | -14.9 | -26.0 | 0 | 11.4 | 181 | -1.7 | -5.3 | -18.6 | -21.8 | -22.2 | 1.318 | -21.7 |
| massdriver_impact_metal.wav | 1.272 | -7.3 | -7.1 | -23.0 | 0 | 12.8 | 855 | -2.1 | -10.0 | -10.0 | -11.9 | -15.2 | 0.389 | -78.3 |
| massdriver_impact_organic.wav | 0.842 | -1.65 | -1.6 | -23.0 | 0 | 14.3 | 89 | -1.2 | -7.1 | -16.6 | -30.2 | -49.0 | 0.125 | -240.0 |
| massdriver_impact_stone.wav | 1.444 | -5.18 | -5.2 | -23.0 | 0 | 12.6 | 340 | -2.1 | -8.1 | -8.0 | -13.6 | -33.9 | 0.38 | -240.0 |
| massdriver_powerdown.wav | 1.039 | -9.66 | -9.6 | -27.0 | 0 | 15.8 | 2016 | -5.2 | -7.6 | -5.5 | -9.0 | -9.7 | 0.606 | -240.0 |
| massdriver_release_early.wav | 1.268 | -4.18 | -4.0 | -23.0 | 0 | 14.2 | 707 | -1.8 | -11.6 | -8.8 | -10.5 | -17.8 | 0.373 | -70.3 |
| massdriver_release_full.wav | 2.118 | -5.21 | -5.1 | -21.0 | 0 | 10.6 | 450 | -1.2 | -11.4 | -10.7 | -12.6 | -20.3 | 0.708 | -90.3 |
| sightline_fire.wav | 0.748 | -1.32 | -1.0 | -21.0 | 0 | 18.5 | 3290 | -8.9 | -6.6 | -10.4 | -3.3 | -10.1 | 0.274 | -56.2 |
| switchback_fire_a.wav | 0.366 | -3.56 | -3.2 | -25.7 | 0 | 20.0 | 2321 | -8.6 | -3.1 | -14.1 | -6.4 | -9.6 | 0.145 | -84.3 |
| switchback_fire_b.wav | 0.366 | -3.7 | -3.3 | -25.7 | 0 | 19.8 | 2313 | -9.7 | -2.8 | -14.6 | -6.6 | -9.5 | 0.138 | -84.3 |
| switchback_release_tail.wav | 1.039 | -13.73 | -13.0 | -30.0 | 0 | 17.1 | 6560 | -57.1 | -25.4 | -9.9 | -2.8 | -4.3 | 0.612 | -72.2 |
| switchback_series_demo.wav | 3.142 | -3.51 | -3.2 | -21.0 | 0 | 20.1 | 2345 | -10.8 | -2.9 | -10.9 | -6.7 | -9.5 | 0.354 | -90.3 |

## Repeated fire (six shots at the brief's candidate interval, overlap-added)

| Sound | Interval s | Single peak dBFS | Six-shot peak dBFS | Build-up dB | Previous tail at next shot (dB below its peak) |
|---|---|---|---|---|---|
| foundry_fire | 0.72 | -4.1 | -4.1 | 0.0 | -50.4 |
| sightline_fire | 0.35 | -1.3 | -1.3 | 0.0 | -42.6 |
| bulkhead_fire | 1.0 | -3.8 | -3.8 | 0.0 | -52.3 |
| massdriver_release_full | 2.0 | -5.2 | -5.2 | 0.0 | -83.2 |
| switchback_fire_a | 0.133 | -3.6 | -3.5 | 0.1 | -36.0 |

Bulkhead's row includes its pump 0.35 s after each shot. Switchback's real 7.5-per-second series is also rendered natively by SigmAudio as `switchback_series_demo.wav` (peak −3.5 dBFS, no clipping).
