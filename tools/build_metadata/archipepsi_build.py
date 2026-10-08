#!/usr/bin/env python3
"""Archipepsi review-build metadata: describe, stamp and validate packages.

A review build is the folder ``Archipepsi-<Name>-<sha8>/`` that
tools/crossing_d/package.sh and tools/impact_lab/package.sh zip up: the game
executable, its ``.bat`` launchers, ``README.txt`` and ``SHA256SUMS.txt``,
delivered as one ZIP or as two (``-part1of2.zip``, ``-part2of2.zip``) with the
executable cut into ``.exe.part1`` and ``.exe.part2``.

This tool adds one optional file to that folder, ``archipepsi-build.json``
(the manifest), which states what a launcher would otherwise have to guess:
title, revision, source branch and commit, play modes and their arguments,
the recommended first mode, a description, known limitations and the
integrity data. The standard is docs/build-package-standard.md.

    archipepsi_build.py validate [--strict] [--json] <zips or folders>...
    archipepsi_build.py stamp --spec <spec.json> <package.sh output folder>
    archipepsi_build.py infer <zips or folder>

Packages without a manifest stay valid: ``validate`` and ``infer`` read them
the way the existing packages are laid out. Standard library only.
"""

import argparse
import datetime
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import zipfile

MANIFEST = "archipepsi-build.json"
SCHEMA = "archipepsi-build/1"
SPEC_SCHEMA = "archipepsi-build-spec/1"
SUMS = "SHA256SUMS.txt"
README = "README.txt"

PART_ZIP_RE = re.compile(r"^(?P<stem>.+)-part(?P<n>\d+)of(?P<total>\d+)\.zip$", re.I)
PART_FILE_RE = re.compile(r"^(?P<target>.+)\.part(?P<n>\d+)$", re.I)
FOLDER_RE = re.compile(r"^(?P<product>Archipepsi-.+)-(?P<rev>[0-9a-f]{7,40})$")
README_TITLE_RE = re.compile(r"^(?P<title>.*?)\s*\(revision\s+(?P<rev>[^)\s]+)\)\s*$", re.I)
# start "" "%~dp0Name.exe" -- --empty-yard
START_RE = re.compile(r'^\s*start\s+""\s+"(?:%~dp0)?(?P<exe>[^"]+\.exe)"(?P<args>.*)$', re.I)
# if not "%JOINED%"=="123456" goto broken
SIZE_RE = re.compile(r'"%JOINED%"\s*==\s*"(?P<size>\d+|@SIZE@)"', re.I)
SUM_LINE_RE = re.compile(r"^(?P<hash>[0-9a-fA-F]{64}) [ *](?P<name>.+)$")
MODE_ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
PLATFORMS = ("windows", "linux")


class Problem(Exception):
    """Something that makes a package unusable; the message is plain words."""


def sha256_file(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(chunk), b""):
            h.update(block)
    return h.hexdigest()


def sha256_parts(paths, chunk=1 << 20):
    """The sha256 and size of the files joined end to end, without joining."""
    h, size = hashlib.sha256(), 0
    for p in paths:
        with open(p, "rb") as f:
            for block in iter(lambda: f.read(chunk), b""):
                h.update(block)
                size += len(block)
    return h.hexdigest(), size


