"""The build library: importing review-build ZIPs, verifying them, reading
their play modes, and launching them.

No GUI code lives here, so it can be tested on any platform.

A review build, as tools/crossing_d/package.sh and tools/impact_lab/package.sh
deliver it, is a ZIP holding one folder, ``Archipepsi-<Name>-<sha8>/``, with:

- the game executable and its ``.console.exe`` twin;
- one or more ``.bat`` launchers, each ending in ``start "" "<exe>" [args]``;
- ``README.txt`` (first line: the title and ``(revision <sha8>)``);
- ``SHA256SUMS.txt`` covering the whole executable.

The same folder may come as two ZIPs (``...-part1of2.zip``,
``...-part2of2.zip``) with the executable cut into ``.exe.part1`` and
``.exe.part2``. The launcher joins the parts itself and checks the result
against SHA256SUMS.txt and the size written into the ``.bat`` files.
"""

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
import uuid
import zipfile

LIBRARY_VERSION = 1

PART_ZIP_RE = re.compile(r"^(?P<stem>.+)-part(?P<n>\d+)of(?P<total>\d+)\.zip$", re.I)
PART_FILE_RE = re.compile(r"^(?P<target>.+)\.part(?P<n>\d+)$", re.I)
REVISION_SUFFIX_RE = re.compile(r"^(?P<product>.+)-(?P<rev>[0-9a-f]{7,40})$", re.I)
README_TITLE_RE = re.compile(r"^(?P<title>.*?)\s*\(revision\s+(?P<rev>[^)\s]+)\)\s*$", re.I)
# start "" "%~dp0Name.exe" -- --empty-yard
START_RE = re.compile(r'^\s*start\s+""\s+"(?:%~dp0)?(?P<exe>[^"]+\.exe)"(?P<args>.*)$', re.I)
# if not "%JOINED%"=="123456" goto broken
SIZE_RE = re.compile(r'"%JOINED%"\s*==\s*"(?P<size>\d+)"', re.I)


class ImportError_(Exception):
    """A package could not be imported; the message is for the player."""


def default_home():
    env = os.environ.get("ARCHIPEPSI_LAUNCHER_HOME")
    if env:
        return env
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
        return os.path.join(base, "ArchipepsiLauncher")
    base = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(base, "archipepsi-launcher")


def sha256_file(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(chunk), b""):
            h.update(block)
    return h.hexdigest()


def _now():
    return datetime.datetime.now().replace(microsecond=0).isoformat()


# --------------------------------------------------------------- selection

def _top_folder(zip_path):
    """The single top-level folder a ZIP holds, or None."""
    try:
        with zipfile.ZipFile(zip_path) as zf:
            tops = {n.replace("\\", "/").split("/")[0] for n in zf.namelist()}
    except (zipfile.BadZipFile, OSError):
        return None
    tops.discard("__MACOSX")
    return tops.pop() if len(tops) == 1 else None


def expand_selection(paths):
    """Group the chosen ZIPs into packages, adding any sibling parts the
    player did not select. ZIPs that unpack into the same folder belong
    to one package (so a part renamed by a browser, e.g. "part2of2 (1).zip",
    still joins its partner when both are chosen). Returns a list of lists
    of ZIP paths, one list per package. Raises ImportError_ if a named part
    is missing."""
    chosen = []
    for p in paths:
        p = os.path.abspath(p)
        if p not in chosen:
            chosen.append(p)
    for p in list(chosen):
        m = PART_ZIP_RE.match(os.path.basename(p))
        if not m:
            continue
        folder, stem, total = os.path.dirname(p), m.group("stem"), int(m.group("total"))
        have = set()
        for q in chosen:
            mq = PART_ZIP_RE.match(os.path.basename(q))
            if mq and mq.group("stem") == stem:
                have.add(int(mq.group("n")))
        missing = []
        for n in range(1, total + 1):
            if n in have:
                continue
            name = "%s-part%dof%d.zip" % (stem, n, total)
            sibling = os.path.join(folder, name)
            if os.path.isfile(sibling):
                chosen.append(sibling)
                have.add(n)
            else:
                missing.append(name)
        if missing and not _covered_by_other_choice(p, chosen):
            raise ImportError_(
                "This build came in %d parts, and these are not next to the "
                "others:\n  %s\nPut every part in one folder (or choose all "
                "of them together) and try again." % (total, "\n  ".join(missing)))
    groups = []
    by_top = {}
    for p in chosen:
        top = _top_folder(p)
        if top is None:
            groups.append([p])
        elif top in by_top:
            by_top[top].append(p)
        else:
            by_top[top] = [p]
            groups.append(by_top[top])
    for g in groups:
        g.sort(key=_part_number)
    return groups


