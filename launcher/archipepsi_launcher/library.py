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

How an install stays safe:

- everything is unpacked, joined and verified in ``staging/`` first; the
  library is only touched once the build has passed every check;
- the verified folder is renamed into ``builds/`` (one rename on one
  drive), and only then recorded in ``library.json``; if recording fails,
  the rename is undone;
- an older copy being replaced is renamed aside first (which fails, and
  changes nothing, while the game is running) and deleted last;
- after a crash, the next start clears ``staging/`` and the renamed-aside
  leftovers, and re-adopts any verified build folder that never got
  recorded; ``library.json`` keeps a ``.bak`` of its previous version.
"""

import datetime
import errno
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
import zlib

LIBRARY_VERSION = 1

PART_ZIP_RE = re.compile(r"^(?P<stem>.+)-part(?P<n>\d+)of(?P<total>\d+)\.zip$", re.I)
PART_FILE_RE = re.compile(r"^(?P<target>.+)\.part(?P<n>\d+)$", re.I)
REVISION_SUFFIX_RE = re.compile(r"^(?P<product>.+)-(?P<rev>[0-9a-f]{7,40})$", re.I)
README_TITLE_RE = re.compile(r"^(?P<title>.*?)\s*\(revision\s+(?P<rev>[^)\s]+)\)\s*$", re.I)
# start "" "%~dp0Name.exe" -- --empty-yard
START_RE = re.compile(r'^\s*start\s+""\s+"(?:%~dp0)?(?P<exe>[^"]+\.exe)"(?P<args>.*)$', re.I)
# if not "%JOINED%"=="123456" goto broken
SIZE_RE = re.compile(r'"%JOINED%"\s*==\s*"(?P<size>\d+)"', re.I)
# Names Windows cannot create, whatever the extension.
RESERVED_RE = re.compile(r"^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$", re.I)
BAD_CHARS_RE = re.compile(r'[<>:"|?*\x00-\x1f]')
SUPPORTED_COMPRESSION = {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED,
                         zipfile.ZIP_BZIP2, zipfile.ZIP_LZMA}
# Room kept free on the drive beyond what the install itself needs.
SPACE_MARGIN = 64 << 20


class InstallError(Exception):
    """An install, launch or removal could not be done. ``message`` says, in
    plain words, what happened and what to do; ``detail`` is the technical
    reason, shown underneath for whoever asks."""

    def __init__(self, message, detail=""):
        super().__init__(message)
        self.message = message
        self.detail = detail

    def full(self):
        return self.message + ("\n\nDetails: " + self.detail if self.detail else "")


ImportError_ = InstallError  # the MVP's name for it


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


def _mb(n):
    return max(1, (n + (1 << 20) - 1) >> 20)


def _drive(path):
    drive = os.path.splitdrive(os.path.abspath(path))[0]
    return ("drive " + drive) if drive else "the disk holding " + path


def _disk_error(e, doing, where):
    """An OSError met while writing, in plain words."""
    if getattr(e, "errno", None) == errno.ENOSPC or getattr(e, "winerror", None) in (39, 112):
        return InstallError("The disk ran out of space while %s. Free some space on "
                            "%s and install again. Nothing was changed in your "
                            "library." % (doing, _drive(where)), str(e))
    if getattr(e, "errno", None) == errno.ENAMETOOLONG or getattr(e, "winerror", None) == 206:
        return InstallError("A file path became too long for Windows while %s. Set "
                            "ARCHIPEPSI_LAUNCHER_HOME to a shorter folder (for example "
                            "C:\\Archipepsi) and install again." % doing, str(e))
    return InstallError("Windows would not let the launcher write its files while %s. "
                        "Check that the library folder is not read-only and that no "
                        "antivirus scan or open window is holding it, then try again. "
                        "Nothing was changed in your library." % doing, str(e))


def _unsafe_name(name):
    """Why a relative path from a package may not be used, or None."""
    if not name or name.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:", name):
        return "it is an absolute path"
    for part in re.split(r"[\\/]", name):
        if part == "..":
            return "it climbs out of the package folder"
        if part in ("", "."):
            continue
        if RESERVED_RE.match(part):
            return "'%s' is a name Windows reserves" % part
        if BAD_CHARS_RE.search(part):
            return "'%s' contains characters Windows does not allow" % part
        if part[-1] in " .":
            return "'%s' ends in a space or dot" % part
    return None


# --------------------------------------------------------------- selection

def _top_folder(zip_path):
    """The single top-level folder a ZIP holds, or None."""
    try:
        with zipfile.ZipFile(zip_path) as zf:
            tops = {n.replace("\\", "/").split("/")[0] for n in zf.namelist()}
    except (zipfile.BadZipFile, OSError, ValueError):
        return None
    tops.discard("__MACOSX")
    return tops.pop() if len(tops) == 1 else None


def expand_selection(paths):
    """Group the chosen ZIPs into packages, adding any sibling parts the
    player did not select. ZIPs that unpack into the same folder belong
    to one package (so a part renamed by a browser, e.g. "part2of2 (1).zip",
    still joins its partner when both are chosen).

    Returns (packages, problems): packages is a list of lists of ZIP paths,
    one list per package in part order; problems is a list of plain-words
    messages for split builds with a part missing, which are left out."""
    chosen = []
    for p in paths:
        p = os.path.abspath(p)
        if p not in chosen:
            chosen.append(p)
    problems = []
    dropped = set()
    for p in list(chosen):
        m = PART_ZIP_RE.match(os.path.basename(p))
        if not m or p in dropped:
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
            for q in chosen:
                mq = PART_ZIP_RE.match(os.path.basename(q))
                if mq and mq.group("stem") == stem:
                    dropped.add(q)
            problems.append(
                "%s came in %d parts, but %s missing. Put %s part ZIPs in the "
                "same folder and install again.\n\nDetails: not found next to %s: %s"
                % (stem, total, "one is" if len(missing) == 1 else "%d are" % len(missing),
                   "both" if total == 2 else "all %d" % total,
                   os.path.basename(p), ", ".join(missing)))
    groups = []
    by_top = {}
    for p in chosen:
        if p in dropped:
            continue
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
    return groups, problems


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

def _open_zip(zip_path):
    base = os.path.basename(zip_path)
    try:
        return zipfile.ZipFile(zip_path)
    except (zipfile.BadZipFile, EOFError, ValueError) as e:
        raise InstallError("\"%s\" is not a complete ZIP file. It probably did not "
                           "finish downloading: download it again." % base, str(e))
    except OSError as e:
        raise InstallError("The launcher could not read \"%s\". Check that the file "
                           "is still there and not open in another program." % base, str(e))


def unpacked_size(zip_paths):
    total = 0
    for z in zip_paths:
        with _open_zip(z) as zf:
            total += sum(i.file_size for i in zf.infolist())
    return total


def _safe_extract(zip_path, dest):
    """Unpack one ZIP into dest, refusing anything that would land outside
    it, be impossible on Windows, or that the ZIP cannot vouch for."""
    base = os.path.basename(zip_path)
    with _open_zip(zip_path) as zf:
        dest_real = os.path.realpath(dest)
        infos = zf.infolist()
        for info in infos:
            why = _unsafe_name(info.filename)
            if why is None:
                target = os.path.realpath(os.path.join(dest, info.filename.replace("\\", "/")))
                if not (target == dest_real or target.startswith(dest_real + os.sep)):
                    why = "it would land outside the package folder"
            if why:
                raise InstallError(
                    "\"%s\" tries to place a file where it should not, so the launcher "
                    "refused it and installed nothing. Ask for a fresh copy of the "
                    "build." % base, "%s: %s" % (info.filename, why))
            if info.flag_bits & 0x1:
                raise InstallError(
                    "\"%s\" is password-protected. Review builds never are, so this is "
                    "probably the wrong file." % base, "encrypted entry " + info.filename)
            if info.compress_type not in SUPPORTED_COMPRESSION:
                raise InstallError(
                    "\"%s\" was packed with a compression method the launcher cannot "
                    "open. Ask for the build as it was delivered, not re-zipped." % base,
                    "%s uses compression method %d" % (info.filename, info.compress_type))
        for info in infos:
            name = info.filename.replace("\\", "/")
            target = os.path.join(dest, *[p for p in name.split("/") if p not in ("", ".")])
            if name.endswith("/"):
                os.makedirs(target, exist_ok=True)
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            try:
                with zf.open(info) as src, open(target, "wb") as dst:
                    shutil.copyfileobj(src, dst, 1 << 20)
            except (zipfile.BadZipFile, zlib.error, EOFError, RuntimeError,
                    NotImplementedError) as e:
                raise InstallError(
                    "\"%s\" is damaged: a file inside it does not unpack correctly. "
                    "Download it again." % base, "%s: %s" % (info.filename, e))
            except OSError as e:
                raise _disk_error(e, "unpacking \"%s\"" % base, dest)


def _package_root(staging, fallback_name):
    """The folder the package unpacked into. Review builds hold exactly one
    top folder; a ZIP with loose files is moved into one named after it."""
    entries = [e for e in os.listdir(staging) if not e.startswith("__MACOSX")]
    if len(entries) == 1 and os.path.isdir(os.path.join(staging, entries[0])):
        return os.path.join(staging, entries[0])
    root = os.path.join(staging, "." + uuid.uuid4().hex[:8])
    os.mkdir(root)
    for e in entries:
        shutil.move(os.path.join(staging, e), os.path.join(root, e))
    final = os.path.join(staging, fallback_name)
    os.rename(root, final)
    return final


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
            have = " and ".join("part %d" % n for n in numbers)
            raise InstallError(
                "This build is incomplete: only %s of the game arrived. Choose all of "
                "the build's part ZIPs (they must be from the same download) and "
                "install again." % have, "%s: found %s" % (target, ", ".join(
                    parts[n] for n in numbers)))
        out = os.path.join(folder, target)
        try:
            with open(out, "wb") as dst:
                for n in numbers:
                    with open(os.path.join(folder, parts[n]), "rb") as src:
                        shutil.copyfileobj(src, dst, 1 << 20)
            for n in numbers:
                os.remove(os.path.join(folder, parts[n]))
        except OSError as e:
            raise _disk_error(e, "joining the game's parts", folder)
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
    .bat files expect. Returns (exe sha256, check notes, verified). Raises
    InstallError on any mismatch."""
    notes = []
    sums = read_sums(folder)
    exe_path = os.path.join(folder, exe)
    exe_hash = sha256_file(exe_path)
    verified = False
    if sums:
        checked = 0
        for name, want in sums.items():
            if name == "SHA256SUMS.txt":
                continue
            why = _unsafe_name(name)
            if why:
                raise InstallError(
                    "The build's checksum list points outside its own folder, so the "
                    "launcher refused it. Ask for a fresh copy of the build.",
                    "SHA256SUMS.txt entry %s: %s" % (name, why))
            path = os.path.join(folder, name)
            if not os.path.isfile(path):
                raise InstallError(
                    "The build is missing a file it should contain (%s). Download it "
                    "again; for a two-part build, download both parts." % name,
                    "listed in SHA256SUMS.txt, not in the package")
            got = exe_hash if name == exe else sha256_file(path)
            if got != want:
                raise InstallError(
                    "%s is damaged, or its parts come from two different downloads. "
                    "Download the build again (every part, from the same message) and "
                    "install again. Nothing was installed." % name,
                    "SHA-256 %s, expected %s" % (got[:16], want[:16]))
            checked += 1
        if exe in sums:
            verified = True
        else:
            notes.append("the checksum list does not cover the game")
        notes.append("%d files match their checksums" % checked)
    else:
        notes.append("no checksum list in the package")
    size = os.path.getsize(exe_path)
    for name, text in bats:
        m = SIZE_RE.search(text)
        if m and "@SIZE@" not in text:
            want = int(m.group("size"))
            if want != size:
                raise InstallError(
                    "The joined game is the wrong size, so a part is damaged or from a "
                    "different build. Download every part again and install again.",
                    "%s is %d bytes; %s expects %d" % (exe, size, name, want))
            notes.append("game size matches what its launchers expect")
            verified = True
            break
    if not verified:
        notes.append("NOT VERIFIED: nothing in the package says what the game should be")
    return exe_hash, notes, verified


