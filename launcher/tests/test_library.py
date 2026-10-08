"""The library against the delivered review-build formats.

The fixtures are made by the review builds' own package.sh scripts (see
make_fixtures.sh): Crossing D (#20, a join script plus a no-enemies
launcher), readable Crossing D (#21, two launchers that each join) and the
Impact Lab (#22, one START HERE launcher), each as one ZIP and as two.
"""

import os
import shutil
import tempfile
import unittest
import zipfile

from archipepsi_launcher.library import ImportError_, Library, expand_selection

FIX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
D = "Archipepsi-Crossing-D-review-4462be29"
RD = "Archipepsi-Crossing-D-readability-0e54caab"
IL = "Archipepsi-Impact-Lab-c45086e1"


def fixture(name):
    return os.path.join(FIX, name)


def rewrite_zip(src, dst, rename=None, edit=None):
    """Copy a ZIP, renaming its top folder and/or editing one member."""
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
        for info in zin.infolist():
            data = zin.read(info)
            name = info.filename
            if edit and name.endswith(edit[0]):
                data = edit[1](data)
            if rename:
                name = rename[1] + name[len(rename[0]):]
            zout.writestr(name, data)


class LibraryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.lib = Library(os.path.join(self.tmp, "home"))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def import_one(self, *names):
        results = self.lib.import_zips([n if os.path.isabs(n) else fixture(n) for n in names])
        self.assertEqual(len(results), 1, results)
        return results[0]

    def assert_installed(self, build, msg):
        self.assertIsNotNone(build, msg)
        self.assertEqual(self.lib.status(build), "ok")
        self.assertTrue(os.path.isfile(os.path.join(self.lib.folder(build), build["exe"])))

    # ------------------------------------------------------------ formats
    def test_crossing_d_single_zip(self):
        b, msg = self.import_one(D + "-windows.zip")
        self.assert_installed(b, msg)
        self.assertEqual(b["exe"], "Archipepsi-Crossing-D.exe")
        self.assertEqual(b["revision"], "4462be29")
        self.assertEqual([(m["label"], m["args"]) for m in b["modes"]],
                         [("Crossing D - no enemies", ["--", "--empty-yard"]),
                          ("Standard (plain executable)", [])])
        self.assertEqual(b["console_exe"], "Archipepsi-Crossing-D.console.exe")

    def test_crossing_d_two_parts(self):
        b, msg = self.import_one(D + "-windows-part1of2.zip", D + "-windows-part2of2.zip")
        self.assert_installed(b, msg)
        modes = {m["label"]: m["args"] for m in b["modes"]}
        self.assertEqual(modes["Crossing D - no enemies"], ["--", "--empty-yard"])
        self.assertEqual(modes["Standard (plain executable)"], [])
        self.assertTrue(any("match SHA256SUMS" in n for n in b["verification"]))
        self.assertTrue(any("size 30000 bytes" in n for n in b["verification"]))
        self.assertFalse(any(n.endswith((".part1", ".part2"))
                             for n in os.listdir(self.lib.folder(b))))

    def test_readable_crossing_d_modes(self):
        b, msg = self.import_one(RD + "-windows-part1of2.zip")  # part 2 found beside it
        self.assert_installed(b, msg)
        self.assertEqual(b["title"], "Crossing D, Readability Review Build")
        self.assertEqual([(m["label"], m["args"], m["recommended"]) for m in b["modes"]],
                         [("Crossing D, NO ENEMIES", ["--", "--empty-yard"], True),
                          ("Crossing D, with enemies", [], False)])

    def test_impact_lab(self):
        for names in ([IL + "-windows.zip"], [IL + "-windows-part2of2.zip"]):
            lib = Library(tempfile.mkdtemp(dir=self.tmp))
            [(b, msg)] = lib.import_zips([fixture(n) for n in names])
            self.assertIsNotNone(b, msg)
            self.assertEqual(b["title"], "Impact Lab")
            self.assertEqual([(m["label"], m["args"], m["recommended"]) for m in b["modes"]],
                             [("Impact Lab", [], True)])
            self.assertIn("TECHNICAL FIXTURE", b["summary"])

    def test_linux_zip_is_refused(self):
        b, msg = self.import_one(IL + "-linux.zip")
        self.assertIsNone(b)
        self.assertIn("Linux package", msg)

    # ------------------------------------------------------------ two-part checks
    def test_missing_part_is_named(self):
        lonely = os.path.join(self.tmp, IL + "-windows-part1of2.zip")
        shutil.copy(fixture(IL + "-windows-part1of2.zip"), lonely)
        with self.assertRaises(ImportError_) as cm:
            expand_selection([lonely])
        self.assertIn(IL + "-windows-part2of2.zip", str(cm.exception))

    def test_renamed_part_chosen_together(self):
        a = os.path.join(self.tmp, "a")
        os.makedirs(a)
        p1 = os.path.join(a, IL + "-windows-part1of2.zip")
        p2 = os.path.join(self.tmp, IL + "-windows-part2of2 (1).zip")
        shutil.copy(fixture(IL + "-windows-part1of2.zip"), p1)
        shutil.copy(fixture(IL + "-windows-part2of2.zip"), p2)
        b, msg = self.import_one(p1, p2)
        self.assert_installed(b, msg)

    def test_damaged_part_is_refused(self):
        d = os.path.join(self.tmp, "dl")
        os.makedirs(d)
        shutil.copy(fixture(RD + "-windows-part1of2.zip"), d)

        def flip(data):
            return data[:100] + bytes([data[100] ^ 1]) + data[101:]
        rewrite_zip(fixture(RD + "-windows-part2of2.zip"),
                    os.path.join(d, RD + "-windows-part2of2.zip"),
                    edit=(".exe.part2", flip))
        b, msg = self.import_one(os.path.join(d, RD + "-windows-part1of2.zip"))
        self.assertIsNone(b)
        self.assertIn("does not match its checksum", msg)
        self.assertEqual(self.lib.builds, [])
        self.assertEqual(os.listdir(self.lib.staging_dir), [])

    def test_unsafe_zip_is_refused(self):
        bad = os.path.join(self.tmp, "bad.zip")
        with zipfile.ZipFile(bad, "w") as z:
            z.writestr("../evil.txt", "x")
        b, msg = self.import_one(bad)
        self.assertIsNone(b)
        self.assertIn("unsafe path", msg)
        self.assertFalse(os.path.exists(os.path.join(self.lib.home, "evil.txt")))

    # ------------------------------------------------------------ updates
    def test_same_build_twice_changes_nothing(self):
        b1, _ = self.import_one(IL + "-windows.zip")
        b2, msg = self.import_one(IL + "-windows-part1of2.zip")
        self.assertIn("already installed and identical", msg)
        self.assertEqual(len(self.lib.builds), 1)

    def test_update_keeps_previous_version(self):
        self.import_one(IL + "-windows.zip")
        newer = os.path.join(self.tmp, "Archipepsi-Impact-Lab-deadbeef-windows.zip")
        rewrite_zip(fixture(IL + "-windows.zip"), newer,
                    rename=(IL, "Archipepsi-Impact-Lab-deadbeef"))
        b, msg = self.import_one(newer)
        self.assertIn("1 earlier version(s) kept", msg)
        [(product, builds)] = self.lib.products()
        self.assertEqual([x["id"] for x in builds],
                         ["Archipepsi-Impact-Lab-deadbeef", IL])
        self.assertTrue(self.lib.is_newest(builds[0]))
        self.assertEqual(self.lib.status(builds[1]), "ok")

    def test_replacement_of_same_revision_is_kept_beside(self):
        self.import_one(IL + "-windows.zip")
        other = os.path.join(self.tmp, "x", IL + "-windows.zip")
        os.makedirs(os.path.dirname(other))
        shutil.copy(fixture(RD + "-windows.zip"), other)
        rewrite_zip(fixture(RD + "-windows.zip"), other, rename=(RD, IL))
        b, msg = self.import_one(other)
        self.assertIsNotNone(b, msg)
        self.assertEqual(b["id"], IL + " (2)")
        self.assertEqual(len(self.lib.builds), 2)

    def test_broken_install_is_repaired_by_reimport(self):
        b, _ = self.import_one(IL + "-windows.zip")
        os.remove(os.path.join(self.lib.folder(b), b["exe"]))
        self.assertEqual(self.lib.status(b), "missing")
        b2, msg = self.import_one(IL + "-windows.zip")
        self.assertIn("Repaired", msg)
        self.assertEqual(self.lib.status(b2), "ok")
        self.assertEqual(len(self.lib.builds), 1)

    # ------------------------------------------------------------ library
    def test_library_persists_and_removes(self):
        b, _ = self.import_one(D + "-windows.zip")
        again = Library(self.lib.home)
        self.assertEqual([x["id"] for x in again.builds], [D])
        again.remove(D)
        self.assertFalse(os.path.exists(again.folder(b)))
        self.assertEqual(Library(self.lib.home).builds, [])

    def test_command_uses_mode_args_and_console(self):
        b, _ = self.import_one(RD + "-windows.zip")
        folder = self.lib.folder(b)
        self.assertEqual(self.lib.command(b, b["modes"][0]),
                         [os.path.join(folder, "Archipepsi-Crossing-D.exe"), "--", "--empty-yard"])
        self.assertEqual(self.lib.command(b, b["modes"][1], console=True),
                         [os.path.join(folder, "Archipepsi-Crossing-D.console.exe")])


if __name__ == "__main__":
    unittest.main()
