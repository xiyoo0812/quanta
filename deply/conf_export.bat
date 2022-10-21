@echo off

chcp 65001

set LUA_PATH=!/../tools/excel2lua/?.lua;!/../script/?.lua;;

:: 解析xlsm文件为lua
..\bin\quanta.exe --entry=convertor  --input=./ --output=../server/config

pause

