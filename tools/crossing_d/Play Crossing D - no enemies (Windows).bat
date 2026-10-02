@echo off
rem Crossing D review build: the same four rooms, the Upper Yard empty.
rem The plain executable is the full Crossing, enemies included.
cd /d "%~dp0"
start "" "%~dp0Archipepsi-Crossing-D.exe" -- --empty-yard
