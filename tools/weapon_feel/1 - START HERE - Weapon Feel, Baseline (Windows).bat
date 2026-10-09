@echo off
rem Weapon Feel, a firing range (no enemies), starting in the baseline (the game as it ships).
rem Keys 1-4 switch treatments in play. Double-click this to play.
rem On the first run it also joins the game's two parts (if it came in two)
rem and checks the result.
cd /d "%~dp0"
if exist "Archipepsi-Weapon-Feel.exe" goto play
if not exist "Archipepsi-Weapon-Feel.exe.part1" goto missing
if not exist "Archipepsi-Weapon-Feel.exe.part2" goto missing
echo Joining the two parts into the game (once)...
copy /b "Archipepsi-Weapon-Feel.exe.part1" + "Archipepsi-Weapon-Feel.exe.part2" "Archipepsi-Weapon-Feel.exe" >nul
for %%F in ("Archipepsi-Weapon-Feel.exe") do set JOINED=%%~zF
if not "%JOINED%"=="@SIZE@" goto broken
del "Archipepsi-Weapon-Feel.exe.part1" "Archipepsi-Weapon-Feel.exe.part2"
:play
start "" "%~dp0Archipepsi-Weapon-Feel.exe" -- --feel=baseline
exit /b 0
:missing
echo Unzip BOTH parts (part1of2 and part2of2) into this same folder,
echo then run this again.
pause
exit /b 1
:broken
echo The joined game is %JOINED% bytes, not @SIZE@. Please download both
echo parts again.
del "Archipepsi-Weapon-Feel.exe"
pause
exit /b 1
