@echo off
REM ARCHIPEPSI - D-22 SLICE review build. Double-click to play or resume.
REM Needs Python 3 (python.org, "Add python.exe to PATH"). Saves go in
REM "saves-d22-slice" in this folder and nowhere else.
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
  echo   and tick "Add python.exe to PATH" on the first screen.
  pause
  exit /b 1
)
%PY% -c "import pydantic, websockets" >nul 2>&1 || %PY% -m pip install --quiet pydantic websockets
%PY% "%~dp0tools\d22_slice_launch.py" --godot "%~dp0Archipepsi-D22-Slice.exe" %*
echo.
pause
