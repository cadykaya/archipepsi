@echo off
REM ===================================================================
REM  PLAYTEST 2.5 - the run we take BEFORE authored art.
REM
REM  Double-click this instead of "Start Archipepsi (Windows).bat".
REM  It is the same game; what it adds is the three things a baseline
REM  run needs and an ordinary run does not:
REM
REM    1. it checks nothing has moved under the baseline, and REFUSES
REM       to start if something has (it never quietly fixes it);
REM    2. it starts the campaign at the scale the baseline was taken
REM       at, which MOCK CAMPAIGN does not do on its own;
REM    3. it keeps your playtest apart from your ordinary saves, and
REM       shows you the numbers the moment you stop.
REM
REM  YOU ONLY HAVE TO PLAY ZONE 1. Zone 2 is optional. Zone 3 is not
REM  needed at all.
REM
REM  The bridge opens in its own window; leave that alone while you
REM  play. Come back to THIS window when Zone 1 is finished.
REM ===================================================================
setlocal
cd /d "%~dp0"
REM UTF-8, so the game's own output does not arrive as mojibake. The
REM messages below are plain ASCII regardless, because a console that
REM refuses this is exactly the console that most needs to be readable.
chcp 65001 >nul 2>&1

set DEST=%~dp0playtest-2.5
REM Made now rather than on first save: the report below is redirected
REM into this folder, and a redirect into a folder that does not exist
REM fails with a bare "The system cannot find the path specified".
if not exist "%DEST%" mkdir "%DEST%"

echo.
echo   ARCHIPEPSI - PLAYTEST 2.5 (pre-art baseline)
echo   ===========================================
echo.

REM --- Python, same two-step as the ordinary launcher ---------------
set PY=
where py >nul 2>&1 && set PY=py
if "%PY%"=="" (
  where python >nul 2>&1 && set PY=python
)
if "%PY%"=="" (
  echo   Python is not installed, or is not on your PATH.
  echo.
  echo   Install it from https://www.python.org/downloads/
  echo   and tick "Add python.exe to PATH" on the first screen.
  echo.
  pause
  exit /b 1
)

%PY% -c "import pydantic, websockets" >nul 2>&1
if errorlevel 1 (
  echo   Installing the two libraries the bridge needs...
  echo.
  %PY% -m pip install --quiet pydantic websockets
  if errorlevel 1 (
    echo.
    echo   That failed. Try running this by hand to see why:
    echo       %PY% -m pip install pydantic websockets
    echo.
    pause
    exit /b 1
  )
)

REM --- Is this checkout in a state worth measuring? -----------------
REM A warning, not a refusal. The record stamps whether the tree was
REM clean, so a dirty run is still a real measurement -- it just cannot
REM be pinned to a commit later. Godot's own rewrite of project.godot
REM is excluded, exactly as the updater excludes it: it happens every
REM time you open the project and you did not do it.
where git >nul 2>&1
if not errorlevel 1 (
  git diff --quiet -- . ":(exclude)godot/project.godot" >nul 2>&1
  if errorlevel 1 (
    echo   NOTE: some files here differ from the version on GitHub. The
    echo   run still counts, but it will be recorded as coming from an
    echo   edited checkout rather than from a known commit.
    echo.
  )
)

REM --- The guard. This is the part that can refuse. ------------------
echo   Checking the baseline...
cd bridge
%PY% -m archipepsi_bridge.playtest check
if errorlevel 1 (
  echo   Nothing was started and nothing was changed.
  echo.
  pause
  exit /b 1
)
cd ..

echo   -------------------------------------------------------------
echo.
echo   PLAY BASELINE ZONE 1.
echo.
echo     1. Leave this window open.
echo     2. Open the Godot project and press Play, as usual.
echo     3. Press MOCK CAMPAIGN.
echo     4. Take the portal into ZONE 1 and play it to the END --
echo        walk back through the portal when you are finished.
echo        Closing the game instead leaves the Zone with no end, and
echo        a Zone with no end has no time.
echo.
echo     Zone 2 is OPTIONAL - only if Zone 1 looked odd, or you want a
echo     second sample. Zone 3 is not needed.
echo.
echo   The bridge opens in a SECOND window. Leave that one alone -
echo   its top line carries the ZONE ID, so the level you are walking
echo   is on screen the whole time. It is in the playtime record too.
echo   Come back to THIS window when you have finished Zone 1.
echo.
echo   -------------------------------------------------------------
echo.

REM --- The bridge, at the baseline configuration --------------------
REM
REM Its OWN window, deliberately. The report below has to run after the
REM playing is done, and the obvious single-window version -- run the
REM bridge here, print afterwards -- only reaches the report if the
REM bridge exits on its own. It does not: a player stops it by closing
REM the window, which kills this script too, and the numbers they came
REM for never print.
REM
REM `cmd /k` so the bridge window survives its own crash. Without it a
REM bridge that dies on startup takes the error message with it, which
REM is the single most common way a .bat file wastes an afternoon.
REM
REM --mock-scale=default is the load-bearing flag: MOCK CAMPAIGN is
REM otherwise the prototype's thirty locations, and Zone 1 of a
REM thirty-location campaign is a different level from the one the
REM baseline is of.
REM
REM --save-dir keeps this run out of your ordinary saves, so a baseline
REM playtest can never overwrite a campaign you care about and the
REM records land in one findable place.
start "Archipepsi bridge - Playtest 2.5 - leave this open" /D "%~dp0bridge" ^
  cmd /k %PY% -m archipepsi_bridge --ap=mock --epsilon=fallback ^
  --mock-scale=default --save-dir "%DEST%"

echo.
echo   Press any key HERE once you have finished playing Zone 1.
echo.
echo   (A Zone is recorded when it ENDS. If you press this before
echo    walking back through the portal, there will be nothing to
echo    report yet -- finish the Zone, then press it.)
echo.
pause

REM --- Afterwards: the numbers, saved and shown ---------------------
echo.
echo   -------------------------------------------------------------
echo.
cd bridge
%PY% -m archipepsi_bridge.playtest report --save-dir "%DEST%" > "%DEST%\REPORT.txt" 2>&1
cd ..
type "%DEST%\REPORT.txt"

echo.
echo   Saved to:
echo     %DEST%\REPORT.txt      (the summary above)
echo     %DEST%\playtime.jsonl  (one line per Zone, the raw record)
echo.
echo   Tell Claude "I'm done with Playtest 2.5" and paste REPORT.txt.
echo   You can close the bridge window now. Opening the folder for you.
echo.
if exist "%DEST%" start "" "%DEST%"
pause
