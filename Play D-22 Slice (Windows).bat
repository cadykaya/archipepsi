@echo off
REM ===================================================================
REM  ARCHIPEPSI - D-22 SLICE (prototype Crossing loop, offline)
REM
REM  Double-click to play (or resume) the slice:
REM    Station 1 -> Forge -> Crossing 1 -> leave/resume -> untether
REM    -> station area 2 -> Forge -> Crossing 2 -> STOP
REM
REM  Mock Archipelago, prototype scale, fallback Epsilon. Its saves are
REM  in "saves-d22-slice" here; bridge\saves is never touched. Close the
REM  ordinary game's bridge first. "Play D-22 Slice - fresh" starts over
REM  (the old slice folder is renamed aside, never deleted).
REM ===================================================================
setlocal
cd /d "%~dp0"
chcp 65001 >nul 2>&1

set PY=
where py >nul 2>&1 && set PY=py
if "%PY%"=="" (
  where python >nul 2>&1 && set PY=python
)
if "%PY%"=="" (
  echo   Python is not installed, or is not on your PATH.
  echo   Install it from https://www.python.org/downloads/
  pause
  exit /b 1
)
%PY% -c "import pydantic, websockets" >nul 2>&1 || %PY% -m pip install --quiet pydantic websockets

call "%~dp0_find-godot.bat"
if not defined GODOT (
  echo   Godot 4.5.1 was not found. See _find-godot.bat.
  pause
  exit /b 1
)

%PY% "%~dp0tools\d22_slice_launch.py" --godot "%GODOT%" %*
echo.
pause
