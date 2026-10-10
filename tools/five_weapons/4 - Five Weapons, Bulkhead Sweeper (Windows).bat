@echo off
rem Five Weapons, an isolated range (no enemies), starting with Bulkhead Sweeper, the fast scattergun.
rem Keys 1-5 switch weapons in play; 6 Heavy Report, 0 Static Pulse. Double-click this to play.
rem On the first run it also joins the game's two parts (if it came in two)
rem and checks the result.
cd /d "%~dp0"
if exist "Archipepsi-Five-Weapons.exe" goto play
if not exist "Archipepsi-Five-Weapons.exe.part1" goto missing
if not exist "Archipepsi-Five-Weapons.exe.part2" goto missing
echo Joining the two parts into the game (once)...
copy /b "Archipepsi-Five-Weapons.exe.part1" + "Archipepsi-Five-Weapons.exe.part2" "Archipepsi-Five-Weapons.exe" >nul
for %%F in ("Archipepsi-Five-Weapons.exe") do set JOINED=%%~zF
if not "%JOINED%"=="@SIZE@" goto broken
del "Archipepsi-Five-Weapons.exe.part1" "Archipepsi-Five-Weapons.exe.part2"
:play
start "" "%~dp0Archipepsi-Five-Weapons.exe" -- --weapon=bulkhead --variant=sweeper
exit /b 0
:missing
echo Unzip BOTH parts (part1of2 and part2of2) into this same folder,
echo then run this again.
pause
exit /b 1
:broken
echo The joined game is %JOINED% bytes, not @SIZE@. Please download both
echo parts again.
del "Archipepsi-Five-Weapons.exe"
pause
exit /b 1
