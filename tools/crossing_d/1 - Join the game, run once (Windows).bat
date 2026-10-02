@echo off
rem Crossing D review build, delivered in two parts: join them into the
rem game, check its size, and start it. Run this once; afterwards start
rem Archipepsi-Crossing-D.exe (or the no-enemies launcher) directly.
cd /d "%~dp0"
if exist "Archipepsi-Crossing-D.exe" goto play
if not exist "Archipepsi-Crossing-D.exe.part1" goto missing
if not exist "Archipepsi-Crossing-D.exe.part2" goto missing
copy /b "Archipepsi-Crossing-D.exe.part1" + "Archipepsi-Crossing-D.exe.part2" "Archipepsi-Crossing-D.exe" >nul
for %%F in ("Archipepsi-Crossing-D.exe") do set JOINED=%%~zF
if not "%JOINED%"=="@SIZE@" goto broken
del "Archipepsi-Crossing-D.exe.part1" "Archipepsi-Crossing-D.exe.part2"
:play
start "" "%~dp0Archipepsi-Crossing-D.exe"
exit /b 0
:missing
echo Unzip BOTH parts (part 1 of 2 and part 2 of 2) into this same folder,
echo then run this again.
pause
exit /b 1
:broken
echo The joined game is %JOINED% bytes, not @SIZE@. Please download both
echo parts again.
del "Archipepsi-Crossing-D.exe"
pause
exit /b 1