def read_text(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


# ------------------------------------------------------------ reading a folder

def read_sums(folder):
    """{name: sha256} from SHA256SUMS.txt; {} when there is none. Raises
    Problem on a malformed line."""
    path = os.path.join(folder, SUMS)
    sums = {}
    if not os.path.isfile(path):
        return sums
    for i, line in enumerate(read_text(path).splitlines(), 1):
        if not line.strip():
            continue
        m = SUM_LINE_RE.match(line.rstrip("\r"))
        if not m:
            raise Problem("%s line %d is not '<sha256>  <file name>'." % (SUMS, i))
        sums[m.group("name")] = m.group("hash").lower()
    return sums


def read_readme_title(folder):
    """(title, revision) from README.txt's first line; ("", "") without one."""
    path = os.path.join(folder, README)
    if not os.path.isfile(path):
        return "", ""
    lines = read_text(path).splitlines()
    first = lines[0].strip() if lines else ""
    m = README_TITLE_RE.match(first)
    return (m.group("title"), m.group("rev")) if m else (first, "")


def read_bat(path):
    """(exe, args, joined size or None) of a .bat launcher's start line and
    its join check. exe is None when it starts nothing."""
    exe, args, size = None, None, None
    for line in read_text(path).splitlines():
        m = SIZE_RE.search(line)
        if m and size is None:
            size = m.group("size")
        m = START_RE.match(line)
        if m and exe is None:
            exe = m.group("exe")
            try:
                args = shlex.split(m.group("args"))
            except ValueError:
                args = m.group("args").split()
    return exe, args, size


def part_files(folder):
    """{target: [part names in order]} for every ``X.partN`` in the folder."""
    groups = {}
    for name in os.listdir(folder):
        m = PART_FILE_RE.match(name)
        if m:
            groups.setdefault(m.group("target"), {})[int(m.group("n"))] = name
    return {t: [p[n] for n in sorted(p)] for t, p in groups.items()}


def _clean_label(bat_name):
    label = re.sub(r"\.bat$", "", bat_name, flags=re.I)
    label = re.sub(r"\s*\(Windows\)\s*$", "", label, flags=re.I)
    label = re.sub(r"^\d+\s*-\s*", "", label)
    label = re.sub(r"^START HERE\s*-\s*", "", label, flags=re.I)
    label = re.sub(r"^Play\s+", "", label, flags=re.I)
    return label.strip() or bat_name


def _mode_id(label, taken):
    base = re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-") or "mode"
    mid, n = base, 2
    while mid in taken:
        mid, n = "%s-%d" % (base, n), n + 1
    return mid


def infer_manifest(folder, zips=()):
    """A manifest for a package that has none, read from its layout the way
    the existing review builds are made (and the way launcher/ reads them).
    Never raises for missing pieces; validate() reports those."""
    name = os.path.basename(os.path.normpath(folder))
    fm = FOLDER_RE.match(name)
    title, rev = read_readme_title(folder)
    title = re.sub(r"^ARCHIPEPSI\s*[-:]\s*", "", title, flags=re.I).strip()
    if title.isupper():
        title = " ".join(w[:1] + w[1:].lower() for w in title.split(" "))
    files = sorted(os.listdir(folder))
    parts = part_files(folder)
    exes = sorted({f for f in files if f.lower().endswith(".exe")} |
                  {t for t in parts if t.lower().endswith(".exe")})
    linux_exes = [f for f in files if f.endswith(".x86_64")]
    platform = "linux" if linux_exes and not exes else "windows"
    modes, recommended, started = [], None, []
    if platform == "windows":
        for bat in [f for f in files if f.lower().endswith(".bat")]:
            exe, args, _ = read_bat(os.path.join(folder, bat))
            if exe is None:
                continue
            started.append(exe)
            if any(m["args"] == args for m in modes):
                continue
            label = ("Standard" if re.search(r"\bjoin\b", bat, re.I)
                     else _clean_label(bat))
            mode = {"id": _mode_id(label, {m["id"] for m in modes}),
                    "label": label, "args": args, "launcher": bat}
            modes.append(mode)
            if recommended is None and "start here" in bat.lower():
                recommended = mode["id"]
    main = [e for e in exes if not e.lower().endswith(".console.exe")]
    if platform == "windows":
        exe = next((e for e in started if e in main), main[0] if main else None)
        console = exe[:-4] + ".console.exe" if exe else None
        if console not in files:
            console = None
    else:
        exe, console = (linux_exes[0] if linux_exes else None), None
        script = next((f for f in files if f.endswith(".sh")), None)
        modes.append({"id": "standard", "label": "Standard", "args": [],
                      "launcher": script})
    if not modes:
        modes.append({"id": "standard", "label": "Standard", "args": [],
                      "launcher": None})
    integrity = {"sums_file": SUMS if SUMS in files else None}
    if exe in parts:
        integrity["split"] = {"parts": [{"name": p} for p in parts[exe]],
                              "zips": [os.path.basename(z) for z in zips]}
    return {
        "schema": SCHEMA,
        "inferred": True,
        "id": name,
        "product": fm.group("product") if fm else name,
        "title": title or (fm.group("product") if fm else name),
        "revision": rev or (fm.group("rev") if fm else ""),
        "source": {"branch": None, "commit": None},
        "platform": platform,
        "executable": exe,
        "console_executable": console,
        "modes": modes,
        "recommended_mode": recommended or modes[0]["id"],
        "description": "",
        "limitations": [],
        "readme": README if README in files else None,
        "integrity": integrity,
    }


# ------------------------------------------------------------ validation

class Report:
    def __init__(self, name):
        self.name = name
        self.errors = []
        self.warnings = []
        self.notes = []
        self.manifest = None

    @property
    def ok(self):
        return not self.errors

    def as_dict(self):
        return {"package": self.name, "ok": self.ok, "errors": self.errors,
                "warnings": self.warnings, "notes": self.notes,
                "manifest": self.manifest}


def _is_str_list(v):
    return isinstance(v, list) and all(isinstance(x, str) for x in v)


def check_schema(m, rep):
    """Shape checks on a manifest dict. Adds errors to rep."""
    err = rep.errors.append
    if not isinstance(m, dict):
        err("%s is not a JSON object." % MANIFEST)
        return
    if m.get("schema") != SCHEMA:
        err('%s: "schema" must be "%s" (found %r).' % (MANIFEST, SCHEMA, m.get("schema")))
    for key in ("id", "product", "title", "revision", "executable", "description"):
        if not isinstance(m.get(key), str) or not m.get(key).strip():
            err('%s: "%s" must be a non-empty string.' % (MANIFEST, key))
    if m.get("platform") not in PLATFORMS:
        err('%s: "platform" must be one of %s.' % (MANIFEST, ", ".join(PLATFORMS)))
    if not _is_str_list(m.get("limitations")):
        err('%s: "limitations" must be a list of strings (it may be empty).' % MANIFEST)
    src = m.get("source")
    if not isinstance(src, dict):
        err('%s: "source" must be an object with "branch" and "commit".' % MANIFEST)
    else:
        for key in ("branch", "commit"):
            if src.get(key) is not None and not isinstance(src.get(key), str):
                err('%s: "source.%s" must be a string or null.' % (MANIFEST, key))
        commit = src.get("commit")
        if isinstance(commit, str) and not re.match(r"^[0-9a-f]{40}$", commit):
            err('%s: "source.commit" must be the full 40-character commit.' % MANIFEST)
    modes = m.get("modes")
    if not isinstance(modes, list) or not modes:
        err('%s: "modes" must list at least one play mode.' % MANIFEST)
        return
    ids = []
    for i, mode in enumerate(modes):
        where = "%s: mode %d" % (MANIFEST, i + 1)
        if not isinstance(mode, dict):
            err("%s is not an object." % where)
            continue
        mid = mode.get("id")
        if not isinstance(mid, str) or not MODE_ID_RE.match(mid):
            err('%s: "id" must be lowercase letters, digits and dashes.' % where)
        elif mid in ids:
            err('%s: the id "%s" is used twice.' % (where, mid))
        ids.append(mid)
        if not isinstance(mode.get("label"), str) or not mode.get("label").strip():
            err('%s: "label" must be a non-empty string.' % where)
        if not _is_str_list(mode.get("args")):
            err('%s: "args" must be a list of strings ([] for none).' % where)
        if mode.get("launcher") is not None and not isinstance(mode.get("launcher"), str):
            err('%s: "launcher" must be a file name or null.' % where)
        if mode.get("description") is not None and not isinstance(mode.get("description"), str):
            err('%s: "description" must be a string.' % where)
    if m.get("recommended_mode") not in ids:
        err('%s: "recommended_mode" must be the id of one of its modes.' % MANIFEST)
    integ = m.get("integrity")
    if not isinstance(integ, dict):
        err('%s: "integrity" must be an object.' % MANIFEST)
        return
    ex = integ.get("executable")
    if not (isinstance(ex, dict) and isinstance(ex.get("size"), int)
            and isinstance(ex.get("sha256"), str) and SHA_RE.match(ex["sha256"])):
        err('%s: "integrity.executable" must give the size and sha256 of the '
            'whole executable.' % MANIFEST)
    split = integ.get("split")
    if split is not None:
        ok = isinstance(split, dict) and isinstance(split.get("parts"), list) \
            and len(split["parts"]) >= 2 and _is_str_list(split.get("zips"))
        for p in (split.get("parts") or []) if isinstance(split, dict) else []:
            ok = ok and isinstance(p, dict) and isinstance(p.get("name"), str) \
                and isinstance(p.get("size"), int) \
                and isinstance(p.get("sha256"), str) and bool(SHA_RE.match(p["sha256"]))
        if not ok:
            err('%s: "integrity.split" must list two or more parts (name, size, '
                'sha256) and the zips they come in.' % MANIFEST)
    for f in integ.get("files") or []:
        if not (isinstance(f, dict) and isinstance(f.get("name"), str)
                and isinstance(f.get("sha256"), str) and SHA_RE.match(f["sha256"])):
            err('%s: every "integrity.files" entry needs a name and sha256.' % MANIFEST)


def check_folder(folder, m, rep, inferred):
    """Check the unpacked folder against its manifest (given or inferred)."""
    err, warn, note = rep.errors.append, rep.warnings.append, rep.notes.append
    name = os.path.basename(os.path.normpath(folder))
    files = set(os.listdir(folder))
    if not inferred and m.get("id") != name:
        err('The folder is "%s" but the manifest says its id is "%s".' % (name, m.get("id")))
    fm = FOLDER_RE.match(name)
    if not fm:
        warn('The folder name "%s" is not Archipepsi-<Name>-<revision>.' % name)
    elif m.get("revision") and fm.group("rev") != m.get("revision"):
        err('The folder name says revision %s but the build says %s.'
            % (fm.group("rev"), m.get("revision")))
    if fm and not inferred and m.get("product") != fm.group("product"):
        err('The folder name says product %s but the manifest says %s.'
            % (fm.group("product"), m.get("product")))
    commit = (m.get("source") or {}).get("commit")
    if commit and m.get("revision") and not commit.startswith(m["revision"]):
        err("The revision %s is not the start of the source commit %s."
            % (m["revision"], commit))
    if not inferred and not commit:
        warn("The manifest does not record the source commit.")
    # README
    if README not in files:
        warn("There is no README.txt for the player.")
    else:
        _, rrev = read_readme_title(folder)
        if not rrev:
            warn("README.txt's first line has no '(revision ...)'.")
        elif m.get("revision") and rrev != m["revision"]:
            err("README.txt says revision %s, the build is %s: the README is "
                "from another build." % (rrev, m["revision"]))
        if "@REVISION@" in read_text(os.path.join(folder, README)):
            err("README.txt still has the @REVISION@ placeholder.")
    # Executable: whole, or in parts.
    exe = m.get("executable")
    parts = part_files(folder)
    integ = m.get("integrity") or {}
    whole = integ.get("executable") or {}
    split = integ.get("split")
    if not exe:
        err("No game executable found in the package.")
        return
    exe_hash = exe_size = None
    if exe in files:
        exe_size = os.path.getsize(os.path.join(folder, exe))
        exe_hash = sha256_file(os.path.join(folder, exe))
        if exe in parts:
            warn("Both %s and its parts are present; the parts are left over." % exe)
    elif exe in parts:
        names = parts[exe]
        numbers = [int(PART_FILE_RE.match(p).group("n")) for p in names]
        if numbers != list(range(1, len(numbers) + 1)) or len(numbers) < 2:
            err("%s is incomplete: only %s arrived. Unzip every part ZIP into "
                "the same folder." % (exe, ", ".join("part%d" % n for n in numbers)))
            return
        if split and len(split.get("parts") or []) != len(names):
            err("%s should come in %d parts but %d are here."
                % (exe, len(split["parts"]), len(names)))
            return
        if split and not inferred:
            for p, want in zip(names, split["parts"]):
                path = os.path.join(folder, p)
                if p != want.get("name"):
                    err("Found part %s where %s was expected." % (p, want.get("name")))
                elif os.path.getsize(path) != want.get("size") or \
                        sha256_file(path) != want.get("sha256"):
                    err("%s does not match the build: it is damaged or from a "
                        "different build. Download that part again." % p)
            if rep.errors:
                return
        exe_hash, exe_size = sha256_parts([os.path.join(folder, p) for p in names])
        note("%s joined from %d parts in memory: %d bytes." % (exe, len(names), exe_size))
    else:
        err("The game executable %s is not in the package." % exe)
        return
    if whole:
        if exe_size != whole.get("size"):
            err("%s is %d bytes but should be %d: a part is missing, damaged "
                "or from another build." % (exe, exe_size, whole.get("size")))
        elif exe_hash != whole.get("sha256"):
            err("%s does not match the build's checksum: a part is damaged or "
                "from another build." % exe)
        else:
            note("%s matches the manifest's size and sha256." % exe)
    console = m.get("console_executable")
    if console and console not in files:
        err("The log-window twin %s is missing." % console)
    # SHA256SUMS.txt covers every file; manifest files cover the rest.
    sums = read_sums(folder)
    extra = {f["name"]: f["sha256"] for f in integ.get("files") or []
             if isinstance(f, dict)}
    if not sums:
        (warn if inferred else err)("There is no %s, so the files cannot be "
                                    "checked." % SUMS)
    else:
        if exe not in sums:
            err("%s does not list the game executable %s." % (SUMS, exe))
        checked = 0
        for fname, want in sorted(sums.items()):
            if fname in (SUMS, MANIFEST):
                continue
            if fname == exe and exe not in files:
                got = exe_hash
            elif fname not in files:
                err("%s is listed in %s but missing from the package." % (fname, SUMS))
                continue
            else:
                got = exe_hash if fname == exe else sha256_file(os.path.join(folder, fname))
            if got != want:
                err("%s does not match its checksum: the download is damaged or "
                    "mixes two builds. Download it again." % fname)
            checked += 1
        note("%d files match %s." % (checked, SUMS))
    covered = set(sums) | set(extra) | {SUMS, MANIFEST}
    for p in parts.get(exe, []):
        covered.add(p)
    for fname in sorted(files - covered):
        if os.path.isdir(os.path.join(folder, fname)):
            err("Unexpected sub-folder %s in the package." % fname)
        else:
            (warn if inferred else err)(
                "%s is in the package but nothing checks it (not in %s)." % (fname, SUMS))
    for fname, want in sorted(extra.items()):
        if fname not in files:
            err("%s is listed in the manifest but missing." % fname)
        elif sha256_file(os.path.join(folder, fname)) != want:
            err("%s does not match the manifest's checksum." % fname)
    # Launchers agree with the modes they belong to.
    ids = set()
    for mode in m.get("modes") or []:
        launcher = mode.get("launcher")
        ids.add(mode.get("id"))
        if not launcher:
            continue
        path = os.path.join(folder, launcher)
        if not os.path.isfile(path):
            err('Mode "%s" names the launcher %s, which is missing.'
                % (mode.get("label"), launcher))
            continue
        if launcher.lower().endswith(".bat"):
            bexe, bargs, _ = read_bat(path)
            if bexe != exe:
                err("%s starts %s, not the game %s." % (launcher, bexe, exe))
            elif bargs != mode.get("args"):
                err('%s starts the game with %s but mode "%s" says %s.'
                    % (launcher, bargs, mode.get("label"), mode.get("args")))
    for fname in sorted(f for f in files if f.lower().endswith(".bat")):
        _, _, size = read_bat(os.path.join(folder, fname))
        if size == "@SIZE@":
            err("%s still has the @SIZE@ placeholder." % fname)
        elif size is not None and int(size) != exe_size:
            err("%s expects the joined game to be %s bytes, but it is %d."
                % (fname, size, exe_size))
    if inferred and m["platform"] == "windows" and not any(
            "start here" in (mm.get("launcher") or "").lower() for mm in m["modes"]):
        warn("No launcher is marked START HERE; the first mode is taken as "
             "the recommended one.")


def _safe_member(name):
    n = name.replace("\\", "/")
    return not (n.startswith("/") or ".." in n.split("/") or ":" in n)


def unpack(zips, dest):
    """Unpack a package's zips into dest and return its folder. Raises
    Problem on anything a player's download could get wrong."""
    tops = set()
    seen = {}
    for z in zips:
        base = os.path.basename(z)
        try:
            zf = zipfile.ZipFile(z)
        except (zipfile.BadZipFile, OSError) as e:
            raise Problem("%s is not a readable ZIP (%s); it may not have finished "
                          "downloading." % (base, e))
        with zf:
            bad = zf.testzip()
            if bad is not None:
                raise Problem("%s is damaged (%s fails its check). Download it "
                              "again." % (base, bad))
            for info in zf.infolist():
                n = info.filename.replace("\\", "/")
                if n.startswith("__MACOSX/"):
                    continue
                if not _safe_member(info.filename):
                    raise Problem("%s contains an unsafe path: %s" % (base, info.filename))
                if n in seen and not n.endswith("/"):
                    raise Problem("%s and %s both contain %s." % (seen[n], base, n))
                seen[n] = base
                tops.add(n.split("/")[0])
                if "/" not in n.rstrip("/"):
                    if not info.is_dir():
                        raise Problem("%s has loose files at its top (%s); a review "
                                      "build holds one folder." % (base, n))
            for info in zf.infolist():
                if not info.filename.replace("\\", "/").startswith("__MACOSX/"):
                    zf.extract(info, dest)
    if len(tops) != 1:
        raise Problem("The ZIP(s) hold %d top folders (%s), not one."
                      % (len(tops), ", ".join(sorted(tops)) or "none"))
    return os.path.join(dest, tops.pop())


def group_zips(paths):
    """[(label, [zips])]: part ZIPs with the same stem go together, sorted
    by part number. Missing parts are reported by validate."""
    groups, by_stem = [], {}
    for p in paths:
        m = PART_ZIP_RE.match(os.path.basename(p))
        if m:
            key = m.group("stem").lower()
            if key not in by_stem:
                by_stem[key] = []
                groups.append((m.group("stem"), by_stem[key]))
            by_stem[key].append(p)
        else:
            groups.append((os.path.basename(p), [p]))
    for _, zs in groups:
        zs.sort(key=lambda z: int(PART_ZIP_RE.match(os.path.basename(z)).group("n"))
                if PART_ZIP_RE.match(os.path.basename(z)) else 0)
    return groups


def check_zip_set(label, zips, rep):
    m0 = PART_ZIP_RE.match(os.path.basename(zips[0]))
    if not m0:
        return
    total = int(m0.group("total"))
    have = []
    for z in zips:
        m = PART_ZIP_RE.match(os.path.basename(z))
        if int(m.group("total")) != total:
            rep.errors.append("%s says %s parts, the others say %d."
                              % (os.path.basename(z), m.group("total"), total))
        have.append(int(m.group("n")))
    missing = [n for n in range(1, total + 1) if n not in have]
    if missing:
        rep.errors.append("This build came in %d ZIPs and these are missing: %s."
                          % (total, ", ".join("%s-part%dof%d.zip" % (m0.group("stem"), n, total)
                                              for n in missing)))


def validate_package(label, zips=None, folder=None, strict=False):
    rep = Report(label)
    tmp = None
    try:
        if zips:
            check_zip_set(label, zips, rep)
            if rep.errors:
                return rep
            tmp = tempfile.mkdtemp(prefix="archipepsi-validate-")
            folder = unpack(zips, tmp)
        path = os.path.join(folder, MANIFEST)
        inferred = not os.path.isfile(path)
        if inferred:
            (rep.errors if strict else rep.warnings).append(
                "No %s: an older package; its details were read from its "
                "file names, launchers and README." % MANIFEST)
            m = infer_manifest(folder, zips or ())
        else:
            try:
                m = json.loads(read_text(path))
            except ValueError as e:
                raise Problem("%s is not valid JSON (%s)." % (MANIFEST, e))
            check_schema(m, rep)
            if rep.errors:
                return rep
            split = (m.get("integrity") or {}).get("split")
            if zips and split and sorted(split.get("zips") or []) != \
                    sorted(os.path.basename(z) for z in zips):
                rep.warnings.append("The manifest names the zips %s; these are "
                                    "%s (renamed downloads are fine if the "
                                    "checks pass)." % (", ".join(split["zips"]),
                                    ", ".join(os.path.basename(z) for z in zips)))
        rep.manifest = m
        check_folder(folder, m, rep, inferred)
    except Problem as e:
        rep.errors.append(str(e))
    finally:
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)
    return rep


