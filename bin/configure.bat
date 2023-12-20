

@echo off
setlocal enabledelayedexpansion

set /p CONF=please input your conf name:

rmdir /Q /S configs
md configs

cd template

set SCRIPT=../../extend/lmake/ltemplate.lua
set ENVIRON=../config/%CONF%.conf
for %%i in (*.conf) do (
    ..\lua.exe %SCRIPT% %%i ..\configs\%%i %ENVIRON%
)

pause

