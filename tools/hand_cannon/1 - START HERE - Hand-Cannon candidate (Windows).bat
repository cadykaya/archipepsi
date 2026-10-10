@echo off
rem Hand-Cannon candidate, a firing range (no enemies), starting in the hand-cannon candidate (mode H).
rem Keys 1-5 switch treatments in play. Double-click this to play.
rem On the first run it also joins the game's two parts (if it came in two)
rem and checks the result.
cd /d "%~dp0"
if exist "Archipepsi-Hand-Cannon.exe" goto play
if not exist "Archipepsi-Hand-Cannon.exe.part1" goto missing
if not exist "Archipepsi-Hand-Cannon.exe.part2" goto missing
echo Joining the two parts into the game (once)...
copy /b "Archipepsi-Hand-Cannon.exe.part1" + "Archipepsi-Hand-Cannon.exe.part2" "Archipepsi-Hand-Cannon.exe" >nul
for %%F in ("Archipepsi-Hand-Cannon.exe") do set JOINED=%%~zF
if not "%JOINED%"=="@SIZE@" goto broken
del "Archipepsi-Hand-Cannon.exe.part1" "Archipepsi-Hand-Cannon.exe.part2"
:play
start "" "%~dp0Archipepsi-Hand-Cannon.exe"
exit /b 0
:missing
echo Unzip BOTH parts (part1of2 and part2of2) into this same folder,
echo then run this again.
pause
exit /b 1
:broken
echo The joined game is %JOINED% bytes, not @SIZE@. Please download both
echo parts again.
del "Archipepsi-Hand-Cannon.exe"
pause
exit /b 1
