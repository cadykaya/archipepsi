"""Tests for archipepsi_build.py on small packages laid out exactly as
tools/*/package.sh lays them out (tests/compat.sh runs the real scripts).

    python3 -m unittest discover -s tools/build_metadata/tests
"""

import hashlib
import json
import os
import shutil
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import archipepsi_build as ab  # noqa: E402

REV = "abcdef12"
COMMIT = REV + "0" * 32
NAME = "Archipepsi-Test-Room-" + REV
EXE = "Archipepsi-Test-Room.exe"
FIRST = "1 - START HERE - Test Room, quiet (Windows).bat"
SECOND = "2 - Test Room, loud (Windows).bat"
BAT = """@echo off
cd /d "%~dp0"
if exist "Archipepsi-Test-Room.exe" goto play
copy /b "Archipepsi-Test-Room.exe.part1" + "Archipepsi-Test-Room.exe.part2" "Archipepsi-Test-Room.exe" >nul
for %%F in ("Archipepsi-Test-Room.exe") do set JOINED=%%~zF
if not "%JOINED%"=="@SIZE@" goto broken
:play
start "" "%~dp0Archipepsi-Test-Room.exe"{args}
exit /b 0
:broken
exit /b 1
"""
SPEC = {
    "schema": "archipepsi-build-spec/1",
    "title": "Test Room",
    "executable": "Archipepsi-Test-Room",
    "description": "A room for tests.",
    "limitations": ["It is only a test."],
    "modes": [
        {"id": "quiet", "label": "Quiet", "args": ["--", "--quiet"],
         "launchers": {"windows": FIRST}},
        {"id": "loud", "label": "Loud", "args": [], "launchers": {"windows": SECOND}},
    ],
    "recommended_mode": "quiet",
}


def sums_for(folder):
    lines = []
    for n in sorted(os.listdir(folder)):
        with open(os.path.join(folder, n), "rb") as f:
            lines.append("%s  %s\n" % (hashlib.sha256(f.read()).hexdigest(), n))
    with open(os.path.join(folder, "SHA256SUMS.txt"), "w", newline="\n") as f:
        f.writelines(lines)


def zip_folder(zip_path, root, names):
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for n in names:
            zf.write(os.path.join(root, NAME, n), "%s/%s" % (NAME, n))


def make_output(out, game=None):
    """What package.sh leaves in its output folder: windows/<NAME>,
    windows-split/<NAME> and the three Windows zips."""
    game = game if game is not None else os.urandom(5000)
    win = os.path.join(out, "windows", NAME)
    os.makedirs(win)
    with open(os.path.join(win, EXE), "wb") as f:
        f.write(game)
    with open(os.path.join(win, "Archipepsi-Test-Room.console.exe"), "wb") as f:
        f.write(b"console")
    for bat, args in ((FIRST, " -- --quiet"), (SECOND, "")):
        with open(os.path.join(win, bat), "w", newline="\r\n") as f:
            f.write(BAT.replace("@SIZE@", str(len(game))).format(args=args))
    with open(os.path.join(win, "README.txt"), "w") as f:
        f.write("ARCHIPEPSI - TEST ROOM   (revision %s)\n\nA room.\n" % REV)
    sums_for(win)
    zip_folder(os.path.join(out, NAME + "-windows.zip"), os.path.dirname(win),
               sorted(os.listdir(win)))
    split = os.path.join(out, "windows-split", NAME)
    shutil.copytree(win, split)
    cut = len(game) * 44 // 100
    for n, data in ((1, game[:cut]), (2, game[cut:])):
        with open(os.path.join(split, EXE + ".part%d" % n), "wb") as f:
            f.write(data)
    os.remove(os.path.join(split, EXE))
    rest = sorted(n for n in os.listdir(split) if not n.endswith(".part2"))
    zip_folder(os.path.join(out, NAME + "-windows-part1of2.zip"), os.path.dirname(split), rest)
    zip_folder(os.path.join(out, NAME + "-windows-part2of2.zip"), os.path.dirname(split),
               [EXE + ".part2"])
    return out


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.out = make_output(os.path.join(self.tmp, "out"))
        self.spec = os.path.join(self.tmp, "spec.json")
        with open(self.spec, "w") as f:
            json.dump(SPEC, f)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def z(self, suffix):
        return os.path.join(self.out, NAME + suffix)

    def stamp(self):
        return ab.stamp(self.spec, self.out, branch="review/test", commit=COMMIT)

    def check(self, zips, strict=True):
        return ab.validate_package("t", zips=zips, strict=strict)

    def rewrite_zip(self, path, edit):
        """Rebuild a zip with edit(name, data) -> data (None drops it)."""
        with zipfile.ZipFile(path) as zf:
            items = [(i.filename, zf.read(i)) for i in zf.infolist()]
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zf:
            for n, data in items:
                data = edit(n, data)
                if data is not None:
                    zf.writestr(n, data)

    def assertFails(self, rep, words):
        self.assertFalse(rep.ok, "expected a failure")
        self.assertTrue(any(words in e for e in rep.errors), rep.errors)