# ------------------------------------------------------------ stamping

def load_spec(path):
    spec = json.loads(read_text(path))
    probs = []
    if spec.get("schema") != SPEC_SCHEMA:
        probs.append('"schema" must be "%s"' % SPEC_SCHEMA)
    for key in ("title", "description", "executable"):
        if not isinstance(spec.get(key), str) or not spec[key].strip():
            probs.append('"%s" must be a non-empty string' % key)
    if not _is_str_list(spec.get("limitations", [])):
        probs.append('"limitations" must be a list of strings')
    modes = spec.get("modes")
    if not isinstance(modes, list) or not modes:
        probs.append('"modes" must list at least one mode')
        modes = []
    ids = [mm.get("id") for mm in modes if isinstance(mm, dict)]
    for mm in modes:
        if not isinstance(mm, dict) or not MODE_ID_RE.match(str(mm.get("id"))) \
                or not isinstance(mm.get("label"), str) or not _is_str_list(mm.get("args")):
            probs.append("every mode needs an id (a-z, 0-9, -), a label and args (a list)")
            break
    if len(set(ids)) != len(ids):
        probs.append("mode ids must be unique")
    if spec.get("recommended_mode") not in ids:
        probs.append('"recommended_mode" must be one of the mode ids')
    if probs:
        raise Problem("%s: %s." % (path, "; ".join(probs)))
    return spec


