@echo off
REM ===================================================================
REM  FIND GODOT, and remember where it was. Not for double-clicking.
REM
REM  `call "%~dp0_find-godot.bat"` and read `%GODOT%` afterwards; it is
REM  empty when nothing was found and the caller decides what to say.
REM  The answer is cached in `godot-path.txt`, which is gitignored: it
REM  is a fact about YOUR machine, not about the project.
REM
REM  THIS IS A COPY of the finder inside `_play-3ab.bat`, and that is a
REM  debt rather than a design. It was extracted here rather than
REM  extracted OUT of that file because `_play-3ab.bat` works, this
REM  container has no Windows to test a change to it on, and breaking
REM  the launcher somebody already relies on to tidy a duplication is a
REM  bad trade. The two must be changed together until someone can run
REM  the 3A/3B launcher on Windows and switch it over to this file.
REM
REM  NO DELAYED EXPANSION, DELIBERATELY, and everything that touches a
REM  path is at the TOP LEVEL: inside a parenthesised block a `"`
REM  changes how cmd parses the rest of the block, which is how a
REM  quoted path once survived being stripped and cmd was asked to run
REM  a command whose name was a quoted string.
REM ===================================================================
set GODOTFILE=%~dp0godot-path.txt
set GODOT=

if defined ARCHIPEPSI_GODOT set "GODOT=%ARCHIPEPSI_GODOT%"
if defined GODOT goto godotclean

if not exist "%GODOTFILE%" goto godotsearch
set /p GODOT=<"%GODOTFILE%"
if defined GODOT goto godotclean

:godotsearch
for /f "delims=" %%g in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%g"
call :findgodot "%LOCALAPPDATA%\Programs\Godot"
call :findgodot "%ProgramFiles%\Godot"
call :findgodot "%ProgramFiles(x86)%\Godot"
call :findgodot "%USERPROFILE%\Downloads"
call :findgodot "%USERPROFILE%\Desktop"
call :findgodot "%USERPROFILE%\Documents"
if defined GODOT goto godotclean

echo   I could not find Godot 4.5.1 on this machine.
echo.
echo   Drag the Godot .exe onto this window and press Enter, or type
echo   the full path to it. I will remember it for next time.
echo.
set "GODOT="
set /p GODOT=Godot .exe: 

:godotclean
if not defined GODOT goto :eof
REM Drag-and-drop wraps the path in quotes and often leaves a trailing
REM space. Both are removed HERE, at the top level.
set GODOT=%GODOT:"=%

:trimtail
if not "%GODOT:~-1%"==" " goto trimmed
set "GODOT=%GODOT:~0,-1%"
goto trimtail
:trimmed

if not exist "%GODOT%" goto notthere

REM IS IT ACTUALLY A FILE? `if exist` says yes to a directory, and the
REM Windows zip extracts to a FOLDER called
REM `Godot_v4.5.1-stable_win64.exe` with the real executables inside
REM it. Where the answer is a directory, look inside rather than refuse.
set ATTR=
for %%i in ("%GODOT%") do set "ATTR=%%~ai"
if /i not "%ATTR:~0,1%"=="d" goto godotisfile
set "GODOTDIR=%GODOT%"
set "GODOT="
call :findgodot "%GODOTDIR%"
if not defined GODOT goto :eof
goto godotclean

:godotisfile
> "%GODOTFILE%" echo %GODOT%
goto :eof

:notthere
set "GODOT="
goto :eof

:findgodot
if defined GODOT goto :eof
if not exist "%~1" goto :eof
REM /a-d = FILES ONLY, for the folder-named-like-an-exe above.
for /f "delims=" %%g in ('dir /b /s /a-d "%~1\Godot_v4.5*.exe" 2^>nul') do if not defined GODOT set "GODOT=%%g"
goto :eof
