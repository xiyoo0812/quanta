

@echo off
setlocal enabledelayedexpansion

set /p CONF=please input your conf name:

set RootDir=%~dp0

set ConfDir=%RootDir%quanta
rmdir /Q /S %ConfDir%
md %ConfDir%

set TplDir=%RootDir%template
cd %TplDir%

set SCRIPT=../../extend/lmake/ltemplate.lua
set ENVIRON=../config/%CONF%.conf
for %%i in (*.conf) do (
    ..\lua.exe %SCRIPT% %%i %ConfDir%\%%i %ENVIRON%
)

pause

