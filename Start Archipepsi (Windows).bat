@echo off
REM ===================================================================
REM  Double-click this to start the Archipepsi bridge.
REM
REM  The bridge is the game's other half: it owns the campaign and talks
REM  to Archipelago. Godot renders and sends what you do. Neither works
REM  alone, and the game says BRIDGE OFFLINE until this is running.
REM
REM  Leave this window OPEN while you play. Close it when you are done.
REM ===================================================================
setlocal
cd /d "%~dp0"

echo.
echo   Archipepsi - starting the bridge
echo   -------------------------------
echo.

REM Find a Python. The `py` launcher ships with the python.org installer
REM and is the most reliable on Windows; `python` is the fallback, and
REM on a machine with no Python at all it opens the Microsoft Store
REM instead of failing, which is why `py` is tried first.
set PY=
where py >nul 2>&1 && set PY=py
if "%PY%"=="" (
  where python >nul 2>&1 && set PY=python
)
if "%PY%"=="" (
  echo   Python is not installed, or is not on your PATH.
  echo.
  echo   Install it from https://www.python.org/downloads/
  echo   and tick "Add python.exe to PATH" on the first screen.
  echo.
  pause
  exit /b 1
)

REM The two libraries the bridge needs. Quiet if they are already there.
%PY% -c "import pydantic, websockets" >nul 2>&1
if errorlevel 1 (
  echo   Installing the two libraries the bridge needs...
  echo.
  %PY% -m pip install --quiet pydantic websockets
  if errorlevel 1 (
    echo.
    echo   That failed. Try running this by hand to see why:
    echo       %PY% -m pip install pydantic websockets
    echo.
    pause
    exit /b 1
  )
  echo   Done.
  echo.
)

echo   Starting. Leave this window open, then press MOCK CAMPAIGN
echo   in the game.
echo.

cd bridge
%PY% -m archipepsi_bridge --ap=mock --epsilon=fallback

REM Only reached if the bridge stops or crashes. Without the pause the
REM window vanishes and takes the error message with it, which is the
REM single most common way a .bat file wastes somebody's afternoon.
echo.
echo   The bridge has stopped. Any error is printed above.
echo.
pause
