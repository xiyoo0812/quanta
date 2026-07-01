@echo off

chcp 65001

:: 解析xlsm文件为lua

set LUA_PATH=!/../tools/excel2lua/?.lua;;

..\bin\quanta.exe --entry=excel2lua --input=./cfg_xls --output=./config

pause

