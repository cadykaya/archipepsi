@echo off
rem Crossing D review build: the same four rooms, the Upper Yard empty.
rem The plain executable is the full Crossing, enemies included.
cd /d "%~dp0"
if exist "%~dp0Archipepsi-Crossing-D.exe" goto play
echo Run "1 - Join the game, run once (Windows).bat" first.
pause
exit /b 1
:play
start "" "%~dp0Archipepsi-Crossing-D.exe" -- --empty-yard