class Legacy(Base):
    def test_legacy_passes_with_inferred_metadata(self):
        rep = self.check([self.z("-windows.zip")], strict=False)
        self.assertTrue(rep.ok, rep.errors)
        m = rep.manifest
        self.assertTrue(m["inferred"])
        self.assertEqual(m["revision"], REV)
        self.assertEqual(m["title"], "Test Room")
        self.assertEqual(m["recommended_mode"], "test-room-quiet")
        self.assertEqual([x["args"] for x in m["modes"]], [["--", "--quiet"], []])

    def test_legacy_split_passes(self):
        rep = self.check([self.z("-windows-part1of2.zip"), self.z("-windows-part2of2.zip")],
                         strict=False)
        self.assertTrue(rep.ok, rep.errors)

    def test_legacy_fails_strict(self):
        self.assertFails(self.check([self.z("-windows.zip")]), "No archipepsi-build.json")


class Stamped(Base):
    def setUp(self):
        super().setUp()
        self.stamped = self.stamp()
        self.parts = [self.z("-windows-part1of2.zip"), self.z("-windows-part2of2.zip")]

    def test_stamps_the_whole_zip_and_part_one_only(self):
        self.assertEqual(sorted(map(os.path.basename, self.stamped)),
                         sorted([NAME + "-windows.zip", NAME + "-windows-part1of2.zip"]))
        with zipfile.ZipFile(self.parts[1]) as zf:
            self.assertNotIn(NAME + "/" + ab.MANIFEST, zf.namelist())

    def test_whole_and_split_pass_strict(self):
        for zips in ([self.z("-windows.zip")], self.parts):
            rep = self.check(zips)
            self.assertTrue(rep.ok, rep.errors)
            m = rep.manifest
            self.assertEqual(m["source"], {"branch": "review/test", "commit": COMMIT})
            self.assertEqual(m["recommended_mode"], "quiet")
            self.assertEqual(m["modes"][0]["launcher"], FIRST)
        self.assertIn("split", rep.manifest["integrity"])

    def test_stamping_twice_is_refused(self):
        with self.assertRaises(ab.Problem):
            self.stamp()

    def test_wrong_commit_is_refused(self):
        with self.assertRaises(ab.Problem):
            ab.stamp(self.spec, self.out, commit="1" * 40)

    def test_missing_part_zip(self):
        self.assertFails(self.check(self.parts[:1]), "-part2of2.zip")

    def test_part_from_another_build(self):
        other = make_output(os.path.join(self.tmp, "other"))
        self.assertFails(self.check([self.parts[0], os.path.join(
            other, NAME + "-windows-part2of2.zip")]), "from a different build")

    def test_part_from_another_build_legacy(self):
        other = make_output(os.path.join(self.tmp, "other"))
        rep = ab.validate_package("t", zips=[
            os.path.join(other, NAME + "-windows-part1of2.zip"), self.parts[1]])
        self.assertFails(rep, "does not match its checksum")

    def test_damaged_file(self):
        self.rewrite_zip(self.z("-windows.zip"), lambda n, d: d + b"!" if
                         n.endswith("README.txt") else d)
        self.assertFails(self.check([self.z("-windows.zip")]), "README.txt does not match")

    def test_truncated_zip(self):
        p = self.z("-windows.zip")
        with open(p, "r+b") as f:
            f.truncate(os.path.getsize(p) // 2)
        self.assertFails(self.check([p]), "not a readable ZIP")

    def test_unsafe_path(self):
        with zipfile.ZipFile(self.z("-windows.zip"), "a") as zf:
            zf.writestr(NAME + "/../escape.txt", "x")
        self.assertFails(self.check([self.z("-windows.zip")]), "unsafe path")

    def test_launcher_and_mode_disagree(self):
        def edit(n, d):
            if n.endswith(ab.MANIFEST):
                m = json.loads(d)
                m["modes"][0]["args"] = ["--", "--loud"]
                return json.dumps(m)
            return d
        self.rewrite_zip(self.z("-windows.zip"), edit)
        self.assertFails(self.check([self.z("-windows.zip")]), "starts the game with")

    def test_bad_recommended_mode(self):
        def edit(n, d):
            if n.endswith(ab.MANIFEST):
                m = json.loads(d)
                m["recommended_mode"] = "nowhere"
                return json.dumps(m)
            return d
        self.rewrite_zip(self.z("-windows.zip"), edit)
        self.assertFails(self.check([self.z("-windows.zip")]), "recommended_mode")

    def test_readme_from_another_revision(self):
        def edit(n, d):
            return d.replace(REV.encode(), b"99999999") if n.endswith("README.txt") else d
        self.rewrite_zip(self.z("-windows.zip"), edit)
        self.assertFails(self.check([self.z("-windows.zip")]), "README is from another build")

    def test_unchecked_extra_file(self):
        with zipfile.ZipFile(self.z("-windows.zip"), "a") as zf:
            zf.writestr(NAME + "/surprise.dll", "x")
        self.assertFails(self.check([self.z("-windows.zip")]), "nothing checks it")

    def test_unpacked_folder(self):
        rep = ab.validate_package("t", folder=os.path.join(self.out, "windows-split", NAME),
                                  strict=True)
        self.assertTrue(rep.ok, rep.errors)


class Cli(Base):
    def test_exit_codes(self):
        self.assertEqual(ab.main(["validate", "-q", self.z("-windows.zip")]), 0)
        self.assertEqual(ab.main(["validate", "-q", "--strict", self.z("-windows.zip")]), 1)
        self.assertEqual(ab.main(["stamp", "--spec", self.spec, "--commit", COMMIT,
                                  self.out]), 0)
        self.assertEqual(ab.main(["validate", "-q", "--strict", self.z("-windows.zip")]), 0)


if __name__ == "__main__":
    unittest.main()
