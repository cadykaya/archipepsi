"""Installation safety: damaged and incomplete downloads, unsafe archives,
interrupted installs and rollback, duplicates and damaged installs.

Each test names the failure it guards against; every refusal must leave
the library exactly as it was.
"""

import errno
import hashlib
import json
import os
import shutil
import tempfile
import unittest
import zipfile
from unittest import mock

from archipepsi_launcher import library as L
from archipepsi_launcher.library import InstallError, Library

FIX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
IL = "Archipepsi-Impact-Lab-c45086e1"
RD = "Archipepsi-Crossing-D-readability-0e54caab"


def patch_headers(path, central_off, local_off, fn):
    """Apply fn(buffer, index) to a field in every ZIP header."""
    b = bytearray(open(path, "rb").read())
    for sig, off in ((b"PK\x01\x02", central_off), (b"PK\x03\x04", local_off)):
        i = b.find(sig)
        while i >= 0:
            fn(b, i + off)
            i = b.find(sig, i + 4)
    with open(path, "wb") as f:
        f.write(bytes(b))


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.lib = Library(os.path.join(self.tmp, "home"))
        self.lib.startup()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def copy(self, *names, sub="dl"):
        d = os.path.join(self.tmp, sub)
        os.makedirs(d, exist_ok=True)
        return [shutil.copy(os.path.join(FIX, n), d) for n in names]

    def install(self, *paths):
        return self.lib.import_zips(list(paths))

    def snapshot(self):
        """What a refusal must not change: the index and the builds folder."""
        index = open(self.lib.index_path).read() if os.path.exists(self.lib.index_path) else None
        return index, sorted(os.listdir(self.lib.builds_dir))

    def assert_refused(self, results, *phrases):
        self.assertEqual(len(results), 1, results)
        build, msg = results[0]
        self.assertIsNone(build, msg)
        for p in phrases:
            self.assertIn(p, msg)
        self.assertFalse(os.listdir(self.lib.staging_dir) if os.path.isdir(
            self.lib.staging_dir) else [], "staging not cleaned")
        return msg


