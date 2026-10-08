@echo off
REM The diagnostic build. Starts the bundled bridge, then the game, and
REM stops the bridge when the game closes. Saves are kept in
REM %LOCALAPPDATA%\Archipepsi\Diagnostic Campaign, never in this folder.
start "" "%~dp0Archipepsi-Diagnostic.exe"
