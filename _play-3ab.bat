@echo off
REM ===================================================================
REM  THE 3A/3B CHECKPOINT - shared launcher. Not for double-clicking.
REM
REM  The three "Play 3AB - <mode>" files are one line each and all call
REM  this with their mode. One copy of the logic, three doors into it,
REM  so a fix to the bridge handling or the Godot search reaches all
REM  three modes rather than two of them.
REM
REM  NO DELAYED EXPANSION, DELIBERATELY. The first version of this used
REM  it, and stripping the quotes drag-and-drop adds to a path was done
REM  with `set GODOT=!GODOT:"=!` INSIDE a parenthesised block -- where a
REM  `"` changes how cmd parses the rest of the block. The quotes
REM  survived, were saved to godot-path.txt, and cmd then tried to run a
REM  command whose name was a quoted string:
REM
REM    '"C:\...\Godot_v4.5.1-stable_win64.exe"' is not recognized
REM
REM  Everything that touches a path is at the TOP LEVEL now, with
REM  labels and `goto` instead of blocks.
REM ===================================================================
setlocal
cd /d "%~dp0"
chcp 65001 >nul 2>&1

set MODE=%~1
set VALID=
if /i "%MODE%"=="none" set VALID=1
if /i "%MODE%"=="rail" set VALID=1
if /i "%MODE%"=="launch" set VALID=1
if not defined VALID goto badmode

REM ONE save directory for all three modes, and that is the whole point
REM of it. The bridge generates Zone 1 once and stores it; every later
REM launch against this directory reads it back instead of generating
REM again, so `none`, `rail` and `launch` are three visits to the SAME
REM level rather than three levels that happen to match. It is also
REM kept apart from `saves\`, so a checkpoint run can never overwrite a
REM campaign you care about.
set SAVES=%~dp0playtest-3ab
if not exist "%SAVES%" mkdir "%SAVES%"

echo.
echo   ARCHIPEPSI - 3A/3B CHECKPOINT - movement package: %MODE%
echo   =======================================================
echo.

REM --- Python, the same two-step as the other launchers -------------
set PY=
where py >nul 2>&1 && set PY=py
if "%PY%"=="" where python >nul 2>&1 && set PY=python
if "%PY%"=="" goto nopython

%PY% -c "import pydantic, websockets" >nul 2>&1
if not errorlevel 1 goto haslibs
echo   Installing the two libraries the bridge needs...
echo.
%PY% -m pip install --quiet pydantic websockets
if errorlevel 1 goto nolibs
:haslibs

REM --- Godot --------------------------------------------------------
REM
REM Asked for once and remembered in `godot-path.txt`, which is
REM gitignored: it is a fact about YOUR machine, not about the project.
set GODOTFILE=%~dp0godot-path.txt
set GODOT=

if defined ARCHIPEPSI_GODOT set "GODOT=%ARCHIPEPSI_GODOT%"
if defined GODOT goto godotclean

if not exist "%GODOTFILE%" goto godotsearch
set /p GODOT=<"%GODOTFILE%"
if defined GODOT goto godotclean

:godotsearch
for /f "delims=" %%g in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%g"
call :findgodot "%LOCALAPPDATA%\Programs\Godot"
call :findgodot "%ProgramFiles%\Godot"
call :findgodot "%ProgramFiles(x86)%\Godot"
call :findgodot "%USERPROFILE%\Downloads"
call :findgodot "%USERPROFILE%\Desktop"
call :findgodot "%USERPROFILE%\Documents"
if defined GODOT goto godotclean

echo   I could not find Godot 4.5.1 on this machine.
echo.
echo   Drag the Godot .exe onto this window and press Enter, or type
echo   the full path to it. I will remember it for next time.
echo.
set "GODOT="
set /p GODOT=Godot .exe: 

:godotclean
if not defined GODOT goto godotmissing
REM Drag-and-drop wraps the path in quotes and often leaves a trailing
REM space. Both are removed HERE, at the top level, where a `"` cannot
REM corrupt the parse of anything else.
set GODOT=%GODOT:"=%

:trimtail
if not "%GODOT:~-1%"==" " goto trimmed
set "GODOT=%GODOT:~0,-1%"
goto trimtail
:trimmed

if not exist "%GODOT%" goto godotmissing

