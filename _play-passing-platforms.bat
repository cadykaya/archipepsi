@echo off
REM ===================================================================
REM  EX50-011 PASSING PLATFORMS - shared launcher. Not for
REM  double-clicking.
REM
REM  NO BRIDGE AND NO PYTHON. It is not a Zone, it carries no Checks
REM  and no exit, it opens no connection and it touches no save. It
REM  runs before the game boots its menu and cannot be reached without
REM  the flag.
REM ===================================================================
setlocal
cd /d "%~dp0"
chcp 65001 >nul 2>&1

set VARIANT=%~1
set EXTRA=
if /i "%VARIANT%"=="parted" set EXTRA=--parted
if /i "%VARIANT%"=="" set VARIANT=passing

echo.
echo   ARCHIPEPSI 0.4 - EX50-011 PASSING PLATFORMS - %VARIANT%
echo   ==================================================
echo.
echo   Not a Zone: no Checks, no exit, no campaign, no bridge.
echo   Development scaffolding, and nothing here is multiworld-safe.
echo.
if /i "%VARIANT%"=="parted" echo   PARTED is the counterexample: the shuttle's track is shifted
if /i "%VARIANT%"=="parted" echo   so nothing passes. It is meant to be uncompletable.
if /i "%VARIANT%"=="parted" echo.

call "%~dp0_find-godot.bat"
if not defined GODOT goto godotmissing

REM The console build, where there is one: the ordinary Windows .exe is
REM a GUI app and its `print` output goes nowhere you can see.
set CONSOLE=
for %%i in ("%GODOT%") do set "CONSOLE=%%~dpni_console%%~xi"
if exist "%CONSOLE%" set "GODOT=%CONSOLE%"

echo   Godot:  %GODOT%
echo.
echo   -------------------------------------------------------------
echo     WASD / space     move
echo     E                pull the lever you are looking at
echo     Esc              quit
echo.
echo     H EAST   at the arrival floor, starts the shuttle
echo     STOP H   holds it wherever it is - the patient route
echo     LAUNCH   on the lift's own deck, sends it up past the
echo              transfer plane to the shelf
echo     RESET    returns both carriers under ordinary motion
echo   -------------------------------------------------------------
echo.

"%GODOT%" --path "%~dp0godot" -- --passing-platforms %EXTRA%

echo.
echo   Passing Platforms has closed.
echo.
pause
exit /b 0

:godotmissing
echo.
echo   I cannot find a Godot executable. Delete "godot-path.txt" next
echo   to this file and run this again to be asked afresh. Typing the
echo   path is safer than dragging it in.
echo.
pause
exit /b 1
