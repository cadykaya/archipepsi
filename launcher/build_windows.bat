@echo off
rem Builds dist\ArchipepsiLauncher.exe on Windows. Needs Python 3.9+ from
rem python.org (with Tcl/Tk, the installer's default). Run from this folder.
cd /d "%~dp0"
py -3 -m pip install --upgrade "pyinstaller==6.11.1" || goto fail
py -3 -m unittest discover -s tests -t . || goto fail
py -3 -m PyInstaller --noconfirm --clean --onefile --windowed ^
  --name ArchipepsiLauncher ArchipepsiLauncher.pyw || goto fail
echo.
echo Built dist\ArchipepsiLauncher.exe
pause
exit /b 0
:fail
echo Build failed.
pause
exit /b 1