class DamagedDownloads(Base):
    def test_truncated_zip(self):
        [p] = self.copy(IL + "-windows.zip")
        data = open(p, "rb").read()
        open(p, "wb").write(data[: len(data) // 2])
        before = self.snapshot()
        self.assert_refused(self.install(p), "not a complete ZIP file", "download it again")
        self.assertEqual(self.snapshot(), before)

    def test_corrupt_member_crc(self):
        [p] = self.copy(IL + "-windows.zip")
        with zipfile.ZipFile(p) as z:
            info = z.getinfo(IL + "/Archipepsi-Impact-Lab.exe")
        b = bytearray(open(p, "rb").read())
        # Flip a byte inside that member's compressed data.
        start = info.header_offset + 30 + len(info.filename.encode()) + len(info.extra)
        b[start + info.compress_size // 2] ^= 0xFF
        open(p, "wb").write(bytes(b))
        self.assert_refused(self.install(p), "does not unpack correctly", "Download it again")
        self.assertEqual(self.lib.builds, [])

    def test_password_protected(self):
        [p] = self.copy(IL + "-windows.zip")
        patch_headers(p, 8, 6, lambda b, k: b.__setitem__(k, b[k] | 1))
        self.assert_refused(self.install(p), "password-protected")

    def test_unsupported_compression(self):
        [p] = self.copy(IL + "-windows.zip")
        patch_headers(p, 10, 8, lambda b, k: b.__setitem__(k, 9))  # Deflate64
        self.assert_refused(self.install(p), "compression method the launcher cannot open")

    def test_parts_from_two_downloads_same_name(self):
        """A part 2 from a different build of the same name: the checksum
        catches the join."""
        d = os.path.join(self.tmp, "dl")
        os.makedirs(d)
        shutil.copy(os.path.join(FIX, IL + "-windows-part1of2.zip"), d)
        with zipfile.ZipFile(os.path.join(FIX, RD + "-windows-part2of2.zip")) as zin, \
                zipfile.ZipFile(os.path.join(d, IL + "-windows-part2of2.zip"), "w") as zout:
            data = zin.read(RD + "/Archipepsi-Crossing-D.exe.part2")
            zout.writestr(IL + "/Archipepsi-Impact-Lab.exe.part2", data)
        self.assert_refused(self.install(os.path.join(d, IL + "-windows-part1of2.zip")),
                            "parts come from two different downloads")

    def test_joined_size_mismatch_without_sums(self):
        d = os.path.join(self.tmp, "dl")
        os.makedirs(d)
        for n in (1, 2):
            src = os.path.join(FIX, IL + "-windows-part%dof2.zip" % n)
            with zipfile.ZipFile(src) as zin, zipfile.ZipFile(
                    os.path.join(d, os.path.basename(src)), "w") as zout:
                for info in zin.infolist():
                    if info.filename.endswith("SHA256SUMS.txt"):
                        continue
                    data = zin.read(info)
                    if info.filename.endswith(".part2"):
                        data = data[:-10]
                    zout.writestr(info, data)
        self.assert_refused(self.install(os.path.join(d, IL + "-windows-part1of2.zip")),
                            "wrong size")


class IncompleteTwoPart(Base):
    def test_missing_part_does_not_block_other_builds(self):
        a, b = self.copy(IL + "-windows-part1of2.zip", RD + "-windows.zip")
        results = self.install(a, b)
        msgs = [m for _, m in results]
        self.assertEqual(len(results), 2, msgs)
        self.assertTrue(any("one is missing" in m and IL + "-windows-part2of2.zip" in m
                            for m in msgs), msgs)
        self.assertEqual([x["id"] for x in self.lib.builds], [RD])

    def test_parts_of_two_different_builds(self):
        a, b = self.copy(IL + "-windows-part1of2.zip", RD + "-windows-part2of2.zip")
        results = self.install(a, b)
        self.assertEqual(len(results), 2)
        self.assertTrue(all(bld is None and "missing" in m for bld, m in results))
        self.assertEqual(self.lib.builds, [])

    def test_only_part_two_renamed(self):
        """A lone renamed part 2 (name no longer says it is a part)."""
        d = os.path.join(self.tmp, "dl")
        os.makedirs(d)
        p = shutil.copy(os.path.join(FIX, IL + "-windows-part2of2.zip"),
                        os.path.join(d, "download (3).zip"))
        self.assert_refused(self.install(p), "incomplete", "only part 2")


class UnsafeArchives(Base):
    def make(self, entries, name="Pkg-1234567-windows.zip"):
        p = os.path.join(self.tmp, name)
        with zipfile.ZipFile(p, "w") as z:
            for n, data in entries:
                z.writestr(n, data)
        return p

    def test_refused_entries(self):
        cases = [
            ("../evil.txt", "climbs out"),
            ("Pkg-1234567/../../evil.txt", "climbs out"),
            ("/abs/evil.txt", "absolute path"),
            ("C:/Windows/evil.txt", "absolute path"),
            ("Pkg-1234567\\..\\..\\evil.txt", "climbs out"),
            ("Pkg-1234567/CON.txt", "reserves"),
            ("Pkg-1234567/a:b.exe", "does not allow"),
            ("Pkg-1234567/trailing. ", "ends in a space or dot"),
        ]
        for entry, why in cases:
            with self.subTest(entry=entry):
                p = self.make([("Pkg-1234567/Pkg.exe", "x"), (entry, "x")])
                msg = self.assert_refused(self.install(p), "should not", why)
                self.assertIn("installed nothing", msg)
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "evil.txt")))
        self.assertFalse(os.path.exists(os.path.join(self.lib.home, "evil.txt")))

    def test_checksum_list_pointing_outside(self):
        outside = os.path.join(self.tmp, "outside.txt")
        open(outside, "w").write("hi")
        sha = hashlib.sha256(b"hi").hexdigest()
        p = self.make([("Pkg-1234567/Pkg.exe", "x"),
                       ("Pkg-1234567/SHA256SUMS.txt", "%s  ../../../outside.txt\n" % sha)])
        self.assert_refused(self.install(p), "checksum list points outside")

    def test_not_enough_space_checked_on_unpacked_size(self):
        [p] = self.copy(IL + "-windows.zip")
        usage = shutil.disk_usage(self.tmp)
        tight = usage._replace(free=L.SPACE_MARGIN + 1000)
        with mock.patch.object(L.shutil, "disk_usage", return_value=tight):
            self.assert_refused(self.install(p), "not enough free space")
        self.assertEqual(self.lib.builds, [])


