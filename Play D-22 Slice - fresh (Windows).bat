@echo off
REM The D-22 slice from the beginning. The previous slice run's folder is
REM renamed aside (saves-d22-slice-<date>-<time>), never deleted.
call "%~dp0Play D-22 Slice (Windows).bat" --fresh
