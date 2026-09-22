#!/usr/bin/env python3
"""The theme-pack coverage table and the catalogue must agree.

A coverage ledger that can silently lose a row is a ledger that will
report full coverage of a shorter list. So this checks, both ways:

* every game in `catalogue.json` has exactly one row in `COVERAGE.md`;
* every row in `COVERAGE.md` names a game in the catalogue;
* the count the document states is the count the catalogue holds;
* the queue ids are unique and the pack ids are unique;
* and the COMPLETION ledger agrees with both. That is a second table,
  added because the owner asked for catalogue coverage and completed
  pack coverage to be reported separately, and a second table is a
  second thing that can drift. Every pack it names must be a catalogue
  pack, its verdicts must be words this file knows, and the counts the
  document states underneath it must be the counts its rows hold --
  so "0 of 81 complete" cannot survive a row quietly turning into a
  COMPLETE.

It does NOT check the catalogue against the live page. That snapshot is
dated and carries the fetched page's SHA-256 on purpose: re-fetching is
a deliberate act with a new date, not something a verifier does behind
the author's back. A catalogue that silently followed an upstream edit
would make the dated snapshot a lie.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
HERE = os.path.join(ROOT, "docs", "art", "theme-packs")
CATALOGUE = os.path.join(HERE, "catalogue.json")
COVERAGE = os.path.join(HERE, "COVERAGE.md")

ROW = re.compile(
    r"^\|\s*(?P<queue>T\d+)\s*\|\s*(?P<title>[^|]+?)\s*\|\s*"
    r"`(?P<pack>[a-z0-9_]+)`\s*\|")
#: A completion-ledger row: pack id first, verdict last.
DONE_ROW = re.compile(
    r"^\|\s*`(?P<pack>tp_[a-z0-9_]+)`\s*\|.*\|\s*\*\*(?P<verdict>[A-Z ]+)\*\*\s*\|\s*$")
#: The only verdicts that mean anything. A new one is a decision and
#: has to be made here rather than by typing it into the table.
VERDICTS = ("COMPLETE", "IN PROGRESS")
STATED = re.compile(
    r"\*\*(?P<done>\d+) of (?P<total>\d+) complete\. "
    r"(?P<prog>\d+) in progress\. (?P<none>\d+) not started\.\*\*")


def main():
    problems = []
    with open(CATALOGUE, encoding="utf-8") as handle:
        cat = json.load(handle)
    games = {g["title"]: g for g in cat["games"]}

    if len(games) != len(cat["games"]):
        problems.append("catalogue.json has duplicate titles")
    if cat["count"] != len(cat["games"]):
        problems.append(
            "catalogue.json says count %d and holds %d games"
            % (cat["count"], len(cat["games"])))
    if cat["first_wave"] + cat["remaining"] != cat["count"]:
        problems.append(
            "first_wave %d + remaining %d is not count %d"
            % (cat["first_wave"], cat["remaining"], cat["count"]))

    with open(COVERAGE, encoding="utf-8") as handle:
        text = handle.read()
    rows = {}
    queues, packs = set(), set()
    for line in text.splitlines():
        got = ROW.match(line)
        if not got:
            continue
        title = got.group("title")
        if title in rows:
            problems.append("%s has two coverage rows" % title)
        rows[title] = got.group("pack")
        if got.group("queue") in queues:
            problems.append("queue id %s is used twice"
                            % got.group("queue"))
        queues.add(got.group("queue"))
        if got.group("pack") in packs:
            problems.append("pack id %s is used twice" % got.group("pack"))
        packs.add(got.group("pack"))

    for title, game in games.items():
        if title not in rows:
            problems.append(
                "%r is in the catalogue and has no coverage row" % title)
        elif rows[title] != game["pack_id"]:
            problems.append(
                "%r covers pack %r and the catalogue says %r"
                % (title, rows[title], game["pack_id"]))
    for title in rows:
        if title not in games:
            problems.append(
                "%r has a coverage row and is not in the catalogue. "
                "Community-only APWorlds are deliberately separate -- "
                "adding one here would widen the definition silently."
                % title)

    # --- the completion ledger, against the catalogue and itself ----
    done = {}
    for line in text.splitlines():
        got = DONE_ROW.match(line)
        if not got:
            continue
        pack, verdict = got.group("pack"), got.group("verdict")
        if pack in done:
            problems.append("%s has two completion rows" % pack)
        if verdict not in VERDICTS:
            problems.append(
                "%s carries verdict %r, which is not one of %s"
                % (pack, verdict, ", ".join(VERDICTS)))
        done[pack] = verdict
    for pack in done:
        if pack not in packs:
            problems.append(
                "%s is in the completion ledger and is not a catalogue "
                "pack id" % pack)
    tally = re.search(STATED, text)
    if not tally:
        problems.append(
            "the completion ledger no longer states its counts in the "
            "form '**N of M complete. N in progress. N not started.**'")
    else:
        n_done = sum(1 for v in done.values() if v == "COMPLETE")
        n_prog = sum(1 for v in done.values() if v == "IN PROGRESS")
        if int(tally.group("done")) != n_done:
            problems.append(
                "the ledger states %s complete and holds %d"
                % (tally.group("done"), n_done))
        if int(tally.group("prog")) != n_prog:
            problems.append(
                "the ledger states %s in progress and holds %d"
                % (tally.group("prog"), n_prog))
        total = int(tally.group("total"))
        if total != cat["count"]:
            problems.append(
                "the ledger totals %d and the catalogue holds %d"
                % (total, cat["count"]))
        if n_done + n_prog + int(tally.group("none")) != total:
            problems.append(
                "%d complete + %d in progress + %s not started is not %d"
                % (n_done, n_prog, tally.group("none"), total))

    stated = re.search(r"\*\*Count:\s*(\d+)\s*included games\.\*\*", text)
    if not stated:
        problems.append("COVERAGE.md no longer states its count")
    elif int(stated.group(1)) != cat["count"]:
        problems.append(
            "COVERAGE.md states %s and the catalogue holds %d"
            % (stated.group(1), cat["count"]))

    print("check-packs: %d catalogued, %d covered; completion ledger: "
          "%d row(s), %d complete"
          % (len(games), len(rows), len(done),
             sum(1 for v in done.values() if v == "COMPLETE")))
    if problems:
        print("\ncheck-packs: FAIL -- %d problem(s):" % len(problems))
        for p in problems:
            print("  - %s" % p)
        return 1
    print("check-packs: PASS -- the ledger and the catalogue agree.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
