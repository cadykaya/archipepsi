#!/usr/bin/env python3
"""The Glyph plumbing the interface family's authoring scripts share.

Two things in here were learned the hard way and are the whole reason
this is a module instead of a copied block:

**A transaction lives in one process.** `glyph run` starts a process per
call, so `txn.begin` in one call and `palette.create` in the next gets
`TARGET_NOT_FOUND: no open transaction`. `Session.txn` therefore emits a
`glyph batch` script -- begin, the steps, commit -- and runs it as one
process, citing the transaction as `$1.transaction.id`.

**An export preset lives in one process too.** "A preset identifier
lives only for the life of the server that declared it." So anything
that consumes a preset -- the font checks, an `export.run` -- has to be
in the same batch that declared it, and writing the files afterwards
goes through the CLI's own `export` subcommand with the
`preset_declaration` an export record carries.

Neither is a quirk of one script, and rediscovering either costs an hour.
"""

from __future__ import annotations

import json
import os
import subprocess


class GlyphError(RuntimeError):
    pass


class Session:
    """One Glyph project, in a scratch directory, with two identities.

    The owner creates the project and grants; the artist does the work.
    They are distinct because the lane's rule is that the artist does not
    approve its own output -- and a script that used one identity for
    both would make that rule unenforceable by accident.
    """

    def __init__(self, checkout, work, name, owner, artist):
        self.cli = os.path.join(checkout, "packages", "cli", "dist", "main.js")
        if not os.path.exists(self.cli):
            raise GlyphError(
                "no Glyph CLI at %s -- set GLYPH_ROOT to a built ECMS Glyph "
                "checkout" % self.cli)
        self.work = work
        self.project = os.path.join(work, name)
        self.owner = owner
        self.artist = artist
        self._seq = 0

    # --- the two ways to reach the CLI ---------------------------------

    def run(self, command, payload, actor=None, extra=()):
        out = subprocess.run(
            ["node", self.cli, "run", self.project, command,
             json.dumps(payload), "--actor", actor or self.artist, *extra],
            capture_output=True, text=True)
        if out.returncode != 0:
            raise GlyphError("glyph %s failed:\n%s\n%s"
                             % (command, out.stdout[-2000:], out.stderr[-2000:]))
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            raise GlyphError("glyph %s returned no JSON:\n%s"
                             % (command, out.stdout[-2000:]))

    def batch(self, script, label="batch"):
        """A list of {command, input} in ONE process, with `$N.field`
        citations between them. Returns one result per command."""
        self._seq += 1
        path = os.path.join(self.work, "_%s_%d.json" % (label, self._seq))
        with open(path, "w") as fh:
            json.dump(script, fh)
        out = subprocess.run(
            ["node", self.cli, "batch", self.project, "@" + path,
             "--actor", self.artist, "--json"],
            capture_output=True, text=True)
        # A batch can exit zero with a refusal inside it. PRECONDITION_FAILED
        # is what a stale `base_revision` looks like, and swallowing it would
        # mean a script that silently authored nothing.
        if out.returncode != 0 or "PRECONDITION_FAILED" in out.stdout:
            raise GlyphError("glyph batch (%s) failed:\n%s\n%s"
                             % (label, out.stdout[-2500:], out.stderr[-1500:]))
        try:
            return json.loads(out.stdout[out.stdout.index("["):])
        except (ValueError, json.JSONDecodeError):
            raise GlyphError("glyph batch (%s) returned no JSON array:\n%s"
                             % (label, out.stdout[-2000:]))

    # --- the project ---------------------------------------------------

    def create(self, rationale):
        """A NEW project, and the one-time grant.

        Never an existing one: the September trial recorded that opening a
        `.glyph` checkpoints its WAL and modified six tracked fixtures, so
        approved sources are not opened by an authoring script at all.
        """
        self.run("project.describe", {}, actor=self.owner)
        self.run("project.grant", {
            "actor": self.artist, "scopes": ["*"],
            "operations": ["edit", "comment", "review", "session_start"],
            "rationale": rationale,
        }, actor=self.owner,
            extra=("--collaborator", "%s:agent" % self.artist))

    def head(self):
        return self.run("project.describe", {}
                        )["project_description"]["head_revision"]

    def txn(self, scope, steps, message):
        """One transaction, one process. `steps` is [(command, payload)];
        the transaction id is filled in for each."""
        script = [{"command": "txn.begin",
                   "input": {"base_revision": self.head(), "scope": scope}}]
        for command, payload in steps:
            script.append({"command": command,
                           "input": dict(payload,
                                         transaction="$1.transaction.id")})
        script.append({"command": "txn.commit",
                       "input": {"transaction": "$1.transaction.id",
                                 "message": message}})
        # begin and commit bracket the steps the caller asked for.
        return self.batch(script, label="txn")[1:-1]

    # --- getting pixels onto a disk ------------------------------------

    def sheet_preset(self, name, scope, width, height, **over):
        """A `sprite_sheet` preset. Every field is spelled out because a
        preset with a field missing is refused, and because the packing
        and the origin corner are the things an engine disagrees with."""
        spec = {
            "name": name, "version": 1, "format": "sprite_sheet",
            "scope": list(scope), "scale": 1, "trim": "none", "padding": 0,
            "packing": "row_major_grid",
            "packing_tie_break": "lower_index_first",
            "frame_ordering": "frame_position",
            "max_sheet_width": width, "max_sheet_height": height,
            "metadata_schema": "glyph.sheet.v1",
            "metadata_fields": ["duration", "anchors"],
            "color_handling": {"kind": "preserve_rgba"},
            "engine_conventions": {"originCorner": "top_left",
                                   "yAxis": "down", "frameIndexBase": 0},
            "gate_on_seams": False, "loop_count": None,
            "frame_duration_unit": "milliseconds",
        }
        spec.update(over)
        return {"preset": spec}

    def write_export(self, record, label="export"):
        """Write an export's files, in a second process.

        `export.run` returns bytes and writes nothing. The CLI's `export`
        subcommand writes them, and can only be pointed at a preset that
        died with its server through the `preset_declaration` the export
        record carries. Decoding the base64 here instead would make this
        module the PNG writer, and then a bug in my decoding would look
        like a bug in Glyph's export.
        """
        path = os.path.join(self.work, "_preset_%s.json" % label)
        with open(path, "w") as fh:
            json.dump(record["preset_declaration"], fh)
        out = subprocess.run(
            ["node", self.cli, "export", self.project,
             "--preset", "@" + path, "--to", self.work],
            capture_output=True, text=True)
        if out.returncode != 0:
            raise GlyphError("glyph export (%s) failed:\n%s\n%s"
                             % (label, out.stdout[-1500:], out.stderr[-1500:]))