class InterruptedAndRollback(Base):
    def test_disk_full_while_joining(self):
        [p] = self.copy(IL + "-windows-part1of2.zip", IL + "-windows-part2of2.zip")[:1]
        before = self.snapshot()
        real_open = open

        def full_open(path, mode="r", *a, **k):
            if "w" in mode and str(path).endswith("Archipepsi-Impact-Lab.exe"):
                raise OSError(errno.ENOSPC, "No space left on device")
            return real_open(path, mode, *a, **k)
        with mock.patch("builtins.open", full_open):
            self.assert_refused(self.install(p), "ran out of space", "Nothing was changed")
        self.assertEqual(self.snapshot(), before)

    def test_index_write_failure_rolls_back(self):
        [p] = self.copy(IL + "-windows.zip")
        before = self.snapshot()
        with mock.patch.object(Library, "save", side_effect=OSError(errno.EACCES, "denied")):
            self.assert_refused(self.install(p), "would not let the launcher write")
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.lib.builds, [])

    def test_crash_after_move_before_record_is_recovered(self):
        [p] = self.copy(IL + "-windows.zip")
        with mock.patch.object(Library, "save", side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):  # the process dies here
                self.install(p)
        again = Library(self.lib.home)
        notices = again.startup()
        self.assertEqual([b["id"] for b in again.builds], [IL])
        self.assertEqual(again.check(again.builds[0], full=True), "ok")
        self.assertTrue(any("back in the list" in n for n in notices), notices)
        self.assertFalse(os.listdir(again.staging_dir) if os.path.isdir(again.staging_dir) else [])

    def test_crash_mid_unpack_leaves_nothing(self):
        [p] = self.copy(IL + "-windows.zip")
        with mock.patch.object(L, "join_parts", side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                self.install(p)
        # A real crash would skip the cleanup too: leave some staging behind.
        os.makedirs(os.path.join(self.lib.staging_dir, "abc", IL))
        os.makedirs(os.path.join(self.lib.builds_dir, ".incoming-1234"))
        os.makedirs(os.path.join(self.lib.builds_dir, ".trash-1234"))
        again = Library(self.lib.home)
        again.startup()
        self.assertFalse(os.path.exists(again.staging_dir))
        self.assertEqual(os.listdir(again.builds_dir), [])
        self.assertEqual(again.builds, [])

    def test_unrecognised_folder_is_set_aside_not_deleted(self):
        junk = os.path.join(self.lib.builds_dir, "Half-Copied-1234567")
        os.makedirs(junk)
        open(os.path.join(junk, "notes.txt"), "w").write("mine")
        again = Library(self.lib.home)
        notices = again.startup()
        self.assertTrue(os.path.isfile(os.path.join(again.aside_dir, "Half-Copied-1234567",
                                                    "notes.txt")))
        self.assertTrue(any("unrecognised" in n for n in notices))

    def test_corrupt_index_restored_from_backup(self):
        [p] = self.copy(IL + "-windows.zip")
        self.install(p)
        [q] = self.copy(RD + "-windows.zip")
        self.install(q)  # second save: the .bak now lists the first build
        open(self.lib.index_path, "w").write("{not json")
        again = Library(self.lib.home)
        notices = again.startup()
        self.assertEqual(sorted(b["id"] for b in again.builds), sorted([IL, RD]))
        self.assertTrue(any("backup" in n for n in notices), notices)
        self.assertTrue(os.path.exists(self.lib.index_path + ".unreadable"))

    def test_lost_index_rebuilt_from_folders(self):
        for n in (IL + "-windows.zip", RD + "-windows.zip"):
            self.install(*self.copy(n))
        os.remove(self.lib.index_path)
        os.remove(self.lib.index_path + ".bak")
        again = Library(self.lib.home)
        again.startup()
        self.assertEqual(sorted(b["id"] for b in again.builds), sorted([IL, RD]))
        self.assertTrue(all(again.check(b, full=True) == "ok" for b in again.builds))

    def test_one_launcher_at_a_time(self):
        self.assertTrue(self.lib.lock())
        other = Library(self.lib.home)
        self.assertFalse(other.lock())
        self.lib.unlock()
        self.assertTrue(other.lock())
        other.unlock()


class DuplicatesAndDamage(Base):
    def test_same_size_damage_is_caught_and_repaired(self):
        [p] = self.copy(IL + "-windows.zip")
        [(b, _)] = self.install(p)
        exe = os.path.join(self.lib.folder(b), b["exe"])
        data = bytearray(open(exe, "rb").read())
        data[10] ^= 1
        open(exe, "wb").write(bytes(data))
        os.utime(exe, (b["exe_mtime"], b["exe_mtime"]))  # even with its old time
        self.assertEqual(self.lib.check(b, full=True), "damaged")
        [(b2, msg)] = self.install(p)
        self.assertIn("Repaired", msg)
        self.assertEqual(self.lib.check(b2, full=True), "ok")
        self.assertEqual(len(self.lib.builds), 1)

    def test_changed_file_is_rehashed_before_launch(self):
        [(b, _)] = self.install(*self.copy(IL + "-windows.zip"))
        exe = os.path.join(self.lib.folder(b), b["exe"])
        data = bytearray(open(exe, "rb").read())
        data[10] ^= 1
        open(exe, "wb").write(bytes(data))
        os.utime(exe, (b["exe_mtime"] + 5, b["exe_mtime"] + 5))
        with self.assertRaises(InstallError) as cm:
            self.lib.launch(b, b["modes"][0])
        self.assertIn("damaged", cm.exception.message)

    def test_repair_keeps_install_order(self):
        [(a, _)] = self.install(*self.copy(IL + "-windows.zip"))
        self.install(*self.copy(RD + "-windows.zip"))
        os.remove(os.path.join(self.lib.folder(a), a["exe"]))
        self.install(*self.copy(IL + "-windows.zip"))
        self.assertEqual([b["id"] for _, bs in self.lib.products() for b in bs], [RD, IL])

    def test_replacement_in_use_changes_nothing(self):
        [(b, _)] = self.install(*self.copy(IL + "-windows.zip"))
        exe = os.path.join(self.lib.folder(b), b["exe"])
        open(exe, "ab").write(b"!")  # damaged: will be replaced
        before = self.snapshot()
        real_rename = os.rename

        def busy(src, dst):
            if src == self.lib.folder(b):
                raise PermissionError(13, "The process cannot access the file")
            return real_rename(src, dst)
        with mock.patch.object(L.os, "rename", busy):
            self.assert_refused(self.install(*self.copy(IL + "-windows.zip")),
                                "still in use", "Close the game")
        self.assertEqual(self.snapshot(), before)

    def test_remove_in_use_keeps_build(self):
        [(b, _)] = self.install(*self.copy(IL + "-windows.zip"))
        with mock.patch.object(L.os, "rename", side_effect=PermissionError(13, "busy")):
            with self.assertRaises(InstallError) as cm:
                self.lib.remove(b["id"])
        self.assertIn("nothing was removed", cm.exception.message)
        self.assertEqual(self.lib.check(b, full=True), "ok")
        self.assertEqual(Library(self.lib.home).builds[0]["id"], IL)

    def test_unrecorded_folder_at_destination_is_kept(self):
        dest = os.path.join(self.lib.builds_dir, IL)
        os.makedirs(dest)
        open(os.path.join(dest, "my-notes.txt"), "w").write("mine")
        [(b, msg)] = self.install(*self.copy(IL + "-windows.zip"))
        self.assertIsNotNone(b, msg)
        self.assertTrue(os.path.isfile(os.path.join(self.lib.aside_dir, IL, "my-notes.txt")))

    def test_old_index_without_new_fields(self):
        """A library written by the MVP (no exe_mtime / verified) still works."""
        [(b, _)] = self.install(*self.copy(IL + "-windows.zip"))
        data = json.load(open(self.lib.index_path))
        for x in data["builds"]:
            x.pop("exe_mtime", None)
            x.pop("verified", None)
        json.dump(data, open(self.lib.index_path, "w"))
        again = Library(self.lib.home)
        again.startup()
        self.assertEqual(again.check(again.builds[0]), "ok")


class Messages(unittest.TestCase):
    """Every refusal speaks plainly: no Python exception names up front."""

    def test_messages_are_plain(self):
        tmp = tempfile.mkdtemp()
        try:
            lib = Library(os.path.join(tmp, "home"))
            bad = os.path.join(tmp, "x-windows.zip")
            open(bad, "wb").write(b"not a zip")
            [(_, msg)] = lib.import_zips([bad])
            head = msg.split("\n\nDetails:")[0]
            for word in ("Error", "Exception", "errno", "Traceback", "BadZipFile"):
                self.assertNotIn(word, head)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
