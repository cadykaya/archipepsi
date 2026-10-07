@echo off
rem Crossing D, readability review build: RUN THIS FIRST. The four rooms
rem with the Upper Yard empty. On the first run it also joins the game's
rem two parts (if it came in two) and checks the result.
cd /d "%~dp0"
if exist "Archipepsi-Crossing-D.exe" goto play
rem Delivered in two parts: join them into the game, once, and check it.
if not exist "Archipepsi-Crossing-D.exe.part1" goto missing
if not exist "Archipepsi-Crossing-D.exe.part2" goto missing
echo Joining the two parts into the game (once)...
copy /b "Archipepsi-Crossing-D.exe.part1" + "Archipepsi-Crossing-D.exe.part2" "Archipepsi-Crossing-D.exe" >nul
for %%F in ("Archipepsi-Crossing-D.exe") do set JOINED=%%~zF
if not "%JOINED%"=="@SIZE@" goto broken
del "Archipepsi-Crossing-D.exe.part1" "Archipepsi-Crossing-D.exe.part2"
:play
start "" "%~dp0Archipepsi-Crossing-D.exe" -- --empty-yard
exit /b 0
:missing
echo Unzip BOTH parts (part1of2 and part2of2) into this same folder,
echo then run this again.
pause
exit /b 1
:broken
echo The joined game is %JOINED% bytes, not @SIZE@. Please download both
echo parts again.
del "Archipepsi-Crossing-D.exe"
pause
exit /b 1
