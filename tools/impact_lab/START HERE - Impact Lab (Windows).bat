@echo off
rem Impact Lab, a technical fixture (no enemies). Double-click this to play.
rem On the first run it also joins the game's two parts (if it came in two)
rem and checks the result.
cd /d "%~dp0"
if exist "Archipepsi-Impact-Lab.exe" goto play
if not exist "Archipepsi-Impact-Lab.exe.part1" goto missing
if not exist "Archipepsi-Impact-Lab.exe.part2" goto missing
echo Joining the two parts into the game (once)...
copy /b "Archipepsi-Impact-Lab.exe.part1" + "Archipepsi-Impact-Lab.exe.part2" "Archipepsi-Impact-Lab.exe" >nul
for %%F in ("Archipepsi-Impact-Lab.exe") do set JOINED=%%~zF
if not "%JOINED%"=="@SIZE@" goto broken
del "Archipepsi-Impact-Lab.exe.part1" "Archipepsi-Impact-Lab.exe.part2"
:play
start "" "%~dp0Archipepsi-Impact-Lab.exe"
exit /b 0
:missing
echo Unzip BOTH parts (part1of2 and part2of2) into this same folder,
echo then run this again.
pause
exit /b 1
:broken
echo The joined game is %JOINED% bytes, not @SIZE@. Please download both
echo parts again.
del "Archipepsi-Impact-Lab.exe"
pause
exit /b 1
