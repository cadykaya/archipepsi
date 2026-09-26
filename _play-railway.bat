@echo off
REM ===================================================================
REM  THE RAILWAY - shared launcher. Not for double-clicking.
REM
REM  The two "Play the Railway" files are one line each and call this
REM  with their binding. One copy of the logic, two doors into it.
REM
REM  NO BRIDGE AND NO PYTHON, and that is the whole character of this
REM  scenario: it is not a Zone, it carries no Checks and no exit, it
REM  opens no connection and it touches no save. It runs before the
REM  game boots its menu and it cannot be reached without the flag.
REM ===================================================================
setlocal
cd /d "%~dp0"
chcp 65001 >nul 2>&1

set BINDING=%~1
set EXTRA=
if /i "%BINDING%"=="bracing" set EXTRA=--bracing
if /i "%BINDING%"=="" set BINDING=gantry

echo.
echo   ARCHIPEPSI 0.4 - THE RAILWAY - binding: %BINDING%
echo   ==================================================
echo.
echo   Not a Zone: no Checks, no exit, no campaign, no bridge.
echo   Development scaffolding, and nothing here is multiworld-safe.
echo.

call "%~dp0_find-godot.bat"
if not defined GODOT goto godotmissing

REM The console build, where there is one: the ordinary Windows .exe is
REM a GUI app and its `print` output goes nowhere you can see. The
REM scenario prints its own controls and every refusal the railway
REM makes, so a run through the GUI build plays fine and tells you
REM nothing. Built from the NAME, not by replacing ".exe" in the whole
REM path -- the containing folder is called `...win64.exe` here.
set CONSOLE=
for %%i in ("%GODOT%") do set "CONSOLE=%%~dpni_console%%~xi"
if exist "%CONSOLE%" set "GODOT=%CONSOLE%"

echo   Godot:  %GODOT%
echo.
echo   -------------------------------------------------------------
echo     WASD / space     move
echo     left mouse       Static Pulse
echo     E                take the hookshot / pull the lever
echo     mobility key     fire the hookshot
echo     Esc              quit
echo   -------------------------------------------------------------
echo.

"%GODOT%" --path "%~dp0godot" -- --railway %EXTRA%

echo.
echo   The railway has closed.
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
