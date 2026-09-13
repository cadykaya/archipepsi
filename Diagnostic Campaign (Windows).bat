@echo off
REM ===================================================================
REM  ARCHIPEPSI - DIAGNOSTIC CAMPAIGN
REM
REM  Double-click this to resume (or start) the default-scale
REM  diagnostic campaign. It is NOT the same as "Start Archipepsi",
REM  which starts the bridge at the PROTOTYPE scale and in the
REM  ordinary save folder. Those are two different games and the
REM  difference does not show until several Zones in.
REM
REM  It resumes the same slot every time. Nothing here ever deletes,
REM  resets or moves a campaign, and it never writes to bridge\saves.
REM
REM  Options, if you want them - drop one of these on the command
REM  line, or just double-click for the ordinary resume:
REM
REM    --list            which diagnostic slots exist, and where
REM    --slot 582e954    resume a slot by name
REM    --new             begin a fresh slot named for this revision
REM    --dry-run         say what would happen and start nothing
REM
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
%PY% -m archipepsi_bridge.diagnostic %*
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