def describe(root, zips=()):
    """Read and verify an unpacked (and joined) package folder, returning
    its library record. Raises InstallError if it is not a playable,
    intact Windows build."""
    folder_name = os.path.basename(root)
    bats = read_bats(root)
    modes, exe_names = read_modes(root, bats)
    exe = find_exe(root, exe_names)
    if not exe:
        if any(n.endswith(".x86_64") for n in os.listdir(root)):
            raise InstallError(
                "This is the Linux version of the build. Choose the Windows ZIP "
                "instead (its name ends in -windows.zip or -windows-part1of2.zip).")
        if any(PART_FILE_RE.match(n) for n in os.listdir(root)):
            raise InstallError("This build is incomplete: the game is still in parts. "
                               "Choose every part ZIP and install again.")
        raise InstallError("There is no Windows game (.exe) in this package, so there "
                           "is nothing to play. Check it is an Archipepsi build.")
    exe_hash, notes, verified = verify_folder(root, exe, bats)
    if not any(m["args"] == [] for m in modes):
        modes.append({"label": "Standard (plain executable)", "args": [],
                      "recommended": not modes, "source": exe})
    title, rev, summary, _readme = read_readme(root)
    m = REVISION_SUFFIX_RE.match(folder_name)
    rev = rev or (m.group("rev") if m else "")
    console = exe[:-4] + ".console.exe"
    return {
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
        "verified": verified,
    }


