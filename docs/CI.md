# CI — what runs, when, and what a failure means

Three tiers. The tier a suite belongs to is decided by **what it needs**,
not by how slow it is — everything in this repository is fast. What
separates the tiers is whether a suite needs the Archipelago checkout,
Godot, or a live server.

| Tier | Workflow | Trigger | Needs | Budget |
| --- | --- | --- | --- | --- |
| **1 — fast PR gate** | `pr.yml` | every PR and push to `main` | Python only | ~1 min |
| **2 — full integration** | `integration.yml` | every PR and push to `main` | + Archipelago checkout, + Godot | ~6 min |
| **3 — heavyweight** | `nightly.yml` | 06:00 UTC daily, or manual | + generated seeds, + live servers | ~15 min |

## Tier 1 — the fast PR gate

| Step | Proves |
| --- | --- |
| `make test-schemas` | the v8 contract itself |
| `pytest` with `ARCHIPELAGO_ROOT=/nonexistent` | the bridge, the campaign, the fold — **and that none of it needs Archipelago at import time** |
| `check_packet.py` | the packet prose still describes the models |
| `make export` + `git diff --exit-code` | no generated artifact was hand-edited or left stale |

**The `ARCHIPELAGO_ROOT=/nonexistent` is load-bearing, not a shortcut.**
`ap_client.ensure_ap_importable()` imports Archipelago lazily, so offline
development works and the schema layer stays independent of a 200 MB
checkout. A change that made AP a load-time dependency would pass every
other gate; this is the one that notices. Exactly two tests skip
themselves here and say why.

## Tier 2 — the full integration gate

Adds the real Archipelago 0.6.7 checkout, the APWorld generating real
seeds, every headless Godot suite, and the whole-campaign run. It runs on
PRs too, because it is affordable and a Godot regression that only nightly
catches is a Godot regression that lands on `main`.

It also **verifies the Godot build** against the one `project.godot`
pins (`4.5.1.stable`, `f62fdbde1`). The suites are written against that
build's behaviour; a silently different one is how a green CI stops
meaning anything.

## Tier 3 — heavyweight and nightly

Two jobs that stay off PRs for opposite reasons.

**`dual`** generates real multiworlds and starts real `MultiServer`
processes to prove two Archipepsi slots share one multiworld cleanly
(`make dual-real-soak`). Genuinely slow, and its failure mode is
environmental as often as not, which is not a thing to block a PR on.

**`clean`** is the opposite: fast, but it runs with **no caches at all**.
Every other job here caches pip, the Archipelago checkout, or the Godot
binary — and a cache is precisely how a missing requirement stops being
visible. This job walks the README's documented route on a bare runner
and is the answer to "does a fresh clone actually reach green".

## Caching, and the rule about it

Caches are keyed so that changing the thing invalidates the cache:

- the Archipelago checkout keys on `ARCHIPELAGO_TAG`, so bumping the pin
  fetches rather than reusing;
- the Godot binary keys on version and build;
- pip uses `setup-python`'s built-in cache.

**A cached checkout does not imply installed requirements.**
`pip install -r .archipelago/requirements.txt` runs on every integration
run, cache hit or not — the tree is cached, `site-packages` is not, and a
cached tree with nothing installed is exactly the failure caching is
supposed to be forbidden from hiding. The `clean` job exists because that
argument is only as good as something that checks it.

## Reading a failure

The steps are named for the layer they exercise, so the failing step names
the layer:

| Failing step | Broken layer |
| --- | --- |
| Schema contract | the v8 models — a bound, a validator, an enum |
| Bridge and campaign | the fold, allocation, transactions, providers |
| Packet prose | a document and the models disagree |
| Generated artifacts are stale | someone edited a generated file, or edited `constants.py` without `make export` |
| Obtain Archipelago | the pin moved or GitHub is down — not your change |
| Full Python suite | the APWorld, or one of the two tests that need a real checkout |
| The Godot build is the one the project pins | the runner got a different Godot |
| Godot project imports | a GDScript parse error — check the traceback for the file |
| A named Godot suite | that subsystem; each is a single `make` target you can run locally |
| Whole campaign, headlessly | integration — the suites passed individually and the loop did not |
| `dual` (nightly) | two-slot isolation, or the environment |
| `clean` (nightly) | **the documented setup route is broken for a fresh clone** |

## Running the tiers locally

```bash
# Tier 1, the whole thing, no Archipelago needed:
make test-schemas
cd bridge && ARCHIPELAGO_ROOT=/nonexistent python -m pytest -q -rs
python docs/design-packet-v0.8/check_packet.py

# Tier 2:
make test && make smoke && make godot-integration

# Tier 3:
make dual-real-soak
```

`make version` prints what a build is — version, commit, tree state,
Python, platform. CI attaches it to every integration run, and the bridge
banner prints the commit (with a `*` when the tree is dirty) so a
playtest bug report carries its own provenance.