def git_source(repo, revision):
    """(branch or None, full commit or None) when repo's HEAD is revision."""
    def run(*args):
        try:
            return subprocess.check_output(("git", "-C", repo) + args,
                                           stderr=subprocess.DEVNULL, text=True).strip()
        except (OSError, subprocess.CalledProcessError):
            return None
    commit = run("rev-parse", "HEAD")
    if not commit or not commit.startswith(revision):
        return None, None
    branch = run("rev-parse", "--abbrev-ref", "HEAD")
    return (None if branch in (None, "HEAD") else branch), commit


def build_manifest(spec, folder, platform, source, built_at, zips=()):
    name = os.path.basename(os.path.normpath(folder))
    fm = FOLDER_RE.match(name)
    if not fm:
        raise Problem('"%s" is not an Archipepsi-<Name>-<revision> folder.' % name)
    base = spec["executable"]
    exe = base + (".exe" if platform == "windows" else ".x86_64")
    console = base + ".console.exe" if platform == "windows" else None
    files = set(os.listdir(folder))
    if console not in files:
        console = None
    parts = part_files(folder)
    integrity = {"sums_file": SUMS}
    if exe in files:
        p = os.path.join(folder, exe)
        integrity["executable"] = {"size": os.path.getsize(p), "sha256": sha256_file(p)}
    elif exe in parts:
        paths = [os.path.join(folder, n) for n in parts[exe]]
        h, size = sha256_parts(paths)
        integrity["executable"] = {"size": size, "sha256": h}
        integrity["split"] = {
            "parts": [{"name": n, "size": os.path.getsize(p), "sha256": sha256_file(p)}
                      for n, p in zip(parts[exe], paths)],
            "zips": [os.path.basename(z) for z in zips]}
    else:
        raise Problem("%s has no %s (or its parts)." % (name, exe))
    sums = read_sums(folder)
    extra = sorted(f for f in files - set(sums) - {SUMS, MANIFEST}
                   - set(parts.get(exe, [])) if os.path.isfile(os.path.join(folder, f)))
    if extra:
        integrity["files"] = [{"name": f, "sha256": sha256_file(os.path.join(folder, f))}
                              for f in extra]
    modes = []
    for mm in spec["modes"]:
        launcher = (mm.get("launchers") or {}).get(platform)
        mode = {"id": mm["id"], "label": mm["label"], "args": list(mm["args"]),
                "launcher": launcher if launcher in files else None}
        if mm.get("description"):
            mode["description"] = mm["description"]
        modes.append(mode)
    return {
        "schema": SCHEMA,
        "id": name,
        "product": fm.group("product"),
        "title": spec["title"],
        "revision": fm.group("rev"),
        "source": {"branch": source[0], "commit": source[1]},
        "built_at": built_at,
        "platform": platform,
        "executable": exe,
        "console_executable": console,
        "modes": modes,
        "recommended_mode": spec["recommended_mode"],
        "description": spec["description"],
        "limitations": list(spec.get("limitations", [])),
        "readme": README if README in files else None,
        "integrity": integrity,
    }


