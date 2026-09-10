@echo off
REM ===================================================================
REM  THE 3A/3B CHECKPOINT - shared launcher. Not for double-clicking.
REM
REM  The three "Play 3AB - <mode>" files are one line each and all call
REM  this with their mode. One copy of the logic, three doors into it,
REM  so a fix to the bridge handling or the Godot search reaches all
REM  three modes rather than two of them.
REM
REM  What it does, in order:
REM    1. finds Python and Godot, remembering Godot for next time;
REM    2. starts the bridge if it is not already up, ONCE, on the
REM       shared save directory - which is what makes all three modes
REM       the same stored Zone rather than three regenerations;
REM    3. runs the game with --movement-package=<mode>.
REM ===================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"
chcp 65001 >nul 2>&1

set MODE=%~1
set VALID=
if /i "%MODE%"=="none" set VALID=1
if /i "%MODE%"=="rail" set VALID=1
if /i "%MODE%"=="launch" set VALID=1
if not defined VALID (
  echo.
  echo   "%MODE%" is not a movement package. The three are:
  echo       none    rail    launch
  echo.
  pause
  exit /b 1
)

REM ONE save directory for all three modes, and that is the whole
REM point of it. The bridge generates Zone 1 once and stores it; every
REM later launch against this directory reads it back instead of
REM generating again, so `none`, `rail` and `launch` are three visits
REM to the SAME level rather than three levels that happen to match.
REM It is also kept apart from `saves\`, so a checkpoint run can never
REM overwrite a campaign you care about.
set SAVES=%~dp0playtest-3ab
if not exist "%SAVES%" mkdir "%SAVES%"

echo.
echo   ARCHIPEPSI - 3A/3B CHECKPOINT - movement package: %MODE%
echo   =======================================================
echo.

REM --- Python, the same two-step as the other launchers -------------
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

REM --- Godot -------------------------------------------------------
REM
REM Asked for once and remembered in `godot-path.txt`, which is
REM gitignored: it is a fact about YOUR machine, not about the project,
REM and committing it would hand everyone else a path that does not
REM exist.
set GODOTFILE=%~dp0godot-path.txt
set GODOT=

if defined ARCHIPEPSI_GODOT (
  if exist "%ARCHIPEPSI_GODOT%" set GODOT=%ARCHIPEPSI_GODOT%
)

if not defined GODOT (
  if exist "%GODOTFILE%" (
    set /p SAVED=<"%GODOTFILE%"
    if exist "!SAVED!" set GODOT=!SAVED!
  )
)

if not defined GODOT (
  for /f "delims=" %%g in ('where godot 2^>nul') do (
    if not defined GODOT set GODOT=%%g
  )
)

if not defined GODOT (
  for %%d in (
    "%LOCALAPPDATA%\Programs\Godot"
    "%ProgramFiles%\Godot"
    "%USERPROFILE%\Downloads"
    "%USERPROFILE%\Desktop"
  ) do (
    if not defined GODOT (
      for /f "delims=" %%g in ('dir /b /s "%%~d\Godot_v4.5*.exe" 2^>nul') do (
        if not defined GODOT set GODOT=%%g
      )
    )
  )
)

if not defined GODOT (
  echo   I could not find Godot 4.5.1 on this machine.
  echo.
  echo   Drag the Godot .exe onto this window and press Enter, or type
  echo   the full path to it. I will remember it for next time.
  echo.
  set /p GODOT=^>
  set GODOT=!GODOT:"=!
)

if not exist "!GODOT!" (
  echo.
  echo   That is not a file I can find:
  echo       !GODOT!
  echo.
  pause
  exit /b 1
)
> "%GODOTFILE%" echo !GODOT!

REM THE CONSOLE BUILD, WHERE THERE IS ONE. Godot ships two .exe files
REM on Windows and the ordinary one is a GUI app: its `print` output
REM goes nowhere you can see. The census lines this checkpoint is read
REM by -- `p3a: zone zone_001 mode=rail ... built=1` -- come from the
REM game, so a run through the GUI build plays fine and tells you
REM nothing.
set CONSOLE=!GODOT:.exe=_console.exe!
if exist "!CONSOLE!" set GODOT=!CONSOLE!

REM --- The bridge, once ---------------------------------------------
REM
REM Started only if nothing is already listening. Switching modes means
REM closing the GAME, not the bridge -- and a second bridge on a taken
REM port fails in a way that looks like the game being broken.
set BRIDGEUP=
netstat -ano | findstr /r /c:"LISTENING" | findstr ":38290" >nul 2>&1
if not errorlevel 1 set BRIDGEUP=1

if defined BRIDGEUP goto bridgeready

echo   Checking the baseline...
echo.
pushd bridge
%PY% -m archipepsi_bridge.playtest check
set CHECKED=%errorlevel%
popd
if not "%CHECKED%"=="0" (
  echo.
  echo   The baseline check refused. Nothing was started and nothing
  echo   was changed. Paste the message above to Claude.
  echo.
  pause
  exit /b 1
)

echo.
echo   Starting the bridge in its own window. Leave that window open
echo   while you play - including while you switch modes.
echo.
start "Archipepsi bridge - 3A/3B checkpoint - leave this open" /D "%~dp0bridge" ^
  cmd /k %PY% -m archipepsi_bridge --ap=mock --epsilon=fallback ^
  --mock-scale=default --save-dir "%SAVES%"

REM Wait for the PORT rather than guessing at a sleep: a game that
REM starts first sits at a menu that cannot reach anything, which reads
REM as "the build is broken" and is not.
REM
REM A LABEL CANNOT LIVE INSIDE A PARENTHESISED BLOCK, which is why this
REM whole section is at the top level with `goto` rather than tucked
REM into an if/else. Batch parses the block in one go; a label in it is
REM silently not a label, and `goto` out of one abandons the block.
set WAITED=0

:waitbridge
netstat -ano | findstr /r /c:"LISTENING" | findstr ":38290" >nul 2>&1
if not errorlevel 1 goto bridgeready
if %WAITED% GEQ 30 (
  echo   The bridge did not come up within 30 seconds. Its window has
  echo   the error in it.
  echo.
  pause
  exit /b 1
)
set /a WAITED+=1
timeout /t 1 /nobreak >nul
goto waitbridge

:bridgeready
if defined BRIDGEUP (
  echo   The bridge was already running - reusing it, so this is the
  echo   same stored Zone you were just in.
  echo.
)

echo   -------------------------------------------------------------
echo.
echo   IN THE GAME:
echo     1. Press MOCK CAMPAIGN.
echo     2. Take the portal into ZONE 1.
echo.
echo   DO NOT take the exit portal until you have tried all three
echo   modes. Finishing Zone 1 moves the campaign on to Zone 2, which
echo   is a different level, and the comparison is gone.
echo.
echo   To switch modes: close the GAME window, leave the bridge window
echo   open, and double-click another "Play 3AB" file.
echo.
echo   Movement package this run: %MODE%
echo   -------------------------------------------------------------
echo.

"!GODOT!" --path "%~dp0godot" -- --movement-package=%MODE%

echo.
echo   The game has closed. The bridge is still running, so the next
echo   mode will be the same stored Zone.
echo.
pause
