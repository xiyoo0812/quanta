@echo off
setlocal enabledelayedexpansion

rem Usage: setup.bat  (then input conf name and env interactively)
rem Env: develop|release. Binaries are copied from bin\<env> into bin.

set /p MODE=please input your env (develop/release):

if /i "%MODE%"=="develop" set "MODE=develop"
if /i "%MODE%"=="release" set "MODE=release"
if not "%MODE%"=="develop" if not "%MODE%"=="release" (
    echo invalid env: %MODE%, expect develop or release
    exit /b 1
)

rem copy binaries first, so the local lua.exe comes from the selected env
set "SRC=%~dp0%MODE%"
set "DST=%~dp0"
if not exist "%SRC%\" (
    echo build directory not found: %SRC%
    exit /b 1
)
dir /b "%SRC%\*.*" >nul 2>&1
if errorlevel 1 (
    echo no binaries found in %SRC%
    exit /b 1
)
copy /y "%SRC%\*.*" "%DST%" >nul
if errorlevel 1 (
    echo copy binaries from %SRC% failed
    exit /b 1
)
echo copied binaries from %SRC% to %DST%

pause