REM IS IT ACTUALLY A FILE? `if exist` says yes to a directory, so a
REM folder named `something.exe` passes every check above and fails only
REM when cmd tries to run it. Where the answer is a directory the useful
REM move is to look INSIDE it rather than refuse -- that is exactly
REM where the real executable was.
set ATTR=
for %%i in ("%GODOT%") do set "ATTR=%%~ai"
if /i not "%ATTR:~0,1%"=="d" goto godotisfile
set "GODOTDIR=%GODOT%"
set "GODOT="
call :findgodot "%GODOTDIR%"
if not defined GODOT goto godotwasdir
goto godotclean

:godotisfile
> "%GODOTFILE%" echo %GODOT%

REM THE CONSOLE BUILD, WHERE THERE IS ONE. Godot ships two .exe files
REM on Windows and the ordinary one is a GUI app: its `print` output
REM goes nowhere you can see. The census lines this checkpoint is read
REM by -- `p3a: zone zone_001 mode=rail ... built=1` -- come from the
REM game, so a run through the GUI build plays fine and tells you
REM nothing.
REM Built from the name, not by replacing ".exe" in the whole path:
REM the containing FOLDER is called `...win64.exe` here, so a blind
REM replace renames the directory too and points at nothing.
set CONSOLE=
for %%i in ("%GODOT%") do set "CONSOLE=%%~dpni_console%%~xi"
if exist "%CONSOLE%" set "GODOT=%CONSOLE%"

echo   Godot:  %GODOT%
echo.

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
if not "%CHECKED%"=="0" goto checkfailed

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
set WAITED=0
:waitbridge
netstat -ano | findstr /r /c:"LISTENING" | findstr ":38290" >nul 2>&1
if not errorlevel 1 goto bridgeready
if %WAITED% GEQ 30 goto bridgefailed
set /a WAITED+=1
timeout /t 1 /nobreak >nul
goto waitbridge

:bridgeready
if defined BRIDGEUP echo   The bridge was already running - reusing it, so this is the
if defined BRIDGEUP echo   same stored Zone you were just in.
if defined BRIDGEUP echo.

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

"%GODOT%" --path "%~dp0godot" -- --movement-package=%MODE%

echo.
echo   The game has closed. The bridge is still running, so the next
echo   mode will be the same stored Zone.
echo.
pause
exit /b 0

REM --- subroutine ---------------------------------------------------
:findgodot
if defined GODOT goto :eof
if not exist "%~1" goto :eof
REM /a-d = FILES ONLY. Without it `dir /s` lists a DIRECTORY whose name
REM matches too -- and one does: the Windows zip extracts to a folder
REM called `Godot_v4.5.1-stable_win64.exe` with the real executables
REM inside it. The launcher resolved that folder, `if exist` agreed it
REM was there, and cmd was then asked to run a directory.
for /f "delims=" %%g in ('dir /b /s /a-d "%~1\Godot_v4.5*.exe" 2^>nul') do if not defined GODOT set "GODOT=%%g"
goto :eof

REM --- the ways this stops ------------------------------------------
:badmode
echo.
echo   "%MODE%" is not a movement package. The three are:
echo       none    rail    launch
echo.
pause
exit /b 1

:nopython
echo   Python is not installed, or is not on your PATH.
echo.
echo   Install it from https://www.python.org/downloads/
echo   and tick "Add python.exe to PATH" on the first screen.
echo.
pause
exit /b 1

:nolibs
echo.
echo   That failed. Try running this by hand to see why:
echo       %PY% -m pip install pydantic websockets
echo.
pause
exit /b 1

:godotwasdir
echo.
echo   That path is a folder, not a program, and I could not find a
echo   Godot executable inside it:
echo       %GODOTDIR%
echo.
echo   Delete "godot-path.txt" next to this file and run this again.
echo.
pause
exit /b 1

:godotmissing
echo.
echo   I cannot find a Godot executable here:
echo       %GODOT%
echo.
echo   Delete "godot-path.txt" next to this file and run this again to
echo   be asked afresh. Typing the path is safer than dragging it in.
echo.
pause
exit /b 1

:checkfailed
echo.
echo   The baseline check refused. Nothing was started and nothing was
echo   changed. Paste the message above to Claude.
echo.
pause
exit /b 1

:bridgefailed
echo   The bridge did not come up within 30 seconds. Its own window has
echo   the error in it.
echo.
pause
exit /b 1
