

@echo off
setlocal enabledelayedexpansion

set /p CONF=please input your conf name:

rmdir /Q /S config
md config

cd template

set SCRIPT=../../extend/lmake/ltemplate.lua
set ENVIRON=../environ/%CONF%.conf
for %%i in (*.conf) do (
    ..\lua.exe %SCRIPT% %%i ..\config\%%i %ENVIRON%
)

pause

