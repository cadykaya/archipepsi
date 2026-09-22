#!/usr/bin/env python3
"""The theme-pack coverage table and the catalogue must agree.

A coverage ledger that can silently lose a row is a ledger that will
report full coverage of a shorter list. So this checks, both ways:

* every game in `catalogue.json` has exactly one row in `COVERAGE.md`;
* every row in `COVERAGE.md` names a game in the catalogue;
* the count the document states is the count the catalogue holds;
* the queue ids are unique and the pack ids are unique.

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

    stated = re.search(r"\*\*Count:\s*(\d+)\s*included games\.\*\*", text)
    if not stated:
        problems.append("COVERAGE.md no longer states its count")
    elif int(stated.group(1)) != cat["count"]:
        problems.append(
            "COVERAGE.md states %s and the catalogue holds %d"
            % (stated.group(1), cat["count"]))

    print("check-packs: %d catalogued, %d covered"
          % (len(games), len(rows)))
    if problems:
        print("\ncheck-packs: FAIL -- %d problem(s):" % len(problems))
        for p in problems:
            print("  - %s" % p)
        return 1
    print("check-packs: PASS -- the ledger and the catalogue agree.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
