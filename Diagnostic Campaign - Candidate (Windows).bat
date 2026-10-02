@echo off
REM ===================================================================
REM  ARCHIPEPSI - DIAGNOSTIC CAMPAIGN (CANDIDATE PROFILE, OVERNIGHT 05)
REM
REM  Double-click this to resume (or start) the OPT-IN CANDIDATE
REM  campaign, for review. It is the same default scale and the same
REM  deterministic Epsilon as the ordinary diagnostic campaign, with one
REM  difference: every new Zone runs the candidate profile after its
REM  graph is proved and before it is accepted --
REM
REM    * zone_state     a reversible lever that changes a doorway and
REM                     lamps in the next room
REM    * latched_route  a plate, latch and shutter (P14)
REM    * transport      a 40 kg power cell you carry to a socket; the
REM                     socket opens the way on
REM
REM  Each step adds its relationship or declines by name; what it did is
REM  written to candidate\<zone>.json in the save folder.
REM
REM  NOTHING IS STAGED: no Echo, item, key or function is seeded.
REM
REM  IT USES ITS OWN SAVE SLOT ("candidate"), never the ordinary one or
REM  the lower-budget one. A slot remembers which mode AND which profile
REM  made it, and refuses to be continued any other way. Nothing here
REM  ever deletes, resets or moves a save.
REM
REM  Options, if you want them - drop one of these on the command
REM  line, or just double-click for the ordinary resume:
REM
REM    --list            which diagnostic slots exist, and where
REM    --slot NAME       resume a candidate slot by name
REM    --new             begin a fresh candidate slot for this revision
REM    --dry-run         say what would happen and start nothing
REM
REM  Start the game the usual way while this window is open.
REM  Updating is a SEPARATE double-click: "Update Archipepsi". This
REM  file never fetches, switches branch or resets anything.
REM
REM  Leave this window OPEN while you play.
REM ===================================================================
setlocal
cd /d "%~dp0"
chcp 65001 >nul 2>&1

REM Find a Python. `py` ships with the python.org installer and is the
REM most reliable on Windows; `python` is the fallback, and on a machine
REM with no Python at all it opens the Microsoft Store rather than
REM failing, which is why `py` is tried first.
set PY=
where py >nul 2>&1 && set PY=py
if "%PY%"=="" (
  where python >nul 2>&1 && set PY=python
)
if "%PY%"=="" (
  echo.
  echo   Python is not installed, or is not on your PATH.
  echo.
  echo   Install it from https://www.python.org/downloads/
  echo   and tick "Add python.exe to PATH" on the first screen.
  echo.
  pause
  exit /b 1
)

REM EVERY DECISION IS IN THE PYTHON, and that is deliberate: scale,
REM provider, slot, the resolved folder, the already-running-bridge
REM message and the missing-library message all live in
REM `archipepsi_bridge.diagnostic`, where `bridge/tests/
REM test_diagnostic_launcher.py` can check them. What is left here is
REM finding Python and keeping the window open, which cannot be tested
REM on anything but Windows and is short enough to read.
REM
REM `%*` passes your options straight through. Quoted separately so a
REM folder path with a space in it stays one argument.
cd bridge
REM `--candidate` is FIRST, so it is this launcher's decision and not
REM something you have to remember. Your own options follow it.
%PY% -m archipepsi_bridge.diagnostic --candidate %*
set RESULT=%errorlevel%
cd ..

echo.
if "%RESULT%"=="0" (
  echo   The bridge has stopped. Any error is printed above.
) else (
  echo   Nothing was started. The reason is printed above, and no
  echo   save was created, changed or deleted.
)
echo.
pause
