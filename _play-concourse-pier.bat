@echo off
REM ===================================================================
REM  THE CONCOURSE-PIER PLAYTEST - shared launcher. Not for
REM  double-clicking; use "Play Concourse Pier - empty" or "- populated".
REM
REM  NO BRIDGE AND NO PYTHON, AND ISOLATED BEFORE ANYTHING CONNECTS.
REM  The game itself refuses to open a bridge connection under this
REM  flag, so a campaign bridge left running on this machine never hears
REM  from it, and it writes none of your settings, favourites or saves.
REM  The room is Arty's pending shell_concourse_pier, loaded for this
REM  playtest only; normal campaigns never choose it.
REM ===================================================================
setlocal
cd /d "%~dp0"
chcp 65001 >nul 2>&1

set MODE=%~1
set EXTRA=
if /i "%MODE%"=="populated" set EXTRA=--populated
if /i "%MODE%"=="" set MODE=empty

echo.
echo   ARCHIPEPSI 0.4 - CONCOURSE PIER PLAYTEST - %MODE%
echo   ==================================================
echo.
echo   One room, pending review, in a short route of the real game.
echo   Not connected, nothing is saved. Not multiworld-safe scaffolding.
echo.

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
echo     WASD / space     move, jump      mouse   look
echo     left click       Static Pulse    Esc     menu
echo.
echo     The route: corridor, then the room, then the exit portal.
echo     The exit portal, RETURN TO HUB or ABANDON all start the
echo     route again from the beginning. Esc, then QUIT GAME, to stop.
if /i "%MODE%"=="populated" echo     POPULATED: a ranged enemy on the pier, a melee on the floor.
if /i "%MODE%"=="populated" echo     You never have to kill them to leave.
echo   -------------------------------------------------------------
echo.

"%GODOT%" --path "%~dp0godot" -- --concourse-pier %EXTRA%

echo.
echo   The playtest has closed.
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