def _part_number(path):
    m = PART_ZIP_RE.match(os.path.basename(path))
    return int(m.group("n")) if m else 0


def _covered_by_other_choice(path, chosen):
    """A chosen ZIP that is not named as a part but unpacks into the same
    folder may be the renamed missing part."""
    top = _top_folder(path)
    return top is not None and any(
        q != path and not PART_ZIP_RE.match(os.path.basename(q)) and _top_folder(q) == top
        for q in chosen)


# --------------------------------------------------------------- extraction

def _safe_extract(zip_path, dest):
    try:
        zf = zipfile.ZipFile(zip_path)
    except (zipfile.BadZipFile, OSError) as e:
        raise ImportError_("%s is not a readable ZIP (%s). It may not have "
                           "finished downloading." % (os.path.basename(zip_path), e))
    with zf:
        dest_real = os.path.realpath(dest)
        for info in zf.infolist():
            name = info.filename.replace("\\", "/")
            if name.startswith("/") or ".." in name.split("/") or ":" in name:
                raise ImportError_("%s contains an unsafe path: %s"
                                   % (os.path.basename(zip_path), info.filename))
            target = os.path.realpath(os.path.join(dest, name))
            if not (target == dest_real or target.startswith(dest_real + os.sep)):
                raise ImportError_("%s contains an unsafe path: %s"
                                   % (os.path.basename(zip_path), info.filename))
        try:
            zf.extractall(dest)
        except (zipfile.BadZipFile, OSError, EOFError) as e:
            raise ImportError_("Could not unpack %s (%s). Try downloading it "
                               "again." % (os.path.basename(zip_path), e))


def _package_root(staging, fallback_name):
    """The folder the package unpacked into. Review builds hold exactly one
    top folder; a ZIP with loose files is moved into one named after it."""
    entries = [e for e in os.listdir(staging) if not e.startswith("__MACOSX")]
    if len(entries) == 1 and os.path.isdir(os.path.join(staging, entries[0])):
        return os.path.join(staging, entries[0])
    root = os.path.join(staging, fallback_name)
    os.mkdir(root)
    for e in entries:
        shutil.move(os.path.join(staging, e), os.path.join(root, e))
    return root


def join_parts(folder):
    """Join every ``X.part1 .. X.partN`` in folder into X. Returns the list
    of joined file names."""
    groups = {}
    for name in os.listdir(folder):
        m = PART_FILE_RE.match(name)
        if m:
            groups.setdefault(m.group("target"), {})[int(m.group("n"))] = name
    joined = []
    for target, parts in sorted(groups.items()):
        numbers = sorted(parts)
        if len(numbers) < 2 or numbers != list(range(1, len(numbers) + 1)):
            have = ", ".join("part%d" % n for n in numbers)
            raise ImportError_("%s is incomplete: only %s arrived. Add the "
                               "missing part ZIP and try again." % (target, have))
        out = os.path.join(folder, target)
        with open(out, "wb") as dst:
            for n in numbers:
                with open(os.path.join(folder, parts[n]), "rb") as src:
                    shutil.copyfileobj(src, dst, 1 << 20)
        for n in numbers:
            os.remove(os.path.join(folder, parts[n]))
        joined.append(target)
    return joined


# --------------------------------------------------------------- reading

def read_sums(folder):
    path = os.path.join(folder, "SHA256SUMS.txt")
    sums = {}
    if not os.path.isfile(path):
        return sums
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\r\n")
            m = re.match(r"^([0-9a-fA-F]{64}) [ *](.+)$", line)
            if m:
                sums[m.group(2)] = m.group(1).lower()
    return sums