def _write_manifest(folder, manifest):
    with open(os.path.join(folder, MANIFEST), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")


def _add_to_zip(zip_path, folder_name, manifest_path):
    with zipfile.ZipFile(zip_path) as zf:
        if "%s/%s" % (folder_name, MANIFEST) in zf.namelist():
            raise Problem("%s already holds a manifest. Run package.sh again "
                          "before stamping." % os.path.basename(zip_path))
    with zipfile.ZipFile(zip_path, "a", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(manifest_path, "%s/%s" % (folder_name, MANIFEST))


def stamp(spec_path, out, branch=None, commit=None, repo=None, built_at=None):
    """Write the manifest into every package folder package.sh left in out
    (windows/, windows-split/, linux/) and add it to the matching zips (the
    two-part set carries it in part 1). Returns the zips it changed."""
    spec = load_spec(spec_path)
    built_at = built_at or datetime.datetime.now(datetime.timezone.utc) \
        .replace(microsecond=0).isoformat().replace("+00:00", "Z")
    done = []
    for kind in ("windows", "windows-split", "linux"):
        d = os.path.join(out, kind)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            folder = os.path.join(d, name)
            if not os.path.isdir(folder):
                continue
            platform = "linux" if kind == "linux" else "windows"
            if kind == "windows-split":
                zips = sorted(z for z in os.listdir(out)
                              if PART_ZIP_RE.match(z)
                              and PART_ZIP_RE.match(z).group("stem") == name + "-windows")
                carrier = next((z for z in zips if PART_ZIP_RE.match(z).group("n") == "1"),
                               None)
            else:
                zips = [z for z in ["%s-%s.zip" % (name, kind)]
                        if os.path.isfile(os.path.join(out, z))]
                carrier = zips[0] if zips else None
            rev = FOLDER_RE.match(name).group("rev") if FOLDER_RE.match(name) else ""
            if commit:
                if not commit.startswith(rev):
                    raise Problem("--commit %s is not revision %s." % (commit, rev))
                source = (branch, commit)
            else:
                source = git_source(repo or os.getcwd(), rev)
                source = (branch or source[0], source[1])
            manifest = build_manifest(spec, folder, platform, source, built_at,
                                      [os.path.join(out, z) for z in zips])
            _write_manifest(folder, manifest)
            if carrier:
                _add_to_zip(os.path.join(out, carrier), name, os.path.join(folder, MANIFEST))
                done.append(os.path.join(out, carrier))
    if not done:
        raise Problem("No package zips found in %s; give the folder package.sh "
                      "wrote to." % out)
    return done


# ------------------------------------------------------------ command line

def _targets(paths):
    """[(label, zips or None, folder or None)] from the command line."""
    zips, out = [], []
    for p in paths:
        if os.path.isdir(p):
            out.append((os.path.basename(os.path.normpath(p)), None, p))
        elif p.lower().endswith(".zip"):
            zips.append(p)
        else:
            raise Problem("%s is neither a ZIP nor a folder." % p)
    for label, zs in group_zips(zips):
        label = re.sub(r"\.zip$", "", label, flags=re.I)
        if PART_ZIP_RE.match(os.path.basename(zs[0])):
            label += " (%d part ZIPs)" % len(zs)
        out.append((label, zs, None))
    return out


def _print_report(rep, verbose):
    status = "PASS" if rep.ok else "FAIL"
    print("%s  %s" % (status, rep.name))
    m = rep.manifest
    if m and verbose:
        rec = next((x for x in m["modes"] if x["id"] == m["recommended_mode"]), None)
        print("      %s, revision %s (%s)%s" % (m["title"], m["revision"], m["platform"],
              ", metadata inferred" if m.get("inferred") else ""))
        src = m.get("source") or {}
        if src.get("commit"):
            print("      from %s %s" % (src.get("branch") or "(no branch)", src["commit"]))
        for x in m["modes"]:
            print("      mode %-14s %s%s" % (x["id"], " ".join(x["args"]) or "(no arguments)",
                  "   <- start here" if x is rec else ""))
    for e in rep.errors:
        print("  error:   %s" % e)
    for w in rep.warnings:
        print("  warning: %s" % w)
    if verbose:
        for n in rep.notes:
            print("  ok:      %s" % n)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    v = sub.add_parser("validate", help="check packages (ZIPs or unpacked folders)")
    v.add_argument("paths", nargs="+")
    v.add_argument("--strict", action="store_true",
                   help="a package without a manifest fails (for new builds)")
    v.add_argument("--json", action="store_true", help="machine-readable output")
    v.add_argument("-q", "--quiet", action="store_true", help="only PASS/FAIL and problems")
    s = sub.add_parser("stamp", help="add the manifest to package.sh's output")
    s.add_argument("out", help="the output folder given to package.sh")
    s.add_argument("--spec", required=True, help="the build's spec JSON")
    s.add_argument("--branch", help="source branch (default: the repo's current branch)")
    s.add_argument("--commit", help="source commit (default: the repo's HEAD, if it "
                                     "is the packaged revision)")
    s.add_argument("--repo", help="the checkout that was packaged (default: here)")
    s.add_argument("--built-at", help=argparse.SUPPRESS)
    i = sub.add_parser("infer", help="print the manifest an older package implies")
    i.add_argument("paths", nargs="+")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "stamp":
            for z in stamp(args.spec, args.out, args.branch, args.commit, args.repo,
                           args.built_at):
                print("stamped %s" % z)
            return 0
        targets = _targets(args.paths)
        if args.cmd == "infer":
            for label, zips, folder in targets:
                tmp = tempfile.mkdtemp(prefix="archipepsi-infer-") if zips else None
                try:
                    f = unpack(zips, tmp) if zips else folder
                    path = os.path.join(f, MANIFEST)
                    m = json.loads(read_text(path)) if os.path.isfile(path) \
                        else infer_manifest(f, zips or ())
                    print(json.dumps(m, indent=2, ensure_ascii=False))
                finally:
                    if tmp:
                        shutil.rmtree(tmp, ignore_errors=True)
            return 0
        reports = [validate_package(label, zips, folder, args.strict)
                   for label, zips, folder in targets]
        if args.json:
            print(json.dumps([r.as_dict() for r in reports], indent=2, ensure_ascii=False))
        else:
            for r in reports:
                _print_report(r, not args.quiet)
        return 0 if all(r.ok for r in reports) else 1
    except Problem as e:
        print("error: %s" % e, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
