"""Release-candidate checks for 0.2.0: the newer review-build formats, and
upgrading a library that launcher 0.1.0 wrote, without losing a build.

library-0.1.0.zip is a real library made by launcher 0.1.0 (d48a51b2) from
the fixtures: readable Crossing D (from its two parts), Impact Lab, and a
second, different copy of Impact Lab's revision that 0.1.0 kept as "(2)".
"""

import json
import os
import shutil
import tempfile
import unittest
import zipfile

from archipepsi_launcher.library import Library

FIX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
IL = "Archipepsi-Impact-Lab-c45086e1"
RD = "Archipepsi-Crossing-D-readability-0e54caab"
RELAY = "Archipepsi-Impact-Relay-21b5fb2f"
RELAY_ART = "Archipepsi-Impact-Relay-Art-23f8fd00"


def fixture(name):
    return os.path.join(FIX, name)


class NewerFormats(unittest.TestCase):
    """Impact Relay G1 and its art candidate use the same packaging, with
    two launchers and a heavy-hit mode."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.lib = Library(os.path.join(self.tmp, "home"))
        self.lib.startup()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_impact_relay(self):
        for zips in ([RELAY + "-windows.zip"], [RELAY + "-windows-part1of2.zip"]):
            lib = Library(tempfile.mkdtemp(dir=self.tmp))
            [(b, msg)] = lib.import_zips([fixture(z) for z in zips])
            self.assertIsNotNone(b, msg)
            self.assertTrue(b["verified"])
            self.assertEqual(b["title"], "Impact Relay")
            self.assertEqual([(m["label"], m["args"], m["recommended"]) for m in b["modes"]],
                             [("Impact Relay", [], True),
                              ("Impact Relay, heavy-hit mode", ["--", "--heavy-hit"], False)])

    def test_relay_and_its_art_candidate_are_separate_builds(self):
        self.lib.import_zips([fixture(RELAY + "-windows-part2of2.zip")])
        [(b, msg)] = self.lib.import_zips([fixture(RELAY_ART + "-windows-part1of2.zip")])
        self.assertIsNotNone(b, msg)
        self.assertEqual(b["exe"], "Archipepsi-Impact-Relay-Art.exe")
        self.assertEqual(b["modes"][0]["label"], "Impact Relay ART candidate")
        self.assertEqual(len(self.lib.products()), 2)

    def test_extra_metadata_file_is_carried_along(self):
        """A package with the packaging standard's optional
        archipepsi-build.json still installs as today (the file is kept,
        not read)."""
        src = fixture(IL + "-windows.zip")
        dst = os.path.join(self.tmp, IL + "-windows.zip")
        with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w") as zout:
            for info in zin.infolist():
                zout.writestr(info, zin.read(info))
            zout.writestr(IL + "/archipepsi-build.json",
                          json.dumps({"schema": "archipepsi-build/1"}))
        [(b, msg)] = self.lib.import_zips([dst])
        self.assertIsNotNone(b, msg)
        self.assertTrue(os.path.isfile(os.path.join(self.lib.folder(b), "archipepsi-build.json")))


class UpgradeFrom010(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.home = os.path.join(self.tmp, "home")
        with zipfile.ZipFile(fixture("library-0.1.0.zip")) as z:
            z.extractall(self.home)
        self.before = json.load(open(os.path.join(self.home, "library.json")))["builds"]

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def open(self):
        lib = Library(self.home)
        self.assertTrue(lib.lock())
        notices = lib.startup()
        self.addCleanup(lib.unlock)
        return lib, notices

    def test_every_build_kept_and_playable(self):
        lib, notices = self.open()
        self.assertEqual([b["id"] for b in lib.builds], [b["id"] for b in self.before])
        for old, new in zip(self.before, lib.builds):
            self.assertEqual(new["modes"], old["modes"])
            self.assertEqual(new["exe_sha256"], old["exe_sha256"])
            self.assertEqual(new["order"], old["order"])
            self.assertEqual(lib.check(new, full=True), "ok")
            self.assertTrue(os.path.isfile(lib.command(new, new["modes"][0])[0]))
        self.assertEqual(len(notices), 1, notices)
        self.assertIn("checked the 3 build(s) already installed: all are intact", notices[0])
        # Checked once: the next start has nothing to report.
        lib.unlock()
        again = Library(self.home)
        self.assertEqual(again.startup(), [])
        self.assertTrue(all("exe_mtime" in b for b in again.builds))

    def test_damaged_old_build_is_reported_not_dropped(self):
        exe = os.path.join(self.home, "builds", IL, "Archipepsi-Impact-Lab.exe")
        data = bytearray(open(exe, "rb").read())
        data[0] ^= 1
        open(exe, "wb").write(bytes(data))
        lib, notices = self.open()
        self.assertIn("2 intact and kept; missing or damaged", notices[0])
        self.assertIn("Impact Lab c45086e1", notices[0])
        self.assertEqual(len(lib.builds), 3)
        b = lib.get(IL)
        self.assertEqual(lib.check(b), "damaged")
        [(b2, msg)] = lib.import_zips([fixture(IL + "-windows.zip")])
        self.assertIn("Repaired", msg)
        self.assertEqual(lib.check(b2, full=True), "ok")
        self.assertEqual(lib.check(lib.get(IL + " (2)"), full=True), "ok")

    def test_reinstall_identical_and_update_keep_everything(self):
        lib, _ = self.open()
        [(_, msg)] = lib.import_zips([fixture(RD + "-windows.zip")])
        self.assertIn("already installed and identical", msg)
        newer = os.path.join(self.tmp, "Archipepsi-Impact-Lab-deadbeef-windows.zip")
        with zipfile.ZipFile(fixture(IL + "-windows.zip")) as zin, \
                zipfile.ZipFile(newer, "w") as zout:
            for info in zin.infolist():
                zout.writestr("Archipepsi-Impact-Lab-deadbeef" + info.filename[len(IL):],
                              zin.read(info))
        [(b, msg)] = lib.import_zips([newer])
        self.assertIn("2 earlier version(s) kept", msg)
        ids = [x["id"] for _, bs in lib.products() for x in bs]
        self.assertEqual(ids[:3], ["Archipepsi-Impact-Lab-deadbeef", IL + " (2)", IL])
        self.assertEqual(len(lib.builds), 4)
        self.assertTrue(all(lib.check(x, full=True) == "ok" for x in lib.builds))

    def test_remove_old_build(self):
        lib, _ = self.open()
        lib.remove(IL + " (2)")
        self.assertFalse(os.path.exists(os.path.join(self.home, "builds", IL + " (2)")))
        self.assertEqual(sorted(b["id"] for b in Library(self.home).builds), sorted([RD, IL]))


if __name__ == "__main__":
    unittest.main()
