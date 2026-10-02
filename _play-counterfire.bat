@echo off
REM ===================================================================
REM  EX50-021 COUNTERFIRE ARCADE - shared launcher. Not for
REM  double-clicking.
REM
REM  NO BRIDGE AND NO PYTHON. Not a Zone, no Checks, no exit, no save,
REM  no connection. It runs before the game boots its menu and cannot
REM  be reached without the flag.
REM ===================================================================
setlocal
cd /d "%~dp0"
chcp 65001 >nul 2>&1

set VARIANT=%~1
set EXTRA=
if /i "%VARIANT%"=="blocked" set EXTRA=--blocked
if /i "%VARIANT%"=="" set VARIANT=arcade

echo.
echo   ARCHIPEPSI 0.4 - EX50-021 COUNTERFIRE ARCADE - %VARIANT%
echo   ==================================================
echo.
echo   Not a Zone: no Checks, no exit, no campaign, no bridge.
echo   Development scaffolding, and nothing here is multiworld-safe.
echo.
if /i "%VARIANT%"=="blocked" echo   BLOCKED is the counterpart: steel across the lane between the
if /i "%VARIANT%"=="blocked" echo   gunner and the trip. The bait cannot work. The west route can.
if /i "%VARIANT%"=="blocked" echo.

call "%~dp0_find-godot.bat"
if not defined GODOT goto godotmissing

set CONSOLE=
for %%i in ("%GODOT%") do set "CONSOLE=%%~dpni_console%%~xi"
if exist "%CONSOLE%" set "GODOT=%CONSOLE%"

echo   Godot:  %GODOT%
echo.
echo   -------------------------------------------------------------
echo     WASD / space     move
echo     left mouse       Static Pulse
echo     E                pull the service release
echo     Esc              quit
echo.
echo     Stand in the painted lane where the gunner can see you. When
echo     it shoots, step west into the alcove -- the shot carries on
echo     into the impact trip behind you and the shutter opens for
echo     eight seconds.
echo.
echo     Or take the west stair, kill the gunner, and shoot the trip
echo     yourself from the lane side. Both finish the room.
echo   -------------------------------------------------------------
echo.

"%GODOT%" --path "%~dp0godot" -- --counterfire %EXTRA%

echo.
echo   The arcade has closed.
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
