@echo off
REM ===================================================================
REM  Double-click this to get the latest Archipepsi.
REM
REM  This replaces the download-a-zip-and-erase-the-old-folder dance.
REM  It only fetches what actually changed, and -- the part that
REM  matters -- it does NOT touch your saves in bridge\saves, your
REM  settings, or Godot's import cache. Erasing the folder deletes all
REM  three, which is a campaign lost every time you update.
REM
REM  The folder path never changes either, so Godot keeps pointing at
REM  the right place and you never re-open the project.
REM ===================================================================
setlocal
cd /d "%~dp0"

echo.
echo   Archipepsi - getting the latest version
echo   --------------------------------------
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo   Git is not installed, so this script cannot update anything.
    echo.
    echo   The easiest fix is GitHub Desktop, which includes Git:
    echo     https://desktop.github.com
    echo.
    echo   Install it, then use "Clone a repository" on cadykaya/archipepsi
    echo   and this script will work from then on.
    echo.
    pause
    exit /b 1
)

REM A folder unpacked from a zip is not a repository -- there is no
REM history to update against, so `git pull` cannot work. Say that
REM plainly rather than printing git's own wording for it.
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo   This folder came from a zip, not from Git, so there is
    echo   nothing to update against.
    echo.
    echo   To switch over, clone the repository once:
    echo     git clone https://github.com/cadykaya/archipepsi.git
    echo.
    echo   ...or use GitHub Desktop's "Clone a repository". After that,
    echo   this script updates you in one double-click, forever.
    echo.
    pause
    exit /b 1
)

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set BRANCH=%%b
echo   Branch: %BRANCH%
echo.

REM Warn before pulling rather than after: a pull onto edited files
REM stops halfway with a message about merging, which is alarming and
REM hard to undo if you do not already know Git.
REM
REM But check for REAL edits first. Godot rewrites godot\project.godot
REM every time it opens the project -- a version stamp, a feature list --
REM so treating that as "you edited files" would block every update you
REM ever run, for a file you never touched.
git diff --quiet -- . ":(exclude)godot/project.godot"
if errorlevel 1 (
    echo   Some files here differ from the version on GitHub, so nothing
    echo   has been done. If you did not edit these on purpose, tell
    echo   Claude what this says.
    echo.
    git diff --stat -- . ":(exclude)godot/project.godot"
    echo.
    pause
    exit /b 1
)

REM Only Godot's own churn is left, if anything. Reset it rather than
REM stopping: the repository's copy is the real project definition, and
REM your settings and key bindings are not kept in this file -- they live
REM in Godot's user folder and are untouched by any of this.
git diff --quiet -- godot/project.godot
if errorlevel 1 (
    echo   Godot rewrote godot\project.godot when it opened the project.
    echo   That is normal and not something you did; resetting it.
    echo.
    git checkout -- godot/project.godot
)

git pull --ff-only origin %BRANCH%
if errorlevel 1 (
    echo.
    echo   The update did not go through. The usual cause is that the
    echo   branch history was rewritten, which a fast-forward refuses on
    echo   purpose rather than throwing your copy away.
    echo.
    echo   Paste the message above to Claude and it will tell you what
    echo   happened.
    echo.
    pause
    exit /b 1
)

echo.
echo   Up to date. Your saves and settings were left alone.
echo.
echo   Now double-click "Start Archipepsi (Windows).bat", then open
echo   the project in Godot as usual.
echo.
pause
