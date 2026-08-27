# Archipepsi

An Archipelago game whose campaign is constructed *during* the multiworld by an AI dungeon master called **Epsilon**, using the actual randomized items sitting in the player's Archipelago locations as the inspiration for levels, rewards, shops, and permanent local abilities called **Echoes**.

> Archipelago decides the randomized truth. Archipepsi's deterministic code decides which truth is currently presented. Epsilon decides what that presentation feels like.

**Status: design phase.** No implementation yet. The repository currently holds the design packet and its audits.

## Layout

```
docs/
├─ design-packet/     v0.3 design packet, unzipped for review and diffing
└─ audit/
   └─ PASS_1_AUDIT.md merged audit of v0.3
```

### `docs/design-packet/`

The v0.3 packet, unpacked so it can be read, reviewed, and edited in version control instead of living inside a zip. Read `README.md` there first — it defines the authority order between the documents.

### `docs/audit/PASS_1_AUDIT.md`

A merge of two audits of v0.3 produced independently and without either side seeing the other: one by Skyiah + ChatGPT (24 items), one by Claude Opus. Twelve findings overlap; each side found things the other missed.

Headline results:

- **B5** — Check 030 is the goal trigger, and nothing excludes it from shop stock or normal Zone allocation. As specified, you can buy the ending for as little as 2 coins.
- **C1** — the packet's "duplicate `LocationChecks` are safe, so resending is expected behavior" assumption is true but useless: verified against `MultiServer.py` and `CommonClient.py`, a resent already-checked location produces no packet and no server response, so any retry loop that waits for confirmation hangs forever.
- **C4** — naming the origin region `Start` without setting `origin_region_name` is a hard generation failure.
- **B1** — the bridge's mandated dependency (Archipelago's `CommonContext`) is not pip-installable and imports the entire `worlds` package at module load.
- **B4** — no movement or combat constant exists anywhere in the packet, which means the "every mandatory path is completable with base movement" guarantee is currently unverifiable.

The audit closes with a proposed constants table (Appendix A) and a prioritized pass-2 plan.

## Next

Pass 2 of the design packet, gated on five decisions listed in §8 of the audit.