# --------------------------------------------------------------- library

class Library:
    """The installed builds. Construct it to read the index; call
    ``lock()`` and then ``startup()`` in the one process that manages the
    library (the GUI) so crash leftovers are cleaned up."""

    def __init__(self, home=None):
        self.home = os.path.abspath(home or default_home())
        self.builds_dir = os.path.join(self.home, "builds")
        self.staging_dir = os.path.join(self.home, "staging")
        self.aside_dir = os.path.join(self.home, "unrecognised")
        self.index_path = os.path.join(self.home, "library.json")
        self.notices = []
        self._lock_file = None
        os.makedirs(self.builds_dir, exist_ok=True)
        self.builds = []
        self.load()

    # -- one launcher at a time
    def lock(self):
        """Take the library for this process. False if another launcher
        already has it open (two would overwrite each other's records)."""
        f = open(os.path.join(self.home, "launcher.lock"), "a+")
        try:
            f.seek(0)
            if sys.platform == "win32":
                import msvcrt
                msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            f.close()
            return False
        self._lock_file = f
        return True

    def unlock(self):
        if self._lock_file:
            self._lock_file.close()
            self._lock_file = None

    # -- persistence
    def load(self):
        self.builds = []
        for path in (self.index_path, self.index_path + ".bak"):
            if not os.path.isfile(path):
                continue
            try:
                with open(path, encoding="utf-8") as f:
                    data = json.load(f)
                builds = data["builds"]
                if not isinstance(builds, list) or not all(
                        isinstance(b, dict) and "id" in b and "exe" in b for b in builds):
                    raise ValueError("unexpected layout")
            except (OSError, ValueError, KeyError, TypeError) as e:
                keep = path + ".unreadable"
                try:
                    shutil.copyfile(path, keep)
                except OSError:
                    pass
                self.notices.append("The launcher's list of builds (%s) could not be "
                                    "read (%s); a copy was kept as %s."
                                    % (os.path.basename(path), e, os.path.basename(keep)))
                continue
            self.builds = builds
            if path != self.index_path:
                self.notices.append("The list of builds was restored from its backup.")
            break
        return self.builds

    def save(self):
        data = {"version": LIBRARY_VERSION, "builds": self.builds}
        fd, tmp = tempfile.mkstemp(dir=self.home, prefix="library-", suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            if os.path.isfile(self.index_path):
                shutil.copyfile(self.index_path, self.index_path + ".bak")
            os.replace(tmp, self.index_path)
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)

    # -- crash recovery
    def startup(self):
        """Clear what an interrupted install or removal left behind, and
        re-adopt build folders that were installed but never recorded.
        Returns notices for the player (also kept in ``self.notices``)."""
        shutil.rmtree(self.staging_dir, ignore_errors=True)
        known = {b["id"] for b in self.builds}
        changed = False
        for name in sorted(os.listdir(self.builds_dir)):
            path = os.path.join(self.builds_dir, name)
            if name.startswith((".incoming-", ".trash-")):
                shutil.rmtree(path, ignore_errors=True)
                continue
            if name in known or name.startswith(".") or not os.path.isdir(path):
                continue
            try:
                build = describe(path)
            except (InstallError, OSError) as e:
                self._set_aside(path)
                self.notices.append(
                    "An unfinished or damaged build folder (%s) was moved to the "
                    "\"unrecognised\" folder in the library. Install its ZIP again if "
                    "you need it." % name)
                continue
            build["id"] = name
            build["verification"] = build["verification"] + [
                "re-added after an interrupted install"]
            self._stamp(build)
            build["order"] = self._next_order()
            self.builds.append(build)
            changed = True
            self.notices.append("%s %s was installed but not listed (the launcher was "
                                "probably closed mid-install); it is checked and back "
                                "in the list." % (build["title"], build["revision"]))
        if changed:
            self.save()
        return self.notices

    def _set_aside(self, path):
        os.makedirs(self.aside_dir, exist_ok=True)
        target = os.path.join(self.aside_dir, os.path.basename(path))
        n = 2
        while os.path.exists(target):
            target = os.path.join(self.aside_dir, "%s (%d)" % (os.path.basename(path), n))
            n += 1
        os.rename(path, target)

    # -- queries
    def get(self, build_id):
        for b in self.builds:
            if b["id"] == build_id:
                return b
        return None

    def folder(self, build):
        return os.path.join(self.builds_dir, build["id"])

    def _stamp(self, build):
        exe = os.path.join(self.folder(build), build["exe"])
        build["exe_mtime"] = os.path.getmtime(exe)

    def check(self, build, full=False):
        """"ok", "missing" or "damaged". The game is re-hashed whenever its
        file's size or time changed since it was verified (or always, with
        full=True), so a damaged copy is caught before it is played."""
        exe = os.path.join(self.folder(build), build["exe"])
        try:
            st = os.stat(exe)
        except OSError:
            return "missing"
        if st.st_size != build.get("exe_size"):
            return "damaged"
        if not full and build.get("exe_mtime") == st.st_mtime:
            return "ok"
        try:
            good = sha256_file(exe) == build.get("exe_sha256")
        except OSError:
            return "missing"
        if not good:
            return "damaged"
        # Remembered in memory; written with the next change to the library.
        build["exe_mtime"] = st.st_mtime
        return "ok"

    status = check

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

    def _next_order(self):
        return max([_order(b) for b in self.builds] + [0]) + 1

    # -- import
    def import_zips(self, paths, progress=None):
        """Install every package in the chosen ZIPs. Returns a list of
        (build or None, message) per package, the message in plain words
        (with a "Details:" line for failures)."""
        groups, problems = expand_selection(paths)
        results = [(None, p) for p in problems]
        for group in groups:
            try:
                results.append(self._import_package(group, progress))
            except InstallError as e:
                results.append((None, "%s: %s" % (_group_name(group), e.full())))
        return results

    def _import_package(self, zips, progress=None):
        say = progress or (lambda msg: None)
        os.makedirs(self.staging_dir, exist_ok=True)
        # Unpacked parts plus the joined game, side by side, at the peak.
        need = unpacked_size(zips) * 2 + SPACE_MARGIN
        free = shutil.disk_usage(self.home).free
        if free < need:
            raise InstallError(
                "There is not enough free space to install this build: it needs about "
                "%d MB on %s and %d MB is free. Free some space and install again."
                % (_mb(need), _drive(self.home), free >> 20))
        staging = os.path.join(self.staging_dir, uuid.uuid4().hex[:12])
        try:
            os.makedirs(staging)
            for z in zips:
                say("Unpacking %s ..." % os.path.basename(z))
                _safe_extract(z, staging)
            root = _package_root(staging, _group_name(zips))
            if os.path.basename(root).startswith("."):
                raise InstallError("This package's folder name is not usable. Ask for a "
                                   "fresh copy of the build.", os.path.basename(root))
            joined = join_parts(root)
            if joined:
                say("Joined %s from its parts." % ", ".join(joined))
            say("Checking the build ...")
            build = describe(root, zips)
            return build, self._place(build, root)
        except OSError as e:
            raise _disk_error(e, "installing", self.home)
        finally:
            shutil.rmtree(staging, ignore_errors=True)

    def _free_id(self, base):
        n = 2
        while True:
            cand = "%s (%d)" % (base, n)
            if not self.get(cand) and not os.path.exists(os.path.join(self.builds_dir, cand)):
                return cand
            n += 1

    def _place(self, build, root):
        """Move the verified folder into the library. A build already there
        is kept: identical means nothing to do; different content is kept
        beside the new one under a new name; a missing or damaged copy is
        replaced."""
        replace = None
        existing = self.get(build["id"])
        if existing is not None:
            health = self.check(existing, full=True)
            if health == "ok":
                if existing.get("exe_sha256") == build["exe_sha256"]:
                    return ("%s %s is already installed and identical; nothing changed."
                            % (build["title"], build["revision"]))
                build["id"] = self._free_id(build["id"])
                note = ("This is a different copy of a revision you already have; the "
                        "earlier copy is kept, and this one is listed as \"%s\"." % build["id"])
            else:
                replace = existing
                note = "Repaired: the copy already installed was %s and has been replaced." % health
        else:
            older = [b for b in self.builds if b["product"] == build["product"]]
            note = ("Update: %d earlier version(s) kept and still playable."
                    % len(older)) if older else "New build."
        dest = os.path.join(self.builds_dir, build["id"])
        if replace is None and os.path.exists(dest):
            # A folder no record points to (normally re-adopted at start-up):
            # never delete it, move it out of the way.
            self._set_aside(dest)
        incoming = os.path.join(self.builds_dir, ".incoming-" + uuid.uuid4().hex[:8])
        os.rename(root, incoming)
        trash = None
        if replace is not None and os.path.exists(dest):
            trash = os.path.join(self.builds_dir, ".trash-" + uuid.uuid4().hex[:8])
            try:
                os.rename(dest, trash)
            except OSError as e:
                shutil.rmtree(incoming, ignore_errors=True)
                raise InstallError(
                    "The damaged copy of this build is still in use, so it cannot be "
                    "replaced. Close the game (and any window showing its folder) and "
                    "install again.", str(e))
        try:
            os.rename(incoming, dest)
            self._stamp(build)
            before = list(self.builds)
            if replace is not None:
                build["order"] = replace.get("order", self._next_order())
                self.builds = [build if b is replace else b for b in self.builds]
            else:
                build["order"] = self._next_order()
                self.builds.append(build)
            try:
                self.save()
            except OSError:
                self.builds = before
                raise
        except OSError:
            # Roll back: the library looks exactly as it did before.
            if os.path.exists(dest):
                shutil.rmtree(dest, ignore_errors=True)
            if os.path.exists(incoming):
                shutil.rmtree(incoming, ignore_errors=True)
            if trash:
                os.rename(trash, dest)
            raise
        if trash:
            shutil.rmtree(trash, ignore_errors=True)
        return "Installed %s %s. %s" % (build["title"], build["revision"], note)

    # -- removal (only ever on the player's request)
    def remove(self, build_id):
        b = self.get(build_id)
        if b is None:
            return
        folder = self.folder(b)
        trash = None
        if os.path.exists(folder):
            trash = os.path.join(self.builds_dir, ".trash-" + uuid.uuid4().hex[:8])
            try:
                os.rename(folder, trash)
            except OSError as e:
                raise InstallError(
                    "This build is still in use, so nothing was removed. Close the "
                    "game (and any window showing its folder) and try again.", str(e))
        self.builds.remove(b)
        try:
            self.save()
        except OSError:
            self.builds.append(b)
            if trash:
                os.rename(trash, folder)
            raise
        if trash:
            shutil.rmtree(trash, ignore_errors=True)

    # -- launching
    def command(self, build, mode, console=False):
        exe = build["console_exe"] if console and build.get("console_exe") else build["exe"]
        return [os.path.join(self.folder(build), exe)] + list(mode["args"])

    def launch(self, build, mode, console=False):
        health = self.check(build)
        if health != "ok":
            raise InstallError(
                "This build's game file is %s, so it was not started. Install its "
                "ZIP(s) again to repair it; your other builds are not affected." % health)
        cmd = self.command(build, mode, console)
        kwargs = {"cwd": self.folder(build), "close_fds": True}
        if sys.platform == "win32":
            flags = 0x00000200  # CREATE_NEW_PROCESS_GROUP
            flags |= 0x00000010 if console else 0x00000008  # NEW_CONSOLE / DETACHED
            kwargs["creationflags"] = flags
        else:
            kwargs["start_new_session"] = True
        try:
            return subprocess.Popen(cmd, **kwargs)
        except OSError as e:
            raise InstallError(
                "Windows would not start the game. If an antivirus quarantined it, "
                "restore it or install the ZIP(s) again.", str(e))


def _order(build):
    """Install order: later installs are newer."""
    return build.get("order", 0)


def _group_name(zips):
    name = os.path.basename(zips[0])
    m = PART_ZIP_RE.match(name)
    stem = m.group("stem") if m else name[:-4] if name.lower().endswith(".zip") else name
    return re.sub(r"-windows$", "", stem)
