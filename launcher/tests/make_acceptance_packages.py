"""Writes the two deliberately broken packages used by the acceptance
checklist (ACCEPTANCE-0.2.0.md), from the test fixtures:

- Acceptance-Broken-Download-0000000-windows.zip: cut in half, as an
  unfinished download is;
- Acceptance-Mismatched-Parts-0000000-windows-part1of2/2of2.zip: a
  two-part build whose second part does not match the first.

Neither can ever install; each must be refused with a plain message.

    python tests/make_acceptance_packages.py <output folder>
"""
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "Archipepsi-Crossing-D-readability-0e54caab"


def main(out):
    os.makedirs(out, exist_ok=True)
    fix = os.path.join(HERE, "fixtures")
    name = "Acceptance-Broken-Download-0000000"
    whole = os.path.join(out, name + "-windows.zip")
    _rename(os.path.join(fix, SRC + "-windows.zip"), whole, name)
    data = open(whole, "rb").read()
    with open(whole, "wb") as f:
        f.write(data[: len(data) // 2])
    name = "Acceptance-Mismatched-Parts-0000000"
    _rename(os.path.join(fix, SRC + "-windows-part1of2.zip"),
            os.path.join(out, name + "-windows-part1of2.zip"), name)
    _rename(os.path.join(fix, SRC + "-windows-part2of2.zip"),
            os.path.join(out, name + "-windows-part2of2.zip"), name, damage=True)


def _rename(src, dst, name, damage=False):
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
        for info in zin.infolist():
            data = zin.read(info)
            if damage and info.filename.endswith(".part2"):
                data = data[:100] + bytes([data[100] ^ 0xFF]) + data[101:]
            zout.writestr(name + info.filename[len(SRC):], data)


if __name__ == "__main__":
    main(sys.argv[1])
