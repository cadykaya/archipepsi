#!/usr/bin/env bash
# Builds dist/ArchipepsiLauncher.exe from Linux, with Windows Python under
# Wine (how the delivered executable was made; on Windows, use
# build_windows.bat instead). Needs: wine (64-bit), msitools, curl.
#
#   ./build_with_wine.sh            # prefix in ./.wine-build
set -eo pipefail
cd "$(dirname "$0")"
PY_VER=3.12.10
export WINEPREFIX="${WINEPREFIX:-$PWD/.wine-build}" WINEDEBUG=-all
PY="$WINEPREFIX/drive_c/Py312"
if [ ! -x "$PY/python.exe" ]; then
	mkdir -p "$PY" .wine-build-dl
	for m in core exe lib tcltk; do
		curl -sSfL -o ".wine-build-dl/$m.msi" \
			"https://www.python.org/ftp/python/$PY_VER/amd64/$m.msi"
		msiextract -C "$PY" ".wine-build-dl/$m.msi" >/dev/null
	done
	wine 'C:\Py312\python.exe' -m ensurepip
	wine 'C:\Py312\python.exe' -m pip install pyinstaller==6.11.1
fi
# Windows Python under Wine cannot write to a redirected file handle, so
# its output always goes through a pipe.
wine 'C:\Py312\python.exe' -m unittest discover -s tests -t . 2>&1 | cat
wine 'C:\Py312\python.exe' -m PyInstaller --noconfirm --clean --onefile \
	--windowed --name ArchipepsiLauncher ArchipepsiLauncher.pyw 2>&1 | cat
sha256sum dist/ArchipepsiLauncher.exe
