@echo off

chcp 65001

:: 解析xlsm文件为lua

set LUA_PATH=!/../tools/validate/?.lua;;

..\bin\quanta.exe --entry=validate --input=../server/config

pause