def read_bats(folder):
    """[(bat file name, text)] in name order."""
    out = []
    for name in sorted(os.listdir(folder)):
        if name.lower().endswith(".bat"):
            with open(os.path.join(folder, name), encoding="utf-8", errors="replace") as f:
                out.append((name, f.read()))
    return out


def mode_label(bat_name):
    label = bat_name[:-4]
    label = re.sub(r"\s*\((?:Windows)\)\s*$", "", label, flags=re.I)
    label = re.sub(r"^\d+\s*-\s*", "", label)
    label = re.sub(r"^START HERE\s*-\s*", "", label, flags=re.I)
    label = re.sub(r"^Play\s+", "", label, flags=re.I)
    return label.strip() or bat_name


def read_modes(folder, bats=None):
    """The play modes the package's .bat launchers offer, as
    [{"label", "args", "recommended", "source"}], recommended first. The
    executable they start is returned too."""
    bats = read_bats(folder) if bats is None else bats
    modes = []
    exe_names = []
    for name, text in bats:
        for line in text.splitlines():
            m = START_RE.match(line)
            if not m:
                continue
            exe_names.append(m.group("exe"))
            try:
                args = shlex.split(m.group("args"))
            except ValueError:
                args = m.group("args").split()
            if any(mm["args"] == args for mm in modes):
                break
            if re.search(r"\bjoin\b", name, re.I):
                label = "Standard (plain executable)"
            else:
                label = mode_label(name)
            modes.append({
                "label": label,
                "args": args,
                "recommended": "start here" in name.lower(),
                "source": name,
            })
            break
    modes.sort(key=lambda mm: not mm["recommended"])
    return modes, exe_names


def find_exe(folder, exe_names):
    exes = [n for n in os.listdir(folder)
            if n.lower().endswith(".exe") and not n.lower().endswith(".console.exe")]
    for n in exe_names:
        if n in exes:
            return n
    if len(exes) == 1:
        return exes[0]
    return sorted(exes)[0] if exes else None


def read_readme(folder):
    path = os.path.join(folder, "README.txt")
    if not os.path.isfile(path):
        return "", "", "", ""
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    lines = text.splitlines()
    title, rev = "", ""
    if lines:
        m = README_TITLE_RE.match(lines[0].strip())
        if m:
            title, rev = m.group("title"), m.group("rev")
        else:
            title = lines[0].strip()
    # The summary is the first paragraph after the title line.
    summary = []
    for line in lines[1:]:
        if not line.strip():
            if summary:
                break
            continue
        summary.append(line.strip())
    return title, rev, " ".join(summary), text


def nice_title(title, folder_name):
    t = re.sub(r"^ARCHIPEPSI\s*[-:]\s*", "", title.strip(), flags=re.I)
    if not t:
        m = REVISION_SUFFIX_RE.match(folder_name)
        t = (m.group("product") if m else folder_name)
        t = re.sub(r"^Archipepsi-", "", t).replace("-", " ")
    if t.isupper():
        t = " ".join(w if len(w) <= 1 else w[0] + w[1:].lower() for w in t.split(" "))
    return t


def product_key(folder_name):
    m = REVISION_SUFFIX_RE.match(folder_name)
    return m.group("product") if m else folder_name


# --------------------------------------------------------------- verification

def verify_folder(folder, exe, bats):
    """Check the folder against SHA256SUMS.txt and the joined size the
    .bat files expect. Returns (exe sha256, list of check notes). Raises
    ImportError_ on any mismatch."""
    notes = []
    sums = read_sums(folder)
    exe_path = os.path.join(folder, exe)
    exe_hash = sha256_file(exe_path)
    if sums:
        checked = 0
        for name, want in sums.items():
            if name == "SHA256SUMS.txt":
                continue
            path = os.path.join(folder, name)
            if not os.path.isfile(path):
                raise ImportError_("%s is listed in SHA256SUMS.txt but is not in "
                                   "the package." % name)
            got = exe_hash if name == exe else sha256_file(path)
            if got != want:
                raise ImportError_(
                    "%s does not match its checksum: the download is damaged or "
                    "a part is from a different build. Download it again." % name)
            checked += 1
        if exe not in sums:
            notes.append("SHA256SUMS.txt does not list %s" % exe)
        notes.append("%d files match SHA256SUMS.txt" % checked)
    else:
        notes.append("no SHA256SUMS.txt in the package: checksums not verified")
    size = os.path.getsize(exe_path)
    for name, text in bats:
        m = SIZE_RE.search(text)
        if m and "@SIZE@" not in text:
            want = int(m.group("size"))
            if want != size:
                raise ImportError_("%s is %d bytes, but %s expects %d. Download "
                                   "the parts again." % (exe, size, name, want))
            notes.append("size %d bytes matches %s" % (size, name))
            break
    return exe_hash, notes


