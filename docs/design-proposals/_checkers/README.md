# Design-proposal checkers

The scripts `06_THE_AMALGAM_AUDIT.md` §9 cites. They were written during the
audit passes and live here so the audit's numbers can be reproduced rather than
taken on trust.

Run them all:

```sh
docs/design-proposals/_checkers/run_all.sh
```

| Script | What it checks |
|---|---|
| `refcheck.py` | Cross-document section references, source-vector citations, and internal `§` references resolve to sections that exist |
| `pipecheck.py` | GFM table integrity — every row in a table has the column count its header declares. Takes one filename |
| `dupcheck.py` | A figure duplicated away from its authoritative section still matches it |
| `closurecheck.py` | Every figure in Design 6 §41.6 matches the section that owns it |
| `semcheck.py` | Semantic contradictions: claims that cannot both be true. `34` classes |
| `atoms.py` | Enumerates the composable Weapon and Ability spaces, the source of those two figures |

**On what these prove.** Each pass of the audit found defects that the previous
pass's checkers had reported clean — three passes running. Every class in
`semcheck.py` exists because something got past the version before it. A green
run is evidence about the classes that are checked and about nothing else.

`semcheck.py` reports its own class count, so the audit copies that number
rather than asserting one.
