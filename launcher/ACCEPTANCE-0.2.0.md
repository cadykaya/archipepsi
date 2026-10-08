# Launcher 0.2.0-rc1: acceptance checklist

`ArchipepsiLauncher-0.2.0-rc1.exe` is the 0.1.0 launcher you tested, made
safe to install with (see `HARDENING.md`). The window and the way you use
it have not changed.

It has **not** been run on native Windows yet; that is what this checklist
is for. Under Wine, it was run against your real Impact Lab download
(`3337769d`, both parts) and against a library written by 0.1.0. It
installed and verified the build, joining it to `0e006640…`, the same
executable Prod's report names. It kept every 0.1.0 build, and Play
started the real game. The container has no graphics card, so the game
stopped at its video-driver warning.

**Before you start:** close 0.1.0. Keep your build ZIPs where they are.
Put the three `Acceptance-*.zip` test files in a new folder of their own.
They hold a tiny fake game that can never install.

| # | Do | Expect |
|---|---|---|
| 1 | Start `ArchipepsiLauncher-0.2.0-rc1.exe`. | A note says it checked the builds already installed and **all are intact and kept**. The same builds are listed. The window title says 0.2.0-rc1. |
| 2 | Play Crossing D, *NO ENEMIES*. Quit. Then play *with enemies*. | The Upper Yard is empty in the first mode and has its fight in the second. |
| 3 | Install Crossing D's two ZIPs again. | "Already installed and identical; nothing changed." |
| 4 | Install Impact Lab by choosing only its **part 1** (both parts in Downloads). | It installs. Its details say *4 files match their checksums; game size matches*. Play starts it. |
| 5 | Install `Acceptance-Broken-Download-…zip`. | Refused: "not a complete ZIP file … download it again". Nothing new in the list. |
| 6 | Install `Acceptance-Mismatched-Parts-…part1of2.zip`. | Refused: "damaged, or its parts come from two different downloads … Nothing was installed". |
| 7 | Copy only Impact Lab's part 1 into an empty folder and install it from there. | Refused: "came in 2 parts, but one is missing". Nothing changes. |
| 8 | Start Impact Lab. While it runs, select it and press *Remove this build…*. | "Still in use, so nothing was removed." Quit the game. |
| 9 | Double-click the launcher exe again while it is open. | "The launcher is already open." |
| 10 | *Open build folder* on Impact Lab and delete `Archipepsi-Impact-Lab.exe`. Back in the launcher, select another build, then Impact Lab again. | Its details say *PROBLEM: … game file is missing*, and Play is greyed out. Install its part 1 again: "Repaired". Play works. |
| 11 | Remove Impact Lab (with the game closed). | It disappears. Every other build still plays. |

If a step does something else, a screenshot of the message is enough to
fix it. Steps 1, 8 and 9 matter most. On Windows they depend on behaviour
that Wine could only simulate.

## Known limits of this release candidate

- The exe is unsigned. SmartScreen asks for *More info → Run anyway*.
- "Latest" means the most recently installed, not the highest revision.
- The launcher keeps any `archipepsi-build.json` from the packaging
  standard (PR #25) but does not read it yet. Modes still come from the
  `.bat` files.
- Built with Windows Python 3.12.10 and PyInstaller 6.11.1, under Wine. To
  rebuild natively, run `build_windows.bat`.