# --------------------------------------------------------------- library

class Library:
    def __init__(self, home=None):
        self.home = os.path.abspath(home or default_home())
        self.builds_dir = os.path.join(self.home, "builds")
        self.staging_dir = os.path.join(self.home, "staging")
        self.index_path = os.path.join(self.home, "library.json")
        os.makedirs(self.builds_dir, exist_ok=True)
        self.builds = []
        self.load()

    # -- persistence
    def load(self):
        self.builds = []
        if os.path.isfile(self.index_path):
            try:
                with open(self.index_path, encoding="utf-8") as f:
                    data = json.load(f)
                self.builds = list(data.get("builds", []))
            except (OSError, ValueError):
                # Keep the unreadable index for inspection; start empty.
                shutil.copyfile(self.index_path, self.index_path + ".unreadable")
        return self.builds

    def save(self):
        data = {"version": LIBRARY_VERSION, "builds": self.builds}
        fd, tmp = tempfile.mkstemp(dir=self.home, prefix="library-", suffix=".tmp")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, self.index_path)

    # -- queries
    def get(self, build_id):
        for b in self.builds:
            if b["id"] == build_id:
                return b
        return None

    def folder(self, build):
        return os.path.join(self.builds_dir, build["id"])

    def status(self, build):
        exe = os.path.join(self.folder(build), build["exe"])
        if not os.path.isfile(exe):
            return "missing"
        if os.path.getsize(exe) != build.get("exe_size"):
            return "changed"
        return "ok"

    def products(self):
        """[(product key, [builds newest first])], products by latest import."""
        groups = {}
        for b in self.builds:
            groups.setdefault(b["product"], []).append(b)
        out = []
        for key, items in groups.items():
            items.sort(key=_order, reverse=True)
            out.append((key, items))
        out.sort(key=lambda kv: _order(kv[1][0]), reverse=True)
        return out

    def is_newest(self, build):
        same = [b for b in self.builds if b["product"] == build["product"]]
        return max(same, key=_order)["id"] == build["id"]

    # -- import
    def import_zips(self, paths, progress=None):
        """Import every package in the chosen ZIPs. Returns a list of
        (build or None, message) per package. Raises ImportError_ only for a
        problem with the selection itself."""
        results = []
        for group in expand_selection(paths):
            try:
                results.append(self._import_package(group, progress))
            except ImportError_ as e:
                results.append((None, "%s: %s" % (_group_name(group), e)))
        return results

    def _import_package(self, zips, progress=None):
        say = progress or (lambda msg: None)
        need = sum(os.path.getsize(z) for z in zips) * 3
        os.makedirs(self.staging_dir, exist_ok=True)
        free = shutil.disk_usage(self.home).free
        if free < need:
            raise ImportError_("Not enough free disk space (about %d MB needed)."
                               % (need // (1 << 20)))
        staging = os.path.join(self.staging_dir, uuid.uuid4().hex[:12])
        os.makedirs(staging)
        try:
            for z in zips:
                say("Unpacking %s ..." % os.path.basename(z))
                _safe_extract(z, staging)
            root = _package_root(staging, _group_name(zips))
            folder_name = os.path.basename(root)
            joined = join_parts(root)
            if joined:
                say("Joined %s from its parts." % ", ".join(joined))
            bats = read_bats(root)
            modes, exe_names = read_modes(root, bats)
            exe = find_exe(root, exe_names)
            if not exe:
                if any(n.endswith(".x86_64") for n in os.listdir(root)):
                    raise ImportError_("This is the Linux package; choose the "
                                       "Windows ZIP(s) instead.")
                raise ImportError_("No Windows executable (.exe) in this package.")
            say("Verifying %s ..." % exe)
            exe_hash, notes = verify_folder(root, exe, bats)
            if not any(m["args"] == [] for m in modes):
                modes.append({"label": "Standard (plain executable)", "args": [],
                              "recommended": not modes, "source": exe})
            title, rev, summary, readme = read_readme(root)
            rev = rev or (REVISION_SUFFIX_RE.match(folder_name).group("rev")
                          if REVISION_SUFFIX_RE.match(folder_name) else "")
            console = exe[:-4] + ".console.exe"
            build = {
                "id": folder_name,
                "product": product_key(folder_name),
                "title": nice_title(title, folder_name),
                "revision": rev,
                "summary": summary,
                "exe": exe,
                "exe_size": os.path.getsize(os.path.join(root, exe)),
                "exe_sha256": exe_hash,
                "console_exe": console if os.path.isfile(os.path.join(root, console)) else None,
                "modes": modes,
                "imported_at": _now(),
                "source_zips": [os.path.basename(z) for z in zips],
                "verification": notes,
            }
            message = self._place(build, root)
            return build, message
        finally:
            shutil.rmtree(staging, ignore_errors=True)

    def _place(self, build, root):
        """Move the verified folder into the library. A build already there
        is kept: identical means nothing to do; different content is kept
        beside the new one under a new name."""
        existing = self.get(build["id"])
        if existing is not None and self.status(existing) == "ok":
            if existing.get("exe_sha256") == build["exe_sha256"]:
                return "%s %s is already installed and identical; nothing changed." % (
                    build["title"], build["revision"])
            n = 2
            while self.get("%s (%d)" % (build["id"], n)):
                n += 1
            build["id"] = "%s (%d)" % (build["id"], n)
            note = ("Installed as a replacement copy; the earlier copy of the "
                    "same revision is kept.")
        elif existing is not None:
            # The recorded copy is missing or damaged: replace it.
            shutil.rmtree(self.folder(existing), ignore_errors=True)
            self.builds.remove(existing)
            note = "Repaired: the earlier copy of this revision was missing or damaged."
        else:
            older = [b for b in self.builds if b["product"] == build["product"]]
            note = ("Update: %d earlier version(s) kept and still playable."
                    % len(older)) if older else "New build."
        dest = os.path.join(self.builds_dir, build["id"])
        if os.path.exists(dest):
            shutil.rmtree(dest)
        shutil.move(root, dest)
        build["order"] = max([_order(b) for b in self.builds] + [0]) + 1
        self.builds.append(build)
        self.save()
        return "Installed %s %s. %s" % (build["title"], build["revision"], note)

    # -- removal (only ever on the player's request)
    def remove(self, build_id):
        b = self.get(build_id)
        if b is None:
            return
        shutil.rmtree(self.folder(b), ignore_errors=True)
        self.builds.remove(b)
        self.save()

    # -- launching
    def command(self, build, mode, console=False):
        exe = build["console_exe"] if console and build.get("console_exe") else build["exe"]
        return [os.path.join(self.folder(build), exe)] + list(mode["args"])

    def launch(self, build, mode, console=False):
        if self.status(build) != "ok":
            raise ImportError_("This build's executable is missing or changed "
                               "on disk. Import its ZIP(s) again.")
        cmd = self.command(build, mode, console)
        kwargs = {"cwd": self.folder(build), "close_fds": True}
        if sys.platform == "win32":
            flags = 0x00000200  # CREATE_NEW_PROCESS_GROUP
            flags |= 0x00000010 if console else 0x00000008  # NEW_CONSOLE / DETACHED
            kwargs["creationflags"] = flags
        else:
            kwargs["start_new_session"] = True
        return subprocess.Popen(cmd, **kwargs)


def _order(build):
    """Install order: later installs are newer."""
    return build.get("order", 0)


def _group_name(zips):
    name = os.path.basename(zips[0])
    m = PART_ZIP_RE.match(name)
    stem = m.group("stem") if m else name[:-4] if name.lower().endswith(".zip") else name
    return re.sub(r"-windows$", "", stem)
