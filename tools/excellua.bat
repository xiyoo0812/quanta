@echo off

chcp 65001

:: 解析xlsm文件为lua

set LUA_PATH=!/../tools/excel2lua/?.lua;!/../script/?.lua;;

..\bin\quanta.exe --entry=convertor --input=./cfg_xls --output=./config

pause

