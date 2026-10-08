@echo off
rem Impact Relay, HEAVY-HIT MODE (no enemies): the same room, with the Braided
rem Lash (14 per hit) on F. On the first run it also joins the game's two
rem parts (if it came in two) and checks the result.
cd /d "%~dp0"
if exist "Archipepsi-Impact-Relay-Art.exe" goto play
if not exist "Archipepsi-Impact-Relay-Art.exe.part1" goto missing
if not exist "Archipepsi-Impact-Relay-Art.exe.part2" goto missing
echo Joining the two parts into the game (once)...
copy /b "Archipepsi-Impact-Relay-Art.exe.part1" + "Archipepsi-Impact-Relay-Art.exe.part2" "Archipepsi-Impact-Relay-Art.exe" >nul
for %%F in ("Archipepsi-Impact-Relay-Art.exe") do set JOINED=%%~zF
if not "%JOINED%"=="@SIZE@" goto broken
del "Archipepsi-Impact-Relay-Art.exe.part1" "Archipepsi-Impact-Relay-Art.exe.part2"
:play
start "" "%~dp0Archipepsi-Impact-Relay-Art.exe" -- --heavy-hit
exit /b 0
:missing
echo Unzip BOTH parts (part1of2 and part2of2) into this same folder,
echo then run this again.
pause
exit /b 1
:broken
echo The joined game is %JOINED% bytes, not @SIZE@. Please download both
echo parts again.
del "Archipepsi-Impact-Relay-Art.exe"
pause
exit /b 1
